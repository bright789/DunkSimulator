-- Welcome-back earnings (see docs/WELCOME_BACK.md): while you're away, your fans keep earning.
-- On join the server pays DunksPerHour dunks' worth of Cash (DailyConfig.DunkValue at your
-- Vertical x your Rebirth Cash bonus) for every hour since you last played, up to MaxHours.
-- VIP pass owners get VipMultiplier times as much. Short breaks (under MinAwayMinutes) pay nothing.
return {
	MinAwayMinutes = 15,
	MaxHours = 8,
	DunksPerHour = 10,
	VipMultiplier = 2,
	-- Studio only: pretend you were away this many seconds (0 = off). Ignored on live servers.
	StudioPretendAwaySeconds = 0,
}
