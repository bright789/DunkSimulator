local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.Parent.Config.DataConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local DunkStyles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local Challenges = require(ReplicatedStorage.Shared.Config.ChallengeConfig)
local Rebirths = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local Leaderboards = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local Locker = require(ReplicatedStorage.Shared.Config.LockerConfig)

local Schema = {}

-- Player settings (v11). Music: background music on/off (MusicController).
local function defaultSettings()
	return { Music = true }
end

local function sanitizeSettings(stored)
	local settings = defaultSettings()
	if type(stored) ~= "table" then return settings, true end
	local repaired = false
	if type(stored.Music) == "boolean" then settings.Music = stored.Music else repaired = true end
	return settings, repaired
end

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
		Rebirths = 0,
		Daily = Daily.DefaultState(),
		Stats = Leaderboards.DefaultStats(ProgressionConfig.StartingVertical),
		Locker = Locker.DefaultState(),
		Settings = defaultSettings(),
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
	if migrated.SchemaVersion == 5 then
		migrated.Rebirths = 0
		migrated.SchemaVersion = 6
	end
	if migrated.SchemaVersion == 6 then
		migrated.Daily = Daily.DefaultState()
		migrated.SchemaVersion = 7
	end
	if migrated.SchemaVersion == 7 then
		-- Lifetime stats start now; the best Vertical so far is the current one.
		migrated.Stats = Leaderboards.DefaultStats(migrated.Vertical)
		migrated.SchemaVersion = 8
	end
	if migrated.SchemaVersion == 8 then
		-- Dunk Contest stats start at zero.
		if type(migrated.Stats) == "table" then
			migrated.Stats = table.clone(migrated.Stats)
			migrated.Stats.BestContestScore = 0
			migrated.Stats.ContestWins = 0
		end
		migrated.SchemaVersion = 9
	end
	if migrated.SchemaVersion == 9 then
		-- Locker: everyone starts with the free Classic shoes and ball.
		migrated.Locker = Locker.DefaultState()
		migrated.SchemaVersion = 10
	end
	if migrated.SchemaVersion == 10 then
		-- Settings: music starts on for everyone.
		migrated.Settings = defaultSettings()
		migrated.SchemaVersion = 11
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
	readInteger("Rebirths", 0, Rebirths.MaxRebirths)
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
	local daily, dailyRepaired = Daily.Sanitize(migrated.Daily)
	profile.Daily = daily
	repaired = repaired or dailyRepaired
	local stats, statsRepaired = Leaderboards.SanitizeStats(migrated.Stats, ProgressionConfig.StartingVertical, Config.MaxVertical)
	profile.Stats = stats
	repaired = repaired or statsRepaired
	local locker, lockerRepaired = Locker.Sanitize(migrated.Locker)
	profile.Locker = locker
	repaired = repaired or lockerRepaired
	local settings, settingsRepaired = sanitizeSettings(migrated.Settings)
	profile.Settings = settings
	repaired = repaired or settingsRepaired
	return profile, revision, nil, repaired
end

function Schema.Snapshot(values)
	if type(values) ~= "table" or values.Cash == nil or values.Vertical == nil or values.TrainingLevel == nil
		or values.EquippedDunkStyle == nil or values.UnlockedCourts == nil or values.CurrentCourt == nil
		or values.VerticalTrainingRemainder == nil or values.Challenges == nil or values.Rebirths == nil
		or values.Daily == nil or values.Stats == nil or values.Locker == nil or values.Settings == nil then
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
		and first.Rebirths == second.Rebirths
		and Daily.SameState(first.Daily, second.Daily)
		and Leaderboards.SameStats(first.Stats, second.Stats)
		and Locker.SameState(first.Locker, second.Locker)
		and first.Settings.Music == second.Settings.Music
end

return Schema
