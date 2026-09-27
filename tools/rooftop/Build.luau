-- Skyline Rooftop builder (Studio EDIT MODE only). Creates the Rooftop gameplay objects once
-- (hoop Rim, spawn, trainer, ball pickup, upgrade station, elevator back to the College)
-- plus the College's bus stop to the Rooftop, then (re)builds the owned scenery: the roof,
-- court, skyline, station props, crowd, hoop visuals and the Rooftop stop at the College.
-- Existing gameplay objects are never moved; only builder-owned roots are replaced.
-- Requires the College Arena to be built first.
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

local function facing(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction)
end

function Build.Run()
	assert(RunService:IsStudio() and not RunService:IsRunning(), "RooftopBuilder is Studio EDIT MODE only; stop Play first.")
	local shared = assert(ReplicatedStorage:FindFirstChild("Shared"), "Sync the main Rojo project first.")
	local courts = require(shared.Config.CourtConfig)
	local rooftop = assert(courts.Get("Rooftop"), "Sync the main Rojo project (CourtConfig needs the Rooftop court).")
	local college = assert(courts.Get("College"), "CourtConfig needs the College court.")
	local progression = require(shared.Config.ProgressionConfig)
	-- The invisible edge walls must be taller than the highest jump anyone can train to here.
	local capJump = progression.GetJumpHeight(rooftop.TrainingVerticalCap)
	assert(capJump + Config.JumpHeadroom <= Config.BarrierHeight, string.format(
		"BarrierHeight %d is too low for the Rooftop cap jump (%.0f studs + %d headroom); raise it in Config.",
		Config.BarrierHeight, capJump, Config.JumpHeadroom))
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
	local courtsFolder = assert(existing(gameplay, "Courts", "Folder"), "Build the High School and College first.")
	local collegeGameplay = assert(existing(courtsFolder, "College", "Folder"), "Build the College first.")
	local collegeHoop = assert(existing(collegeGameplay, "DunkHoop", "Model"), "Missing College hoop.")
	local collegeRim = assert(existing(collegeHoop, "Rim", "BasePart"), "Missing College rim.")
	local collegeMap = assert(existing(map, "College", "Folder"), "Build the College first (Map.College missing).")
	local floorY = surface.Position.Y + surface.Size.Y / 2
	local rimHeight = neighborhoodRim.Position.Y - floorY
	assert(rimHeight > 6 and rimHeight < 30, "Unexpected Neighborhood floor-to-rim height; nothing changed.")
	local frame = CFrame.new(Vector3.new(surface.Position.X, floorY, surface.Position.Z) + Config.Offset)
	local collegeFrame = CFrame.new(collegeRim.Position - Vector3.new(0, rimHeight, Config.CollegeRimDepth))

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
		local rooftopMap = folder(map, "Rooftop")
		local rooftopGameplay = folder(courtsFolder, "Rooftop")
		local hoop = once(rooftopGameplay, "DunkHoop", "Model", function() return Instance.new("Model") end)
		local rim = once(hoop, "Rim", "BasePart", function()
			local part = Geometry.Part(nil, "Rim", neighborhoodRim.Size, frame * CFrame.new(0, rimHeight, Config.RimDepth), Config.Colors.Orange)
			part.Transparency = 1
			return part
		end)
		frame = CFrame.new(rim.Position - Vector3.new(0, rimHeight, Config.RimDepth))
		local spawn = once(rooftopGameplay, "Spawn", "SpawnLocation", function()
			local result = Instance.new("SpawnLocation")
			result.Size = Vector3.new(6, 0.2, 6)
			result.CFrame = frame * CFrame.new(0, 0.1, Config.SpawnZ)
			result.Anchored = true
			result.Neutral = true
			result.Enabled = true
			result.Duration = 0
			result.CanCollide = false
			result.CanTouch = false
			result.Transparency = 1
			return result
		end)
		assert(spawn.Enabled and spawn.Neutral, "Rooftop Spawn must be enabled and neutral; existing properties preserved.")
		local stations = Config.Stations
		local trainer = station(rooftopGameplay, "VerticalTrainer", frame * CFrame.new(stations.Trainer), Config.Colors.Magenta)
		local pickup = station(rooftopGameplay, "BasketballPickup", frame * CFrame.new(stations.Pickup), Config.Colors.Orange)
		local upgrade = station(rooftopGameplay, "UpgradeStation", frame * CFrame.new(stations.Upgrade), Config.Colors.Magenta)
		-- The elevator faces the court (-Z); the College bus stop faces its road (+Z).
		local elevator = station(rooftopGameplay, rooftop.Portals.College,
			facing((frame * CFrame.new(stations.Elevator)).Position, -Vector3.zAxis), Config.Colors.Dark)
		local outgoing = station(collegeGameplay, college.Portals.Rooftop,
			facing((collegeFrame * CFrame.new(Config.CollegeStop)).Position, Vector3.zAxis), Config.Colors.Dark)

		local environment = output(folder(rooftopMap, "Environment"), Config.GeneratedName)
		Scenery.Roof(environment, { Frame = frame, Marks = marks })
		local props = Geometry.Folder(environment, "Stations")
		Scenery.Stations(props, trainer, pickup, upgrade)
		Scenery.Elevator(Geometry.Folder(props, "Elevator"), elevator, "TO THE COLLEGE")
		Scenery.Hoop(output(hoop, Config.GeneratedName), rim, rimHeight)
		local requirement = rooftop.Requirements
		Scenery.TransitStop(output(folder(collegeMap, "Environment"), Config.GateName), outgoing,
			string.format("SKYLINE ROOFTOP\n%d VERTICAL  /  $%s", requirement.Vertical, tostring(requirement.Cash)))

		for _, root in stage:GetChildren() do
			root:SetAttribute("BuilderOwner", Config.Owner)
			for _, child in root:GetDescendants() do
				assert(not child:IsA("LuaSourceContainer"), "No scripts allowed in generated environment")
				child:SetAttribute("BuilderOwner", Config.Owner)
				if child:IsA("BasePart") then count += 1; assert(child.Anchored, "Scenery must be anchored") end
			end
		end
		assert(count <= Config.MaxParts, string.format("Rooftop Part budget exceeded (%d > %d)", count, Config.MaxParts))
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
		error("Rooftop build rolled back: " .. tostring(problem), 0)
	end
	for _, entry in installations do if entry.Previous then entry.Previous:Destroy() end end
	stage:Destroy()
	print(string.format("[RooftopBuilder] Built %d decorative Parts; missing Rooftop gameplay objects and the College Rooftop stop created once. Rim height %.3f studs. Save the place and restart Play.", count, rimHeight))
	return count
end

return Build
