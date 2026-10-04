local ProgressionConfig = {
	-- Same as DunkConfig.DunkMinimumVertical, so a new player can dunk straight away (train
	-- second). Saved profiles below this are raised to it on load (PlayerDataSchema).
	StartingVertical = 35,
	StartingCash = 0,
	Training = {
		StationName = "VerticalTrainer",
		TickIntervalSeconds = 0.5,
		MaxDistance = 10,
		-- Vertical per rep comes from the Training Level (UpgradeConfig.Levels.VerticalPerRep).
		CapFeedbackCooldownSeconds = 2,
		-- Active training: every rep is a beat. Press (click / tap / RB) right on the beat for a
		-- bigger rep. The server judges the press (its own clock minus latency) like the slam
		-- meter. Only one press per beat counts: mashing gets no bonus.
		Rhythm = {
			PerfectSeconds = 0.07,
			GoodSeconds = 0.14,
			PerfectMultiplier = 3,
			GoodMultiplier = 1.5,
			MinPressGapSeconds = 0.2,
			MaxLatencyCompensationSeconds = 0.25,
		},
	},
	Jump = {
		ReferenceVertical = 30,
		BaseHeight = 7.2,
		Exponent = 1.7,
		-- Workspace gravity set at server start. Humanoid.JumpHeight keeps every
		-- Vertical level's apex the same; higher gravity only shortens hang time.
		Gravity = 285,
	},
}

function ProgressionConfig.GetJumpHeight(vertical: number): number
	local jump = ProgressionConfig.Jump
	return jump.BaseHeight * (math.max(vertical, 0) / jump.ReferenceVertical) ^ jump.Exponent
end

return ProgressionConfig
