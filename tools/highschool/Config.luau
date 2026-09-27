return {
	Owner = "DunkSimulator.HighSchool.v1",
	GeneratedName = "HighSchoolV01",
	GateName = "HighSchoolGateV01",
	Offset = Vector3.new(2400, 0, 0),
	-- Gym walls (gym frame). The entrance wall stays at FrontZ because the bus stops sit on
	-- the sidewalk just outside it; the gym grows sideways, backward and up.
	RoomWidth = 130,
	BackZ = -84,
	FrontZ = 70,
	-- Tall enough that a max High School jump (TrainingVerticalCap) plus JumpHeadroom for
	-- the head and camera stays indoors. Build.Run checks this against the jump formula.
	CeilingHeight = 150,
	JumpHeadroom = 25,
	-- Lines on the back wall at the height your feet reach with this much Vertical.
	VerticalMarks = { 75, 100, 125, 150 },
	-- Running-track balcony along both side walls (overhead, so it never collides).
	Balcony = { Height = 30, Width = 11 },
	LightHeight = 40,
	-- Leaderboard stand (gym frame): right side behind the baseline, near the hoop, facing the court (-X).
	Leaderboard = { Position = Vector3.new(52, 0, -61), Facing = Vector3.new(-1, 0, 0) },
	CourtWidth = 60,
	CourtDepth = 104,
	RimDepth = -45,
	MaxParts = 1400,
	-- Bleacher fans: PerSide per bleacher, seated at Spacing-stud slots between FirstZ and
	-- LastZ (gym frame) on random rows. Seed keeps rebuilds identical.
	Crowd = { PerSide = 10, FirstZ = -31, LastZ = 23, Spacing = 4.5, Seed = 213, FoamFingerChance = 0.2 },
	-- Bus stops used by Build.PlaceTransitStops (stations face the road, +Z).
	Transit = {
		-- Neighborhood stop, offset from the Neighborhood SpawnLocation (sidewalk right of the gate).
		NeighborhoodStop = Vector3.new(12, 0.5, 15),
		NeighborhoodBusDistance = 11.3,
		NeighborhoodRoadDrop = 0.25,
		-- High School stop, offset from the gym frame (sidewalk outside the entrance).
		SchoolStop = Vector3.new(12, 1, 84),
		SchoolBusDistance = 7.3,
		SchoolRoadDrop = 0.2,
	},
	Colors = {
		-- Saturated "pop" palette: warm hardwood, royal-blue paint and stripes, clean walls.
		Wood = Color3.fromRGB(222, 152, 80), WoodLight = Color3.fromRGB(238, 174, 100),
		Paint = Color3.fromRGB(28, 98, 214), Lines = Color3.fromRGB(255, 252, 242),
		Wall = Color3.fromRGB(232, 238, 248), Metal = Color3.fromRGB(44, 52, 76),
		Blue = Color3.fromRGB(28, 112, 230), Orange = Color3.fromRGB(255, 128, 28),
		Dark = Color3.fromRGB(20, 28, 52), Light = Color3.fromRGB(255, 246, 222),
		Rubber = Color3.fromRGB(40, 44, 58), Glass = Color3.fromRGB(150, 214, 255),
		Yellow = Color3.fromRGB(255, 196, 24), Road = Color3.fromRGB(56, 60, 76),
		Concrete = Color3.fromRGB(206, 210, 220), Grass = Color3.fromRGB(86, 178, 64),
		-- Tinted glass backboard (a white board blooms too brightly).
		Backboard = Color3.fromRGB(176, 200, 222), BackboardTransparency = 0.35,
		-- Electric purple for the Training Upgrades lab.
		Lab = Color3.fromRGB(150, 80, 255),
	},
}
