local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.CourtConfig)
local PlayerService = require(script.Parent.PlayerService)
local GameplayObjects = require(script.Parent.GameplayObjects)
local BasketballService = require(script.Parent.BasketballService)
local TrainingService = require(script.Parent.TrainingService)
local UpgradeService = require(script.Parent.UpgradeService)

local CourtTravel = {}
local placements = {}
local riders = {}

function CourtTravel.Character(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not character:IsDescendantOf(Workspace) or not humanoid or humanoid.Health <= 0
		or not root or not root:IsA("BasePart") or root.Anchored then return nil end
	return character, humanoid, root
end

function CourtTravel.Destination(player: Player, courtId: string)
	local spawn = GameplayObjects.FindSpawn(courtId)
	local character, humanoid, root = CourtTravel.Character(player)
	if not spawn or not character then return nil, nil, "Court spawn or character is unavailable." end
	local rootHeight = math.max(3, humanoid.HipHeight + root.Size.Y / 2)
	local destination = spawn.CFrame * CFrame.new(0, spawn.Size.Y / 2 + rootHeight + Config.ArrivalClearance, 0)
	local excluded = { spawn }
	for _, other in Players:GetPlayers() do
		if other.Character then table.insert(excluded, other.Character) end
	end
	local parameters = OverlapParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = excluded
	parameters.RespectCanCollide = true
	local size = Vector3.new(Config.ArrivalWidth, rootHeight * 2, Config.ArrivalWidth)
	if #Workspace:GetPartBoundsInBox(destination, size, parameters) > 0 then
		return nil, nil, "Court arrival area is obstructed. Try again later."
	end
	return destination, spawn, nil
end

local function place(player: Player, courtId: string, destination: CFrame, spawn: SpawnLocation)
	local character, _, root = CourtTravel.Character(player)
	assert(character and root and PlayerService.IsDataReady(player), "Character or data unavailable")
	assert(PlayerService.HasCourt(player, courtId) and GameplayObjects.FindSpawn(courtId) == spawn, "Court unavailable")
	TrainingService.Cancel(player)
	UpgradeService.Close(player)
	BasketballService.ClearPossession(player)
	character:PivotTo(destination * root.CFrame:Inverse() * character:GetPivot())
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	player.RespawnLocation = spawn
	assert(PlayerService.SetCurrentCourt(player, courtId), "Court selection unavailable")
end

function CourtTravel.Move(player: Player, courtId: string): (boolean, string)
	if not Config.Get(courtId) or not PlayerService.IsReady(player) or not PlayerService.HasCourt(player, courtId)
		or PlayerService.GetDunkState(player) ~= "Idle" then
		return false, "Court locked, data loading, or dunk still in progress."
	end
	local destination, spawn, problem = CourtTravel.Destination(player, courtId)
	if not destination or not spawn then return false, problem end
	PlayerService.SetCourtTransition(player, true)
	local succeeded, failure = pcall(place, player, courtId, destination, spawn)
	PlayerService.SetCourtTransition(player, false)
	if not succeeded then
		warn("[CourtService] Travel cancelled: " .. tostring(failure))
		return false, "Travel unavailable. Please try again."
	end
	return true, "Arrived at " .. Config.Get(courtId).DisplayName .. "."
end

-- Board the bus: the rider is anchored at the stop and flagged (TransitRide) so clients
-- can play the departure. FinishRide then performs the normal validated Move.
function CourtTravel.BeginRide(player: Player, courtId: string): (boolean, string)
	if riders[player] then return false, "You are already on the bus." end
	if not Config.Get(courtId) or not PlayerService.IsReady(player) or not PlayerService.HasCourt(player, courtId)
		or PlayerService.GetDunkState(player) ~= "Idle" then
		return false, "Court locked, data loading, or dunk still in progress."
	end
	local character, _, root = CourtTravel.Character(player)
	if not character or not root then return false, "Character unavailable." end
	riders[player] = character
	TrainingService.Cancel(player)
	UpgradeService.Close(player)
	PlayerService.SetCourtTransition(player, true)
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	player:SetAttribute("TransitRide", courtId)
	return true, "All aboard! Riding to " .. Config.Get(courtId).DisplayName .. "."
end

function CourtTravel.FinishRide(player: Player, courtId: string): (boolean, string)
	local character = riders[player]
	riders[player] = nil
	if not character then return false, "Ride cancelled." end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then root.Anchored = false end
	PlayerService.SetCourtTransition(player, false)
	local arrived, message = false, "Ride cancelled."
	if player.Parent == Players and player.Character == character then
		arrived, message = CourtTravel.Move(player, courtId)
	end
	if player.Parent == Players then player:SetAttribute("TransitRide", nil) end
	return arrived, message
end

function CourtTravel.PlacePlayer(player: Player, character: Model?)
	if not PlayerService.IsDataReady(player) then return end
	local selected = PlayerService.GetCurrentCourt(player)
	player.RespawnLocation = GameplayObjects.FindSpawn(selected) or GameplayObjects.FindSpawn(Config.StartingId)
	if not character or player.Character ~= character or placements[player] == character then return end
	placements[player] = character
	PlayerService.SetCourtTransition(player, true)
	local success, problem = pcall(function()
		local deadline = os.clock() + Config.SpawnWaitSeconds
		while true do
			if placements[player] ~= character or player.Character ~= character or not PlayerService.IsDataReady(player) then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health <= 0 then return end
			if CourtTravel.Character(player) then break end
			assert(os.clock() < deadline, "Character did not become ready for court placement")
			task.wait()
		end
		local destination, spawn, message = CourtTravel.Destination(player, selected)
		if not destination and selected ~= Config.StartingId then
			warn("[CourtService] Saved court unavailable; using Neighborhood without removing its unlock.")
			selected = Config.StartingId
			destination, spawn, message = CourtTravel.Destination(player, selected)
		end
		assert(destination and spawn, message)
		place(player, selected, destination, spawn)
		PlayerService.SetCourtTransition(player, false)
	end)
	if placements[player] == character then
		placements[player] = nil
		if not success and player.Parent == Players and player.Character == character then
			warn("[CourtService] Spawn failed: " .. tostring(problem))
			player:Kick("Your court spawn is unavailable. Please rejoin in a moment.")
		end
	end
end

function CourtTravel.Init()
	local function setStartingSpawn(player)
		player.RespawnLocation = GameplayObjects.FindSpawn(Config.StartingId)
	end
	Players.PlayerAdded:Connect(setStartingSpawn)
	Players.PlayerRemoving:Connect(function(player)
		placements[player] = nil
		riders[player] = nil
	end)
	for _, player in Players:GetPlayers() do setStartingSpawn(player) end
end

return CourtTravel
