return {
	Owner = "DunkSimulator.Rooftop.v1",
	GeneratedName = "RooftopV01",
	-- Rooftop bus stop dressing built outside the College Arena (owned by this builder).
	GateName = "RooftopGateV01",
	-- Court frame relative to the Neighborhood court (College is at +4800).
	Offset = Vector3.new(7200, 0, 0),
	-- The skyscraper roof the court sits on (roof frame, floor at y = 0).
	RoofWidth = 150,
	RoofDepth = 196,
	-- Invisible walls around the roof edge, taller than a max jump here, so nobody drifts
	-- off the building. Build.Run checks this against the jump formula.
	BarrierHeight = 520,
	JumpHeadroom = 25,
	-- The tower keeps going below the roof; the night haze hides its base.
	TowerDepth = 420,
	-- Neon "height gates" floating over the back of the court at the height your feet reach
	-- with this much Vertical.
	VerticalMarks = { 250, 300, 350 },
	CourtWidth = 60,
	CourtDepth = 104,
	RimDepth = -45,
	SpawnZ = 76,
	MaxParts = 2000,
	-- The College arena frame sits RimDepth studs toward the court from its rim.
	CollegeRimDepth = -45,
	-- Short bleachers on both sidelines (roof frame) with a few fans.
	Stands = { Rows = 3, FirstX = 38, RowStep = 4, RowRise = 1.8, Length = 70 },
	Crowd = { PerSide = 10, FirstZ = -30, LastZ = 30, Spacing = 4.4, Seed = 4700, FoamFingerChance = 0.3 },
	-- Flood-light poles at the four court corners.
	FloodLights = { Height = 34, Brightness = 1.4, Range = 90 },
	-- Leaderboard stand (roof frame): behind the hoop, left of it, facing the court.
	Leaderboard = Vector3.new(-50, 0, -86),
	-- Stations near the elevator (roof frame, floor level).
	Stations = {
		Trainer = Vector3.new(-46, 1, 72),
		Pickup = Vector3.new(-24, 1, 72),
		Upgrade = Vector3.new(46, 1, 68),
		Elevator = Vector3.new(24, 1, 88),
	},
	-- New bus stop on the College sidewalk (arena frame), left of the High School stop.
	CollegeStop = Vector3.new(-44, 1, 110),
	Transit = { BusDistance = 7.3, RoadDrop = 0.2 },
	-- Surrounding skyline: Buildings towers in a ring, deterministic from Seed.
	City = { Buildings = 46, InnerRadius = 190, OuterRadius = 720, Seed = 9100, BaseY = -420 },
	Colors = {
		-- Night palette: teal sport court, magenta and cyan neon, dark glass towers.
		Court = Color3.fromRGB(26, 110, 130), CourtLight = Color3.fromRGB(34, 132, 152),
		Paint = Color3.fromRGB(210, 40, 140), Lines = Color3.fromRGB(245, 250, 255),
		Roof = Color3.fromRGB(60, 62, 76), RoofDark = Color3.fromRGB(38, 40, 52),
		Parapet = Color3.fromRGB(84, 88, 104), Glass = Color3.fromRGB(150, 214, 255),
		Tower = Color3.fromRGB(24, 26, 40), TowerLight = Color3.fromRGB(36, 40, 60),
		Magenta = Color3.fromRGB(255, 60, 200), Cyan = Color3.fromRGB(60, 230, 255),
		Gold = Color3.fromRGB(255, 200, 60), Warm = Color3.fromRGB(255, 214, 140),
		Red = Color3.fromRGB(255, 50, 50), Metal = Color3.fromRGB(70, 76, 96),
		Dark = Color3.fromRGB(16, 16, 30), Light = Color3.fromRGB(255, 246, 222),
		Rubber = Color3.fromRGB(40, 44, 58), Orange = Color3.fromRGB(255, 128, 28),
		Wood = Color3.fromRGB(226, 160, 88), Yellow = Color3.fromRGB(255, 196, 24),
		Backboard = Color3.fromRGB(176, 200, 222), BackboardTransparency = 0.35,
		Lab = Color3.fromRGB(150, 80, 255),
	},
}
