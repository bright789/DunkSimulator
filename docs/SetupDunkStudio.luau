local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Selection = game:GetService("Selection")

assert(RunService:IsStudio() and not RunService:IsRunning(), "Stop Play before running this setup in Studio's Command Bar.")
assert(not Workspace:FindFirstChild("Gameplay"), "This legacy test-area helper is not for the Neighborhood. Use docs/NEIGHBORHOOD_COURT.md; no objects have been changed.")

local pickup = Workspace:FindFirstChild("BasketballPickup")
local hoop = Workspace:FindFirstChild("DunkHoop")
local rim = hoop and hoop:FindFirstChild("Rim")
assert(not pickup or pickup:IsA("BasePart"), "Existing BasketballPickup must be a Part; nothing has been changed.")
assert(not hoop or hoop:IsA("Model"), "Existing DunkHoop must be a Model; nothing has been changed.")
assert(not rim or rim:IsA("BasePart"), "Existing Rim must be a Part; nothing has been changed.")

local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local origin = Vector3.zero
if spawn then
	origin = spawn.Position + Vector3.new(0, spawn.Size.Y / 2, 0)
else
	warn("[Dunk setup] No SpawnLocation found; using floor height Y = 0 near the origin. Adjust positions to your court.")
end

if not pickup then
	pickup = Instance.new("Part")
	pickup.Name = "BasketballPickup"
	pickup.Size = Vector3.new(3, 2, 3)
	pickup.Position = origin + Vector3.new(6, 1, 0)
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.Color = Color3.fromRGB(230, 115, 25)
	pickup.Material = Enum.Material.SmoothPlastic
	pickup.Parent = Workspace
end

if not pickup:FindFirstChildOfClass("ProximityPrompt") then
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ProximityPrompt"
	prompt.ActionText = "Pick Up Basketball"
	prompt.ObjectText = "Basketball"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Enabled = true
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = true
	prompt.Parent = pickup
end

if not hoop then
	hoop = Instance.new("Model")
	hoop.Name = "DunkHoop"
	hoop.Parent = Workspace
end

if not rim then
	rim = Instance.new("Part")
	rim.Name = "Rim"
	rim.Size = Vector3.new(4, 0.4, 4)
	rim.Position = origin + Vector3.new(0, 12, -15)
	rim.Anchored = true
	rim.CanCollide = false
	rim.Color = Color3.fromRGB(255, 100, 0)
	rim.Material = Enum.Material.Neon
	rim.Parent = hoop
end

if not pickup.Anchored or not rim.Anchored then
	warn("[Dunk setup] Existing pickup/rim settings were preserved. Set Anchored = true on both before testing.")
end
Selection:Set({ pickup, rim })
print("[Dunk setup] Pickup and rim are ready for inspection. Existing objects were preserved. Check clear floor space, save the place, sync Rojo, then press Play.")
