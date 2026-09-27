-- Per-court lighting and post-processing, applied locally by LightingController.
-- Values are plain Lighting / effect properties; anything missing keeps its current value.
return {
	-- Seconds to blend between court looks when travelling.
	BlendSeconds = 1.2,
	DefaultCourt = "Neighborhood",
	Courts = {
		-- Sunny afternoon with a clear blue sky. Toned down (was Brightness 3.2 / exposure +0.1)
		-- so the court and lines don't wash out: about 15% of a mid-court view was near-white.
		Neighborhood = {
			Lighting = {
				ClockTime = 14.2,
				GeographicLatitude = 28,
				Brightness = 2.6,
				ExposureCompensation = -0.2,
				Ambient = Color3.fromRGB(78, 84, 104),
				OutdoorAmbient = Color3.fromRGB(128, 136, 158),
				ColorShift_Top = Color3.fromRGB(255, 238, 214),
				ColorShift_Bottom = Color3.fromRGB(70, 110, 170),
				EnvironmentDiffuseScale = 1,
				EnvironmentSpecularScale = 1,
				ShadowSoftness = 0.12,
				GlobalShadows = true,
			},
			Effects = {
				ColorCorrection = { Enabled = true, Saturation = 0.3, Contrast = 0.16, Brightness = -0.02,
					TintColor = Color3.fromRGB(255, 250, 242) },
				Bloom = { Enabled = true, Intensity = 0.35, Size = 32, Threshold = 1.6 },
				SunRays = { Enabled = true, Intensity = 0.06, Spread = 0.8 },
				Atmosphere = { Density = 0.2, Offset = 0.12, Color = Color3.fromRGB(196, 222, 255),
					Decay = Color3.fromRGB(96, 150, 225), Glare = 0.1, Haze = 0.4 },
				DepthOfField = { Enabled = true, FarIntensity = 0.06, FocusDistance = 40, InFocusRadius = 70,
					NearIntensity = 0 },
			},
		},
		-- Well-lit indoor gym: warm light, punchy colors, no haze. Toned down (was Brightness 2.4 /
		-- exposure +0.15 / ambient 142,134,124): the pale floor and walls were ~30% blown to white.
		HighSchool = {
			Lighting = {
				ClockTime = 13,
				GeographicLatitude = 28,
				Brightness = 1.6,
				ExposureCompensation = -0.35,
				Ambient = Color3.fromRGB(100, 96, 92),
				OutdoorAmbient = Color3.fromRGB(120, 120, 132),
				ColorShift_Top = Color3.fromRGB(255, 236, 206),
				ColorShift_Bottom = Color3.fromRGB(90, 110, 160),
				EnvironmentDiffuseScale = 1,
				EnvironmentSpecularScale = 1,
				ShadowSoftness = 0.25,
				GlobalShadows = true,
			},
			Effects = {
				ColorCorrection = { Enabled = true, Saturation = 0.28, Contrast = 0.18, Brightness = -0.02,
					TintColor = Color3.fromRGB(252, 250, 248) },
				Bloom = { Enabled = true, Intensity = 0.35, Size = 28, Threshold = 1.5 },
				SunRays = { Enabled = true, Intensity = 0.02, Spread = 0.6 },
				Atmosphere = { Density = 0.12, Offset = 0, Color = Color3.fromRGB(230, 226, 220),
					Decay = Color3.fromRGB(180, 170, 160), Glare = 0, Haze = 0 },
				DepthOfField = { Enabled = true, FarIntensity = 0.04, FocusDistance = 40, InFocusRadius = 70,
					NearIntensity = 0 },
			},
		},
		-- Big-game arena: cooler ambient, purple-gold tint, stronger glow on the neon.
		College = {
			Lighting = {
				ClockTime = 13,
				GeographicLatitude = 28,
				Brightness = 2.2,
				ExposureCompensation = 0,
				Ambient = Color3.fromRGB(140, 132, 158),
				OutdoorAmbient = Color3.fromRGB(150, 146, 168),
				ColorShift_Top = Color3.fromRGB(255, 232, 200),
				ColorShift_Bottom = Color3.fromRGB(110, 80, 170),
				EnvironmentDiffuseScale = 1,
				EnvironmentSpecularScale = 1,
				ShadowSoftness = 0.2,
				GlobalShadows = true,
			},
			Effects = {
				ColorCorrection = { Enabled = true, Saturation = 0.3, Contrast = 0.18, Brightness = 0.02,
					TintColor = Color3.fromRGB(252, 248, 255) },
				Bloom = { Enabled = true, Intensity = 0.55, Size = 28, Threshold = 1.25 },
				SunRays = { Enabled = true, Intensity = 0.02, Spread = 0.6 },
				Atmosphere = { Density = 0.14, Offset = 0, Color = Color3.fromRGB(226, 220, 236),
					Decay = Color3.fromRGB(170, 150, 190), Glare = 0, Haze = 0 },
				DepthOfField = { Enabled = true, FarIntensity = 0.04, FocusDistance = 40, InFocusRadius = 80,
					NearIntensity = 0 },
			},
		},
		-- Night on a skyscraper roof: cool moonlight, city glow in the haze, strong neon bloom.
		-- The court itself is lit by the builder's flood lights.
		Rooftop = {
			Lighting = {
				ClockTime = 21.5,
				GeographicLatitude = 28,
				Brightness = 1.5,
				ExposureCompensation = 0,
				Ambient = Color3.fromRGB(96, 98, 136),
				OutdoorAmbient = Color3.fromRGB(110, 114, 156),
				ColorShift_Top = Color3.fromRGB(170, 180, 255),
				ColorShift_Bottom = Color3.fromRGB(70, 44, 120),
				EnvironmentDiffuseScale = 0.6,
				EnvironmentSpecularScale = 1,
				ShadowSoftness = 0.3,
				GlobalShadows = true,
			},
			Effects = {
				ColorCorrection = { Enabled = true, Saturation = 0.25, Contrast = 0.16, Brightness = 0.02,
					TintColor = Color3.fromRGB(242, 242, 255) },
				Bloom = { Enabled = true, Intensity = 0.5, Size = 30, Threshold = 1.3 },
				SunRays = { Enabled = true, Intensity = 0, Spread = 0.6 },
				-- Light haze so the lit skyline still shows through.
				Atmosphere = { Density = 0.12, Offset = 0.1, Color = Color3.fromRGB(70, 80, 130),
					Decay = Color3.fromRGB(40, 32, 90), Glare = 0, Haze = 0.4 },
				DepthOfField = { Enabled = true, FarIntensity = 0.05, FocusDistance = 50, InFocusRadius = 90,
					NearIntensity = 0 },
			},
		},
	},
}
