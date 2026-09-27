-- Redeem codes (CodesConfig, server-only). The client sends CodeRequest("Redeem", text); the
-- server normalizes it, checks it exists, hasn't expired, isn't group-only for a non-member,
-- then claims it for this player in the codes DataStore (key = UserId, value = list of
-- redeemed codes) before paying, so each code pays once per player even across servers. If
-- paying fails the claim is released. The reply comes back on the same remote.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.Config.CodesConfig)
local DataConfig = require(script.Parent.Parent.Config.DataConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local DailyService = require(script.Parent.DailyService)
local Analytics = require(script.Parent.AnalyticsReporter)

local CodesService = {}
local initialized = false
local store: DataStore? = nil
local remote: RemoteEvent
local nextRequest: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}

local function commas(value: number): string
	local text = string.format("%.0f", value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return text
end

local function reply(player: Player, ok: boolean, message: string)
	if player.Parent == Players then remote:FireClient(player, ok, message) end
end

-- Adds (claim = true) or removes (claim = false) a code in the player's redeemed list.
-- Returns "claimed", "already" or nil on failure.
local function setClaim(player: Player, code: string, claim: boolean): string?
	if not store then return nil end
	local outcome = nil
	for attempt = 1, 3 do
		local ok = pcall(function()
			store:UpdateAsync(tostring(player.UserId), function(value)
				local list = type(value) == "table" and value or {}
				local has = table.find(list, code) ~= nil
				if claim then
					if has then
						outcome = "already"
						return nil
					end
					table.insert(list, code)
					outcome = "claimed"
					return list
				end
				local index = table.find(list, code)
				if index then table.remove(list, index) end
				outcome = "released"
				return list
			end)
		end)
		if ok then return outcome end
		task.wait(attempt)
	end
	return nil
end

local function redeem(player: Player, text: string)
	local code = string.upper((string.gsub(text, "%s", "")))
	local definition = Config.Codes[code]
	if not definition then return reply(player, false, "That code doesn't exist.") end
	if definition.Expires and os.time() >= definition.Expires then return reply(player, false, "That code has expired.") end
	if definition.GroupOnly and player:GetAttribute("InGroup") ~= true then
		return reply(player, false, "Join the Dunk Simulator group to use this code.")
	end
	local claim = setClaim(player, code, true)
	if claim == "already" then return reply(player, false, "You already used that code.") end
	if claim ~= "claimed" then return reply(player, false, "Codes are busy right now. Try again soon.") end
	local cash = (definition.Dunks or 0) * Daily.DunkValue(PlayerService.GetVertical(player) or 0)
	local paid = (cash <= 0 or PlayerService.GrantCash(player, cash, "Code_" .. code, "Onboarding"))
		and (not definition.BoostMinutes or DailyService.GrantBoost(player, definition.BoostMinutes))
	if not paid then
		setClaim(player, code, false)
		return reply(player, false, "Couldn't redeem that code right now. Try again.")
	end
	DataService.RequestSave(player)
	Analytics.Custom(player, "CodeRedeemed_" .. code)
	local parts = {}
	if cash > 0 then table.insert(parts, "+$" .. commas(cash)) end
	if definition.BoostMinutes then table.insert(parts, string.format("2x Cash for %d min", definition.BoostMinutes)) end
	reply(player, true, code .. " REDEEMED! " .. table.concat(parts, " and "))
end

function CodesService.Init()
	if initialized then return end
	initialized = true
	remote = ReplicatedStorage.Remotes:WaitForChild("CodeRequest")
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService,
		RunService:IsStudio() and DataConfig.StudioCodesStoreName or DataConfig.ProductionCodesStoreName)
	if ok then store = result else warn("[CodesService] Codes store unavailable: " .. tostring(result)) end
	remote.OnServerEvent:Connect(function(player, action, text, ...)
		if action ~= "Redeem" or type(text) ~= "string" or #text == 0 or #text > Config.MaxLength or select("#", ...) ~= 0 then return end
		if busy[player] or os.clock() < (nextRequest[player] or 0) or not PlayerService.IsDataReady(player) then return end
		nextRequest[player] = os.clock() + Config.RequestCooldownSeconds
		busy[player] = true
		local done, problem = pcall(redeem, player, text)
		if not done then
			warn("[CodesService] Redeem failed: " .. tostring(problem))
			reply(player, false, "Couldn't redeem that code right now. Try again.")
		end
		busy[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		nextRequest[player] = nil
		busy[player] = nil
	end)
end

return CodesService
