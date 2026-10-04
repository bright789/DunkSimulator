-- Playtime gifts (GiftService): free rewards that open after a number of minutes played in
-- this session. Progress is per session: the clock starts when your data has loaded, and the
-- clock and the claims both start over when you rejoin. Nothing is saved.
--   Dunks         Cash worth this many plain dunks at your Vertical (DailyConfig.DunkValue),
--                 at least MinCash, so a gift stays worth opening at every stage
--   BoostMinutes  minutes of Cash Boost (DailyService.GrantBoost; stacks, max 60)
--   CrewPack      a free Hype Crew pack: the best pack your courts unlock (CrewService.GrantPack)
-- The early gifts are small on purpose: rejoining to farm them pays less than just playing.
local GiftConfig = {
	Gifts = {
		{ Minutes = 1, Dunks = 3, MinCash = 60 },
		{ Minutes = 3, Dunks = 4, MinCash = 80 },
		{ Minutes = 5, Dunks = 2, MinCash = 40, BoostMinutes = 3 },
		{ Minutes = 8, Dunks = 6, MinCash = 120 },
		{ Minutes = 12, Dunks = 8, MinCash = 160 },
		{ Minutes = 20, Dunks = 12, MinCash = 250 },
		-- The best one.
		{ Minutes = 30, Dunks = 20, MinCash = 400, BoostMinutes = 10, CrewPack = true },
	},
	ClaimCooldownSeconds = 0.5,
	ReadCooldownSeconds = 1,
	-- A claim this many seconds before the gift opens still counts (the client counts down
	-- on its own clock).
	GraceSeconds = 2,
	-- Studio-only test flag: when true, each gift "minute" lasts StudioSecondsPerMinute
	-- seconds in Studio so the whole ladder can be checked quickly. Live servers always use
	-- real minutes. Keep it false.
	StudioFastGifts = false,
	StudioSecondsPerMinute = 5,
}

-- Cash a gift pays when one plain dunk is worth `dunkValue` (0 if it pays no Cash).
function GiftConfig.Cash(gift, dunkValue: number): number
	if not gift.Dunks then return 0 end
	return math.max(gift.MinCash or 0, math.floor(gift.Dunks * dunkValue + 0.5))
end

return GiftConfig
