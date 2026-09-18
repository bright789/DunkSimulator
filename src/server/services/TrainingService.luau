local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local PlayerService = require(script.Parent.PlayerService)

local TrainingService = {}
type TrainingSession = {
	Character: Model,
	NextTickAt: number,
}

local sessions: { [Player]: TrainingSession } = {}
local initialized = false

local function getValidCharacter(player: Player, station: BasePart, prompt: ProximityPrompt): Model?
	if not PlayerService.IsReady(player) then
		return nil
	end
	if station.Parent ~= Workspace or station.Name ~= Config.Training.StationName or not station.Anchored
		or prompt.Parent ~= station or not prompt.Enabled then
		return nil
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not character:IsDescendantOf(Workspace) or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	if not rootPart or not rootPart:IsA("BasePart") then
		return nil
	end

	local distance = (rootPart.Position - station.Position).Magnitude
	local maxDistance = math.min(Config.Training.MaxDistance, prompt.MaxActivationDistance)
	if not (distance <= maxDistance) then
		return nil
	end

	if prompt.RequiresLineOfSight then
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { character, station }
		local obstruction = Workspace:Raycast(rootPart.Position, station.Position - rootPart.Position, raycastParams)
		if obstruction then
			return nil
		end
	end

	return character
end

local function stopTraining(player: Player)
	sessions[player] = nil
end

local function startTraining(player: Player, station: BasePart, prompt: ProximityPrompt)
	if sessions[player] then
		return
	end
	local character = getValidCharacter(player, station, prompt)
	if character then
		sessions[player] = {
			Character = character,
			NextTickAt = os.clock() + Config.Training.TickIntervalSeconds,
		}
	end
end

local function updateSessions(station: BasePart, prompt: ProximityPrompt)
	local now = os.clock()
	for player, session in sessions do
		local character = getValidCharacter(player, station, prompt)
		if character ~= session.Character then
			stopTraining(player)
		elseif now >= session.NextTickAt then
			if PlayerService.AwardTraining(player) then
				session.NextTickAt = now + Config.Training.TickIntervalSeconds
			else
				stopTraining(player)
			end
		end
	end
end

function TrainingService.Init()
	if initialized then
		return
	end
	initialized = true
	assert(Config.Training.TickIntervalSeconds > 0 and Config.Training.TickIntervalSeconds < math.huge,
		"Training.TickIntervalSeconds must be a finite positive number")

	local station = Workspace:FindFirstChild(Config.Training.StationName)
	if not station or not station:IsA("BasePart") or not station.Anchored then
		warn("[DunkSimulator] Training unavailable: create an anchored Part named VerticalTrainer directly under Workspace, with a ProximityPrompt directly inside it. Restart Play after setup.")
		return
	end

	local prompt = station:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		warn("[DunkSimulator] Training unavailable: add a ProximityPrompt directly inside Workspace.VerticalTrainer. Restart Play after setup.")
		return
	end

	prompt.ActionText = "Hold to Train Vertical"
	prompt.ObjectText = "Vertical Trainer"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Training.MaxDistance

	Players.PlayerRemoving:Connect(stopTraining)
	prompt.TriggerEnded:Connect(stopTraining)
	prompt.Triggered:Connect(function(player)
		startTraining(player, station, prompt)
	end)
	RunService.Heartbeat:Connect(function()
		updateSessions(station, prompt)
	end)

	print("[DunkSimulator] Training ready at Workspace.VerticalTrainer.")
end

return TrainingService
