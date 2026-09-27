return {
	Dunk = {
		Styles = {
			BasicOneHand = { ImpactIntensity = 0.7, RimSizePixels = 42, RimStreaks = 0,
				RimColor = Color3.fromRGB(244, 247, 250) },
			TwoHandPower = { ImpactIntensity = 0.9, RimSizePixels = 54, RimStreaks = 2,
				RimColor = Color3.fromRGB(244, 247, 250) },
			Tomahawk = { ImpactIntensity = 1.1, RimSizePixels = 62, RimStreaks = 3,
				RimColor = Color3.fromRGB(255, 195, 120) },
			Windmill = { ImpactIntensity = 1.3, RimSizePixels = 72, RimStreaks = 4,
				RimColor = Color3.fromRGB(255, 195, 120) },
		},
		PopupInSeconds = 0.12,
		-- Success popup starts this big and bounces back to 1 over PopupInSeconds * PopBounceLength.
		PopStartScale = 1.35,
		PopBounceLength = 2.4,
		PopupHoldSeconds = 1.05,
		PopupOutSeconds = 0.22,
		PopupRisePixels = 12,
		RimBurstSeconds = 0.3,
		RimMaxDistance = 45,
		RimStreakLengthPixels = 16,
		RewardScalePerCash = 0.00025,
		MaxRewardScale = 1.08,
		-- Air-trick popup (one per paid trick while dropping into the dunk).
		TrickPopStartScale = 1.4,
		TrickPopSeconds = 0.26,
		TrickHoldSeconds = 0.75,
		TrickFadeSeconds = 0.2,
		StaleCueGuardSeconds = 0.5,
	},
	Camera = {
		CameraShakeEnabled = true,
		FOVPunchEnabled = true,
		DurationSeconds = 0.3,
		ShakeStuds = 0.09,
		ShakeFrequency = 12,
		MaxShakeStuds = 0.35,
		FOVDegrees = 2.2,
		MaxFOVDegrees = 6,
		MaxCameraOffsetStuds = 0.45,
		Styles = {
			BasicOneHand = {
				Impact = { DurationSeconds = 0.22, FOVDelta = 2.52, ShakeStuds = 0.121,
					Kick = Vector3.new(0, -0.02, 0) },
			},
			TwoHandPower = {
				Gather = { DurationSeconds = 0.28, FOVDelta = -0.8 },
				Windup = { DurationSeconds = 0.19, FOVDelta = -1.1 },
				Impact = { DurationSeconds = 0.32, FOVDelta = 4.05, ShakeStuds = 0.22,
					Kick = Vector3.new(0, -0.085, -0.02) },
			},
			Tomahawk = {
				Gather = { DurationSeconds = 0.3, FOVDelta = -0.5 },
				Windup = { DurationSeconds = 0.25, FOVDelta = -1.4 },
				Impact = { DurationSeconds = 0.32, FOVDelta = 5.4, ShakeStuds = 0.264,
					Kick = Vector3.new(0, -0.09, -0.05) },
			},
			Windmill = {
				Gather = { DurationSeconds = 0.62, FOVDelta = 1.6 },
				Windup = { DurationSeconds = 0.3, FOVDelta = 2.2 },
				Impact = { DurationSeconds = 0.36, FOVDelta = 6.12, ShakeStuds = 0.308,
					Kick = Vector3.new(0, -0.08, -0.045) },
			},
		},
	},
	Hint = { FadeSeconds = 0.18, SlidePixels = 8 },
	Stats = {
		-- Gain badge on the stat cards: pops in, holds, then rises and fades.
		GainHoldSeconds = 1.1,
		GainFadeSeconds = 0.45,
		GainRisePixels = 14,
		BadgeWidth = 98,
		BadgeHeight = 28,
		BadgeTextSize = 19,
		BadgePopScale = 1.45,
		BadgePopSeconds = 0.28,
		LevelUpText = "LEVEL UP!",
		PulseSeconds = 0.18,
		CashScale = 1.04,
		VerticalScale = 1.025,
		LevelScale = 1.05,
	},
	Unlock = {
		FadeSeconds = 0.2,
		SlidePixels = 8,
		DunkHoldSeconds = 2,
		CourtHoldSeconds = 2.2,
		UpgradeHoldSeconds = 2,
		UpgradePulseScale = 1.035,
	},
	Arrival = { FadeSeconds = 0.22, HoldSeconds = 1.4 },
	Challenge = {
		FadeSeconds = 0.18,
		SlidePixels = 10,
		CompletionHoldSeconds = 1.25,
		ClaimHoldSeconds = 1.65,
	},
	UI = { HoverScale = 1.025, PressScale = 0.96, TweenSeconds = 0.12 },
	Audio = {
		-- Free Creator Store audio: Roblox's own UI sounds and the Pro Sound Effects library.
		-- Swap any ID for your own upload; "" = silent.
		AssetIds = {
			BasketballPickup = "rbxassetid://9113730389", -- Catch Ball 2
			DunkImpact = "rbxassetid://9116763770", -- Metal Pole Hits 2
			CashReward = "rbxassetid://9113728042", -- Cash Register 1
			AirTrick = "rbxassetid://9126073001", -- Synth sparkle bell ding (pitched up per combo)
			PerfectSlam = "rbxassetid://9126073318", -- Synth sparkle bell ding, longer
			TrainingTick = "rbxassetid://9114742182", -- Gym bag thud
			UpgradePurchase = "rbxassetid://17208380755", -- Roblox GUI - Purchase
			DunkUnlock = "rbxassetid://9119816546", -- Synth power-up rise
			CourtUnlock = "rbxassetid://15675043410", -- Roblox UI tonal stinger
			CourtArrival = "rbxassetid://9113052962", -- Bus air brake burst
			UIClick = "rbxassetid://15675032796", -- Roblox UI small click
			ChallengeReady = "rbxassetid://17208361335", -- Roblox GUI - Notification High
			ChallengeClaim = "rbxassetid://9119220620", -- Slot machine payout
		},
		StyleAssetIds = {
			BasicOneHand = { Approach = "", Whoosh = "rbxassetid://9126229255", Impact = "", Rim = "rbxassetid://9125434858" },
			TwoHandPower = { Approach = "", Whoosh = "rbxassetid://9126229255", Impact = "", Rim = "rbxassetid://9125434858" },
			Tomahawk = { Approach = "", Whoosh = "rbxassetid://9126229255", Impact = "rbxassetid://9116764094", Rim = "rbxassetid://9125434858" },
			Windmill = { Approach = "", Whoosh = "rbxassetid://9126229255", Impact = "rbxassetid://9116764094", Rim = "rbxassetid://9125434858" },
		},
		StyleVolumes = {
			Approach = 0.14,
			Whoosh = 0.3,
			Impact = 0.45,
			Rim = 0.3,
		},
		Volumes = {
			BasketballPickup = 0.3,
			DunkImpact = 0.45,
			CashReward = 0.22,
			AirTrick = 0.2,
			PerfectSlam = 0.35,
			TrainingTick = 0.12,
			UpgradePurchase = 0.3,
			DunkUnlock = 0.3,
			CourtUnlock = 0.35,
			CourtArrival = 0.25,
			UIClick = 0.15,
			ChallengeReady = 0.28,
			ChallengeClaim = 0.35,
		},
		TrainingMinIntervalSeconds = 1.5,
		-- 3D sounds in the world that every nearby player hears (WorldAudio).
		World = {
			AssetIds = {
				Dribble = "rbxassetid://9113342352", -- Basketball on concrete
				BallBounce = "rbxassetid://9113342352",
				RimClang = "rbxassetid://9116763770", -- Metal pole hit
				RimRattle = "rbxassetid://9125434858", -- Chain-link metal rattle
				CrowdCheer = "rbxassetid://9120974911", -- Wrestling crowd roar
				CrowdClap = "rbxassetid://9114762281", -- Hand claps
				GymAmbience = "rbxassetid://9119562817", -- Stadium crowd bed (High School loop)
				BusDoor = "rbxassetid://9114660506", -- Bus door open/close
				BusBrake = "rbxassetid://9113052763", -- Bus air brakes
			},
			Volumes = {
				Dribble = 0.35, BallBounce = 0.3, RimClang = 0.5, RimRattle = 0.35,
				CrowdCheer = 0.55, CrowdClap = 0.5, GymAmbience = 0.1, BusDoor = 0.5, BusBrake = 0.45,
			},
			RollOffMinDistance = 10,
			RollOffMaxDistance = 150,
			-- This many cheering fans turn claps into a full crowd roar.
			CheerCrowdSize = 6,
			AmbienceFadeSeconds = 1.5,
		},
	},
	-- Perfect-slam meter shown to the dunker (timing windows live in DunkRewards.Timing).
	SlamMeter = {
		-- Estimated server time between the end of the descent and the wind-up start.
		SettleSeconds = 0.14,
		-- Where the slam moment sits on the bar (the rest shows late presses).
		SlamLine = 0.82,
		HideDelaySeconds = 0.9,
		CallPopScale = 1.6,
		CallHoldSeconds = 0.8,
	},
}
