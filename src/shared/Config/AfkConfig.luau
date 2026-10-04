-- AFK Practice Court (AfkService): one glowing pad per court, placed by the server near the
-- court's spawn when the server starts. Standing on it earns Cash every RewardSeconds and a
-- free prize every PrizeSeconds of time on the pad. Leaving the pad pauses both timers for
-- the session (they don't reset). The prizes are free, so they are not paid random items.
-- Note: Roblox disconnects players who give no input for about 20 minutes.
local AfkConfig = {
	-- Cash every 3 minutes on the pad: AfkDunks plain dunks at your Vertical (DailyConfig.DunkValue).
	RewardSeconds = 180,
	AfkDunks = 4,
	-- The VIP pass multiplies all AFK Cash (the 3-minute Cash and the Cash prize).
	VipMultiplier = 2,
	-- A free prize every 15 minutes on the pad, picked by Weight.
	PrizeSeconds = 900,
	Prizes = {
		{ Kind = "Boost", Minutes = 5, Weight = 40, Text = "5 MIN 2x CASH" },
		{ Kind = "Cash", Dunks = 10, Weight = 40, Text = "CASH" },
		-- Dunk Pass XP (only while a season is running; otherwise the Cash prize is given).
		{ Kind = "PassXp", Xp = 50, Weight = 20, Text = "+50 DUNK PASS XP" },
	},

	Pad = {
		Name = "AFK PRACTICE",
		Subtitle = "earn while you chill",
		-- Standing within Radius studs (flat distance) of the centre counts, if your
		-- HumanoidRootPart is less than Height studs above the pad.
		Radius = 5,
		Height = 8,
		Color = Color3.fromRGB(90, 220, 255),
	},

	-- Where the pad goes. The search starts at the court's spawn and looks at spots in front
	-- of it (toward the court) and to the sides, never behind it (the entrance), at each
	-- distance in Distances and each angle in Angles (0 = straight ahead, 90 = right, -90 = left).
	-- A spot is used when the floor there is flat, near the spawn's height, nothing solid is in
	-- the way, and it is at least KeepAway studs from every named object below (the rim, the
	-- stations and their props, bus stops, the spawn).
	Placement = {
		Distances = { 14, 18, 22, 26, 30 },
		Angles = { 60, -60, 45, -45, 75, -75, 90, -90, 30, -30 },
		MaxHeightDifference = 3,
		-- How flat: every point on the pad's edge must be within this many studs of its centre's height.
		Flatness = 0.6,
		-- Studs of empty space needed above the pad.
		ClearHeight = 7,
		KeepAway = {
			DunkHoop = 30, VerticalTrainer = 14, BasketballPickup = 14, UpgradeStation = 14,
			HoopShop = 10, PickupShop = 10, TrainerGym = 10, LegDayGym = 10, UpgradeLab = 10,
			UpgradeStationDressing = 10, BusStop = 12, ReturnGate = 12, Elevator = 12, LeaderboardArea = 8,
		},
		-- Court portals (CourtConfig Portals) and spawns.
		PortalKeepAway = 14,
		SpawnKeepAway = 8,
		-- Objects bigger than this (studs, flat) are containers like a whole building, not a
		-- prop to keep away from, so they're skipped.
		MaxPropSize = 80,
	},
	-- Fixed spots per court, used instead of the search: studs from the court's spawn, with
	-- X to the spawn's right and Z forward (toward the court), e.g. Vector3.new(12, 0, 8).
	-- nil = search. The pad still snaps to the floor there.
	Offsets = {
		Neighborhood = nil,
		HighSchool = nil,
		College = nil,
		Rooftop = nil,
	},

	-- Studio-only test flag: when true, rewards come every StudioRewardSeconds and prizes every
	-- StudioPrizeSeconds in Studio. Live servers always use the real times. Keep it false.
	StudioFastAfk = false,
	StudioRewardSeconds = 10,
	StudioPrizeSeconds = 30,
}

-- Picks a prize by weight (`roll` is 0-1).
function AfkConfig.PickPrize(roll: number)
	local total = 0
	for _, prize in AfkConfig.Prizes do total += prize.Weight end
	local pick = roll * total
	for _, prize in AfkConfig.Prizes do
		pick -= prize.Weight
		if pick <= 0 then return prize end
	end
	return AfkConfig.Prizes[#AfkConfig.Prizes]
end

-- Adds `seconds` of pad time to a session's timers ({ Reward, Prize } seconds so far) and
-- returns how many rewards and prizes are now due. Timers keep their leftover time.
function AfkConfig.Accrue(timers, seconds: number, rewardSeconds: number, prizeSeconds: number): (number, number)
	timers.Reward += seconds
	timers.Prize += seconds
	local rewards, prizes = 0, 0
	while timers.Reward >= rewardSeconds do
		timers.Reward -= rewardSeconds
		rewards += 1
	end
	while timers.Prize >= prizeSeconds do
		timers.Prize -= prizeSeconds
		prizes += 1
	end
	return rewards, prizes
end

return AfkConfig
