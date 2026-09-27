-- Client-only presentation tuning. Nothing here changes possession, dunk
-- eligibility, rewards, or any other server-owned gameplay decision.
return {
	Ball = {
		-- Seconds to blend when the visual ball switches between sources.
		SourceBlendSeconds = 0.1,
		-- Render delay used to smooth server-moved (anchored) dunk ball updates.
		InterpolationDelaySeconds = 0.05,
		MaxSnapshots = 12,
		-- Dunks: the ball rides the hand, is steered over the ring centre on the slam,
		-- and is let go once the hand drives down to the rim.
		SlamCenterPull = 0.85,
		ReleaseAboveRim = 0.25,
		ReleaseSpeed = 38,
		Restitution = 0.5,
		FloorFriction = 0.75,
		-- After a dunk the loose ball is caught back once the player has landed.
		CatchDelaySeconds = 0.45,
		CatchBlendSeconds = 0.22,
		-- Motion trail behind the ball from the descent until the dunk ends (0 = off).
		TrailLifetime = 0.1,
		TrailColor = Color3.fromRGB(255, 190, 110),
		-- Ball detail: pebbled leather with dark seams that roll with the ball's motion.
		SeamColor = Color3.fromRGB(26, 18, 14),
		SeamWidth = 0.045, -- fraction of the ball diameter
		DribbleSpin = 0.6, -- extra forward spin per stud the ball travels while dribbling
		MaxSpinStep = 4, -- studs; bigger jumps (teleports) do not spin the ball
		-- Loose-ball floor hits faster than this (studs/s) make a bounce sound.
		BounceSoundMinSpeed = 8,
		-- While the player trains, the ball rests on the floor beside them.
		RestSide = 2.4,
		RestForward = 0.8,
		RestBlendSeconds = 0.35,
	},

	Dribble = {
		IdleBouncesPerSecond = 1.55,
		RunBouncesPerSecond = 2.45,
		RunSpeed = 16,
		SpeedSmoothing = 10,
		-- Fraction of each bounce spent travelling down to the floor.
		DownFraction = 0.44,
		-- Ball position in HumanoidRootPart space (studs). X is to the right.
		SideOffset = 1.05,
		IdleForwardOffset = 0.6,
		RunForwardOffset = 1.4,
		-- Height of the ball's centre at the top of the bounce, below the root.
		TopBelowRoot = 1.0,
		FloorProbeDistance = 12,
		GatherSeconds = 0.14,
		-- Hand IK: how far the hand follows the ball down before it lets go.
		HandFollowDepth = 0.45,
		ArmWeight = 0.95,
		ArmBlendSeconds = 0.15,
		IdleLeanDegrees = 9,
		RunLeanDegrees = 15,
		LeanSmoothing = 8,
		OffArmGuardDegrees = 22,
	},

	Air = {
		-- Extra gravity (multiplier) while falling for a snappier, less floaty jump.
		FallGravityMultiplier = 1.45,
		BlendInSeconds = 0.12,
		BlendOutSeconds = 0.08,
		-- Knee tuck while rising fast, extension while falling toward the floor.
		RiseTuckDegrees = 38,
		FallReachDegrees = 12,
		TuckSpeedReference = 60,
		ArmLiftDegrees = 28,
		HeldBallChestLift = 22,
	},

	Descent = {
		-- Tuck-and-trick pose while a high jump drops into the dunk.
		BlendInSeconds = 0.06,
		BlendOutSeconds = 0.12,
		-- Air-trick timing (which tricks, how long each) comes from DunkRewards.Tricks.
		-- The body opens toward the wind-up pose from this fraction of the descent.
		UntuckStartFraction = 0.72,
		EndTuck = 0.55,
		-- Body shape per trick (degrees): Tuck = flips, Layout = 360, Pike = 720/corkscrew,
		-- Star = cartwheel (legs and free arm spread).
		Shapes = {
			Tuck = { Hip = 80, Knee = 115, Waist = 18, Spread = 0 },
			Layout = { Hip = 20, Knee = 25, Waist = 4, Spread = 0 },
			Pike = { Hip = 95, Knee = 10, Waist = 24, Spread = 0 },
			Star = { Hip = 15, Knee = 15, Waist = 2, Spread = 32 },
		},
		ShapeBlendRate = 14,
		StarArmDegrees = 85,
		BallChestLiftDegrees = 38,
		BallElbowDegrees = 95,
	},

	Rim = {
		-- Hand grip on the front of the ring while hanging.
		GripBlendInSeconds = 0.05,
		GripBlendOutSeconds = 0.12,
		GripHandSpacing = 0.5,
		-- Leg swing while hanging (degrees) and its decay.
		HangHipDegrees = 28,
		HangKneeDegrees = 38,
		HangSwingDegrees = 22,
		HangSwingSpeed = 9,
		HangSwingDecay = 2.6,
		-- Ring bend: spring toward this angle while someone hangs, kicked on impact.
		HangBendDegrees = 9,
		ImpactKickDegreesPerSecond = 420,
		Stiffness = 700,
		Damping = 16,
		HitStopSeconds = 0.075,
		Sparks = 26,
		SparkColor = Color3.fromRGB(255, 214, 120),
	},

	Transit = {
		-- Bus departure (server ride length is CourtConfig.RideSeconds).
		BusSearchRadius = 40,
		DoorOpenSeconds = 0.35,
		BoardSeconds = 0.5,
		DriveDistance = 120,
		-- Extra driving time after the rider's screen fades, before the bus returns.
		DriveOverrunSeconds = 1.4,
		ReturnDelaySeconds = 2.5,
		RiderFadeSeconds = 0.35,
		ScreenFadeOutSeconds = 0.35,
		ScreenFadeInSeconds = 0.5,
		-- Rider camera: a fixed spot across the road (or the curb side if blocked), slightly
		-- ahead of the bus, that turns to follow it as it pulls away.
		CameraSide = 22,
		CameraAhead = 12,
		CameraHeight = 7,
	},

	Crowd = {
		-- Spectators (builder-made, tag "Spectator") animate only near the camera.
		AnimateDistance = 220,
		UpdateHz = 30,
		-- Heads: attentive fans follow whoever is dunking (else you) within LookDistance;
		-- the rest glance around slowly.
		AttentiveChance = 0.75,
		LookDistance = 90,
		LookYawDegrees = 60,
		LookPitchDegrees = 25,
		LookRate = 5,
		IdleLookDegrees = 22,
		BreathDegrees = 1.4,
		BreathSpeed = 1.7,
		-- Cheer when a player within CheerRadius slams a dunk: arms up, fist pumps, bouncing.
		CheerRadius = 170,
		CheerDelayMax = 0.3,
		CheerAttackSeconds = 0.15,
		CheerHoldSeconds = 1.3,
		CheerReleaseSeconds = 0.5,
		StandBounce = 0.9,
		SeatedBounce = 0.35,
		BounceSpeed = 9,
		PumpDegrees = 12,
		-- A Perfect slam re-triggers the cheer this much bigger (bounce and volume).
		PerfectHype = 1.5,
	},

	Workout = {
		-- Leg-day routine played while holding the Vertical Trainer prompt.
		Routine = {
			{ Exercise = "Squat", Reps = 4, RepSeconds = 1.0 },
			{ Exercise = "Lunge", Reps = 4, RepSeconds = 1.1 },
			{ Exercise = "JumpSquat", Reps = 3, RepSeconds = 0.95 },
			{ Exercise = "CalfRaise", Reps = 4, RepSeconds = 0.7 },
		},
		BlendSeconds = 0.2,
		-- Workout pauses while the player walks around.
		MaxMoveSpeed = 3,
		SquatDrop = 1.1,
		LungeDrop = 0.95,
		JumpHeight = 1.6,
		CalfRaiseHeight = 0.45,
	},

	Landing = {
		MinImpactSpeed = 22,
		HeavyImpactSpeed = 110,
		MaxDipStuds = 0.6,
		RecoverSeconds = 0.32,
		CameraDipStuds = 0.55,
		DustParticles = 14,
		HeavyDustParticles = 30,
		DustColor = Color3.fromRGB(205, 190, 165),
	},
}
