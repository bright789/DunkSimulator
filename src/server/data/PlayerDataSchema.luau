local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.Parent.Config.DataConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local DunkStyles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local Challenges = require(ReplicatedStorage.Shared.Config.ChallengeConfig)

local Schema = {}

local function finite(value): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Schema.Defaults()
	return {
		SchemaVersion = Config.SchemaVersion,
		Cash = ProgressionConfig.StartingCash,
		Vertical = ProgressionConfig.StartingVertical,
		TrainingLevel = UpgradeConfig.StartingLevel,
		EquippedDunkStyle = DunkStyles.DefaultId,
		UnlockedCourts = Courts.DefaultUnlocks(),
		CurrentCourt = Courts.StartingId,
		VerticalTrainingRemainder = 0,
		Challenges = Challenges.DefaultState(),
	}
end

function Schema.Decode(stored)
	if stored == nil then
		return Schema.Defaults(), 0, nil, false
	end
	if type(stored) ~= "table" then
		return nil, nil, "Invalid profile structure"
	end
	local version = stored.SchemaVersion
	if version == nil then
		version = 0
	end
	if not finite(version) or version % 1 ~= 0 or version < 0 or version > Config.SchemaVersion then
		return nil, nil, "Unsupported schema version"
	end
	local revision = stored.Revision
	if revision == nil then
		revision = 0
	end
	if not finite(revision) or revision % 1 ~= 0 or revision < 0 or revision >= Config.MaxCash then
		return nil, nil, "Invalid persistence revision"
	end
	local migrated = table.clone(stored)
	if version == 0 then
		migrated.SchemaVersion = 1
	end
	if migrated.SchemaVersion == 1 then
		migrated.EquippedDunkStyle = DunkStyles.DefaultId
		migrated.SchemaVersion = 2
	end
	if migrated.SchemaVersion == 2 then
		migrated.UnlockedCourts = Courts.DefaultUnlocks()
		migrated.CurrentCourt = Courts.StartingId
		migrated.SchemaVersion = 3
	end
	if migrated.SchemaVersion == 3 then
		migrated.VerticalTrainingRemainder = 0
		migrated.SchemaVersion = 4
	end
	if migrated.SchemaVersion == 4 then
		migrated.Challenges = Challenges.DefaultState()
		migrated.SchemaVersion = 5
	end
	if migrated.SchemaVersion ~= Config.SchemaVersion then
		return nil, nil, "No migration for this schema version"
	end
	local profile = Schema.Defaults()
	local repaired = false
	local function readInteger(name: string, minimum: number, maximum: number)
		local original = migrated[name]
		local result = profile[name]
		if finite(original) then
			result = math.clamp(math.floor(original), minimum, maximum)
		end
		if original ~= result then
			repaired = true
		end
		profile[name] = result
	end
	readInteger("Cash", 0, Config.MaxCash)
	readInteger("Vertical", ProgressionConfig.StartingVertical, Config.MaxVertical)
	readInteger("TrainingLevel", UpgradeConfig.StartingLevel, #UpgradeConfig.Levels)
	profile.EquippedDunkStyle = DunkStyles.ResolveEquipped(migrated.EquippedDunkStyle, profile.Vertical)
	repaired = repaired or migrated.EquippedDunkStyle ~= profile.EquippedDunkStyle
	profile.UnlockedCourts = Courts.SanitizeUnlocks(migrated.UnlockedCourts)
	profile.CurrentCourt = Courts.ResolveCurrent(migrated.CurrentCourt, profile.UnlockedCourts)
	repaired = repaired or not Courts.SameUnlocks(migrated.UnlockedCourts, profile.UnlockedCourts)
		or migrated.CurrentCourt ~= profile.CurrentCourt
	profile.VerticalTrainingRemainder = Courts.NormalizeTrainingRemainder(migrated.VerticalTrainingRemainder)
	repaired = repaired or migrated.VerticalTrainingRemainder ~= profile.VerticalTrainingRemainder
	local storedChallenges = migrated.Challenges
	if type(storedChallenges) ~= "table" then
		repaired = true
		storedChallenges = {}
	end
	for challengeId, definition in Challenges.Definitions do
		local original = storedChallenges[challengeId]
		local target = Challenges.Target(definition)
		local progress = type(original) == "table" and original.Progress or nil
		local completed = nil
		if type(original) == "table" then completed = original.Completed end
		local normalized = type(progress) == "number" and finite(progress)
			and math.clamp(math.floor(progress), 0, target) or 0
		local claimed = completed == true
		if claimed then normalized = target end
		profile.Challenges[challengeId] = { Progress = normalized, Completed = claimed }
		if type(original) ~= "table" or progress ~= normalized or completed ~= claimed then repaired = true end
	end
	repaired = repaired or not Challenges.SameState(storedChallenges, profile.Challenges)
	return profile, revision, nil, repaired
end

function Schema.Snapshot(values)
	if type(values) ~= "table" or values.Cash == nil or values.Vertical == nil or values.TrainingLevel == nil
		or values.EquippedDunkStyle == nil or values.UnlockedCourts == nil or values.CurrentCourt == nil
		or values.VerticalTrainingRemainder == nil or values.Challenges == nil then
		return nil, "Runtime snapshot is missing progression"
	end
	local current = table.clone(values)
	current.SchemaVersion = Config.SchemaVersion
	local profile, _, problem, repaired = Schema.Decode(current)
	if not profile or problem or repaired then
		return nil, problem or "Runtime snapshot contains invalid progression"
	end
	return profile
end

function Schema.SameProgress(first, second): boolean
	return first.Cash == second.Cash and first.Vertical == second.Vertical
		and first.TrainingLevel == second.TrainingLevel
		and first.EquippedDunkStyle == second.EquippedDunkStyle
		and first.CurrentCourt == second.CurrentCourt and Courts.SameUnlocks(first.UnlockedCourts, second.UnlockedCourts)
		and first.VerticalTrainingRemainder == second.VerticalTrainingRemainder
		and Challenges.SameState(first.Challenges, second.Challenges)
end

return Schema
