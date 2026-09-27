-- Per-court lighting and post-processing, applied locally by LightingController.
-- Values are plain Lighting / effect properties; anything missing keeps its current value.
return {
	-- Seconds to blend between court looks when travelling.
	BlendSeconds = 1.2,
	DefaultCourt = "Neighborhood",
	Courts = {
		-- Bright, saturated sunny afternoon with a clear blue sky.
		Neighborhood = {
			Lighting = {
				ClockTime = 14.2,
				GeographicLatitude = 28,
				Brightness = 3.2,
				ExposureCompensation = 0.1,
				Ambient = Color3.fromRGB(78, 84, 104),
				OutdoorAmbient = Color3.fromRGB(150, 160, 186),
				ColorShift_Top = Color3.fromRGB(255, 238, 214),
				ColorShift_Bottom = Color3.fromRGB(70, 110, 170),
				EnvironmentDiffuseScale = 1,
				EnvironmentSpecularScale = 1,
				ShadowSoftness = 0.12,
				GlobalShadows = true,
			},
			Effects = {
				ColorCorrection = { Enabled = true, Saturation = 0.32, Contrast = 0.14, Brightness = 0.02,
					TintColor = Color3.fromRGB(255, 250, 242) },
				Bloom = { Enabled = true, Intensity = 0.5, Size = 32, Threshold = 1.35 },
				SunRays = { Enabled = true, Intensity = 0.06, Spread = 0.8 },
				Atmosphere = { Density = 0.24, Offset = 0.12, Color = Color3.fromRGB(196, 222, 255),
					Decay = Color3.fromRGB(96, 150, 225), Glare = 0.2, Haze = 0.6 },
				DepthOfField = { Enabled = true, FarIntensity = 0.06, FocusDistance = 40, InFocusRadius = 70,
					NearIntensity = 0 },
			},
		},
		-- Arena-bright indoor gym: warm light, punchy colors, glowing highlights, no haze.
		HighSchool = {
			Lighting = {
				ClockTime = 13,
				GeographicLatitude = 28,
				Brightness = 2.4,
				ExposureCompensation = 0.15,
				Ambient = Color3.fromRGB(142, 134, 124),
				OutdoorAmbient = Color3.fromRGB(150, 150, 164),
				ColorShift_Top = Color3.fromRGB(255, 236, 206),
				ColorShift_Bottom = Color3.fromRGB(90, 110, 160),
				EnvironmentDiffuseScale = 1,
				EnvironmentSpecularScale = 1,
				ShadowSoftness = 0.25,
				GlobalShadows = true,
			},
			Effects = {
				ColorCorrection = { Enabled = true, Saturation = 0.26, Contrast = 0.16, Brightness = 0.03,
					TintColor = Color3.fromRGB(252, 250, 248) },
				Bloom = { Enabled = true, Intensity = 0.6, Size = 28, Threshold = 1.2 },
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
	},
}
