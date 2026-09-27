-- Dunk Contest: a timed, server-wide event. When a round is open, every completed dunk by
-- anyone on any court is scored by five judges (1-10 each, 50 max) and each player's best
-- dunk counts. At the buzzer players are ranked and paid. ContestService runs everything;
-- clients only display it.
local ContestConfig = {
	-- Schedule (seconds). Rounds start FirstDelaySeconds after the server starts (Studio
	-- uses the shorter delay for quick testing), then every IntervalSeconds.
	FirstDelaySeconds = 90,
	StudioFirstDelaySeconds = 20,
	IntervalSeconds = 480,
	AnnounceSeconds = 30,
	OpenSeconds = 90,
	ResultsSeconds = 12,

	-- Judging: each judge starts from the style's base, adds the bonuses, then their own
	-- opinion (+/- Variance) and rounds to a whole card from 1 to 10.
	Judges = 5,
	StyleBase = { BasicOneHand = 4, TwoHandPower = 5, Tomahawk = 6, Windmill = 7 },
	TrickPoints = 0.25, -- per air trick landed (6 max)
	VarietyTricks = 3, -- this many different tricks in one dunk earns the variety bonus
	VarietyBonus = 0.5,
	TimingBonus = { Perfect = 1.5, Good = 0.5 },
	Variance = 0.7,
	-- The crowd erupts for dunks scoring at least this much.
	HypeScore = 45,

	-- Prizes are priced in "dunks" (DailyConfig.DunkValue: one plain dunk of your best
	-- style at your Vertical), so they matter at every stage. Best matching tier, plus a
	-- placement bonus when at least two players scored.
	ScoreTiers = {
		{ MinScore = 45, Dunks = 20, Name = "ALL-STAR" },
		{ MinScore = 40, Dunks = 12, Name = "HIGHLIGHT" },
		{ MinScore = 30, Dunks = 6, Name = "SOLID" },
		{ MinScore = 1, Dunks = 3, Name = "ROOKIE" },
	},
	PlacementDunks = { 10, 5, 3 },
	MaxScore = 50,
}

-- Five judge cards for one dunk. `tricks` is the list of air tricks landed (ids).
function ContestConfig.Judge(styleId: string, tricks: { string }, rating: string?, random: Random): { number }
	local distinct = {}
	local different = 0
	for _, trickId in tricks do
		if not distinct[trickId] then
			distinct[trickId] = true
			different += 1
		end
	end
	local base = (ContestConfig.StyleBase[styleId] or 4) + math.min(#tricks, 6) * ContestConfig.TrickPoints
		+ (different >= ContestConfig.VarietyTricks and ContestConfig.VarietyBonus or 0)
		+ (rating and ContestConfig.TimingBonus[rating] or 0)
	local cards = {}
	for index = 1, ContestConfig.Judges do
		local opinion = random:NextNumber(-ContestConfig.Variance, ContestConfig.Variance)
		cards[index] = math.clamp(math.floor(base + opinion + 0.5), 1, 10)
	end
	return cards
end

function ContestConfig.Total(cards: { number }): number
	local total = 0
	for _, card in cards do total += card end
	return total
end

function ContestConfig.Tier(score: number)
	for _, tier in ContestConfig.ScoreTiers do
		if score >= tier.MinScore then return tier end
	end
	return nil
end

return ContestConfig
