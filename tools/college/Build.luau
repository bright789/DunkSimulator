-- College Arena builder (Studio EDIT MODE only). Creates the College gameplay objects once
-- (hoop Rim, spawn, trainer, ball pickup, upgrade station, bus stop back to the High
-- School) plus the High School's bus stop to College, then (re)builds the owned scenery:
-- the arena, station props, crowd, hoop visuals and the College stop dressing at the High
-- School. Existing gameplay objects are never moved; only builder-owned roots are replaced.
-- Requires the High School to be built first.
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

local function facingRoad(position: Vector3): CFrame
	return CFrame.lookAt(position, position + Vector3.zAxis)
end

function Build.Run()
	assert(RunService:IsStudio() and not RunService:IsRunning(), "CollegeBuilder is Studio EDIT MODE only; stop Play first.")
	local shared = assert(ReplicatedStorage:FindFirstChild("Shared"), "Sync the main Rojo project first.")
	local courts = require(shared.Config.CourtConfig)
	local college = assert(courts.Get("College"), "Sync the main Rojo project (CourtConfig needs the College court).")
	local progression = require(shared.Config.ProgressionConfig)
	-- The roof must clear the highest jump anyone can train to here, plus head/camera room.
	local capJump = progression.GetJumpHeight(college.TrainingVerticalCap)
	assert(capJump + Config.JumpHeadroom <= Config.CeilingHeight, string.format(
		"CeilingHeight %d is too low for the College cap jump (%.0f studs + %d headroom); raise it in Config.",
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
	local courtsFolder = assert(existing(gameplay, "Courts", "Folder"), "Build the High School first (Gameplay.Courts missing).")
	local school = assert(existing(courtsFolder, "HighSchool", "Folder"), "Build the High School first.")
	local schoolHoop = assert(existing(school, "DunkHoop", "Model"), "Missing High School hoop.")
	local schoolRim = assert(existing(schoolHoop, "Rim", "BasePart"), "Missing High School rim.")
	local schoolMap = assert(existing(map, "HighSchool", "Folder"), "Build the High School first (Map.HighSchool missing).")
	local floorY = surface.Position.Y + surface.Size.Y / 2
	local rimHeight = neighborhoodRim.Position.Y - floorY
	assert(rimHeight > 6 and rimHeight < 30, "Unexpected Neighborhood floor-to-rim height; nothing changed.")
	local frame = CFrame.new(Vector3.new(surface.Position.X, floorY, surface.Position.Z) + Config.Offset)
	local schoolFrame = CFrame.new(schoolRim.Position - Vector3.new(0, rimHeight, Config.HighSchoolRimDepth))

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
		local collegeMap = folder(map, "College")
		local collegeGameplay = folder(courtsFolder, "College")
		local hoop = once(collegeGameplay, "DunkHoop", "Model", function() return Instance.new("Model") end)
		local rim = once(hoop, "Rim", "BasePart", function()
			local part = Geometry.Part(nil, "Rim", neighborhoodRim.Size, frame * CFrame.new(0, rimHeight, Config.RimDepth), Config.Colors.Orange)
			part.Transparency = 1
			return part
		end)
		frame = CFrame.new(rim.Position - Vector3.new(0, rimHeight, Config.RimDepth))
		local spawn = once(collegeGameplay, "Spawn", "SpawnLocation", function()
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
		assert(spawn.Enabled and spawn.Neutral, "College Spawn must be enabled and neutral; existing properties preserved.")
		local stations = Config.Stations
		local trainer = station(collegeGameplay, "VerticalTrainer", frame * CFrame.new(stations.Trainer), Config.Colors.Purple)
		local pickup = station(collegeGameplay, "BasketballPickup", frame * CFrame.new(stations.Pickup), Config.Colors.Orange)
		local upgrade = station(collegeGameplay, "UpgradeStation", frame * CFrame.new(stations.Upgrade), Config.Colors.Purple)
		local returnPortal = station(collegeGameplay, college.Portals.HighSchool,
			facingRoad((frame * CFrame.new(Config.Transit.CollegeStop)).Position), Config.Colors.Dark)
		local outgoing = station(school, courts.Get("HighSchool").Portals.College,
			facingRoad((schoolFrame * CFrame.new(Config.Transit.SchoolStop)).Position), Config.Colors.Dark)

		local environment = output(folder(collegeMap, "Environment"), Config.GeneratedName)
		Scenery.Arena(environment, { Frame = frame, Marks = marks })
		local props = Geometry.Folder(environment, "Stations")
		Scenery.Stations(props, trainer, pickup, upgrade)
		Scenery.TransitStop(Geometry.Folder(props, "ReturnGate"), returnPortal, "TO THE HIGH SCHOOL")
		Scenery.Hoop(output(hoop, Config.GeneratedName), rim, rimHeight)
		local requirement = college.Requirements
		Scenery.TransitStop(output(folder(schoolMap, "Environment"), Config.GateName), outgoing,
			string.format("COLLEGE ARENA\n%d VERTICAL  /  $%s", requirement.Vertical, tostring(requirement.Cash)))

		for _, root in stage:GetChildren() do
			root:SetAttribute("BuilderOwner", Config.Owner)
			for _, child in root:GetDescendants() do
				assert(not child:IsA("LuaSourceContainer"), "No scripts allowed in generated environment")
				child:SetAttribute("BuilderOwner", Config.Owner)
				if child:IsA("BasePart") then count += 1; assert(child.Anchored, "Scenery must be anchored") end
			end
		end
		assert(count <= Config.MaxParts, "College Part budget exceeded")
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
		error("College build rolled back: " .. tostring(problem), 0)
	end
	for _, entry in installations do if entry.Previous then entry.Previous:Destroy() end end
	stage:Destroy()
	print(string.format("[CollegeBuilder] Built %d decorative Parts; missing College gameplay objects and the High School College stop created once. Rim height %.3f studs. Save the place and restart Play.", count, rimHeight))
	return count
end

return Build
