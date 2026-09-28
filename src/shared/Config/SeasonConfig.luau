-- Dunk Pass seasons (see docs/DUNK_PASS.md). XP from playing fills 30 tiers; every tier has a
-- FREE reward and a PREMIUM reward (needs the season's Robux pass, PassKey in
-- MonetizationConfig). Premium rewards can be claimed retroactively after buying the pass.
-- A new season resets XP and claims: the saved record carries the season Id. The server
-- decides and pays everything; clients only display it.
--
-- Reward kinds:
--   { Cash = N }      N dunks' worth of Cash (DailyConfig.DunkValue at your Vertical)
--   { Boost = M }     M minutes of 2x Cash
--   { Pack = true }   one free Hype Crew pack (the best pack your courts have unlocked)
--   { Shoe = id } / { Ball = id }   a Locker item (season exclusives have Season = "S1")
--   { Crew = id }     a Hype Crew member (season exclusives are in CrewConfig pack "Season1")
local SeasonConfig = {
	MaxTiers = 30,
	-- XP for each action (SeasonXp.Add). Dunk XP is Dunk + the grade bonus + AirTrick per trick.
	XP = {
		Dunk = 4,
		Perfect = 4,
		Good = 2,
		AirTrick = 1,
		PerfectRep = 1,
		GoldenBall = 25,
		CrewPack = 15,
		DailyChallenge = 50,
	},
	RequestCooldownSeconds = 0.3,
	Seasons = {
		{
			Id = "S1",
			Name = "LAUNCH SEASON",
			-- Monday 28 Sep 2026 00:00 UTC to Monday 2 Nov 2026 00:00 UTC.
			Starts = 1790553600,
			Ends = 1793577600,
			PassKey = "DunkPass",
			Free = {
				{ Cash = 8 }, { Pack = true }, { Boost = 10 }, { Cash = 12 }, { Pack = true },
				{ Cash = 15 }, { Boost = 15 }, { Pack = true }, { Cash = 20 }, { Ball = "launch_day" },
				{ Cash = 22 }, { Pack = true }, { Boost = 15 }, { Cash = 25 }, { Pack = true },
				{ Cash = 30 }, { Boost = 20 }, { Pack = true }, { Cash = 35 }, { Pack = true },
				{ Cash = 40 }, { Boost = 20 }, { Pack = true }, { Cash = 45 }, { Pack = true },
				{ Cash = 50 }, { Boost = 30 }, { Pack = true }, { Cash = 60 }, { Crew = "rookie_s1" },
			},
			Premium = {
				{ Shoe = "launch_jets" }, { Cash = 20 }, { Pack = true }, { Boost = 20 }, { Pack = true },
				{ Cash = 30 }, { Pack = true }, { Boost = 30 }, { Pack = true }, { Crew = "hype_man_s1" },
				{ Cash = 40 }, { Pack = true }, { Boost = 30 }, { Pack = true }, { Cash = 50 },
				{ Pack = true }, { Boost = 30 }, { Pack = true }, { Cash = 60 }, { Ball = "rocket" },
				{ Pack = true }, { Cash = 70 }, { Pack = true }, { Boost = 45 }, { Pack = true },
				{ Cash = 80 }, { Pack = true }, { Boost = 60 }, { Cash = 100 }, { Crew = "launch_legend" },
			},
		},
	},
}

-- XP needed to go from tier n-1 to tier n (tier 1 = 100 XP, each next tier +20).
function SeasonConfig.XpForTier(tier: number): number
	return 100 + 20 * (tier - 1)
end

-- Tier reached with `xp` (0 to MaxTiers), plus XP into the next tier and what it needs.
function SeasonConfig.TierForXp(xp: number): (number, number, number)
	local tier, remaining = 0, math.max(0, xp)
	while tier < SeasonConfig.MaxTiers do
		local need = SeasonConfig.XpForTier(tier + 1)
		if remaining < need then return tier, remaining, need end
		remaining -= need
		tier += 1
	end
	return tier, 0, 0
end

-- The season running at `unixTime` (nil between seasons).
function SeasonConfig.Current(unixTime: number)
	for _, season in SeasonConfig.Seasons do
		if unixTime >= season.Starts and unixTime < season.Ends then return season end
	end
	return nil
end

function SeasonConfig.Get(seasonId)
	for _, season in SeasonConfig.Seasons do
		if season.Id == seasonId then return season end
	end
	return nil
end

-- Saved record (schema v14): Id = season it belongs to, Xp, and the claimed tiers per track.
function SeasonConfig.DefaultState()
	return { Id = "", Xp = 0, Free = {}, Premium = {} }
end

local function cleanTiers(list): ({ number }, boolean)
	local clean, seen, repaired = {}, {}, type(list) ~= "table"
	if type(list) == "table" then
		for _, tier in list do
			if type(tier) == "number" and tier == tier and tier % 1 == 0 and tier >= 1 and tier <= SeasonConfig.MaxTiers
				and not seen[tier] then
				seen[tier] = true
				table.insert(clean, tier)
			else
				repaired = true
			end
		end
	end
	table.sort(clean)
	return clean, repaired
end

function SeasonConfig.Sanitize(stored)
	local state = SeasonConfig.DefaultState()
	if type(stored) ~= "table" then return state, true end
	local repaired = false
	if type(stored.Id) == "string" and #stored.Id <= 20 then state.Id = stored.Id else repaired = true end
	if type(stored.Xp) == "number" and stored.Xp == stored.Xp then
		state.Xp = math.clamp(math.floor(stored.Xp), 0, 100000000)
		if state.Xp ~= stored.Xp then repaired = true end
	else
		repaired = true
	end
	local free, freeRepaired = cleanTiers(stored.Free)
	local premium, premiumRepaired = cleanTiers(stored.Premium)
	state.Free, state.Premium = free, premium
	return state, repaired or freeRepaired or premiumRepaired
end

function SeasonConfig.CopyState(state)
	return { Id = state.Id, Xp = state.Xp, Free = table.clone(state.Free), Premium = table.clone(state.Premium) }
end

function SeasonConfig.SameState(first, second): boolean
	if first.Id ~= second.Id or first.Xp ~= second.Xp or #first.Free ~= #second.Free or #first.Premium ~= #second.Premium then
		return false
	end
	for index, tier in first.Free do
		if second.Free[index] ~= tier then return false end
	end
	for index, tier in first.Premium do
		if second.Premium[index] ~= tier then return false end
	end
	return true
end

return SeasonConfig
