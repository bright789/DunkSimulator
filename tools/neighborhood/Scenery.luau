local Config = require(script.Parent.Config)
local Geometry = require(script.Parent.Geometry)
local Colors = Config.Colors

local Scenery = {}

function Scenery.Court(parent, context)
	local frame = context.Frame
	local halfWidth = context.Court.Size.X / 2
	local baseline = context.Court.Size.Z / 2
	local rimDepth = baseline - Config.RimInset
	local lineHeight = 0.055
	local lines = Geometry.Folder(parent, "Lines")
	local function stripe(name, size, position)
		Geometry.Part(lines, name, size, frame * CFrame.new(position), Colors.Line)
	end
	stripe("Baseline", Vector3.new(halfWidth * 2, 0.02, 0.3), Vector3.new(0, lineHeight, baseline))
	stripe("HalfCourt", Vector3.new(halfWidth * 2, 0.02, 0.3), Vector3.new(0, lineHeight, -baseline))
	for _, side in { -1, 1 } do
		stripe("Sideline" .. side, Vector3.new(0.3, 0.02, baseline * 2), Vector3.new(side * halfWidth, lineHeight, 0))
		stripe("KeySide" .. side, Vector3.new(0.3, 0.02, Config.KeyDepth), Vector3.new(side * Config.KeyWidth / 2, lineHeight, baseline - Config.KeyDepth / 2))
		stripe("CornerThree" .. side, Vector3.new(0.3, 0.02, Config.RimInset), Vector3.new(side * Config.ArcRadius, lineHeight, baseline - Config.RimInset / 2))
	end
	Geometry.Part(parent, "Paint", Vector3.new(Config.KeyWidth, 0.02, Config.KeyDepth),
		frame * CFrame.new(0, 0.025, baseline - Config.KeyDepth / 2), Colors.Paint)
	stripe("FreeThrow", Vector3.new(Config.KeyWidth, 0.02, 0.3), Vector3.new(0, lineHeight, baseline - Config.KeyDepth))
	Geometry.Arc(lines, "FreeThrowCircle", frame * CFrame.new(0, lineHeight, baseline - Config.KeyDepth),
		6, 0, math.pi * 2, Config.FreeThrowSegments, 0.25, 0.02, Colors.Line)
	Geometry.Arc(lines, "ThreePointArc", frame * CFrame.new(0, lineHeight, rimDepth),
		Config.ArcRadius, 0, math.pi, Config.ArcSegments, 0.3, 0.02, Colors.Line)
end

function Scenery.Hoop(parent, context)
	local frame = CFrame.new(context.Rim.Position) * context.Frame.Rotation
	local height = context.Rim.Position.Y - context.FloorY
	Geometry.Arc(parent, "VisibleRim", frame, Config.RimRadius, 0, math.pi * 2,
		Config.RimSegments, 0.22, 0.22, Colors.Orange)
	Geometry.Part(parent, "Backboard", Vector3.new(14, 8, 0.4), frame * CFrame.new(0, 3, 3.6), Colors.Line)
	Geometry.Part(parent, "Pole", Vector3.new(1, height + 6, 1), frame * CFrame.new(0, (6 - height) / 2, 6), Colors.Metal, Enum.Material.Metal)
	Geometry.Part(parent, "Base", Vector3.new(4, 0.4, 4), frame * CFrame.new(0, -height + 0.2, 6), Colors.Metal)
	Geometry.Part(parent, "Support", Vector3.new(0.7, 0.7, 3), frame * CFrame.new(0, 3, 5), Colors.Metal, Enum.Material.Metal)
	Geometry.Part(parent, "RimBracket", Vector3.new(0.5, 0.3, 1.3), frame * CFrame.new(0, 0, 2.9), Colors.Orange)
	for _, side in { -1, 1 } do
		Geometry.Part(parent, "TargetSide" .. side, Vector3.new(0.15, 3.5, 0.04), frame * CFrame.new(side * 2.5, 1.8, 3.37), Colors.Orange)
		Geometry.Part(parent, "TargetEdge" .. side, Vector3.new(5, 0.15, 0.04), frame * CFrame.new(0, 1.8 + side * 1.75, 3.37), Colors.Orange)
	end
end

function Scenery.Stations(parent, context)
	local trainer = Geometry.Folder(parent, "TrainingArea")
	local pickup = Geometry.Folder(parent, "BallStand")
	local trainingFrame = context.TrainerFrame
	local pickupFrame = context.PickupFrame
	Geometry.Part(trainer, "RubberPad", Vector3.new(12, 0.04, 12), trainingFrame, Colors.Metal)
	Geometry.Sign(trainer, "TrainingSign", trainingFrame * CFrame.new(0, 5, 6), "VERTICAL TRAINING", Colors.Paint, 12)
	Geometry.Part(trainer, "SignPost", Vector3.new(0.3, 5, 0.3), trainingFrame * CFrame.new(0, 2.5, 6), Colors.Metal)
	for index = 1, 3 do
		Geometry.Part(trainer, "JumpMark" .. index, Vector3.new(4, 0.02, 0.3), trainingFrame * CFrame.new(0, 0.04, -2 - index), Colors.Line)
	end
	Geometry.Part(pickup, "StandShelf", Vector3.new(6, 0.3, 3), pickupFrame * CFrame.new(0, 2.2, 3), Colors.Wood, Enum.Material.Wood)
	for _, side in { -1, 1 } do
		Geometry.Part(pickup, "Leg" .. side, Vector3.new(0.4, 2.2, 2.5), pickupFrame * CFrame.new(side * 2.5, 1.1, 3), Colors.Metal)
		local ball = Geometry.Part(pickup, "DisplayBall" .. side, Vector3.new(1.8, 1.8, 1.8), pickupFrame * CFrame.new(side * 1.3, 3.2, 3), Colors.Orange)
		ball.Shape = Enum.PartType.Ball
	end
	Geometry.Sign(pickup, "PickupSign", pickupFrame * CFrame.new(0, 5, 4), "BASKETBALL  /  PICK UP", Colors.Metal, 10)
	if context.UpgradeStation then
		local station = context.UpgradeStation
		local upgrade = Geometry.Folder(parent, "UpgradeArea")
		local upgradeFrame = station.CFrame * CFrame.new(0, -station.Size.Y / 2, 0)
		Geometry.Part(upgrade, "Pad", Vector3.new(10, 0.03, 8), upgradeFrame, Colors.Paint)
		Geometry.Part(upgrade, "EquipmentShelf", Vector3.new(8, 0.3, 2), upgradeFrame * CFrame.new(0, 2.5, 3), Colors.Wood, Enum.Material.Wood)
		for _, side in { -1, 1 } do
			Geometry.Part(upgrade, "Support" .. side, Vector3.new(0.4, 5, 0.4), upgradeFrame * CFrame.new(side * 3.5, 2.5, 3), Colors.Metal)
			Geometry.Part(upgrade, "Equipment" .. side, Vector3.new(2, 0.6, 1), upgradeFrame * CFrame.new(side * 1.7, 3, 3), Colors.Orange)
		end
		Geometry.Sign(upgrade, "UpgradeSign", upgradeFrame * CFrame.new(0, 5.5, 3), "UPGRADES", Colors.Metal, 10)
	else
		warn("[Neighborhood] UpgradeStation is absent; skipping upgrade dressing. Run SetupUpgradeStation.Run once if needed.")
	end
end

function Scenery.Environment(parent, props, boundaries, context)
	local frame = context.GroundFrame
	local halfWidth = context.Ground.Size.X / 2
	local halfDepth = context.Ground.Size.Z / 2
	local function part(folder, name, size, position, color, material, collision)
		return Geometry.Part(folder, name, size, frame * CFrame.new(position), color, material, collision)
	end
	part(parent, "Sidewalk", Vector3.new(halfWidth * 2 + 10, 0.4, 10), Vector3.new(0, -0.2, -halfDepth - 5), Colors.Concrete, Enum.Material.Concrete, true)
	part(parent, "Curb", Vector3.new(halfWidth * 2 + 10, 0.4, 0.6), Vector3.new(0, -0.1, -halfDepth - 10), Colors.Line, Enum.Material.Concrete, true)
	part(parent, "Street", Vector3.new(halfWidth * 2 + 30, 0.5, 24), Vector3.new(0, -0.5, -halfDepth - 22), Colors.Road, Enum.Material.Asphalt, true)
	for index = -3, 3 do
		part(parent, "RoadDash" .. index, Vector3.new(10, 0.02, 0.3), Vector3.new(index * 20, -0.235, -halfDepth - 22), Colors.Line)
	end
	local houses = Geometry.Folder(parent, "Houses")
	for index = -1, 1 do
		local house = Geometry.Folder(houses, "House" .. index)
		local center = Vector3.new(index * 38, 0, -halfDepth - 49)
		part(house, "Facade", Vector3.new(24, 17 + index * 2, 16), center + Vector3.new(0, (17 + index * 2) / 2, 0), Color3.fromRGB(158 + index * 12, 143, 122), Enum.Material.Brick)
		part(house, "Roof", Vector3.new(26, 1.2, 18), center + Vector3.new(0, 17.6 + index * 2, 0), Colors.Metal)
		part(house, "Door", Vector3.new(3, 6, 0.15), center + Vector3.new(0, 3, 8.1), Colors.Wood)
		for _, side in { -1, 1 } do
			part(house, "Window" .. side, Vector3.new(4, 4, 0.15), center + Vector3.new(side * 7, 10, 8.1), Colors.Paint)
		end
	end
	local benches = Geometry.Folder(props, "Benches")
	local trees = Geometry.Folder(props, "Trees")
	local lights = Geometry.Folder(props, "Lights")
	for _, side in { -1, 1 } do
		local bench = Geometry.Folder(benches, "Bench" .. side)
		local center = Vector3.new(side * 45, 0, 28)
		part(bench, "Seat", Vector3.new(8, 0.4, 2.5), center + Vector3.new(0, 2, 0), Colors.Wood, Enum.Material.Wood)
		part(bench, "Back", Vector3.new(8, 2, 0.3), center + Vector3.new(0, 3.1, 1.2), Colors.Wood, Enum.Material.Wood)
		for _, leg in { -1, 1 } do
			part(bench, "Leg" .. leg, Vector3.new(0.4, 2, 2), center + Vector3.new(leg * 3, 1, 0), Colors.Metal)
		end
		part(props, "TrashCan" .. side, Vector3.new(2, 3, 2), center + Vector3.new(7, 1.5, 0), Colors.Metal, Enum.Material.Metal)
		for _, depth in { -25, 40 } do
			local tree = Geometry.Folder(trees, "Tree" .. side .. "_" .. depth)
			local treeCenter = Vector3.new(side * (halfWidth - 10), 0, depth)
			part(tree, "Trunk", Vector3.new(1.5, 9, 1.5), treeCenter + Vector3.new(0, 4.5, 0), Colors.Wood, Enum.Material.Wood)
			local crown = part(tree, "Crown", Vector3.new(11, 12, 10), treeCenter + Vector3.new(0, 12, 0), Colors.Leaf, Enum.Material.Grass)
			crown.Shape = Enum.PartType.Ball
		end
		local bush = part(props, "Bush" .. side, Vector3.new(8, 3, 4), Vector3.new(side * 32, 1.5, -halfDepth + 6), Colors.Leaf, Enum.Material.Grass)
		bush.Shape = Enum.PartType.Ball
		part(lights, "Pole" .. side, Vector3.new(0.7, 22, 0.7), Vector3.new(side * 45, 11, 8), Colors.Metal, Enum.Material.Metal)
		local fixture = part(lights, "Fixture" .. side, Vector3.new(4, 0.4, 2), Vector3.new(side * 45, 22, 8), Colors.Line)
		local light = Instance.new("SpotLight")
		light.Name = "CourtLight"
		light.Face = Enum.NormalId.Bottom
		light.Angle = 100
		light.Range = 60
		light.Brightness = 1
		light.Shadows = false
		light.Color = Color3.fromRGB(255, 237, 209)
		light.Parent = fixture
	end
	local gate = Config.EntranceWidth / 2
	local postWidth = Config.EntrancePostWidth
	local postHeight = Config.EntrancePostHeight
	local fenceEnd = gate + postWidth + Config.EntranceFenceGap
	assert(gate > 0 and postWidth > 0 and Config.EntranceFenceGap >= 0.1 and fenceEnd < halfWidth,
		"Entrance dimensions must leave separate front fence sections and positive post clearance")
	assert(postHeight - 2.5 >= Config.FenceHeight, "Entrance sign must sit above the fence")
	local entrance = Geometry.Folder(props, "Entrance")
	Geometry.Sign(entrance, "EntranceSign", frame * CFrame.new(0, postHeight - 1.25, -halfDepth),
		"THE NEIGHBORHOOD", Colors.Metal, Config.EntranceWidth + 2 * postWidth)
	for _, side in { -1, 1 } do
		part(entrance, "EntrancePost" .. side, Vector3.new(postWidth, postHeight, postWidth),
			Vector3.new(side * (gate + postWidth / 2), postHeight / 2, -halfDepth), Colors.Metal, Enum.Material.Metal, true)
	end
	local fences = Geometry.Folder(boundaries, "Fences")
	local function fence(name, first, last, skipFirstPost, skipLastPost)
		local folder = Geometry.Folder(fences, name)
		local length = (last - first).Magnitude
		local sections = math.ceil(length / 32)
		for index = 0, sections do
			if not ((index == 0 and skipFirstPost) or (index == sections and skipLastPost)) then
				local point = first:Lerp(last, index / sections)
				part(folder, "Post" .. index, Vector3.new(0.4, Config.FenceHeight, 0.4), point + Vector3.new(0, Config.FenceHeight / 2, 0), Colors.Metal, Enum.Material.Metal)
			end
		end
		for index = 1, sections do
			local start = first:Lerp(last, (index - 1) / sections)
			local finish = first:Lerp(last, index / sections)
			for _, height in { 0.5, Config.FenceHeight - 0.5 } do
				Geometry.Line(folder, "Rail" .. index .. "_" .. height, frame:PointToWorldSpace(start + Vector3.new(0, height, 0)), frame:PointToWorldSpace(finish + Vector3.new(0, height, 0)), 0.15, 0.15, Colors.Metal)
			end
			for half = 0, 1 do
				local left = start:Lerp(finish, half / 2)
				local right = start:Lerp(finish, (half + 1) / 2)
				for _, reverse in { false, true } do
					local low = left + Vector3.new(0, reverse and Config.FenceHeight - 0.5 or 0.5, 0)
					local high = right + Vector3.new(0, reverse and 0.5 or Config.FenceHeight - 0.5, 0)
					Geometry.Line(folder, "Wire" .. index .. "_" .. half .. "_" .. tostring(reverse), frame:PointToWorldSpace(low), frame:PointToWorldSpace(high), 0.05, 0.05, Colors.Metal)
				end
			end
		end
		local center = frame:PointToWorldSpace((first + last) / 2 + Vector3.new(0, Config.FenceHeight / 2, 0))
		local barrier = Geometry.Part(folder, "Collision", Vector3.new(0.4, Config.FenceHeight, length), CFrame.lookAt(center, center + frame:VectorToWorldSpace(last - first)), Colors.Metal, nil, true)
		barrier.Transparency = 1
	end
	fence("Left", Vector3.new(-halfWidth, 0, -halfDepth), Vector3.new(-halfWidth, 0, halfDepth))
	fence("Right", Vector3.new(halfWidth, 0, -halfDepth), Vector3.new(halfWidth, 0, halfDepth))
	fence("Back", Vector3.new(-halfWidth, 0, halfDepth), Vector3.new(halfWidth, 0, halfDepth))
	fence("FrontLeft", Vector3.new(-halfWidth, 0, -halfDepth), Vector3.new(-fenceEnd, 0, -halfDepth), false, true)
	fence("FrontRight", Vector3.new(fenceEnd, 0, -halfDepth), Vector3.new(halfWidth, 0, -halfDepth), true, false)
end

return Scenery
