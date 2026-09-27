-- Daily login rewards, streaks and daily challenges. A "day" is a UTC calendar day counted
-- by the server (os.time() // SecondsPerDay). DailyService decides everything; clients
-- only display these numbers.
local DunkStyles = require(script.Parent.DunkStyles)
local DunkRewards = require(script.Parent.DunkRewards)
local Courts = require(script.Parent.CourtConfig)

local DailyConfig = {
	SecondsPerDay = 86400,
	ReadCooldownSeconds = 0.5,
	ClaimCooldownSeconds = 0.5,
	-- Rewards are priced in "dunks": the Cash one dunk of your best unlocked style earns at
	-- your Vertical (no court, rebirth, timing or boost bonus), so they stay worth claiming
	-- at every stage of the game.
	MinDunkValue = 10,
	-- 7-day login ladder. The streak keeps counting after day 7 and the ladder repeats.
	-- Missing a whole UTC day starts the streak over at day 1.
	Ladder = {
		{ Dunks = 4, MinCash = 50 },
		{ Dunks = 6, MinCash = 75 },
		{ Dunks = 8, MinCash = 100, BoostMinutes = 10 },
		{ Dunks = 10, MinCash = 125 },
		{ Dunks = 12, MinCash = 150 },
		{ Dunks = 15, MinCash = 200 },
		{ Dunks = 25, MinCash = 400, BoostMinutes = 30 },
	},
	-- Cash Boost: dunk and air-trick Cash x Multiplier while active. It runs in real time
	-- (also while offline) and stacks up to MaxMinutes.
	Boost = { Multiplier = 2, MaxMinutes = 60 },
	Challenges = {
		PerDay = 3,
		RewardDunks = 6,
		RewardMinCash = 75,
		-- Claiming all of today's challenges also starts a Cash Boost.
		SweepBoostMinutes = 15,
		-- Kind says what counts. Target is fixed, or TargetDunks prices it in dunks. A
		-- challenge is only rolled if the player can finish it (see DailyService).
		Pool = {
			dunks = { Kind = "Dunk", Title = "Dunk Session", Text = "Land %s dunks.", Target = 15 },
			perfects = { Kind = "Perfect", Title = "Perfect Timing", Text = "Hit %s PERFECT slams.", Target = 5 },
			tricks = { Kind = "Trick", Title = "Air Show", Text = "Land %s air tricks.", Target = 20, MinVertical = 60 },
			combos = { Kind = "Combo", Title = "Combo King", Text = "Land %s dunks with a 4+ trick combo.",
				Target = 3, MinTricks = 4, MinVertical = 130 },
			style = { Kind = "Style", Title = "Signature Move", Text = "Land %s %s dunks.", Target = 10 },
			court = { Kind = "Court", Title = "Road Trip", Text = "Land %s dunks at %s.", Target = 10 },
			training = { Kind = "Training", Title = "Leg Day", Text = "Finish %s training reps.", Target = 40 },
			cash = { Kind = "Cash", Title = "Money Maker", Text = "Earn $%s from dunks.", TargetDunks = 20 },
		},
	},
	-- Sanity bounds for saved values.
	MaxStreak = 100000,
	MaxDay = 10000000,
	MaxTime = 2 ^ 40,
	MaxTarget = 1e12,
	MaxReward = 1e12,
}

local function integer(value, minimum: number, maximum: number): number?
	if type(value) == "number" and value == value and math.abs(value) ~= math.huge then
		return math.clamp(math.floor(value), minimum, maximum)
	end
	return nil
end

function DailyConfig.PoolIds(): { string }
	local ids = {}
	for id in DailyConfig.Challenges.Pool do table.insert(ids, id) end
	table.sort(ids)
	return ids
end

-- Cash of one plain dunk with the best style this Vertical has unlocked.
function DailyConfig.DunkValue(vertical: number): number
	local best = DunkStyles.Get(DunkStyles.DefaultId)
	for _, styleId in DunkStyles.OrderedIds() do
		if DunkStyles.IsUnlocked(styleId, vertical) then best = DunkStyles.Get(styleId) end
	end
	return math.max(DailyConfig.MinDunkValue, DunkRewards.DunkCash(best.Reward, 1, vertical))
end

-- Ladder position (1-7) for a streak count (1, 2, ...).
function DailyConfig.CycleDay(streak: number): number
	return (math.max(streak, 1) - 1) % #DailyConfig.Ladder + 1
end

function DailyConfig.LadderCash(cycleDay: number, vertical: number): number
	local step = DailyConfig.Ladder[cycleDay]
	return math.max(step.MinCash, math.floor(step.Dunks * DailyConfig.DunkValue(vertical) + 0.5))
end

function DailyConfig.ChallengeReward(vertical: number): number
	local config = DailyConfig.Challenges
	return math.max(config.RewardMinCash, math.floor(config.RewardDunks * DailyConfig.DunkValue(vertical) + 0.5))
end

function DailyConfig.BoostMultiplier(boostUntil: number, now: number): number
	return now < boostUntil and DailyConfig.Boost.Multiplier or 1
end

-- New boost end time after adding some minutes (stacks, capped at MaxMinutes from now).
function DailyConfig.ExtendBoost(boostUntil: number, now: number, minutes: number): number
	return math.min(math.max(boostUntil, now) + minutes * 60, now + DailyConfig.Boost.MaxMinutes * 60)
end

-- Player-facing description of a rolled challenge.
function DailyConfig.Describe(entry): string
	local definition = DailyConfig.Challenges.Pool[entry.Id]
	if not definition then return "" end
	local amount = tostring(entry.Target):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	if definition.Kind == "Style" then
		local style = DunkStyles.Get(entry.Param)
		return string.format(definition.Text, amount, style and style.DisplayName or "?")
	elseif definition.Kind == "Court" then
		local court = Courts.Get(entry.Param)
		return string.format(definition.Text, amount, court and court.DisplayName or "?")
	end
	return string.format(definition.Text, amount)
end

function DailyConfig.DefaultState()
	return { Streak = 0, LastClaimDay = -1, BoostUntil = 0, ChallengeDay = -1, Challenges = {} }
end

function DailyConfig.CopyState(state)
	local copy = { Streak = state.Streak, LastClaimDay = state.LastClaimDay, BoostUntil = state.BoostUntil,
		ChallengeDay = state.ChallengeDay, Challenges = {} }
	for index, entry in state.Challenges do
		copy.Challenges[index] = { Id = entry.Id, Param = entry.Param, Target = entry.Target, Reward = entry.Reward,
			Progress = entry.Progress, Claimed = entry.Claimed }
	end
	return copy
end

function DailyConfig.SameState(first, second): boolean
	if type(first) ~= "table" or type(second) ~= "table" or first.Streak ~= second.Streak
		or first.LastClaimDay ~= second.LastClaimDay or first.BoostUntil ~= second.BoostUntil
		or first.ChallengeDay ~= second.ChallengeDay or type(first.Challenges) ~= "table"
		or type(second.Challenges) ~= "table" or #first.Challenges ~= #second.Challenges then
		return false
	end
	for index, entry in first.Challenges do
		local other = second.Challenges[index]
		if type(entry) ~= "table" or type(other) ~= "table" then return false end
		for _, field in { "Id", "Param", "Target", "Reward", "Progress", "Claimed" } do
			if entry[field] ~= other[field] then return false end
		end
	end
	for index in second.Challenges do
		if first.Challenges[index] == nil then return false end
	end
	return true
end

local function sanitizeEntry(entry)
	if type(entry) ~= "table" then return nil end
	local definition = DailyConfig.Challenges.Pool[entry.Id]
	if not definition then return nil end
	local param = ""
	if definition.Kind == "Style" then
		if not DunkStyles.Get(entry.Param) then return nil end
		param = entry.Param
	elseif definition.Kind == "Court" then
		if not Courts.Get(entry.Param) then return nil end
		param = entry.Param
	end
	local target = integer(entry.Target, 1, DailyConfig.MaxTarget)
	local reward = integer(entry.Reward, 0, DailyConfig.MaxReward)
	if not target or not reward then return nil end
	local claimed = entry.Claimed == true
	local progress = claimed and target or (integer(entry.Progress, 0, target) or 0)
	return { Id = entry.Id, Param = param, Target = target, Reward = reward, Progress = progress, Claimed = claimed }
end

-- Clean saved daily data. Returns (state, repaired).
function DailyConfig.Sanitize(stored)
	local state = DailyConfig.DefaultState()
	if type(stored) ~= "table" then return state, true end
	local repaired = false
	for name, bounds in {
		Streak = { 0, DailyConfig.MaxStreak },
		LastClaimDay = { -1, DailyConfig.MaxDay },
		BoostUntil = { 0, DailyConfig.MaxTime },
		ChallengeDay = { -1, DailyConfig.MaxDay },
	} do
		local value = integer(stored[name], bounds[1], bounds[2])
		if value == nil then value = state[name] end
		if value ~= stored[name] then repaired = true end
		state[name] = value
	end
	local entries = stored.Challenges
	if type(entries) ~= "table" then
		return state, true
	end
	for key in entries do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > DailyConfig.Challenges.PerDay then repaired = true end
	end
	for index = 1, DailyConfig.Challenges.PerDay do
		local original = entries[index]
		if original ~= nil then
			local clean = sanitizeEntry(original)
			if clean then
				table.insert(state.Challenges, clean)
				for field, value in clean do
					if original[field] ~= value then repaired = true end
				end
			end
			if not clean or #state.Challenges ~= index then repaired = true end
		end
	end
	return state, repaired
end

return DailyConfig
