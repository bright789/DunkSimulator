-- Abilities (AbilityConfig): Slow-Mo Slam, Fireball and Hang Time. Levels are saved in the
-- player's profile (PlayerService "Abilities", schema v12); cooldowns and the ARMED flag
-- live here only (not saved). The client sends AbilityRequest("Use" | "Unlock" | "Upgrade",
-- abilityId) and the server answers on the same remote with (ok, message, abilityId).
--   Earned: reaching an ability's UnlockVertical gives level 1 for free.
--   Bought: UnlockPrice Cash unlocks it early; UpgradePrices buy levels 2-5 (shorter cooldowns).
--   Use:    arms it (the next completed dunk uses it) and starts the cooldown.
-- State for the HUD is mirrored to AbilityLevel_<id>, AbilityReadyAt_<id> (server time from
-- Workspace:GetServerTimeNow) and AbilityArmed_<id> attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.AbilityConfig)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.AnalyticsReporter)

local AbilityService = {}
local initialized = false
local remote: RemoteEvent
local runtime: { [Player]: { ReadyAt: { [string]: number }, Armed: { [string]: boolean }, NextRequest: number } } = {}
local watchers: { [Player]: RBXScriptConnection } = {}

local function commas(value: number): string
	local text = string.format("%.0f", value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return text
end

local function getRuntime(player: Player)
	local entry = runtime[player]
	if not entry then
		entry = { ReadyAt = {}, Armed = {}, NextRequest = 0 }
		runtime[player] = entry
	end
	return entry
end

local function publish(player: Player)
	local levels = PlayerService.GetAbilities(player)
	if not levels or player.Parent ~= Players then return end
	local entry = getRuntime(player)
	for abilityId in Config.Abilities do
		player:SetAttribute("AbilityLevel_" .. abilityId, levels[abilityId] or 0)
		player:SetAttribute("AbilityReadyAt_" .. abilityId, entry.ReadyAt[abilityId] or 0)
		player:SetAttribute("AbilityArmed_" .. abilityId, entry.Armed[abilityId] == true)
	end
end

-- Takes Cash for a purchase. Returns false and a reason when it can't.
local function spend(player: Player, price: number, sku: string): (boolean, string?)
	if (PlayerService.GetCash(player) or 0) < price then return false, "Not enough Cash." end
	if not PlayerService.SpendCash(player, price, sku) then return false, "Try again in a moment." end
	return true, nil
end

local function reply(player: Player, ok: boolean, message: string, abilityId: string?)
	if player.Parent == Players then remote:FireClient(player, ok, message, abilityId) end
end

-- Earned unlocks: reaching an ability's Vertical gives level 1 for free.
local function checkEarned(player: Player)
	local levels = PlayerService.GetAbilities(player)
	local vertical = PlayerService.GetVertical(player)
	if not levels or not vertical then return end
	local changed = false
	for _, abilityId in Config.Ids() do
		local definition = Config.Abilities[abilityId]
		if (levels[abilityId] or 0) == 0 and vertical >= definition.UnlockVertical then
			levels[abilityId] = 1
			changed = true
			Analytics.Custom(player, "AbilityEarned_" .. abilityId)
			reply(player, true, string.format("%s UNLOCKED!\nPress %s to use it.", definition.DisplayName, definition.KeyLabel), abilityId)
		end
	end
	if changed then
		publish(player)
		DataService.RequestSave(player)
	end
end

local function unlock(player: Player, abilityId: string, definition)
	local levels = PlayerService.GetAbilities(player)
	if not levels then return reply(player, false, "Player data is not ready.", abilityId) end
	if levels[abilityId] > 0 then return reply(player, false, "Already unlocked.", abilityId) end
	local paid, problem = spend(player, definition.UnlockPrice, "Ability_" .. abilityId)
	if not paid then return reply(player, false, problem :: string, abilityId) end
	levels[abilityId] = 1
	publish(player)
	DataService.RequestSave(player)
	Analytics.Custom(player, "AbilityBought_" .. abilityId)
	reply(player, true, string.format("%s UNLOCKED!\nPress %s to use it.", definition.DisplayName, definition.KeyLabel), abilityId)
end

local function upgrade(player: Player, abilityId: string, definition)
	local levels = PlayerService.GetAbilities(player)
	if not levels then return reply(player, false, "Player data is not ready.", abilityId) end
	local level = levels[abilityId]
	if level < 1 then return reply(player, false, "Unlock it first.", abilityId) end
	local price = Config.UpgradePrice(abilityId, level)
	if not price then return reply(player, false, "Max level.", abilityId) end
	local paid, problem = spend(player, price, string.format("Ability_%s_L%d", abilityId, level + 1))
	if not paid then return reply(player, false, problem :: string, abilityId) end
	levels[abilityId] = level + 1
	-- A shorter cooldown also applies to a recharge that is already running.
	local entry = getRuntime(player)
	local now = Workspace:GetServerTimeNow()
	if entry.ReadyAt[abilityId] then
		entry.ReadyAt[abilityId] = math.min(entry.ReadyAt[abilityId], now + Config.Cooldown(abilityId, level + 1))
	end
	publish(player)
	DataService.RequestSave(player)
	reply(player, true, string.format("%s LEVEL %d!\nRecharge %ds  (-$%s)", definition.DisplayName, level + 1,
		Config.Cooldown(abilityId, level + 1), commas(price)), abilityId)
end

local function use(player: Player, abilityId: string, definition)
	local levels = PlayerService.GetAbilities(player)
	if not levels then return reply(player, false, "Player data is not ready.", abilityId) end
	local level = levels[abilityId]
	if level < 1 then
		return reply(player, false, string.format("%s unlocks at %d Vertical.", definition.DisplayName, definition.UnlockVertical), abilityId)
	end
	local entry = getRuntime(player)
	if entry.Armed[abilityId] then return reply(player, false, "Already armed. Dunk to use it!", abilityId) end
	local now = Workspace:GetServerTimeNow()
	local readyAt = entry.ReadyAt[abilityId] or 0
	if now < readyAt - 0.1 then
		return reply(player, false, string.format("Recharging (%ds)", math.ceil(readyAt - now)), abilityId)
	end
	entry.Armed[abilityId] = true
	entry.ReadyAt[abilityId] = now + Config.Cooldown(abilityId, level)
	publish(player)
	Analytics.Custom(player, "AbilityUsed_" .. abilityId)
	reply(player, true, definition.DisplayName .. " ARMED!", abilityId)
end

-- The abilities armed right now (a copy). DunkService takes this when a dunk starts, so
-- anything armed mid-dunk waits for the next one.
function AbilityService.ArmedFor(player: Player): { [string]: boolean }
	local entry = runtime[player]
	return entry and table.clone(entry.Armed) or {}
end

-- Dunk Cash multiplier for a set from ArmedFor (Fireball).
function AbilityService.CashMultiplier(armed: { [string]: boolean }): number
	return armed.Fireball and Config.Abilities.Fireball.CashMultiplier or 1
end

-- A dunk that used these abilities completed: disarm them.
function AbilityService.Consume(player: Player, armed: { [string]: boolean })
	local entry = runtime[player]
	if not entry or next(armed) == nil then return end
	for abilityId in armed do entry.Armed[abilityId] = nil end
	publish(player)
end

function AbilityService.OnPlayerReady(player: Player)
	publish(player)
	checkEarned(player)
	-- Vertical grows by training; re-check earned unlocks whenever it changes.
	local stats = player:FindFirstChild("leaderstats")
	local vertical = stats and stats:FindFirstChild("Vertical")
	if vertical and vertical:IsA("IntValue") then
		if watchers[player] then watchers[player]:Disconnect() end
		watchers[player] = vertical.Changed:Connect(function() checkEarned(player) end)
	end
end

local ACTIONS = { Use = use, Unlock = unlock, Upgrade = upgrade }

function AbilityService.Init()
	if initialized then return end
	initialized = true
	remote = ReplicatedStorage.Remotes:WaitForChild("AbilityRequest")
	remote.OnServerEvent:Connect(function(player, action, abilityId, ...)
		local handler = type(action) == "string" and ACTIONS[action]
		local definition = Config.Get(abilityId)
		if not handler or not definition or select("#", ...) ~= 0 or not PlayerService.IsDataReady(player) then return end
		local entry = getRuntime(player)
		if os.clock() < entry.NextRequest then return end
		entry.NextRequest = os.clock() + Config.RequestCooldownSeconds
		local done, problem = pcall(handler, player, abilityId, definition)
		if not done then
			warn("[AbilityService] " .. action .. " failed: " .. tostring(problem))
			reply(player, false, "Try again.", abilityId)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		runtime[player] = nil
		if watchers[player] then watchers[player]:Disconnect() end
		watchers[player] = nil
	end)
end

return AbilityService
