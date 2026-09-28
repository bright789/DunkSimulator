-- Dunk Pass claims (SeasonConfig). The client sends SeasonRequest("Claim", tier, "Free" or
-- "Premium") or ("ClaimAll"). The server checks the tier is reached, isn't claimed yet and,
-- for the premium track, that the season's pass is owned (premium tiers reached before buying
-- the pass can be claimed later). It marks the tier claimed first, then pays; if paying fails
-- the claim is undone. Replies on the same remote: ("Claimed", { labels }) or
-- ("Result", ok, message). XP itself comes from SeasonXp.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.SeasonConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local CrewConfig = require(ReplicatedStorage.Shared.Config.CrewConfig)
local LockerConfig = require(ReplicatedStorage.Shared.Config.LockerConfig)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local DailyService = require(script.Parent.DailyService)
local LockerService = require(script.Parent.LockerService)
local CrewService = require(script.Parent.CrewService)
local SeasonXp = require(script.Parent.SeasonXp)
local Analytics = require(script.Parent.AnalyticsReporter)

local SeasonService = {}
local initialized = false
local remote: RemoteEvent
local nextRequest: { [Player]: number } = {}

local function commas(value: number): string
	local text = string.format("%.0f", value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return text
end

local function reply(player: Player, ok: boolean, message: string)
	if player.Parent == Players then remote:FireClient(player, "Result", ok, message) end
end

-- Pays one reward. Returns a short label for the reply, or nil if it couldn't be paid.
local function pay(player: Player, reward): string?
	if reward.Cash then
		local cash = reward.Cash * Daily.DunkValue(PlayerService.GetVertical(player) or 0)
		return PlayerService.GrantCash(player, cash, "DunkPass", "Gameplay") and ("+$" .. commas(cash)) or nil
	elseif reward.Boost then
		return DailyService.GrantBoost(player, reward.Boost) and string.format("2x Cash %d min", reward.Boost) or nil
	elseif reward.Pack then
		local result = CrewService.GrantPack(player)
		return result and ("Crew: " .. CrewConfig.Members[result.Id].Name) or nil
	elseif reward.Shoe then
		local item = LockerConfig.Get("Shoes", reward.Shoe)
		return item and LockerService.GrantItem(player, "Shoes", reward.Shoe) and item.Name or nil
	elseif reward.Ball then
		local item = LockerConfig.Get("Balls", reward.Ball)
		return item and LockerService.GrantItem(player, "Balls", reward.Ball) and (item.Name .. " ball") or nil
	elseif reward.Crew then
		local member = CrewConfig.GetMember(reward.Crew)
		return member and CrewService.GrantMember(player, reward.Crew) and member.Name or nil
	end
	return nil
end

-- Claims one tier on one track. Returns the reward label, or nil and a reason.
local function claimOne(player: Player, record, season, tier: number, track: string): (string?, string?)
	if tier % 1 ~= 0 or tier < 1 or tier > Config.MaxTiers then return nil, "Unknown tier." end
	if tier > Config.TierForXp(record.Xp) then return nil, string.format("Reach tier %d first.", tier) end
	local list = track == "Premium" and record.Premium or record.Free
	if table.find(list, tier) then return nil, "Already claimed." end
	if track == "Premium" and not PlayerService.HasPass(player, season.PassKey) then
		return nil, "That reward needs the Dunk Pass."
	end
	local reward = (track == "Premium" and season.Premium or season.Free)[tier]
	if not reward then return nil, "No reward on that tier." end
	table.insert(list, tier)
	table.sort(list)
	local label = pay(player, reward)
	if not label then
		local index = table.find(list, tier)
		if index then table.remove(list, index) end
		return nil, "Couldn't pay that reward. Try again."
	end
	Analytics.Custom(player, track == "Premium" and "DunkPassClaimPremium" or "DunkPassClaimFree", tier)
	return label
end

local function handle(player: Player, action, tier, track)
	local record, season = SeasonXp.Record(player)
	if not record or not season then return reply(player, false, "No Dunk Pass season is running right now.") end
	local labels = {}
	if action == "Claim" then
		if type(tier) ~= "number" or tier ~= tier or (track ~= "Free" and track ~= "Premium") then return end
		local label, problem = claimOne(player, record, season, tier, track)
		if not label then return reply(player, false, problem :: string) end
		table.insert(labels, label)
	elseif action == "ClaimAll" then
		local reached = Config.TierForXp(record.Xp)
		local premium = PlayerService.HasPass(player, season.PassKey)
		for t = 1, reached do
			if not table.find(record.Free, t) then
				local label = claimOne(player, record, season, t, "Free")
				if label then table.insert(labels, label) end
			end
			if premium and not table.find(record.Premium, t) then
				local label = claimOne(player, record, season, t, "Premium")
				if label then table.insert(labels, label) end
			end
		end
		if #labels == 0 then return reply(player, false, "Nothing to claim yet. Keep dunking!") end
	else
		return
	end
	SeasonXp.Publish(player)
	DataService.RequestSave(player)
	if player.Parent == Players then remote:FireClient(player, "Claimed", labels) end
end

function SeasonService.OnPlayerReady(player: Player)
	SeasonXp.Publish(player)
end

function SeasonService.Init()
	if initialized then return end
	initialized = true
	remote = ReplicatedStorage.Remotes:WaitForChild("SeasonRequest")
	remote.OnServerEvent:Connect(function(player, action, tier, track, ...)
		if type(action) ~= "string" or select("#", ...) ~= 0 or not PlayerService.IsDataReady(player) then return end
		if os.clock() < (nextRequest[player] or 0) then return end
		nextRequest[player] = os.clock() + Config.RequestCooldownSeconds
		local ok, problem = pcall(handle, player, action, tier, track)
		if not ok then
			warn("[SeasonService] " .. action .. " failed: " .. tostring(problem))
			reply(player, false, "Try again.")
		end
	end)
	Players.PlayerRemoving:Connect(function(player) nextRequest[player] = nil end)
end

return SeasonService
