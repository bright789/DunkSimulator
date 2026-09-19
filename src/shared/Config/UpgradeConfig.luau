local UpgradeConfig = {
	StartingLevel = 1,
	StationName = "UpgradeStation",
	MaxDistance = 8,
	RequestCooldownSeconds = 0.5,
	SessionCheckSeconds = 0.2,
	FeedbackSeconds = 2,
	Levels = {
		{ VerticalGain = 1, Cost = 0 },
		{ VerticalGain = 2, Cost = 100 },
		{ VerticalGain = 3, Cost = 300 },
		{ VerticalGain = 4, Cost = 750 },
		{ VerticalGain = 5, Cost = 1500 },
		{ VerticalGain = 6, Cost = 3000 },
		{ VerticalGain = 7, Cost = 6000 },
		{ VerticalGain = 8, Cost = 12000 },
		{ VerticalGain = 9, Cost = 25000 },
		{ VerticalGain = 10, Cost = 50000 },
	},
}

function UpgradeConfig.GetLevel(level: number)
	if type(level) ~= "number" or level ~= level or level % 1 ~= 0 then
		return nil
	end
	return UpgradeConfig.Levels[level]
end

return UpgradeConfig
