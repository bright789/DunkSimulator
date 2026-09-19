local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SetupUpgradeStation = {}

function SetupUpgradeStation.Run()
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Stop Play before creating UpgradeStation.")
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local configFolder = shared and shared:FindFirstChild("Config")
	local configModule = configFolder and configFolder:FindFirstChild("UpgradeConfig")
	assert(configModule and configModule:IsA("ModuleScript"), "Sync the gameplay Rojo project with UpgradeConfig before setup.")
	local config = require(configModule)
	local gameplay = Workspace:FindFirstChild("Gameplay")
	assert(gameplay and gameplay:IsA("Folder"), "Expected Workspace.Gameplay Folder; nothing changed.")
	local existing = gameplay:FindFirstChild(config.StationName)
	if existing then
		assert(existing:IsA("BasePart") and existing.Anchored and existing:FindFirstChildOfClass("ProximityPrompt"),
			"Existing UpgradeStation needs Anchored=true and a direct ProximityPrompt; its properties were preserved.")
		print("[Upgrade setup] Existing UpgradeStation preserved.")
		return existing
	end
	local trainer = gameplay:FindFirstChild("VerticalTrainer")
	assert(trainer and trainer:IsA("BasePart"), "Expected existing VerticalTrainer; nothing changed.")
	local station = Instance.new("Part")
	station.Name = config.StationName
	station.Size = Vector3.new(4, 2, 3)
	station.CFrame = trainer.CFrame * CFrame.new(0, (station.Size.Y - trainer.Size.Y) / 2, -24)
	station.Anchored = true
	station.CanCollide = false
	station.CanTouch = false
	station.CanQuery = true
	station.Color = Color3.fromRGB(70, 119, 132)
	station.Material = Enum.Material.SmoothPlastic
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Upgrades"
	prompt.ObjectText = "Training Upgrades"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = config.MaxDistance
	prompt.RequiresLineOfSight = true
	prompt.Parent = station
	station.Parent = gameplay
	print("[Upgrade setup] Created Studio-owned Workspace.Gameplay.UpgradeStation, 24 studs behind the trainer. Save the place and restart Play.")
	return station
end

return SetupUpgradeStation
