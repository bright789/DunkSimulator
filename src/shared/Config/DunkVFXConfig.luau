-- Dunk impact VFX (client only, see DunkVFX and docs/DUNK_VFX.md). Every slam gets its
-- court's theme, and the Perfect-slam meter grade decides how big it is:
--   PERFECT: the court's big signature effect, double floor shockwave, screen flash.
--   GOOD:    a solid burst plus a small version of the court effect.
--   EARLY / LATE: a small smoke fizzle (no court effect).
--   None (no press): the court's normal impact.
local DunkVFXConfig = {
	Grades = {
		-- Scale multiplies particle counts and speeds. RimKick and HitStopSeconds shape the
		-- rim bend and freeze frame; CameraBoost scales the dunker's impact shake.
		Perfect = { Scale = 1.5, Signature = "Big", FloorRings = 2, Light = 7, Flash = true, Label = "PERFECT!",
			RimKick = 1.5, HitStopSeconds = 0.12, CameraBoost = 1.6 },
		Good = { Scale = 1.1, Signature = "Small", FloorRings = 1, Light = 5, Label = "GOOD!",
			RimKick = 1.15, HitStopSeconds = 0.09, CameraBoost = 1.2 },
		Early = { Scale = 0.6, Fizzle = true, RimKick = 0.8 },
		Late = { Scale = 0.6, Fizzle = true, RimKick = 0.8 },
		None = { Scale = 0.8, Light = 4 },
	},

	-- Other players' slams: skipped past this distance from the camera, and drawn with
	-- fewer particles so busy servers stay smooth on phones.
	MaxDistance = 260,
	OthersScale = 0.6,
	-- Floating "PERFECT!" / "GOOD!" over other players (the dunker already has the meter text).
	LabelSeconds = 1.2,
	FlashSeconds = 0.35,
	FlashTransparency = 0.72,

	-- Built-in Roblox particle textures (no uploads needed).
	Textures = {
		Spark = "rbxasset://textures/particles/sparkles_main.dds",
		Smoke = "rbxasset://textures/particles/smoke_main.dds",
		Fire = "rbxasset://textures/particles/fire_main.dds",
		Embers = "rbxasset://textures/particles/fire_sparks_main.dds",
		Shockwave = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
		Square = "rbxasset://textures/particles/SquareParticle.png",
	},

	-- One theme per court (keyed by CourtConfig id). Spark = rim sparks, Glow = shockwaves
	-- and light, Flash = the dunker's Perfect screen flash, Confetti/Chips = signature bits.
	Themes = {
		Neighborhood = {
			Signature = "Street", -- dust shockwave, flying asphalt chips, spark fountain
			Spark = Color3.fromRGB(255, 170, 60),
			Glow = Color3.fromRGB(255, 236, 200),
			Flash = Color3.fromRGB(255, 214, 150),
			Dust = Color3.fromRGB(205, 185, 150),
			Chips = { Color3.fromRGB(70, 70, 78), Color3.fromRGB(255, 150, 50) },
		},
		HighSchool = {
			Signature = "PepRally", -- confetti cannons in Dunk High blue and gold
			Spark = Color3.fromRGB(255, 214, 70),
			Glow = Color3.fromRGB(90, 160, 255),
			Flash = Color3.fromRGB(255, 225, 120),
			Confetti = { Color3.fromRGB(40, 110, 240), Color3.fromRGB(255, 205, 50), Color3.fromRGB(250, 250, 255) },
		},
		College = {
			Signature = "Pyro", -- fire columns beside the hoop and a gold confetti drop
			Spark = Color3.fromRGB(255, 200, 80),
			Glow = Color3.fromRGB(170, 90, 255),
			Flash = Color3.fromRGB(255, 190, 90),
			Fire = Color3.fromRGB(255, 140, 40),
			Confetti = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(150, 80, 255), Color3.fromRGB(255, 255, 255) },
		},
		Rooftop = {
			Signature = "Neon", -- lightning strike, neon rings, fireworks over the city
			Spark = Color3.fromRGB(60, 230, 255),
			Glow = Color3.fromRGB(255, 60, 200),
			Flash = Color3.fromRGB(120, 230, 255),
			Bolt = Color3.fromRGB(210, 245, 255),
			Fireworks = { Color3.fromRGB(255, 60, 200), Color3.fromRGB(60, 230, 255), Color3.fromRGB(255, 214, 70) },
		},
	},

	-- Sizes and counts at Scale 1.
	RimSparks = 30,
	RimShockwaveSize = 9,
	FloorRingSize = 34,
	ConfettiCount = 70,
	PyroSeconds = 0.7,
	PyroSideOffset = 16,
	CannonSideOffset = 14,
	LightningHeight = 80,
	FireworkBursts = 3,
}

return DunkVFXConfig
