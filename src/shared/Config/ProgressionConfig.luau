local ProgressionConfig = {
	StartingVertical = 30,
	StartingCash = 0,
	Training = {
		StationName = "VerticalTrainer",
		TickIntervalSeconds = 0.5,
		MaxDistance = 10,
	},
	Jump = {
		ReferenceVertical = 30,
		BaseHeight = 7.2,
		Exponent = 1.7,
	},
}

function ProgressionConfig.GetJumpHeight(vertical: number): number
	local jump = ProgressionConfig.Jump
	return jump.BaseHeight * (math.max(vertical, 0) / jump.ReferenceVertical) ^ jump.Exponent
end

return ProgressionConfig
