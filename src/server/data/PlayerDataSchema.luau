local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.Parent.Config.DataConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)

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
	return profile, revision, nil, repaired
end

function Schema.Snapshot(values)
	if type(values) ~= "table" or values.Cash == nil or values.Vertical == nil or values.TrainingLevel == nil then
		return nil, "Runtime snapshot is missing progression"
	end
	local profile, _, problem, repaired = Schema.Decode(values)
	if not profile or problem or repaired then
		return nil, problem or "Runtime snapshot contains invalid progression"
	end
	return profile
end

function Schema.SameProgress(first, second): boolean
	return first.Cash == second.Cash and first.Vertical == second.Vertical
		and first.TrainingLevel == second.TrainingLevel
end

return Schema
