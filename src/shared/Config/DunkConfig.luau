local ProgressionConfig = require(script.Parent.ProgressionConfig)
local CourtConfig = require(script.Parent.CourtConfig)

-- The most Vertical anyone can train to: the highest court training cap.
local function highestTrainingCap(): number
	local highest = 0
	for _, court in CourtConfig.Definitions do
		highest = math.max(highest, court.TrainingVerticalCap or 0)
	end
	return highest
end

local DunkConfig = {
	PickupDistance = 10,
	PickupCooldown = 0.5,
	BallDiameter = 1.5,
	BallColor = Color3.fromRGB(230, 115, 25),
	DunkHorizontalDistance = 8,
	DunkMinimumVertical = 35,
	DunkMaxBelowRim = 8,
	DunkMaxAboveRim = 8,
	-- Hard cap on how far above the rim a dunk may start. High-Vertical players can start
	-- at their apex; the Descent phase brings them down into the wind-up. It follows the
	-- peak of a jump at the highest court cap (+20 studs of room), so raising a cap never
	-- leaves top players "too high" (250 Vertical: about 285).
	DunkMaxEngagementAboveRim = math.ceil(ProgressionConfig.GetJumpHeight(highestTrainingCap()) + 20),
	DunkInputBufferSeconds = 0.5,
	DunkBufferVerticalAllowance = 3,
	-- Presses this far above the allowed height keep buffering while the player falls.
	DunkHighBufferStuds = 45,
	DunkHighBufferSeconds = 1.1,
	-- Facing or inward movement qualifies, but clear outward movement never does.
	DunkMaxFacingAngleDegrees = 110,
	DunkMaxRetreatSpeed = 3,
	DunkApproachDirectionEpsilon = 0.1,
	DunkCooldown = 1,
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
		-- Rising players keep moving for a moment after F; allow this much overshoot
		-- above the accepted entry ceiling before cancelling.
		HandoffOvershootStuds = 12,
		-- Velocity kept per Heartbeat during the ownership handoff (0 = hard stop).
		HandoffVelocityDamping = 0.45,
		-- Descent into the wind-up: seconds = base + drop studs * per-stud, capped.
		DescentBaseSeconds = 0.22,
		DescentSecondsPerStud = 0.008,
		DescentMaxSeconds = 0.7,
		DescentMaxVelocity = 240,
		DescentResponsiveness = 120,
		-- Air-trick combos (how many, which, Cash) live in DunkRewards.Tricks; a combo
		-- stretches the descent to DunkRewards.ComboSeconds when it needs more air time.
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
		-- Rim hang: root this far below the rim, just outside the ring's front edge.
		HangRootBelowRim = 3.3,
		HangStandOffPadding = 0.35,
		MaxHangReach = 1.2,
		DefaultRimRadius = 1.3,
		-- Extra room for the raised wind-up position when checking alignment.
		WindupTolerance = 1,
		DebugLogging = false,
	},
}

function DunkConfig.GetMaxAboveRim(vertical: number): number
	local extraHeight = math.max(0, ProgressionConfig.GetJumpHeight(vertical)
		- ProgressionConfig.GetJumpHeight(DunkConfig.DunkMinimumVertical))
	return math.min(DunkConfig.DunkMaxAboveRim + extraHeight, DunkConfig.DunkMaxEngagementAboveRim)
end

return DunkConfig
