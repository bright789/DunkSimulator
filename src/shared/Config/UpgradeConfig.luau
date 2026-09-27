local UpgradeConfig = {
	StartingLevel = 1,
	StationName = "UpgradeStation",
	MaxDistance = 8,
	RequestCooldownSeconds = 0.5,
	SessionCheckSeconds = 0.2,
	Levels = {
		{ TrainingMultiplier = 1.00, Cost = 0 },
		{ TrainingMultiplier = 1.10, Cost = 250 },
		{ TrainingMultiplier = 1.20, Cost = 600 },
		{ TrainingMultiplier = 1.30, Cost = 1200 },
		{ TrainingMultiplier = 1.40, Cost = 2000 },
		{ TrainingMultiplier = 1.50, Cost = 3500 },
		{ TrainingMultiplier = 1.60, Cost = 5500 },
		{ TrainingMultiplier = 1.70, Cost = 8000 },
		{ TrainingMultiplier = 1.80, Cost = 12000 },
		{ TrainingMultiplier = 2.00, Cost = 18000 },
	},
}

function UpgradeConfig.GetLevel(level: number)
	if type(level) ~= "number" or level ~= level or level % 1 ~= 0 then
		return nil
	end
	return UpgradeConfig.Levels[level]
end

return UpgradeConfig
