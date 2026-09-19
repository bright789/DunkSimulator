local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Parent.Config.DataConfig)
local Schema = require(script.Parent.PlayerDataSchema)

local Store = {}
local dataStore = nil

function Store.Name(): string
	return RunService:IsStudio() and Config.StudioStoreName or Config.ProductionStoreName
end

local function getStore()
	if not dataStore then
		assert(Config.StudioStoreName ~= Config.ProductionStoreName, "Studio and production stores must differ")
		dataStore = DataStoreService:GetDataStore(Store.Name())
	end
	return dataStore
end

local function retry(userId: number, operation: string, callback, canContinue)
	for attempt = 1, Config.MaxAttempts do
		if not canContinue() then
			return false, "Operation cancelled or deadline reached"
		end
		local success, result = pcall(callback)
		if success then
			return true, result
		end
		warn(string.format("[DataService] %s failed for player %d (%d/%d): %s",
			operation, userId, attempt, Config.MaxAttempts, tostring(result)))
		if attempt < Config.MaxAttempts and canContinue() then
			local delaySeconds = math.min(Config.RetryBaseSeconds * 2 ^ (attempt - 1), Config.RetryMaxSeconds)
			task.wait(delaySeconds + math.random() * Config.RetryJitterSeconds)
		end
	end
	return false, "DataStore retries exhausted"
end

function Store.Load(userId: number, canContinue)
	local success, stored = retry(userId, "Load", function()
		local options = Instance.new("DataStoreGetOptions")
		options.UseCache = false
		return getStore():GetAsync(Config.KeyPrefix .. tostring(userId), options)
	end, canContinue)
	if not success then
		return nil, nil, stored
	end
	return Schema.Decode(stored)
end

function Store.Write(userId: number, pending, canContinue)
	local rejection = nil
	local success, stored = retry(userId, "Save", function()
		return getStore():UpdateAsync(Config.KeyPrefix .. tostring(userId), function(current, keyInfo)
			rejection = nil
			if not canContinue() then
				rejection = "Cancelled"
				return nil
			end
			local profile, revision, problem = Schema.Decode(current)
			if not profile then
				rejection = problem
				return nil
			end
			local userIds = keyInfo and keyInfo:GetUserIds() or (userId > 0 and { userId } or {})
			local metadata = keyInfo and keyInfo:GetMetadata() or {}
			if current and current.WriteId == pending.WriteId and revision == pending.Revision + 1 then
				return current, userIds, metadata
			end
			if revision ~= pending.Revision then
				rejection = "Revision conflict"
				return nil
			end
			local updated = current and table.clone(current) or {}
			updated.SchemaVersion = Config.SchemaVersion
			updated.Cash = pending.Snapshot.Cash
			updated.Vertical = pending.Snapshot.Vertical
			updated.TrainingLevel = pending.Snapshot.TrainingLevel
			updated.Revision = pending.Revision + 1
			updated.WriteId = pending.WriteId
			return updated, userIds, metadata
		end)
	end, canContinue)
	if not success then
		return false, false, stored
	end
	if rejection then
		return false, rejection ~= "Cancelled", rejection
	end
	if type(stored) ~= "table" or stored.WriteId ~= pending.WriteId or stored.Revision ~= pending.Revision + 1 then
		return false, true, "Unexpected save response"
	end
	return true, false, nil
end

function Store.ResetStudioData(userId: number, confirmation: string)
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Reset is Studio EDIT MODE only; stop all tests first")
	assert(type(userId) == "number" and userId % 1 == 0 and userId > 0, "Use your positive solo-test UserId")
	assert(userId == game:GetService("StudioService"):GetUserId(), "Reset only the signed-in Studio user's solo-test data")
	assert(confirmation == "RESET " .. tostring(userId), "Confirmation must be RESET followed by your exact UserId")
	assert(Store.Name() == Config.StudioStoreName and Store.Name() ~= Config.ProductionStoreName, "Reset must use the isolated DEV store")
	local success, problem = pcall(function()
		getStore():RemoveAsync(Config.KeyPrefix .. tostring(userId))
	end)
	assert(success, "DEV reset failed: " .. tostring(problem))
	print(string.format("[DataService] Reset DEV data for player %d. Next join will use new-player defaults.", userId))
end

return Store
