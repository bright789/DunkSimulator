-- Clip timing matches DunkStyles: Slam = GatherSeconds, Release = Gather + Finish.
-- Each clip ends with the arm reaching up so the client rim grab takes over.
local Config = {
	Owner = "DunkAnimationBuilderV1",
	OutputName = "GeneratedDunkAnimations",
	Styles = {
		{
			Id = "BasicOneHand",
			Duration = 0.52,
			Markers = { Gather = 0, Slam = 0.30, Release = 0.42, Recover = 0.48 },
		},
		{
			Id = "TwoHandPower",
			Duration = 0.64,
			Markers = { Gather = 0, Slam = 0.42, Release = 0.54, Recover = 0.60 },
		},
		{
			Id = "Tomahawk",
			Duration = 0.76,
			Markers = { Gather = 0, Slam = 0.55, Release = 0.66, Recover = 0.72 },
		},
		{
			Id = "Windmill",
			Duration = 0.92,
			Markers = { Gather = 0, Slam = 0.70, Release = 0.82, Recover = 0.88 },
		},
	},
}

return Config
