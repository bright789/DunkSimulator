-- Playtime gifts (GiftConfig): free rewards that open after 1, 3, 5, 8, 12, 20 and 30 minutes
-- played in this session. The server keeps each player's session clock (started when their
-- data loads) and claims in memory only: rejoining starts both over, and nothing is saved.
-- A client can only ask to read its gifts or claim one by its number; the server checks the
-- time itself and decides every reward (Cash priced in dunks, Cash Boost minutes, a free
-- Hype Crew pack). Where Hype Crew packs are restricted (CrewService.PacksRestricted) the
-- pack's price is paid as Cash instead, and the snapshot shows that Cash and no pack.
--   GiftRequest  client -> server: ("Read") or ("Claim", index)
--   GiftState    server -> client: (snapshot, result?) where snapshot is
--     { StartedAt, Gifts = { { Minutes, UnlockAt, Claimed, Cash, BoostMinutes, CrewPack } } }
--     (times are Workspace:GetServerTimeNow() seconds) and result is
--     { Kind = "Claimed", Index, Cash, BoostMinutes, CrewPack } or { Kind = "Rejected", Message }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.GiftConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local DailyService = require(script.Parent.DailyService)
local CrewService = require(script.Parent.CrewService)
local Analytics = require(script.Parent.AnalyticsReporter)

local GiftService = {}
local initialized = false
local stateRemote: RemoteEvent? = nil
-- This session's clock and claims, per player (not saved).
local sessions: { [Player]: { StartedAt: number, Claimed: { [number]: boolean } } } = {}
local processing: { [Player]: boolean } = {}
local nextClaim: { [Player]: number } = {}
local nextRead: { [Player]: number } = {}
local secondsPerMinute = (RunService:IsStudio() and Config.StudioFastGifts) and Config.StudioSecondsPerMinute or 60

local function unlockAt(session, index: number): number
	return session.StartedAt + Config.Gifts[index].Minutes * secondsPerMinute
end

-- True when this gift's crew pack is paid as Cash instead (packs restricted in the player's region).
local function packAsCash(player: Player, gift): boolean
	return gift.CrewPack == true and CrewService.PacksRestricted(player)
end

local function cashFor(player: Player, gift): number
	local cash = Config.Cash(gift, Daily.DunkValue(PlayerService.GetVertical(player) or 0))
	if packAsCash(player, gift) then cash += CrewService.BestPackPrice(player) end
	return cash
end

local function snapshot(player: Player, session)
	local gifts = {}
	for index, gift in Config.Gifts do
		gifts[index] = {
			Minutes = gift.Minutes,
			UnlockAt = unlockAt(session, index),
			Claimed = session.Claimed[index] == true,
			Cash = cashFor(player, gift),
			BoostMinutes = gift.BoostMinutes or 0,
			CrewPack = gift.CrewPack == true and not packAsCash(player, gift),
		}
	end
	return { StartedAt = session.StartedAt, Gifts = gifts }
end

local function publish(player: Player, result)
	local session = sessions[player]
	if not session or player.Parent ~= Players or not stateRemote then return end
	stateRemote:FireClient(player, snapshot(player, session), result)
end

-- Pays one gift. Returns the result for the client, or nil and a reason. Nothing yields.
local function claim(player: Player, index: number)
	local session = sessions[player]
	local gift = Config.Gifts[index]
	if not session or not gift or not PlayerService.IsDataReady(player) then return nil, "Gift unavailable." end
	if session.Claimed[index] then return nil, "Already claimed." end
	if Workspace:GetServerTimeNow() + Config.GraceSeconds < unlockAt(session, index) then
		return nil, "That gift isn't ready yet. Keep playing!"
	end
	local cash = cashFor(player, gift)
	if cash > 0 and not PlayerService.GrantCash(player, cash, "Gift_" .. index, "TimedReward") then
		return nil, "Reward unavailable."
	end
	session.Claimed[index] = true
	local boost = gift.BoostMinutes or 0
	if boost > 0 and not DailyService.GrantBoost(player, boost) then
		warn("[GiftService] Cash Boost not granted to " .. player.Name)
		boost = 0
	end
	local pack = false
	if gift.CrewPack and not packAsCash(player, gift) then
		pack = CrewService.GrantPack(player) ~= nil
		if not pack then warn("[GiftService] Crew pack not granted to " .. player.Name) end
	end
	Analytics.Custom(player, "GiftClaimed", index)
	return { Kind = "Claimed", Index = index, Cash = cash, BoostMinutes = boost, CrewPack = pack }
end

-- Called once the player's saved data has loaded: starts this session's gift clock.
function GiftService.OnPlayerReady(player: Player)
	if sessions[player] or player.Parent ~= Players then return end
	sessions[player] = { StartedAt = Workspace:GetServerTimeNow(), Claimed = {} }
	publish(player)
end

function GiftService.Init()
	if initialized then return end
	initialized = true
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild("GiftRequest")
	stateRemote = remotes:WaitForChild("GiftState")
	if RunService:IsStudio() and Config.StudioFastGifts then
		print(string.format("[GiftService] StudioFastGifts is on: a gift minute lasts %d s.", secondsPerMinute))
	end

	request.OnServerEvent:Connect(function(player, action, ...)
		if player.Parent ~= Players or not sessions[player] or not PlayerService.IsDataReady(player) then return end
		local extra = select("#", ...)
		local now = os.clock()
		if action == "Read" and extra == 0 then
			if now >= (nextRead[player] or 0) then
				nextRead[player] = now + Config.ReadCooldownSeconds
				publish(player)
			end
			return
		end
		local index = select(1, ...)
		local valid = action == "Claim" and extra == 1 and type(index) == "number" and index % 1 == 0
			and Config.Gifts[index] ~= nil
		if not valid or processing[player] or now < (nextClaim[player] or 0) then return end
		nextClaim[player] = now + Config.ClaimCooldownSeconds
		processing[player] = true
		local ok, result, problem = pcall(claim, player, index)
		processing[player] = nil
		if not ok then
			warn("[GiftService] Claim failed: " .. tostring(result))
			result, problem = nil, "Claim unavailable. Please try again."
		end
		if result then DataService.RequestSave(player) end
		publish(player, result or { Kind = "Rejected", Index = index, Message = problem })
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		processing[player] = nil
		nextClaim[player] = nil
		nextRead[player] = nil
	end)
end

return GiftService
