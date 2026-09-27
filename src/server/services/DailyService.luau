-- Daily login rewards, streaks and daily challenges. The server owns the calendar (UTC
-- days from os.time()), the challenge rolls, progress and every payout. A client can only
-- ask to read its daily state, claim today's login reward, or claim a finished challenge
-- by its slot number (1-3).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.DailyConfig)
local DunkStyles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local Monetization = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)

local DailyService = {}
local initialized = false
local processing: { [Player]: boolean } = {}
local nextClaim: { [Player]: number } = {}
local nextRead: { [Player]: number } = {}
local poolIds = Config.PoolIds()
local stateRemote: RemoteEvent? = nil

-- 2x Daily Rewards pass multiplier for this player's daily Cash.
local function dailyMultiplier(player: Player): number
	return PlayerService.HasPass(player, "DoubleDaily") and Monetization.DoubleDailyMultiplier or 1
end

local function today(): number
	return math.floor(os.time() / Config.SecondsPerDay)
end

-- Options a pool challenge can be rolled with for this player ("" = no option); an empty
-- list means the player can't finish it right now, so it is never offered.
local function optionsFor(definition, context): { string }
	if definition.MinVertical and context.Vertical < definition.MinVertical then return {} end
	if definition.Kind == "Style" then
		local options = {}
		for _, styleId in DunkStyles.OrderedIds() do
			if DunkStyles.IsUnlocked(styleId, context.Vertical) then table.insert(options, styleId) end
		end
		return options
	elseif definition.Kind == "Court" then
		local options = {}
		for _, courtId in Courts.OrderedIds() do
			if courtId ~= Courts.StartingId and context.UnlockedCourts[courtId] then table.insert(options, courtId) end
		end
		return options
	elseif definition.Kind == "Training" then
		return context.Vertical < context.HighestTrainingCap and { "" } or {}
	end
	return { "" }
end

-- Rolls today's challenges: a fixed shuffle per player and day, priced at today's level.
local function roll(player: Player, daily, day: number)
	local context = PlayerService.GetDailyContext(player)
	if not context then return end
	local random = Random.new(day * 1000003 + math.abs(player.UserId) % 1000003)
	local candidates = {}
	for _, id in poolIds do
		local options = optionsFor(Config.Challenges.Pool[id], context)
		if #options > 0 then table.insert(candidates, { Id = id, Options = options }) end
	end
	for index = #candidates, 2, -1 do
		local swap = random:NextInteger(1, index)
		candidates[index], candidates[swap] = candidates[swap], candidates[index]
	end
	local dunkValue = Config.DunkValue(context.Vertical)
	local entries = {}
	for index = 1, math.min(Config.Challenges.PerDay, #candidates) do
		local pick = candidates[index]
		local definition = Config.Challenges.Pool[pick.Id]
		local target = definition.Target or math.max(1, math.floor(definition.TargetDunks * dunkValue + 0.5))
		table.insert(entries, {
			Id = pick.Id, Param = pick.Options[random:NextInteger(1, #pick.Options)], Target = target,
			Reward = Config.ChallengeReward(context.Vertical), Progress = 0, Claimed = false,
		})
	end
	daily.ChallengeDay = day
	daily.Challenges = entries
end

-- The live daily record, with today's challenges rolled if the day changed.
local function prepare(player: Player)
	local daily = PlayerService.GetDaily(player)
	if not daily then return nil, nil end
	local day = today()
	if daily.ChallengeDay ~= day then roll(player, daily, day) end
	return daily, day
end

local function snapshot(player: Player, daily, day: number)
	local vertical = PlayerService.GetVertical(player) or 0
	local canClaim = daily.LastClaimDay ~= day
	local continues = daily.LastClaimDay == day - 1
	local claimStreak = canClaim and (continues and daily.Streak + 1 or 1) or daily.Streak
	local ladder = {}
	for index, step in Config.Ladder do
		ladder[index] = { Cash = Config.LadderCash(index, vertical) * dailyMultiplier(player), BoostMinutes = step.BoostMinutes or 0 }
	end
	return {
		Day = day,
		ServerTime = os.time(),
		CanClaim = canClaim,
		Streak = daily.Streak,
		-- Ladder position of today's reward (claimable if CanClaim, else already claimed).
		ClaimDay = Config.CycleDay(claimStreak),
		ClaimStreak = claimStreak,
		StreakLost = canClaim and daily.Streak > 0 and not continues,
		Ladder = ladder,
		BoostUntil = daily.BoostUntil,
		BoostMultiplier = Config.Boost.Multiplier,
		SweepBoostMinutes = Config.Challenges.SweepBoostMinutes,
		Challenges = (function()
			-- Display copy: rewards shown as they will actually be paid.
			local challenges = Config.CopyState(daily).Challenges
			for _, entry in challenges do entry.Reward *= dailyMultiplier(player) end
			return challenges
		end)(),
	}
end

-- Sends the snapshot. Callers that already prepared today's record pass it (and its day)
-- so a UTC midnight tick in between can't re-roll away progress they just added.
local function publish(player: Player, result, readySlots, preparedDaily, preparedDay)
	if player.Parent ~= Players or not stateRemote then return end
	local daily, day = preparedDaily, preparedDay
	if not daily then daily, day = prepare(player) end
	if daily then
		stateRemote:FireClient(player, snapshot(player, daily, day), result, readySlots)
	end
end

local function extendBoost(player: Player, daily, minutes: number)
	if minutes > 0 then
		daily.BoostUntil = Config.ExtendBoost(daily.BoostUntil, os.time(), minutes)
		player:SetAttribute("CashBoostUntil", daily.BoostUntil)
	end
end

local function claimReward(player: Player)
	local daily, day = prepare(player)
	if not daily then return nil, "Daily rewards are unavailable." end
	if daily.LastClaimDay == day then return nil, "Already claimed today. Come back tomorrow!" end
	local streak = daily.LastClaimDay == day - 1 and math.min(daily.Streak + 1, Config.MaxStreak) or 1
	local cycleDay = Config.CycleDay(streak)
	local cash = Config.LadderCash(cycleDay, PlayerService.GetVertical(player) or 0) * dailyMultiplier(player)
	if not PlayerService.GrantCash(player, cash, "DailyLogin", "TimedReward") then return nil, "Reward unavailable." end
	daily.LastClaimDay = day
	daily.Streak = streak
	local boost = Config.Ladder[cycleDay].BoostMinutes or 0
	extendBoost(player, daily, boost)
	return { Kind = "Reward", Day = cycleDay, Streak = streak, Cash = cash, BoostMinutes = boost }
end

local function claimChallenge(player: Player, slot: number)
	local daily = prepare(player)
	local entry = daily and daily.Challenges[slot]
	if not entry then return nil, "Challenge unavailable." end
	if entry.Claimed then return nil, "Already claimed." end
	if entry.Progress < entry.Target then return nil, "Not finished yet." end
	local reward = entry.Reward * dailyMultiplier(player)
	if not PlayerService.GrantCash(player, reward, "DailyChallenge", "TimedReward") then return nil, "Reward unavailable." end
	entry.Claimed = true
	local sweep = true
	for _, other in daily.Challenges do
		if not other.Claimed then sweep = false end
	end
	local boost = sweep and Config.Challenges.SweepBoostMinutes or 0
	extendBoost(player, daily, boost)
	return { Kind = "Challenge", Slot = slot, Cash = reward, Sweep = sweep, BoostMinutes = boost }
end

-- Adds progress to today's matching challenges; `amountFor` returns how much an entry gets.
local function advance(player: Player, amountFor: (any, any) -> number, publishEvery: number?)
	local daily, day = prepare(player)
	if not daily then return end
	local ready, update = {}, false
	for slot, entry in daily.Challenges do
		local definition = Config.Challenges.Pool[entry.Id]
		if definition and not entry.Claimed and entry.Progress < entry.Target then
			local amount = amountFor(definition, entry)
			if type(amount) == "number" and amount >= 1 then
				entry.Progress = math.min(entry.Target, entry.Progress + math.floor(amount))
				update = update or not publishEvery or entry.Progress % publishEvery == 0
				if entry.Progress >= entry.Target then table.insert(ready, slot) end
			end
		end
	end
	if #ready > 0 then
		publish(player, nil, ready, daily, day)
	elseif update then
		publish(player, nil, nil, daily, day)
	end
end

-- Called by DunkService after a completed, rewarded dunk.
function DailyService.OnDunk(player: Player, info)
	if not PlayerService.IsDataReady(player) then return end
	advance(player, function(definition, entry)
		local kind = definition.Kind
		if kind == "Dunk" then return 1
		elseif kind == "Perfect" then return info.Rating == "Perfect" and 1 or 0
		elseif kind == "Trick" then return info.Tricks
		elseif kind == "Combo" then return info.Tricks >= definition.MinTricks and 1 or 0
		elseif kind == "Style" then return info.StyleId == entry.Param and 1 or 0
		elseif kind == "Court" then return info.CourtId == entry.Param and 1 or 0
		elseif kind == "Cash" then return info.Cash
		end
		return 0
	end)
end

-- Called by TrainingService for each rep that earned progress. Reps are frequent, so the
-- client is updated every few reps and when the challenge completes.
function DailyService.OnTrainingRep(player: Player)
	if not PlayerService.IsDataReady(player) then return end
	advance(player, function(definition)
		return definition.Kind == "Training" and 1 or 0
	end, 5)
end

-- Adds Cash Boost minutes (the Cash Boost developer product). Returns false if the
-- player's data isn't ready, so the purchase can be retried later.
function DailyService.GrantBoost(player: Player, minutes: number): boolean
	local daily = PlayerService.GetDaily(player)
	if not daily or type(minutes) ~= "number" or minutes <= 0 then return false end
	extendBoost(player, daily, math.floor(minutes))
	publish(player)
	return true
end

-- Re-sends the daily snapshot (e.g. after pass ownership changes the displayed rewards).
function DailyService.Refresh(player: Player)
	if PlayerService.IsDataReady(player) then publish(player) end
end

function DailyService.OnPlayerReady(player: Player)
	local daily = prepare(player)
	if daily then
		player:SetAttribute("CashBoostUntil", daily.BoostUntil)
		publish(player)
	end
end

function DailyService.Init()
	if initialized then return end
	initialized = true
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild("DailyRequest")
	stateRemote = remotes:WaitForChild("DailyState")

	request.OnServerEvent:Connect(function(player, action, ...)
		if player.Parent ~= Players or not PlayerService.IsDataReady(player) then return end
		local extra = select("#", ...)
		local now = os.clock()
		if action == "Read" and extra == 0 then
			if now >= (nextRead[player] or 0) then
				nextRead[player] = now + Config.ReadCooldownSeconds
				publish(player)
			end
			return
		end
		local slot = select(1, ...)
		local valid = (action == "Reward" and extra == 0) or (action == "Challenge" and extra == 1
			and type(slot) == "number" and slot % 1 == 0 and slot >= 1 and slot <= Config.Challenges.PerDay)
		if not valid or processing[player] or now < (nextClaim[player] or 0) then return end
		nextClaim[player] = now + Config.ClaimCooldownSeconds
		processing[player] = true
		local ok, result, problem = pcall(function()
			if action == "Reward" then return claimReward(player) end
			return claimChallenge(player, slot)
		end)
		processing[player] = nil
		if not ok then
			warn("[DailyService] Claim failed: " .. tostring(result))
			result, problem = nil, "Claim unavailable. Please try again."
		end
		if result then DataService.RequestSave(player) end
		publish(player, result or { Kind = "Rejected", Message = problem })
	end)
	Players.PlayerRemoving:Connect(function(player)
		processing[player] = nil
		nextClaim[player] = nil
		nextRead[player] = nil
	end)
end

return DailyService
