local ProgressionConfig = require(script.Parent.ProgressionConfig)

local DunkConfig = {
	PickupDistance = 10,
	PickupCooldown = 0.5,
	BallDiameter = 2,
	BallColor = Color3.fromRGB(230, 115, 25),
	DunkHorizontalDistance = 8,
	DunkMinimumVertical = 35,
	DunkMaxBelowRim = 8,
	DunkMaxAboveRim = 8,
	DunkMaxEngagementAboveRim = 60,
	DunkInputBufferSeconds = 0.5,
	DunkBufferVerticalAllowance = 3,
	-- Facing or inward movement qualifies, but clear outward movement never does.
	DunkMaxFacingAngleDegrees = 110,
	DunkMaxRetreatSpeed = 3,
	DunkApproachDirectionEpsilon = 0.1,
	DunkCooldown = 1,
	DunkCashReward = 25,
	FeedbackDuration = 1.5,
	DebugDunkValidation = false,
	Execution = {
		AnimationName = "BasicOneHand",
		FacingMaxTorque = 40000,
		FacingMaxAngularVelocity = 8,
		FacingResponsiveness = 20,
		FacingDirectionEpsilon = 0.1,
		HandFollowFraction = 0.35,
		GatherSeconds = 0.3,
		FinishSeconds = 0.25,
		ReturnSeconds = 0.2,
		TimeoutSeconds = 1.2,
		RootBelowRim = 3,
		NormalizeMaxVelocity = 100,
		NormalizeTimeoutSeconds = 1.25,
		OwnershipSettleSeconds = 0.1,
		AlignmentTimeoutSeconds = 0.75,
		AlignmentSettleSeconds = 0.08,
		AlignmentSettleSpeed = 3,
		MaxAssistDistance = 5,
		RimStandOff = 2,
		MaxVelocity = 20,
		MaxForce = 60000,
		Responsiveness = 40,
		PositionTolerance = 1.5,
		BallAboveRim = 2,
		BallBelowRim = 2,
		RimMovementTolerance = 0.25,
		DebugLogging = false,
	},
}

function DunkConfig.GetMaxAboveRim(vertical: number): number
	local extraHeight = math.max(0, ProgressionConfig.GetJumpHeight(vertical)
		- ProgressionConfig.GetJumpHeight(DunkConfig.DunkMinimumVertical))
	return math.min(DunkConfig.DunkMaxAboveRim + extraHeight, DunkConfig.DunkMaxEngagementAboveRim)
end

return DunkConfig
