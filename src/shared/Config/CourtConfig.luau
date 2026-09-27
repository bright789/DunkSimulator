local Courts = {
	StartingId = "Neighborhood",
	RequestCooldownSeconds = 1,
	ReadCooldownSeconds = 0.5,
	PortalDistance = 10,
	-- Seconds a player rides the bus before arriving at the next court.
	RideSeconds = 3.4,
	SpawnWaitSeconds = 10,
	ArrivalClearance = 0.5,
	ArrivalWidth = 4,
	TrainingProgressScale = 1000000,
	Definitions = {
		Neighborhood = {
			Id = "Neighborhood", DisplayName = "Neighborhood Court", Order = 1, StartingCourt = true,
			TrainingVerticalCap = 75,
			Requirements = { Vertical = 0, Cash = 0 },
			Bonuses = { DunkCashMultiplier = 1.00, TrainingMultiplier = 1.00 },
			GameplayPath = { "Gameplay" }, SpawnPath = { "SpawnLocation" },
			LegacyRootFallback = true,
			Portals = { HighSchool = "HighSchoolPortal" },
		},
		HighSchool = {
			Id = "HighSchool", DisplayName = "High School Gym", Order = 2, StartingCourt = false,
			TrainingVerticalCap = 150,
			Requirements = { Vertical = 75, Cash = 6000 },
			Bonuses = { DunkCashMultiplier = 1.25, TrainingMultiplier = 1.15 },
			GameplayPath = { "Gameplay", "Courts", "HighSchool" },
			SpawnPath = { "Gameplay", "Courts", "HighSchool", "Spawn" },
			Portals = { Neighborhood = "NeighborhoodPortal" },
		},
	},
}

function Courts.Get(courtId)
	return type(courtId) == "string" and Courts.Definitions[courtId] or nil
end

function Courts.OrderedIds(): { string }
	local ids = {}
	for courtId in Courts.Definitions do table.insert(ids, courtId) end
	table.sort(ids, function(first, second) return Courts.Get(first).Order < Courts.Get(second).Order end)
	return ids
end

function Courts.DefaultUnlocks()
	local unlocked = {}
	for courtId, definition in Courts.Definitions do
		if definition.StartingCourt then unlocked[courtId] = true end
	end
	return unlocked
end

function Courts.SanitizeUnlocks(stored)
	local unlocked = Courts.DefaultUnlocks()
	if type(stored) == "table" then
		for courtId in Courts.Definitions do
			if stored[courtId] == true then unlocked[courtId] = true end
		end
	end
	return unlocked
end

function Courts.SameUnlocks(first, second): boolean
	if type(first) ~= "table" or type(second) ~= "table" then return false end
	for courtId, value in first do if second[courtId] ~= value then return false end end
	for courtId, value in second do if first[courtId] ~= value then return false end end
	return true
end

function Courts.ResolveCurrent(courtId, unlocked): string
	return Courts.Get(courtId) and unlocked[courtId] == true and courtId or Courts.StartingId
end

function Courts.GetBonuses(courtId, unlocked)
	local court = Courts.Get(courtId)
	if not court or type(unlocked) ~= "table" or unlocked[courtId] ~= true then
		court = Courts.Get(Courts.StartingId)
	end
	return court.Bonuses
end

function Courts.GetTrainingCap(courtId, unlocked): number
	local court = Courts.Get(courtId)
	if not court or type(unlocked) ~= "table" or unlocked[courtId] ~= true then
		court = Courts.Get(Courts.StartingId)
	end
	return court.TrainingVerticalCap
end

function Courts.NormalizeTrainingRemainder(value): number
	if type(value) ~= "number" or value ~= value or value < 0 or value >= 1 then return 0 end
	local scale = Courts.TrainingProgressScale
	local units = math.clamp(math.floor(value * scale + 0.5), 0, scale - 1)
	return units / scale
end

return Courts
