local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)

local GameplayObjects = {}

local function uniqueChild(parent: Instance, name: string): Instance?
	local found = nil
	for _, child in parent:GetChildren() do
		if child.Name == name then
			if found then return nil end
			found = child
		end
	end
	return found
end

function GameplayObjects.AtPath(path): Instance?
	local current: Instance? = Workspace
	for _, name in path do current = current and uniqueChild(current, name) end
	return current
end

function GameplayObjects.Find(name: string, courtId: string?): Instance?
	local court = Courts.Get(courtId or Courts.StartingId)
	if not court then return nil end
	local gameplay = GameplayObjects.AtPath(court.GameplayPath)
	if gameplay then
		if not gameplay:IsA("Folder") then return nil end
		if gameplay:FindFirstChild(name) then return uniqueChild(gameplay, name) end
	end
	if court.LegacyRootFallback and not (Workspace:FindFirstChild("Gameplay") and not gameplay) then
		return uniqueChild(Workspace, name)
	end
	return nil
end

function GameplayObjects.FindRim(courtId: string?): BasePart?
	local hoop = GameplayObjects.Find("DunkHoop", courtId)
	local rim = hoop and uniqueChild(hoop, "Rim")
	if not hoop or not hoop:IsA("Model") or not rim or not rim:IsA("BasePart") or not rim.Anchored then
		return nil
	end
	return rim
end

function GameplayObjects.FindSpawn(courtId: string): SpawnLocation?
	local court = Courts.Get(courtId)
	local spawn = court and GameplayObjects.AtPath(court.SpawnPath)
	if not spawn or not spawn:IsA("SpawnLocation") or not spawn.Anchored or not spawn.Enabled or not spawn.Neutral then return nil end
	return spawn
end

function GameplayObjects.FindPortal(sourceId: string, targetId: string): Instance?
	local court = Courts.Get(sourceId)
	local name = court and court.Portals[targetId]
	return name and GameplayObjects.Find(name, sourceId) or nil
end

function GameplayObjects.BindStations(name: string, callback)
	for _, courtId in Courts.OrderedIds() do
		local station = GameplayObjects.Find(name, courtId)
		local prompt = station and station:FindFirstChildOfClass("ProximityPrompt")
		if station and station:IsA("BasePart") and station.Anchored and prompt then
			callback(station, prompt, courtId)
		else
			warn(string.format("[GameplayObjects] %s: missing anchored %s with ProximityPrompt under Workspace.%s. Build/setup in edit mode, then restart Play.",
				courtId, name, table.concat(Courts.Get(courtId).GameplayPath, ".")))
		end
	end
end

return GameplayObjects
