local DunkConfig = require(script.Parent.DunkConfig)

local Styles = {
	DefaultId = "BasicOneHand",
	EquipCooldownSeconds = 0.35,
	ExecutionSlackSeconds = 0.45,
	Definitions = {
		BasicOneHand = {
			DisplayName = "Basic One-Hand", RequiredVertical = DunkConfig.DunkMinimumVertical,
			Reward = 20, Order = 1, SuccessHeading = "DUNK!",
			GatherSeconds = 0.3, FinishSeconds = 0.12, HangSeconds = 0.34, ReturnSeconds = 0.14,
			Path = { Kind = "Direct" },
			Motion = { HeightLift = 1.2, LiftByFraction = 0.7, SlamReach = 0.5, FinishExponent = 2 },
			-- Trick played while dropping in from a high jump: Spin360, Spin720, FrontFlip, Corkscrew or None.
			DescentTrick = "Spin360",
			Pose = {
				Hands = { "Right" }, GripOffset = 0.5, Weight = 0.75, SmoothSeconds = 0.04, BlendFraction = 0.2,
				Body = {
					Weight = 0.35, SmoothSeconds = 0.04, BlendFraction = 0.18,
					Gather = { { Time = 0 }, { Time = 1, Pitch = 8 } },
					Slam = { Pitch = 12 },
				},
			},
			Presentation = { WhooshCue = "Slam" },
		},
		TwoHandPower = {
			DisplayName = "Two-Hand Power", RequiredVertical = 50,
			Reward = 35, Order = 2,
			GatherSeconds = 0.42, FinishSeconds = 0.12, HangSeconds = 0.45, ReturnSeconds = 0.16,
			Path = {
				Kind = "Waypoints",
				Points = {
					{ Time = 0.23, Offset = Vector3.new(0, 1.2, -1.5) },
					{ Time = 0.58, Offset = Vector3.new(0, 2.5, -1.4) },
					{ Time = 0.71, Offset = Vector3.new(0, 2.5, -1.4) },
				},
			},
			Motion = { HeightLift = 1.5, LiftByFraction = 0.7, SlamReach = 0.6, FinishExponent = 2.3 },
			DescentTrick = "FrontFlip",
			Pose = {
				Hands = { "Right", "Left" }, GripOffset = 0.5, Weight = 1, SmoothSeconds = 0.035, BlendFraction = 0.2,
				Body = {
					Weight = 0.55, SmoothSeconds = 0.035, BlendFraction = 0.18,
					Gather = { { Time = 0 }, { Time = 0.6, Pitch = -5, Sink = 0.18 },
						{ Time = 1, Pitch = -3, Sink = 0.13 } },
					Slam = { Pitch = 17, Sink = 0.12 },
				},
			},
			Presentation = { WindupCueFraction = 0.58, WhooshCue = "Slam" },
		},
		Tomahawk = {
			DisplayName = "Tomahawk", RequiredVertical = 75,
			Reward = 60, Order = 3,
			GatherSeconds = 0.55, FinishSeconds = 0.11, HangSeconds = 0.42, ReturnSeconds = 0.16,
			Path = {
				Kind = "Waypoints",
				Points = {
					{ Time = 0.24, Offset = Vector3.new(1.3, 3.3, 0.6) },
					{ Time = 0.62, Offset = Vector3.new(1.6, 4.1, 3) },
					{ Time = 0.74, Offset = Vector3.new(1.6, 4.1, 3) },
				},
			},
			Motion = { HeightLift = 1.7, LiftByFraction = 0.7, SlamReach = 0.7, FinishExponent = 3 },
			DescentTrick = "Corkscrew",
			Pose = {
				Hands = { "Right" }, GripOffset = 0.6, Weight = 1, SmoothSeconds = 0.03, BlendFraction = 0.2,
				Body = {
					Weight = 0.65, SmoothSeconds = 0.03, BlendFraction = 0.18,
					Gather = { { Time = 0 }, { Time = 0.38, Pitch = -5, Yaw = 7 },
						{ Time = 0.7, Pitch = -14, Yaw = 17, Roll = 6 },
						{ Time = 1, Pitch = -10, Yaw = 14, Roll = 4 } },
					Slam = { Pitch = 19, Yaw = -4 },
				},
			},
			Presentation = { WindupCueFraction = 0.62, WhooshCue = "Windup" },
		},
		Windmill = {
			DisplayName = "Windmill", RequiredVertical = 110,
			Reward = 100, Order = 4,
			GatherSeconds = 0.7, FinishSeconds = 0.12, HangSeconds = 0.4, ReturnSeconds = 0.16,
			Path = {
				Kind = "Circle", Center = Vector3.new(2.1, 1.2, -0.2),
				VerticalRadius = 3.15, DepthRadius = 2.25, SideSweep = 0.5,
				StartAngleDegrees = 225, TurnDegrees = 300, EnterFraction = 0.11,
				HangStartFraction = 0.62, HangEndFraction = 0.73,
				HangAngleFraction = 0.75, ExitFraction = 0.91,
			},
			Motion = { HeightLift = 1.9, LiftByFraction = 0.72, SlamReach = 0.6, FinishExponent = 2.2 },
			DescentTrick = "Spin720",
			Pose = {
				Hands = { "Right" }, GripOffset = 0.55, Weight = 0.9, SmoothSeconds = 0.025, BlendFraction = 0.15,
				Body = {
					Weight = 0.65, SmoothSeconds = 0.03, BlendFraction = 0.16,
					Gather = { { Time = 0 }, { Time = 0.22, Pitch = 5, Roll = 5, Yaw = -5 },
						{ Time = 0.55, Pitch = -5, Roll = -8, Yaw = 8 },
						{ Time = 0.75, Pitch = -4, Roll = 10, Yaw = 9 },
						{ Time = 1, Pitch = 7, Roll = -3, Yaw = -5 } },
					Slam = { Pitch = 17, Roll = 0 },
				},
			},
			Presentation = { WindupCueFraction = 0.62, WhooshCue = "Windup" },
		},
	},
}

function Styles.Get(styleId)
	return type(styleId) == "string" and Styles.Definitions[styleId] or nil
end

function Styles.OrderedIds(): { string }
	local ids = {}
	for styleId in Styles.Definitions do
		table.insert(ids, styleId)
	end
	table.sort(ids, function(first, second)
		return Styles.Definitions[first].Order < Styles.Definitions[second].Order
	end)
	return ids
end

function Styles.IsUnlocked(styleId, vertical: number): boolean
	local style = Styles.Get(styleId)
	return style ~= nil and vertical >= style.RequiredVertical
end

function Styles.ResolveEquipped(styleId, vertical: number): string
	if Styles.IsUnlocked(styleId, vertical) then
		return styleId
	end
	local fallback = Styles.DefaultId
	for _, candidate in Styles.OrderedIds() do
		if Styles.IsUnlocked(candidate, vertical) then
			fallback = candidate
		end
	end
	return fallback
end

function Styles.NextLocked(vertical: number): string?
	for _, styleId in Styles.OrderedIds() do
		if not Styles.IsUnlocked(styleId, vertical) then
			return styleId
		end
	end
	return nil
end

return Styles
