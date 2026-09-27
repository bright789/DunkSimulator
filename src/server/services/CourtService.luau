local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config.CourtConfig)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local GameplayObjects = require(script.Parent.GameplayObjects)
local CourtTravel = require(script.Parent.CourtTravel)
local remotes = ReplicatedStorage.Remotes

local CourtService = {}
local nextRequest = {}
local nextRead = {}
local processing = {}
local initialized = false

local function publish(player, message, unlockedId, fromPortal)
	if player.Parent == Players then
		remotes.CourtState:FireClient(player, PlayerService.GetCourtSnapshot(player), message, unlockedId, fromPortal == true)
	end
end

local function admit(player): boolean
	if player.Parent ~= Players or processing[player] or os.clock() < (nextRequest[player] or 0) then return false end
	nextRequest[player] = os.clock() + Config.RequestCooldownSeconds
	return true
end

local function validPortal(player, sourceId, targetId, station, prompt): boolean
	local _, _, root = CourtTravel.Character(player)
	if not PlayerService.IsReady(player) or PlayerService.GetDunkState(player) ~= "Idle" or not root
		or PlayerService.GetCurrentCourt(player) ~= sourceId or GameplayObjects.FindPortal(sourceId, targetId) ~= station
		or not station.Anchored or prompt.Parent ~= station or not prompt.Enabled then return false end
	if not ((root.Position - station.Position).Magnitude <= math.min(Config.PortalDistance, prompt.MaxActivationDistance)) then return false end
	if prompt.RequiresLineOfSight then
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = { player.Character, station }
		if Workspace:Raycast(root.Position, station.Position - root.Position, parameters) then return false end
	end
	return true
end

local function usePortal(player, sourceId, targetId, station, prompt)
	if not admit(player) then return end
	if not validPortal(player, sourceId, targetId, station, prompt) then
		publish(player, "Approach the portal after your dunk finishes.", nil, true)
		return
	end
	processing[player] = true
	local boarded = false
	local succeeded, message, unlocked = pcall(function()
		if PlayerService.HasCourt(player, targetId) then
			local result
			boarded, result = CourtTravel.BeginRide(player, targetId)
			if boarded then
				task.delay(Config.RideSeconds, function()
					local _, arrival = CourtTravel.FinishRide(player, targetId)
					publish(player, arrival, nil, true)
				end)
			end
			return result, nil
		end
		local destination, _, problem = CourtTravel.Destination(player, targetId)
		if not destination then return problem, nil end
		local purchased, result, newUnlock = PlayerService.BuyCourt(player, targetId)
		if purchased and newUnlock then return result .. " Press E again to travel.", targetId end
		return result, nil
	end)
	processing[player] = nil
	if not succeeded then
		warn("[CourtService] Portal failed: " .. tostring(message))
		publish(player, "Court unavailable. Please try again.", nil, true)
		return
	end
	-- Boarding only shows a toast; the courts panel opens for portal problems.
	publish(player, message, unlocked, not boarded)
	if unlocked then DataService.RequestSave(player) end
end

function CourtService.Init()
	if initialized then return end
	initialized = true
	CourtTravel.Init()
	for _, sourceId in Config.OrderedIds() do
		for targetId in Config.Get(sourceId).Portals do
			local station = GameplayObjects.FindPortal(sourceId, targetId)
			local prompt = station and station:FindFirstChildOfClass("ProximityPrompt")
			if station and station:IsA("BasePart") and station.Anchored and prompt and Config.Get(targetId) then
				prompt.ObjectText = "Bus to " .. Config.Get(targetId).DisplayName
				prompt.ActionText = "Ride / Unlock"
				prompt.MaxActivationDistance = Config.PortalDistance
				prompt.HoldDuration = 0
				prompt.Triggered:Connect(function(player) usePortal(player, sourceId, targetId, station, prompt) end)
			else
				warn("[CourtService] Missing portal " .. sourceId .. " -> " .. targetId .. ". Run HighSchoolBuilder in edit mode, then restart Play.")
			end
		end
	end
	remotes.CourtRequest.OnServerEvent:Connect(function(player, action, courtId, ...)
		if player.Parent ~= Players then return end
		if action == "Read" and courtId == nil and select("#", ...) == 0 then
			if os.clock() >= (nextRead[player] or 0) then
				nextRead[player] = os.clock() + Config.ReadCooldownSeconds
				publish(player)
			end
			return
		end
		if not admit(player) then return end
		if action ~= "Travel" or type(courtId) ~= "string" or not Config.Get(courtId) or select("#", ...) ~= 0 then
			publish(player, "Invalid court request.")
			return
		end
		processing[player] = true
		local success, _, message = pcall(CourtTravel.Move, player, courtId)
		processing[player] = nil
		publish(player, success and message or "Travel unavailable.")
	end)
	Players.PlayerRemoving:Connect(function(player)
		nextRequest[player] = nil
		nextRead[player] = nil
		processing[player] = nil
	end)
end

return CourtService
