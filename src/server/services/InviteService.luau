-- Friends and invites (SocialConfig): the friends-in-server Cash bonus and one-time referral
-- rewards for invites sent with the INVITE button. Server-authoritative:
--   * Friend checks use Player:IsFriendsWith on the server; the bonus is applied inside
--     PlayerService.RegisterDunk / AwardDunkTrick.
--   * A player who joins with "ref:<id>" launch data credits that inviter once, and only if
--     they are a fresh player (no dunks, no Rebirth), their account is old enough, they are
--     friends with the inviter, and they never credited anyone before (recorded in the
--     referral DataStore). Inviters earn at most MaxInviterRewardsPerDay rewards per UTC day;
--     rewards for an offline inviter wait in the store until their next join.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.SocialConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local DataConfig = require(script.Parent.Parent.Config.DataConfig)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local DailyService = require(script.Parent.DailyService)
local Analytics = require(script.Parent.AnalyticsReporter)

local InviteService = {}
local isStudio = RunService:IsStudio()
local initialized = false
local store: DataStore? = nil
local friends: { [Player]: { [Player]: boolean } } = {}
local notice: RemoteEvent

local function today(): number
	return math.floor(os.time() / 86400)
end

local function notify(player: Player, kind: string, data)
	if player.Parent == Players then notice:FireClient(player, kind, data) end
end

local function isFriend(player: Player, userId: number): boolean
	for attempt = 1, 3 do
		local ok, result = pcall(player.IsFriendsWith, player, userId)
		if ok then return result == true end
		task.wait(attempt)
	end
	return false
end

-- Recomputes one player's friend count and bonus.
local function updateBonus(player: Player)
	local set = friends[player]
	if not set then return end
	local count = 0
	for other in set do
		if other.Parent == Players then count += 1 end
	end
	if isStudio and Config.StudioPretendFriendsOnline > 0 then count = Config.StudioPretendFriendsOnline end
	local multiplier = Config.FriendMultiplier(count)
	PlayerService.SetFriendMultiplier(player, multiplier)
	player:SetAttribute("FriendsOnline", count)
	player:SetAttribute("FriendBonusPercent", math.floor((multiplier - 1) * 100 + 0.5))
end

local function trackFriends(player: Player)
	friends[player] = friends[player] or {}
	for other in friends do
		if other ~= player and other.Parent == Players and not friends[player][other] then
			if isFriend(player, other.UserId) and friends[other] and player.Parent == Players then
				friends[player][other] = true
				friends[other][player] = true
				updateBonus(other)
			end
		end
	end
	updateBonus(player)
end

-- Pays one inviter reward now: Cash worth InviterRewardDunks dunks at their Vertical plus a
-- Cash Boost. Returns false if their data isn't ready.
local function payInviter(inviter: Player, count: number, friendName: string?): boolean
	if not PlayerService.IsDataReady(inviter) or count <= 0 then return false end
	local cash = Config.InviterRewardDunks * Daily.DunkValue(PlayerService.GetVertical(inviter) or 0) * count
	local paid = PlayerService.GrantCash(inviter, cash, "InviteReward", "Gameplay")
	DailyService.GrantBoost(inviter, Config.InviterBoostMinutes * count)
	DataService.RequestSave(inviter)
	Analytics.Custom(inviter, "InviteRewarded", count)
	notify(inviter, "InviterReward", { Cash = paid and cash or 0, Minutes = Config.InviterBoostMinutes * count,
		Count = count, Friend = friendName })
	return true
end

-- Adds one reward to the inviter's record (counting toward today's cap). `pending` = the
-- inviter is offline, so the reward waits for their next join. Returns true if allowed.
local function recordInviterReward(inviterId: number, pending: boolean): boolean
	if not store then return false end
	local allowed = false
	local ok = pcall(function()
		store:UpdateAsync("Inviter_" .. inviterId, function(value)
			local record = type(value) == "table" and value or {}
			local day = today()
			if record.Day ~= day then
				record.Day = day
				record.DayCount = 0
			end
			record.DayCount = tonumber(record.DayCount) or 0
			record.Pending = tonumber(record.Pending) or 0
			if record.DayCount >= Config.MaxInviterRewardsPerDay then
				allowed = false
				return nil
			end
			allowed = true
			record.DayCount += 1
			if pending then record.Pending += 1 end
			return record
		end)
	end)
	return ok and allowed
end

-- Rewards waiting from while this inviter was offline.
local function claimPending(player: Player)
	if not store then return end
	local claimed = 0
	local ok = pcall(function()
		store:UpdateAsync("Inviter_" .. player.UserId, function(value)
			if type(value) ~= "table" or (tonumber(value.Pending) or 0) <= 0 then
				claimed = 0
				return nil
			end
			claimed = math.clamp(math.floor(tonumber(value.Pending) or 0), 0, Config.MaxInviterRewardsPerDay * 7)
			value.Pending = 0
			return value
		end)
	end)
	if ok and claimed > 0 and not payInviter(player, claimed, nil) then
		-- Data went away mid-claim: put them back for next time.
		pcall(function()
			store:UpdateAsync("Inviter_" .. player.UserId, function(value)
				local record = type(value) == "table" and value or {}
				record.Pending = (tonumber(record.Pending) or 0) + claimed
				return record
			end)
		end)
	end
end

local function readLaunchData(player: Player): string?
	if isStudio and type(Config.StudioLaunchData) == "string" then return Config.StudioLaunchData end
	for attempt = 1, Config.LaunchDataAttempts do
		local ok, joinData = pcall(player.GetJoinData, player)
		local data = ok and type(joinData) == "table" and joinData.LaunchData
		if type(data) == "string" and data ~= "" then return data end
		if attempt < Config.LaunchDataAttempts then task.wait(Config.LaunchDataRetrySeconds) end
		if player.Parent ~= Players then return nil end
	end
	return nil
end

local function handleReferral(player: Player)
	local data = readLaunchData(player)
	local inviterId = data and tonumber(string.match(data, "^" .. Config.LaunchPrefix .. "(%d+)$"))
	if not inviterId or inviterId == player.UserId or inviterId <= 0 or not store then return end
	Analytics.Custom(player, "JoinedFromInvite")
	local snapshot = PlayerService.GetMilestoneSnapshot(player)
	if not snapshot or snapshot.TotalDunks > 0 or snapshot.Rebirths > 0 then return end
	-- The Studio test launch data skips the friend and account-age checks (live servers never do).
	local studioTest = isStudio and type(Config.StudioLaunchData) == "string"
	if not studioTest and (player.AccountAge < Config.MinAccountAgeDays or not isFriend(player, inviterId)) then return end
	-- Claim this invitee once, forever.
	local fresh = false
	local claimed = pcall(function()
		store:UpdateAsync("Invitee_" .. player.UserId, function(value)
			if value ~= nil then
				fresh = false
				return nil
			end
			fresh = true
			return { InviterId = inviterId, At = os.time() }
		end)
	end)
	if not claimed or not fresh or player.Parent ~= Players then return end
	DailyService.GrantBoost(player, Config.InviteeBoostMinutes)
	DataService.RequestSave(player)
	local inviter = Players:GetPlayerByUserId(inviterId)
	notify(player, "InviteeReward", { Minutes = Config.InviteeBoostMinutes, Inviter = inviter and inviter.DisplayName or nil })
	local online = inviter ~= nil and PlayerService.IsDataReady(inviter)
	if recordInviterReward(inviterId, not online) and online and inviter then
		payInviter(inviter, 1, player.DisplayName)
	end
end

-- Called (in its own thread) once a player's data is ready.
function InviteService.OnPlayerReady(player: Player)
	trackFriends(player)
	claimPending(player)
	handleReferral(player)
end

function InviteService.Init()
	if initialized then return end
	initialized = true
	notice = ReplicatedStorage.Remotes:WaitForChild("SocialNotice")
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService,
		isStudio and DataConfig.StudioReferralStoreName or DataConfig.ProductionReferralStoreName)
	if ok then store = result else warn("[InviteService] Referral store unavailable: " .. tostring(result)) end
	Players.PlayerRemoving:Connect(function(player)
		local set = friends[player]
		friends[player] = nil
		if set then
			for other in set do
				if friends[other] then
					friends[other][player] = nil
					updateBonus(other)
				end
			end
		end
	end)
end

return InviteService
