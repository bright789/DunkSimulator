-- Things to grab on the court (see docs/ENGAGEMENT.md). The server decides and pays every
-- pickup; clients only draw them and ask to collect when they touch one.
return {
	-- Every completed dunk spills a few cash bills around the hoop.
	Bills = {
		Count = 3,
		-- Each bill is worth this share of the dunk's Cash (3 x 5% = +15%).
		ShareOfDunk = 0.05,
		-- Where they land: this far from the spot under the rim, on the court side.
		MinRadius = 6,
		MaxRadius = 14,
		LifetimeSeconds = 15,
		-- Bills fly to you inside MagnetRadius; the server accepts a collect within CollectRadius.
		MagnetRadius = 10,
		CollectRadius = 16,
		Color = Color3.fromRGB(80, 200, 95),
	},
	-- A Golden Ball appears on each court with players about every EverySeconds. First to
	-- touch it wins RewardDunks dunks' worth of Cash (DailyConfig.DunkValue at their Vertical).
	GoldenBall = {
		EverySeconds = 75,
		JitterSeconds = 15,
		LifetimeSeconds = 30,
		GrabRadius = 5,
		RewardDunks = 8,
		-- Spawn area: MinForward-MaxForward studs out from under the rim, up to Spread to either side.
		MinForward = 10,
		MaxForward = 40,
		Spread = 24,
		Size = 3,
		Color = Color3.fromRGB(255, 200, 40),
	},
}
