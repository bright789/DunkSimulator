local Challenges = {
	ClaimCooldownSeconds = 0.35,
	ReadCooldownSeconds = 0.5,
	Definitions = {
		basic_dunker_1 = {
			Id = "basic_dunker_1", DisplayName = "Getting Started",
			Description = "Perform 10 Basic One-Hand dunks.", Type = "DunkStyleCount",
			Requirements = { DunkStyle = "BasicOneHand", Count = 10 },
			Reward = { Cash = 150 }, Order = 1,
		},
		two_hand_dunker_1 = {
			Id = "two_hand_dunker_1", DisplayName = "Power Finisher",
			Description = "Perform 15 Two-Hand Power dunks.", Type = "DunkStyleCount",
			Requirements = { DunkStyle = "TwoHandPower", Count = 15 },
			Reward = { Cash = 350 }, Order = 2,
		},
		tomahawk_dunker_1 = {
			Id = "tomahawk_dunker_1", DisplayName = "Tomahawk Specialist",
			Description = "Perform 15 Tomahawk dunks.", Type = "DunkStyleCount",
			Requirements = { DunkStyle = "Tomahawk", Count = 15 },
			Reward = { Cash = 600 }, Order = 3,
		},
		windmill_dunker_1 = {
			Id = "windmill_dunker_1", DisplayName = "Windmill Specialist",
			Description = "Perform 20 Windmill dunks.", Type = "DunkStyleCount",
			Requirements = { DunkStyle = "Windmill", Count = 20 },
			Reward = { Cash = 1000 }, Order = 4,
		},
		vertical_50 = {
			Id = "vertical_50", DisplayName = "Rising Athlete",
			Description = "Reach 60 Vertical.", Type = "VerticalReached",
			Requirements = { Vertical = 60 },
			Reward = { Cash = 300 }, Order = 5,
		},
		vertical_75 = {
			Id = "vertical_75", DisplayName = "Above the Rim",
			Description = "Reach 120 Vertical.", Type = "VerticalReached",
			Requirements = { Vertical = 120 },
			Reward = { Cash = 800 }, Order = 6,
		},
		highschool_dunks_10 = {
			Id = "highschool_dunks_10", DisplayName = "High School Highlights",
			Description = "Perform 25 dunks at High School Gym.", Type = "CourtDunkCount",
			Requirements = { Court = "HighSchool", Count = 25 },
			Reward = { Cash = 1500 }, Order = 7,
		},
	},
}

function Challenges.Get(challengeId)
	return type(challengeId) == "string" and Challenges.Definitions[challengeId] or nil
end

function Challenges.OrderedIds(): { string }
	local ids = {}
	for challengeId in Challenges.Definitions do table.insert(ids, challengeId) end
	table.sort(ids, function(first, second)
		return Challenges.Definitions[first].Order < Challenges.Definitions[second].Order
	end)
	return ids
end

function Challenges.Target(definition): number
	return definition.Type == "VerticalReached" and definition.Requirements.Vertical or definition.Requirements.Count
end

function Challenges.DefaultState()
	local state = {}
	for challengeId in Challenges.Definitions do
		state[challengeId] = { Progress = 0, Completed = false }
	end
	return state
end

function Challenges.CopyState(state)
	local copy = {}
	for challengeId in Challenges.Definitions do
		local entry = state[challengeId]
		copy[challengeId] = { Progress = entry.Progress, Completed = entry.Completed }
	end
	return copy
end

function Challenges.SameState(first, second): boolean
	if type(first) ~= "table" or type(second) ~= "table" then return false end
	for challengeId, entry in first do
		local other = second[challengeId]
		if not Challenges.Get(challengeId) or type(entry) ~= "table" or type(other) ~= "table"
			or entry.Progress ~= other.Progress or entry.Completed ~= other.Completed then return false end
	end
	for challengeId in Challenges.Definitions do
		if first[challengeId] == nil or second[challengeId] == nil then return false end
	end
	for challengeId in second do
		if not Challenges.Get(challengeId) then return false end
	end
	return true
end

return Challenges
