return {
	Owner = "DunkSimulator.College.v1",
	GeneratedName = "CollegeV01",
	-- College bus stop dressing built at the High School (owned by this builder).
	GateName = "CollegeGateV01",
	Offset = Vector3.new(4800, 0, 0),
	-- Arena walls (arena frame). The entrance wall stays at +RoomDepth/2 because the bus stop
	-- sits just outside it; the arena grows sideways (for the upper deck) and up.
	RoomWidth = 204,
	RoomDepth = 190,
	-- Tall enough that a max College jump (TrainingVerticalCap) plus JumpHeadroom for the
	-- head and camera stays indoors. Build.Run checks this against the jump formula.
	CeilingHeight = 300,
	JumpHeadroom = 25,
	-- Lines on the back wall at the height your feet reach with this much Vertical.
	VerticalMarks = { 100, 150, 200, 250 },
	CourtWidth = 60,
	CourtDepth = 104,
	RimDepth = -45,
	SpawnZ = 76,
	MaxParts = 3600,
	-- The High School gym frame sits RimDepth studs toward the court from its rim.
	HighSchoolRimDepth = -45,
	-- Six-row stands on both sidelines (arena frame).
	Stands = { Rows = 6, FirstX = 38, RowStep = 4.2, RowRise = 2.2, Length = 96 },
	-- Suite level (solid block with lit suite windows and an LED ribbon board) and the
	-- ten-row upper deck on top of it, reaching the side walls.
	Suites = { FrontX = 61, Top = 24, Length = 128 },
	UpperDeck = { Rows = 10, FirstX = 64, RowStep = 4, RowRise = 3.2, Length = 128 },
	-- Seated fans: PerSide per side on random lower-bowl rows at Spacing-stud slots, plus
	-- UpperPerSide on the upper deck (Seed keeps rebuilds identical).
	Crowd = { PerSide = 20, FirstZ = -44, LastZ = 44, Spacing = 4.4, Seed = 3100, FoamFingerChance = 0.25,
		UpperPerSide = 8, UpperFirstZ = -56, UpperLastZ = 56, UpperSpacing = 5 },
	-- Hanging light rigs: court rig over the floor, deck rigs over each upper deck.
	LightRig = { Height = 54, DeckHeight = 84, DeckX = 80 },
	-- Leaderboard stand (arena frame): behind the live hoop, left of it, facing the court.
	Leaderboard = { Position = Vector3.new(-50, 0, -86), Facing = Vector3.new(0, 0, 1) },
	-- Stations inside the entrance (arena frame, floor level).
	Stations = {
		Trainer = Vector3.new(-46, 1, 70),
		Pickup = Vector3.new(-22, 1, 70),
		Upgrade = Vector3.new(46, 1, 66),
	},
	-- Bus stops (both face the road, +Z) and where each bus parks.
	Transit = {
		CollegeStop = Vector3.new(14, 1, 110), -- arena frame: sidewalk outside the College entrance
		SchoolStop = Vector3.new(-28, 1, 84), -- High School gym frame: second stop on its sidewalk
		BusDistance = 7.3,
		RoadDrop = 0.2,
	},
	Colors = {
		-- Big-game palette: purple and gold, dark arena shell, bright hardwood.
		Wood = Color3.fromRGB(226, 160, 88), WoodLight = Color3.fromRGB(240, 180, 108),
		Purple = Color3.fromRGB(104, 52, 190), Gold = Color3.fromRGB(255, 190, 40),
		Paint = Color3.fromRGB(104, 52, 190), Lines = Color3.fromRGB(255, 252, 242),
		Wall = Color3.fromRGB(150, 138, 196), WallLight = Color3.fromRGB(176, 164, 220),
		Floor = Color3.fromRGB(70, 62, 100), Metal = Color3.fromRGB(44, 52, 76),
		Dark = Color3.fromRGB(22, 18, 40), Light = Color3.fromRGB(255, 246, 222),
		Rubber = Color3.fromRGB(40, 44, 58), Glass = Color3.fromRGB(150, 214, 255),
		Yellow = Color3.fromRGB(255, 196, 24), Orange = Color3.fromRGB(255, 128, 28),
		Road = Color3.fromRGB(56, 60, 76), Concrete = Color3.fromRGB(206, 210, 220),
		Grass = Color3.fromRGB(86, 178, 64),
		Backboard = Color3.fromRGB(176, 200, 222), BackboardTransparency = 0.35,
		Lab = Color3.fromRGB(150, 80, 255),
	},
}
