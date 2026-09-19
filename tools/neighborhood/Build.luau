local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Config = require(script.Parent.Config)
local Geometry = require(script.Parent.Geometry)
local Scenery = require(script.Parent.Scenery)

local Build = {}

local function child(parent, name, className)
	local found = nil
	for _, object in parent:GetChildren() do
		if object.Name == name then
			assert(not found, "Duplicate name: " .. parent:GetFullName() .. "." .. name)
			found = object
		end
	end
	assert(found and found:IsA(className), "Expected " .. className .. " at " .. parent:GetFullName() .. "." .. name)
	return found
end

local function optionalFolder(parent, name)
	if parent:FindFirstChild(name) then
		return child(parent, name, "Folder")
	end
	return nil
end

local function preflight()
	assert(RunService:IsStudio() and not RunService:IsRunning(), "Neighborhood builder is edit-mode only. Stop Play first.")
	local map = child(Workspace, "Map", "Folder")
	local neighborhood = child(map, "Neighborhood", "Folder")
	local courtFolder = child(neighborhood, "Court", "Folder")
	local environment = child(neighborhood, "Environment", "Folder")
	local court = child(courtFolder, "CourtSurface", "BasePart")
	local ground = child(environment, "ParkGround", "BasePart")
	local gameplay = child(Workspace, "Gameplay", "Folder")
	local hoop = child(gameplay, "DunkHoop", "Model")
	local rim = child(hoop, "Rim", "BasePart")
	local trainer = child(gameplay, "VerticalTrainer", "BasePart")
	local pickup = child(gameplay, "BasketballPickup", "BasePart")
	local upgradeStation = nil
	if gameplay:FindFirstChild("UpgradeStation") then
		upgradeStation = child(gameplay, "UpgradeStation", "BasePart")
		assert(upgradeStation.Anchored, "UpgradeStation must be anchored")
	end
	local spawn = child(Workspace, "SpawnLocation", "SpawnLocation")
	for _, station in { trainer, pickup } do
		assert(station:FindFirstChildOfClass("ProximityPrompt"), station.Name .. " requires its existing direct ProximityPrompt")
		assert(station.Anchored, station.Name .. " must already be anchored")
	end
	assert(court.Anchored and ground.Anchored and rim.Anchored and spawn.Anchored, "Court, ground, rim and spawn must already be anchored")
	assert(court.CanCollide and ground.CanCollide, "Existing court and ground must provide collidable floors")
	assert(court.CFrame.UpVector:Dot(Vector3.yAxis) > 0.99999 and ground.CFrame.UpVector:Dot(Vector3.yAxis) > 0.99999,
		"CourtSurface and ParkGround must be horizontal (yaw rotation is supported)")
	assert(math.abs(court.Size.X - 60) <= 2 and math.abs(court.Size.Z - 55) <= 2,
		"Expected the tested approximately 60 x 55 CourtSurface; no dimensions will be changed")
	assert(math.abs(ground.Size.X - 130) <= 2 and math.abs(ground.Size.Z - 120) <= 2,
		"Expected the tested approximately 130 x 120 ParkGround; no dimensions will be changed")
	local floorY = court.Position.Y + court.Size.Y / 2
	local groundY = ground.Position.Y + ground.Size.Y / 2
	assert(groundY <= floorY and floorY - groundY <= 1, "ParkGround top must be at or up to one stud below CourtSurface top")
	assert(rim.Position.Y > floorY + 6, "Rim must be above the tested takeoff floor")
	local rotation = court.CFrame.Rotation
	if court.CFrame:PointToObjectSpace(rim.Position).Z < 0 then
		rotation *= CFrame.Angles(0, math.pi, 0)
	end
	local rimDepth = court.Size.Z / 2 - Config.RimInset
	local offset = rotation:VectorToWorldSpace(Vector3.new(0, 0, rimDepth))
	local center = Vector3.new(rim.Position.X - offset.X, floorY, rim.Position.Z - offset.Z)
	local frame = CFrame.new(center) * rotation
	local groundFrame = CFrame.new(center.X, groundY, center.Z) * rotation
	return {
		Neighborhood = neighborhood, CourtFolder = courtFolder, Environment = environment,
		Props = optionalFolder(neighborhood, "Props"), Boundaries = optionalFolder(neighborhood, "Boundaries"),
		Court = court, Ground = ground, Hoop = hoop, Rim = rim, Trainer = trainer, Pickup = pickup, Spawn = spawn,
		UpgradeStation = upgradeStation,
		FloorY = floorY, Frame = frame, GroundFrame = groundFrame,
		TrainerFrame = groundFrame * CFrame.new(-43, 0.035, -18),
		PickupFrame = groundFrame * CFrame.new(-18, 0.035, -35),
	}
end

function Build.Run()
	local context = preflight()
	local stage = Instance.new("Folder")
	stage.Name = "NeighborhoodBuildStaging"
	local roots = {}
	local destinations = {
		Court = context.CourtFolder, Environment = context.Environment,
		Props = context.Props, Boundaries = context.Boundaries, Hoop = context.Hoop,
	}
	local oldRoots = {}
	local changes = {}
	local createdFolders = {}
	local originalRimFrame = context.Rim.CFrame
	local originalRimSize = context.Rim.Size
	local originalHeight = context.Rim.Position.Y - context.FloorY
	local count = 0
	local function change(object, property, value)
		table.insert(changes, { Object = object, Property = property, Value = object[property] })
		object[property] = value
	end
	local success, failure = pcall(function()
		for _, name in { "Court", "Environment", "Props", "Boundaries", "Hoop" } do
			local root = Geometry.Folder(stage, name)
			root:SetAttribute("BuilderOwner", Config.Owner)
			roots[name] = root
			local destination = destinations[name]
			local previous = destination and destination:FindFirstChild(Config.GeneratedName)
			if previous then
				child(destination, Config.GeneratedName, "Folder")
				assert(previous:GetAttribute("BuilderOwner") == Config.Owner, "Refusing to replace unowned " .. previous:GetFullName())
				table.insert(oldRoots, { Object = previous, Parent = destination })
			end
		end
		Scenery.Court(roots.Court, context)
		Scenery.Hoop(roots.Hoop, context)
		Scenery.Stations(roots.Props, context)
		Scenery.Environment(roots.Environment, roots.Props, roots.Boundaries, context)
		for _, object in stage:GetDescendants() do
			assert(not object:IsA("LuaSourceContainer"), "Generated scenery cannot contain scripts")
			if object:IsA("BasePart") then
				count += 1
				assert(object.Anchored, "Unanchored generated Part")
			end
		end
		assert(count <= Config.MaxParts, "Scenery exceeded its Part budget")
		for _, name in { "Props", "Boundaries" } do
			if not destinations[name] then
				local folder = Geometry.Folder(context.Neighborhood, name)
				table.insert(createdFolders, folder)
				destinations[name] = folder
			end
		end
		for _, previous in oldRoots do
			previous.Object.Parent = nil
		end
		for name, root in roots do
			root.Name = Config.GeneratedName
			root.Parent = destinations[name]
		end
		change(context.Court, "CFrame", context.Frame * CFrame.new(0, -context.Court.Size.Y / 2, 0))
		change(context.Court, "Color", Config.Colors.Court)
		change(context.Court, "Material", Enum.Material.Asphalt)
		change(context.Ground, "CFrame", context.GroundFrame * CFrame.new(0, -context.Ground.Size.Y / 2, 0))
		change(context.Ground, "Color", Config.Colors.Grass)
		change(context.Ground, "Material", Enum.Material.Grass)
		change(context.Trainer, "CFrame", context.TrainerFrame * CFrame.new(0, context.Trainer.Size.Y / 2, 0))
		change(context.Pickup, "CFrame", context.PickupFrame * CFrame.new(0, context.Pickup.Size.Y / 2, 0))
		change(context.Spawn, "CFrame", context.GroundFrame * CFrame.new(0, context.Spawn.Size.Y / 2, -context.Ground.Size.Z / 2 + 12) * CFrame.Angles(0, math.pi, 0))
		change(context.Spawn, "Transparency", 1)
		change(context.Spawn, "CastShadow", false)
		for _, object in context.Spawn:GetDescendants() do
			if object:IsA("Decal") or object:IsA("Texture") then
				change(object, "Transparency", 1)
			end
		end
		change(context.Rim, "Transparency", 1)
		for _, name in { "Backboard", "Pole", "Support", "VisualRim", "TargetBox", "Visuals" } do
			local legacy = context.Hoop:FindFirstChild(name)
			if legacy then
				local objects = legacy:GetDescendants()
				table.insert(objects, legacy)
				for _, object in objects do
					if object:IsA("BasePart") then
						change(object, "Transparency", 1)
						change(object, "CanCollide", false)
						change(object, "CanQuery", false)
					end
				end
			end
		end
		change(Lighting, "ClockTime", 15.5)
		change(Lighting, "Brightness", 2)
		change(Lighting, "OutdoorAmbient", Color3.fromRGB(140, 140, 140))
		assert(context.Rim.CFrame == originalRimFrame and context.Rim.Size == originalRimSize, "Logical rim changed")
		assert(math.abs(context.Rim.Position.Y - (context.Court.Position.Y + context.Court.Size.Y / 2) - originalHeight) < 0.0001,
			"Floor-to-rim height changed")
	end)
	if not success then
		for index = #changes, 1, -1 do
			local entry = changes[index]
			entry.Object[entry.Property] = entry.Value
		end
		for _, root in roots do
			root:Destroy()
		end
		for _, previous in oldRoots do
			previous.Object.Parent = previous.Parent
		end
		for _, folder in createdFolders do
			folder:Destroy()
		end
		stage:Destroy()
		error("Neighborhood build cancelled and rolled back: " .. tostring(failure), 0)
	end
	for _, previous in oldRoots do
		previous.Object:Destroy()
	end
	stage:Destroy()
	print(string.format("[Neighborhood] Built %d anchored Parts. Rim height preserved: %.3f studs. Save this Studio place; no runtime generator is needed.", count, originalHeight))
	print("[Neighborhood] Court/ground aligned horizontally around the fixed Rim; trainer, pickup and spawn moved to the entrance layout. Existing unrelated map objects were not removed.")
	return count
end

return Build
