local UpgradeConfig = {
	StartingLevel = 1,
	StationName = "UpgradeStation",
	MaxDistance = 8,
	RequestCooldownSeconds = 0.5,
	SessionCheckSeconds = 0.2,
	-- Vertical gained per training rep (every 0.5 s at a station, or with Auto Train) at
	-- each Training Level, before court and Rebirth bonuses: Level n = n x 0.1.
	Levels = {
		{ VerticalPerRep = 0.1, Cost = 0 },
		-- Cheap first steps so a new player can buy something about every minute.
		{ VerticalPerRep = 0.2, Cost = 120 },
		{ VerticalPerRep = 0.3, Cost = 350 },
		{ VerticalPerRep = 0.4, Cost = 800 },
		{ VerticalPerRep = 0.5, Cost = 1500 },
		{ VerticalPerRep = 0.6, Cost = 3000 },
		{ VerticalPerRep = 0.7, Cost = 5500 },
		{ VerticalPerRep = 0.8, Cost = 8000 },
		{ VerticalPerRep = 0.9, Cost = 12000 },
		{ VerticalPerRep = 1.0, Cost = 18000 },
	},
}

function UpgradeConfig.GetLevel(level: number)
	if type(level) ~= "number" or level ~= level or level % 1 ~= 0 then
		return nil
	end
	return UpgradeConfig.Levels[level]
end

return UpgradeConfig
