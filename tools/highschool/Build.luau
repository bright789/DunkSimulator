local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.Config)
local Geometry = require(script.Parent.Geometry)
local Scenery = require(script.Parent.Scenery)

local Build = {}

local function existing(parent, name, className)
	local found = nil
	for _, child in parent:GetChildren() do
		if child.Name == name then
			assert(not found, "Duplicate " .. parent:GetFullName() .. "." .. name)
			found = child
		end
	end
	assert(not found or found:IsA(className), "Wrong type at " .. parent:GetFullName() .. "." .. name)
	return found
end

function Build.Run()
	assert(RunService:IsStudio() and not RunService:IsRunning(), "HighSchoolBuilder is Studio EDIT MODE only; stop Play first.")
	local shared = assert(ReplicatedStorage:FindFirstChild("Shared"), "Sync the main Rojo project first.")
	local courts = require(shared.Config.CourtConfig)
	local progression = require(shared.Config.ProgressionConfig)
	-- The roof must clear the highest jump anyone can train to here, plus head/camera room.
	local capJump = progression.GetJumpHeight(courts.Get("HighSchool").TrainingVerticalCap)
	assert(capJump + Config.JumpHeadroom <= Config.CeilingHeight, string.format(
		"CeilingHeight %d is too low for the High School cap jump (%.0f studs + %d headroom); raise it in Config.",
		Config.CeilingHeight, capJump, Config.JumpHeadroom))
	local marks = {}
	for _, vertical in Config.VerticalMarks do
		table.insert(marks, { Vertical = vertical, Height = progression.GetJumpHeight(vertical) })
	end
	local map = assert(existing(Workspace, "Map", "Folder"), "Expected existing Workspace.Map.")
	local neighborhood = assert(existing(map, "Neighborhood", "Folder"), "Expected existing Neighborhood.")
	local courtFolder = assert(existing(neighborhood, "Court", "Folder"), "Expected existing Neighborhood.Court.")
	local surface = assert(existing(courtFolder, "CourtSurface", "BasePart"), "Expected existing CourtSurface.")
	local gameplay = assert(existing(Workspace, "Gameplay", "Folder"), "Expected existing Workspace.Gameplay.")
	local neighborhoodHoop = assert(existing(gameplay, "DunkHoop", "Model"), "Expected Neighborhood DunkHoop.")
	local neighborhoodRim = assert(existing(neighborhoodHoop, "Rim", "BasePart"), "Expected Neighborhood Rim.")
	local neighborhoodSpawn = assert(existing(Workspace, "SpawnLocation", "SpawnLocation"), "Expected Neighborhood SpawnLocation.")
	assert(surface.Anchored and neighborhoodRim.Anchored and neighborhoodSpawn.Anchored, "Existing floor/rim/spawn must be anchored.")
	assert(neighborhoodSpawn.Enabled and neighborhoodSpawn.Neutral, "Neighborhood SpawnLocation must be enabled and neutral; nothing changed.")
	local floorY = surface.Position.Y + surface.Size.Y / 2
	local rimHeight = neighborhoodRim.Position.Y - floorY
	assert(rimHeight > 6 and rimHeight < 30, "Unexpected Neighborhood floor-to-rim height; nothing changed.")
	local frame = CFrame.new(Vector3.new(surface.Position.X, floorY, surface.Position.Z) + Config.Offset)
	local created = {}
	local installations = {}
	local stage = Instance.new("Folder")
	local function folder(parent, name)
		local found = existing(parent, name, "Folder")
		if found then return found end
		local result = Geometry.Folder(parent, name)
		table.insert(created, result)
		return result
	end
	local function once(parent, name, className, create)
		local found = existing(parent, name, className)
		if found then
			if found:IsA("BasePart") then assert(found.Anchored, name .. " must stay anchored") end
			return found
		end
		local result = create()
		result.Name = name
		result.Parent = parent
		table.insert(created, result)
		return result
	end
	local function station(parent, name, target, color)
		local result = once(parent, name, "BasePart", function()
			local part = Geometry.Part(nil, name, Vector3.new(4, 2, 3), target, color, Enum.Material.SmoothPlastic)
			local prompt = Instance.new("ProximityPrompt")
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = true
			prompt.MaxActivationDistance = 10
			prompt.Parent = part
			return part
		end)
		assert(result:FindFirstChildOfClass("ProximityPrompt"), result:GetFullName() .. " needs a ProximityPrompt; existing station preserved.")
		return result
	end
	local function output(parent, name)
		local previous = existing(parent, name, "Folder")
		if previous then
			assert(previous:GetAttribute("BuilderOwner") == Config.Owner, "Refusing to replace unowned " .. previous:GetFullName())
			for _, child in previous:GetDescendants() do
				assert(child:GetAttribute("BuilderOwner") == Config.Owner, "Move manually added content out of " .. previous:GetFullName() .. " before rebuilding.")
			end
		end
		local root = Geometry.Folder(stage, name)
		table.insert(installations, { Root = root, Parent = parent, Previous = previous })
		return root
	end
	local count = 0
	local success, problem = pcall(function()
		local school = folder(map, "HighSchool")
		local schoolGameplay = folder(folder(gameplay, "Courts"), "HighSchool")
		local hoop = once(schoolGameplay, "DunkHoop", "Model", function() return Instance.new("Model") end)
		local rim = once(hoop, "Rim", "BasePart", function()
			local part = Geometry.Part(nil, "Rim", neighborhoodRim.Size, frame * CFrame.new(0, rimHeight, Config.RimDepth), Config.Colors.Orange)
			part.Transparency = 1
			return part
		end)
		frame = CFrame.new(rim.Position - Vector3.new(0, rimHeight, Config.RimDepth))
		local spawn = once(schoolGameplay, "Spawn", "SpawnLocation", function()
			local result = Instance.new("SpawnLocation")
			result.Size = Vector3.new(6, 0.2, 6)
			result.CFrame = frame * CFrame.new(0, 0.1, 57)
			result.Anchored = true
			result.Neutral = true
			result.Enabled = true
			result.Duration = 0
			result.CanCollide = false
			result.CanTouch = false
			result.Transparency = 1
			return result
		end)
		assert(spawn.Enabled and spawn.Neutral, "High School Spawn must be enabled and neutral; existing properties preserved.")
		local trainer = station(schoolGameplay, "VerticalTrainer", frame * CFrame.new(-38, 1, 50), Config.Colors.Blue)
		local pickup = station(schoolGameplay, "BasketballPickup", frame * CFrame.new(-16, 1, 50), Config.Colors.Orange)
		local upgrade = station(schoolGameplay, "UpgradeStation", frame * CFrame.new(40, 1, 35), Config.Colors.Blue)
		local returnPortal = station(schoolGameplay, courts.Get("HighSchool").Portals.Neighborhood, frame * CFrame.new(24, 1, 59), Config.Colors.Dark)
		local outgoing = station(gameplay, courts.Get("Neighborhood").Portals.HighSchool,
			neighborhoodSpawn.CFrame * CFrame.new(26, 1 - neighborhoodSpawn.Size.Y / 2, 0), Config.Colors.Dark)
		local environment = output(folder(school, "Environment"), Config.GeneratedName)
		Scenery.Gym(environment, { Frame = frame, Marks = marks })
		local props = Geometry.Folder(environment, "Stations")
		Scenery.Gymnasium(Geometry.Folder(props, "TrainerGym"), trainer)
		Scenery.Shop(Geometry.Folder(props, "PickupShop"), pickup)
		Scenery.UpgradeLab(props, upgrade, "TRAINING UPGRADES")
		Scenery.TransitStop(Geometry.Folder(props, "ReturnGate"), returnPortal, "TO THE NEIGHBORHOOD",
			Config.Transit.SchoolBusDistance, Config.Transit.SchoolRoadDrop)
		Scenery.Hoop(output(hoop, Config.GeneratedName), rim, rimHeight)
		local requirement = courts.Get("HighSchool").Requirements
		Scenery.TransitStop(output(folder(neighborhood, "Props"), Config.GateName), outgoing,
			string.format("HIGH SCHOOL GYM\n%d VERTICAL  /  $%s", requirement.Vertical, tostring(requirement.Cash)),
			Config.Transit.NeighborhoodBusDistance, Config.Transit.NeighborhoodRoadDrop)
		for _, root in stage:GetChildren() do
			root:SetAttribute("BuilderOwner", Config.Owner)
			for _, child in root:GetDescendants() do
				assert(not child:IsA("LuaSourceContainer"), "No scripts allowed in generated environment")
				child:SetAttribute("BuilderOwner", Config.Owner)
				if child:IsA("BasePart") then count += 1; assert(child.Anchored, "Scenery must be anchored") end
			end
		end
		assert(count <= Config.MaxParts, "High School Part budget exceeded")
		for _, entry in installations do
			if entry.Previous then entry.Previous.Parent = nil end
			entry.Root.Parent = entry.Parent
		end
	end)
	if not success then
		for _, entry in installations do
			entry.Root:Destroy()
			if entry.Previous then entry.Previous.Parent = entry.Parent end
		end
		for index = #created, 1, -1 do created[index]:Destroy() end
		stage:Destroy()
		error("High School build rolled back: " .. tostring(problem), 0)
	end
	for _, entry in installations do if entry.Previous then entry.Previous:Destroy() end end
	stage:Destroy()
	print(string.format("[HighSchoolBuilder] Built %d decorative Parts; new missing gameplay objects created once. Existing objects preserved. Rim height %.3f studs. Save the Studio place and restart Play.", count, rimHeight))
	return count
end

-- Explicit, rerunnable edit-mode step: move both travel stations to their bus stops
-- (Neighborhood sidewalk by the street, High School sidewalk outside the entrance).
-- Run this before Build.Run so the bus stop scenery is built around the new positions.
function Build.PlaceTransitStops()
	assert(RunService:IsStudio() and not RunService:IsRunning(), "HighSchoolBuilder is Studio EDIT MODE only; stop Play first.")
	local courts = require(assert(ReplicatedStorage:FindFirstChild("Shared"), "Sync the main Rojo project first.").Config.CourtConfig)
	local gameplay = assert(existing(Workspace, "Gameplay", "Folder"), "Expected existing Workspace.Gameplay.")
	local spawn = assert(existing(Workspace, "SpawnLocation", "SpawnLocation"), "Expected Neighborhood SpawnLocation.")
	local courtsFolder = assert(existing(gameplay, "Courts", "Folder"), "Expected Gameplay.Courts.")
	local school = assert(existing(courtsFolder, "HighSchool", "Folder"), "Run Build.Run once first to create the High School.")
	local outgoing = assert(existing(gameplay, courts.Get("Neighborhood").Portals.HighSchool, "BasePart"), "Missing Neighborhood travel station.")
	local returning = assert(existing(school, courts.Get("HighSchool").Portals.Neighborhood, "BasePart"), "Missing High School travel station.")
	local schoolSpawn = assert(existing(school, "Spawn", "SpawnLocation"), "Missing High School spawn.")
	local hoop = assert(existing(school, "DunkHoop", "Model"), "Missing High School hoop.")
	local rim = assert(existing(hoop, "Rim", "BasePart"), "Missing High School rim.")
	-- Same gym frame Build.Run uses: under the rim at floor level, shifted back by RimDepth.
	local floorY = schoolSpawn.Position.Y - schoolSpawn.Size.Y / 2
	local frame = CFrame.new(Vector3.new(rim.Position.X, floorY, rim.Position.Z - Config.RimDepth))
	local function face(position)
		return CFrame.lookAt(position, position + Vector3.zAxis)
	end
	outgoing.CFrame = face(spawn.Position + Config.Transit.NeighborhoodStop)
	returning.CFrame = face((frame * CFrame.new(Config.Transit.SchoolStop)).Position)
	print("[HighSchoolBuilder] Travel stations moved to the bus stops: " .. outgoing:GetFullName() .. " "
		.. tostring(outgoing.Position) .. ", " .. returning:GetFullName() .. " " .. tostring(returning.Position)
		.. ". Now run Build.Run() to rebuild the stops and buses, then save.")
end

return Build
