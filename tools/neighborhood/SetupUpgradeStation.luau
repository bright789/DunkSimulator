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
		print("[Upgrade setup] Existing UpgradeStation preserved at " .. tostring(existing.Position)
			.. ". Run PlaceExistingNearTrainer() explicitly in edit mode to repair misplaced station/dressing.")
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

function SetupUpgradeStation.PlaceExistingNearTrainer()
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Stop Play before repositioning UpgradeStation.")
	local gameplay = Workspace:FindFirstChild("Gameplay")
	assert(gameplay and gameplay:IsA("Folder"), "Expected Workspace.Gameplay Folder; nothing changed.")
	local station = gameplay:FindFirstChild("UpgradeStation")
	local trainer = gameplay:FindFirstChild("VerticalTrainer")
	assert(station and station:IsA("BasePart") and station.Anchored
		and station:FindFirstChildOfClass("ProximityPrompt"), "Expected existing anchored UpgradeStation with a direct ProximityPrompt; nothing changed.")
	assert(trainer and trainer:IsA("BasePart") and trainer.Anchored, "Expected anchored VerticalTrainer; nothing changed.")
	local config = require(script.Parent.Config)
	assert(station:GetAttribute("BuilderOwner") == nil, "UpgradeStation must be Studio-owned, not builder-owned; nothing changed.")
	local map = Workspace:FindFirstChild("Map")
	local neighborhood = map and map:FindFirstChild("Neighborhood")
	local props = neighborhood and neighborhood:FindFirstChild("Props")
	local generated = props and props:FindFirstChild(config.GeneratedName)
	local dressing = generated and generated:FindFirstChild("UpgradeArea")
	if dressing then
		assert(generated:GetAttribute("BuilderOwner") == config.Owner and dressing:IsA("Folder"),
			"Refusing to move unowned upgrade dressing; nothing changed.")
	end
	local target = trainer.CFrame * CFrame.new(0, (station.Size.Y - trainer.Size.Y) / 2, -24)
	local offset = target * station.CFrame:Inverse()
	local parts = {}
	if dressing then
		for _, descendant in dressing:GetDescendants() do
			if descendant:IsA("BasePart") then
				assert(descendant.Anchored, "Upgrade dressing must be anchored; nothing changed.")
				table.insert(parts, descendant)
			end
		end
	end
	for _, part in parts do
		part.CFrame = offset * part.CFrame
	end
	station.CFrame = target
	print("[Upgrade setup] Moved the existing station and its owned dressing to " .. tostring(target.Position)
		.. ". No map rebuild or instance replacement. Save the place before Play.")
	return station
end

return SetupUpgradeStation
