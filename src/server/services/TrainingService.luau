local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local PlayerService = require(script.Parent.PlayerService)
local GameplayObjects = require(script.Parent.GameplayObjects)
local ChallengeService = require(script.Parent.ChallengeService)
local DailyService = require(script.Parent.DailyService)

local TrainingService = {}
type TrainingSession = {
	Character: Model,
	Station: BasePart,
	Prompt: ProximityPrompt,
	NextTickAt: number,
}

local sessions: { [Player]: TrainingSession } = {}
local nextCapNotice: { [Player]: number } = {}
local initialized = false

local function notifyCap(player: Player)
	local cap = PlayerService.GetTrainingCap(player)
	local vertical = PlayerService.GetVertical(player)
	if not cap or not vertical or vertical < cap or os.clock() < (nextCapNotice[player] or 0) then return end
	nextCapNotice[player] = os.clock() + Config.Training.CapFeedbackCooldownSeconds
	ReplicatedStorage.Remotes.TrainingCapNotice:FireClient(player, PlayerService.GetCurrentCourt(player), cap)
end

local function getValidCharacter(player: Player, station: BasePart, prompt: ProximityPrompt): Model?
	if not PlayerService.IsReady(player) or PlayerService.GetDunkState(player) == "Executing" then
		return nil
	end
	if GameplayObjects.Find(Config.Training.StationName, PlayerService.GetCurrentCourt(player)) ~= station or not station.Anchored
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
	-- Presentation-only mirror so clients can animate the workout.
	if player.Parent == Players then player:SetAttribute("Training", nil) end
end

local function startTraining(player: Player, station: BasePart, prompt: ProximityPrompt)
	if sessions[player] then
		return
	end
	local character = getValidCharacter(player, station, prompt)
	if character then
		local cap = PlayerService.GetTrainingCap(player)
		if cap and PlayerService.GetVertical(player) >= cap then
			notifyCap(player)
			return
		end
		sessions[player] = {
			Character = character,
			Station = station,
			Prompt = prompt,
			NextTickAt = os.clock() + Config.Training.TickIntervalSeconds,
		}
		player:SetAttribute("Training", true)
	end
end

local function updateSessions()
	local now = os.clock()
	for player, session in sessions do
		local character = getValidCharacter(player, session.Station, session.Prompt)
		if character ~= session.Character then
			stopTraining(player)
		elseif now >= session.NextTickAt then
			if PlayerService.AwardTraining(player) then
				local tracked, problem = pcall(ChallengeService.OnVerticalChanged, player)
				if not tracked then warn("[TrainingService] Challenge tracking failed: " .. tostring(problem)) end
				local dailyTracked, dailyProblem = pcall(DailyService.OnTrainingRep, player)
				if not dailyTracked then warn("[TrainingService] Daily tracking failed: " .. tostring(dailyProblem)) end
				local cap = PlayerService.GetTrainingCap(player)
				if cap and PlayerService.GetVertical(player) >= cap then
					notifyCap(player)
					stopTraining(player)
				else
					session.NextTickAt = now + Config.Training.TickIntervalSeconds
				end
			else
				notifyCap(player)
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

	Players.PlayerRemoving:Connect(function(player)
		stopTraining(player)
		nextCapNotice[player] = nil
	end)
	GameplayObjects.BindStations(Config.Training.StationName, function(station, prompt)
		prompt.ActionText = "Hold to Train Vertical"
		prompt.ObjectText = "Leg Day Gym"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Config.Training.MaxDistance
		prompt.TriggerEnded:Connect(function(player)
			if sessions[player] and sessions[player].Station == station then stopTraining(player) end
		end)
		prompt.Triggered:Connect(function(player) startTraining(player, station, prompt) end)
		print("[DunkSimulator] Training ready at " .. station:GetFullName() .. ".")
	end)
	RunService.Heartbeat:Connect(updateSessions)
end

TrainingService.Cancel = stopTraining

return TrainingService
