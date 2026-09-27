-- Detailed decorative props shared by the Neighborhood and High School builders:
-- seamed basketballs, a ball shop, a leg-day gym corner, a bus stop, a school bus and the
-- Training Upgrades lab.
-- Every part is anchored scenery; gameplay stations are never created or moved here.
--
-- Frames: every function takes the station's floor frame. Its LookVector points toward
-- the player (the side you walk up to); local +Z is "behind" the station.
local Geometry = require(script.Parent.Geometry)

local Props = {}

local SEAM = Color3.fromRGB(26, 18, 14)
local BALL = Color3.fromRGB(226, 104, 34)

local function cylinder(parent, name, length, diameter, frame, color, material)
	local part = Geometry.Part(parent, name, Vector3.new(length, diameter, diameter), frame, color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function sphere(parent, name, frame, diameter, color, material)
	local part = Geometry.Part(parent, name, Vector3.new(diameter, diameter, diameter), frame, color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

local function glass(part, transparency)
	part.Material = Enum.Material.Glass
	part.Transparency = transparency
	return part
end

-- Orange pebbled ball with black seams. Each seam is a thin disc a little wider than the
-- ball, so only its edge shows as a line on the surface.
function Props.Basketball(parent, name, frame, diameter)
	local folder = Geometry.Folder(parent, name)
	local radius = diameter / 2
	local seam = math.max(diameter * 0.045, 0.05)
	sphere(folder, "Ball", frame, diameter, BALL, Enum.Material.Leather)
	cylinder(folder, "SeamA", seam, diameter * 1.02, frame, SEAM)
	cylinder(folder, "SeamB", seam, diameter * 1.02, frame * CFrame.Angles(0, math.rad(90), 0), SEAM)
	for _, side in { -1, 1 } do
		local height = radius * 0.62
		local ring = 2 * math.sqrt(radius * radius - height * height) + diameter * 0.02
		cylinder(folder, "Curve" .. (side > 0 and "Top" or "Bottom"), seam, ring,
			frame * CFrame.new(0, side * height, 0) * CFrame.Angles(0, 0, math.rad(90)), SEAM)
	end
	return folder
end

-- "Hoop Shop" stall built behind the pickup station.
function Props.BallShop(parent, frame, colors)
	local shop = Geometry.Folder(parent, "HoopShop")
	Geometry.Part(shop, "Floor", Vector3.new(12, 0.3, 7), frame * CFrame.new(0, 0.15, 3.9), colors.Wood, Enum.Material.WoodPlanks)
	Geometry.Part(shop, "BackWall", Vector3.new(12, 7.5, 0.4), frame * CFrame.new(0, 3.75, 7.3), colors.Accent)
	for _, side in { -1, 1 } do
		Geometry.Part(shop, "SideWall" .. side, Vector3.new(0.4, 7.5, 7), frame * CFrame.new(side * 6, 3.75, 3.9), colors.Light)
		Geometry.Part(shop, "FrontPost" .. side, Vector3.new(0.45, 7.5, 0.45), frame * CFrame.new(side * 5.8, 3.75, 0.9), colors.Metal, Enum.Material.Metal)
	end
	Geometry.Part(shop, "Counter", Vector3.new(10, 3, 1.6), frame * CFrame.new(0, 1.5, 2.3), colors.Wood, Enum.Material.Wood)
	Geometry.Part(shop, "CounterTop", Vector3.new(10.4, 0.25, 2), frame * CFrame.new(0, 3.1, 2.3), colors.Light)
	Geometry.Part(shop, "CounterStripe", Vector3.new(10, 0.6, 0.08), frame * CFrame.new(0, 2.2, 1.46), colors.Accent)
	-- Striped awning, tilted down toward the customer.
	for index = 0, 5 do
		local x = -5 + index * 2
		Geometry.Part(shop, "Awning" .. index, Vector3.new(2, 0.2, 4), frame * CFrame.new(x, 7.6, 1.2) * CFrame.Angles(math.rad(18), 0, 0),
			index % 2 == 0 and colors.Accent or colors.Light)
	end
	Geometry.Sign(shop, "ShopSign", frame * CFrame.new(0, 9.4, 0.9), "HOOP SHOP", colors.Dark, 10)
	-- Ball racks on the back wall and two balls on the counter.
	for row, height in { 2.3, 4.2 } do
		Geometry.Part(shop, "Shelf" .. row, Vector3.new(10, 0.25, 1.4), frame * CFrame.new(0, height, 6.4), colors.Metal, Enum.Material.Metal)
		for column = -1, 1 do
			Props.Basketball(shop, string.format("RackBall%d_%d", row, column + 2),
				frame * CFrame.new(column * 3, height + 0.95, 6.4) * CFrame.Angles(0, math.rad(column * 25), 0), 1.6)
		end
	end
	for _, side in { -1, 1 } do
		Props.Basketball(shop, "CounterBall" .. side, frame * CFrame.new(side * 3.2, 4.0, 2.3) * CFrame.Angles(0, math.rad(side * 40), 0), 1.6)
	end
	return shop
end

-- Leg-day corner around the trainer: squat rack, bench, plyo boxes and dumbbells.
function Props.LegGym(parent, frame, colors)
	local gym = Geometry.Folder(parent, "LegDayGym")
	Geometry.Part(gym, "RubberFloor", Vector3.new(16, 0.06, 13), frame * CFrame.new(0, 0.03, 2), colors.Rubber, Enum.Material.Rubber)
	Geometry.Part(gym, "BackPanel", Vector3.new(16, 7, 0.3), frame * CFrame.new(0, 3.5, 8.5), colors.Accent)
	Geometry.Sign(gym, "GymSign", frame * CFrame.new(0, 6, 8.3), "LEG DAY", colors.Dark, 9)
	-- Squat rack with a loaded barbell.
	local rack = frame * CFrame.new(5.5, 0, 5)
	for _, side in { -1, 1 } do
		Geometry.Part(gym, "RackUpright" .. side, Vector3.new(0.4, 7, 0.4), rack * CFrame.new(side * 1.8, 3.5, 0), colors.Metal, Enum.Material.Metal)
		Geometry.Part(gym, "RackHook" .. side, Vector3.new(0.3, 0.3, 0.6), rack * CFrame.new(side * 1.8, 4.6, -0.4), colors.Metal, Enum.Material.Metal)
		for plate = 1, 2 do
			cylinder(gym, "Plate" .. side .. "_" .. plate, 0.3, plate == 1 and 2.6 or 1.9,
				rack * CFrame.new(side * (2.35 + plate * 0.35), 4.85, -0.4), plate == 1 and colors.Accent or colors.Dark)
		end
	end
	Geometry.Part(gym, "RackTop", Vector3.new(4, 0.4, 0.4), rack * CFrame.new(0, 7, 0), colors.Metal, Enum.Material.Metal)
	cylinder(gym, "Barbell", 7, 0.22, rack * CFrame.new(0, 4.85, -0.4), colors.Metal, Enum.Material.Metal)
	-- Flat bench.
	local bench = frame * CFrame.new(-5.5, 0, 4.5)
	Geometry.Part(gym, "BenchPad", Vector3.new(1.4, 0.45, 4.2), bench * CFrame.new(0, 1.6, 0), colors.Dark, Enum.Material.Leather)
	for _, side in { -1, 1 } do
		Geometry.Part(gym, "BenchLeg" .. side, Vector3.new(1.2, 1.4, 0.3), bench * CFrame.new(0, 0.7, side * 1.7), colors.Metal, Enum.Material.Metal)
	end
	-- Stacked plyo boxes.
	Geometry.Part(gym, "PlyoBoxLarge", Vector3.new(2.6, 2, 2.6), frame * CFrame.new(-6.5, 1, -1), colors.Wood, Enum.Material.Wood)
	Geometry.Part(gym, "PlyoBoxSmall", Vector3.new(2, 1.2, 2), frame * CFrame.new(-6.5, 2.6, -1) * CFrame.Angles(0, math.rad(20), 0), colors.Wood, Enum.Material.Wood)
	-- Dumbbell rack along the back.
	Geometry.Part(gym, "DumbbellRack", Vector3.new(6, 1.2, 1.2), frame * CFrame.new(0, 0.6, 7.3), colors.Metal, Enum.Material.Metal)
	for index = 0, 3 do
		local x = -2.25 + index * 1.5
		cylinder(gym, "DumbbellHandle" .. index, 1.2, 0.18, frame * CFrame.new(x, 1.45, 7.3) * CFrame.Angles(0, math.rad(90), 0), colors.Metal, Enum.Material.Metal)
		for _, side in { -1, 1 } do
			cylinder(gym, "DumbbellHead" .. index .. side, 0.35, 0.7, frame * CFrame.new(x, 1.45, 7.3 + side * 0.55) * CFrame.Angles(0, math.rad(90), 0), colors.Dark)
		end
	end
	return gym
end

-- Bus shelter around the travel station (the station block acts as the bench seat).
function Props.BusStop(parent, frame, destination, colors)
	local stop = Geometry.Folder(parent, "BusStop")
	glass(Geometry.Part(stop, "BackGlass", Vector3.new(9, 6, 0.15), frame * CFrame.new(0, 3.5, 2.4), colors.Glass), 0.45)
	Geometry.Part(stop, "Roof", Vector3.new(9.6, 0.35, 4.2), frame * CFrame.new(0, 7.1, 0.9), colors.Accent)
	for _, side in { -1, 1 } do
		Geometry.Part(stop, "Post" .. side, Vector3.new(0.3, 7, 0.3), frame * CFrame.new(side * 4.5, 3.5, 2.4), colors.Metal, Enum.Material.Metal)
	end
	Geometry.Sign(stop, "RouteBoard", frame * CFrame.new(0, 8.6, 0.9), destination, colors.Dark, 9)
	Geometry.Part(stop, "SignPole", Vector3.new(0.25, 8, 0.25), frame * CFrame.new(-6, 4, -1.5), colors.Metal, Enum.Material.Metal)
	Geometry.Sign(stop, "BusSign", frame * CFrame.new(-6, 7.4, -1.5), "BUS STOP", colors.Accent, 3.5)
	Geometry.Part(stop, "CurbPaint", Vector3.new(12, 0.04, 2), frame * CFrame.new(0, 0.03, -2.5), colors.Yellow)
	return stop
end

-- Yellow school bus. busFrame sits on the road surface, facing forward; the door is on
-- the bus's right side. The model is named TransitBus so clients can animate it.
function Props.SchoolBus(parent, busFrame, colors)
	local bus = Instance.new("Model")
	bus.Name = "TransitBus"
	bus.Parent = parent
	local yellow, black = colors.Yellow, Color3.fromRGB(24, 24, 28)
	local tint = Color3.fromRGB(40, 60, 80)
	local body = Geometry.Part(bus, "Body", Vector3.new(7.6, 6.2, 22), busFrame * CFrame.new(0, 4.4, 1), yellow)
	bus.PrimaryPart = body
	Geometry.Part(bus, "Hood", Vector3.new(7.4, 3.2, 2.6), busFrame * CFrame.new(0, 2.9, -11.3), yellow)
	Geometry.Part(bus, "Roof", Vector3.new(7.3, 0.4, 21.6), busFrame * CFrame.new(0, 7.7, 1), yellow:Lerp(Color3.new(1, 1, 1), 0.25))
	for index, height in { 3.2, 5.0 } do
		Geometry.Part(bus, "Stripe" .. index, Vector3.new(7.7, 0.18, 22.1), busFrame * CFrame.new(0, height, 1), black)
	end
	for _, side in { -1, 1 } do
		glass(Geometry.Part(bus, "SideWindows" .. side, Vector3.new(0.12, 1.9, 16), busFrame * CFrame.new(side * 3.82, 6.1, 3), tint), 0.2)
		for pillar = 0, 5 do
			Geometry.Part(bus, "Pillar" .. side .. "_" .. pillar, Vector3.new(0.14, 1.9, 0.3), busFrame * CFrame.new(side * 3.86, 6.1, -4.5 + pillar * 3), yellow)
		end
	end
	glass(Geometry.Part(bus, "Windshield", Vector3.new(7, 2.4, 0.15), busFrame * CFrame.new(0, 6, -10.05), tint), 0.2)
	glass(Geometry.Part(bus, "RearWindow", Vector3.new(6, 1.9, 0.15), busFrame * CFrame.new(0, 6.1, 12.05), tint), 0.2)
	-- Folding door on the right side near the front.
	for index, offset in { -8.6, -7.4 } do
		glass(Geometry.Part(bus, index == 1 and "DoorFront" or "DoorRear", Vector3.new(0.14, 4.8, 1.15),
			busFrame * CFrame.new(3.85, 3.9, offset), tint), 0.15)
	end
	Geometry.Part(bus, "DoorFrame", Vector3.new(0.1, 5.2, 2.6), busFrame * CFrame.new(3.81, 3.9, -8), black)
	for _, side in { -1, 1 } do
		for _, depth in { -7.5, 7.5 } do
			cylinder(bus, "Wheel" .. side .. depth, 1, 2.8, busFrame * CFrame.new(side * 3.4, 1.4, depth), black, Enum.Material.Rubber)
			cylinder(bus, "Hub" .. side .. depth, 1.05, 1.1, busFrame * CFrame.new(side * 3.4, 1.4, depth), Color3.fromRGB(190, 194, 200), Enum.Material.Metal)
		end
		Geometry.Part(bus, "Headlight" .. side, Vector3.new(0.9, 0.7, 0.1), busFrame * CFrame.new(side * 2.6, 2.7, -12.62), Color3.fromRGB(255, 250, 220), Enum.Material.Neon)
		Geometry.Part(bus, "Taillight" .. side, Vector3.new(0.7, 0.9, 0.1), busFrame * CFrame.new(side * 3, 2.8, 12.05), Color3.fromRGB(230, 40, 40), Enum.Material.Neon)
	end
	for _, depth in { -12.7, 12.15 } do
		Geometry.Part(bus, "Bumper" .. depth, Vector3.new(7.9, 0.6, 0.35), busFrame * CFrame.new(0, 1.6, depth), black)
	end
	Geometry.Sign(bus, "BusName", busFrame * CFrame.new(0, 8.5, -10.2), "SCHOOL BUS", black, 5)
	return bus
end

-- Regulation-style hoop shared by every court: glass backboard with a target square,
-- orange ring (Segment parts, which the dunk code measures), net, bracket, arm and a pole
-- down to the floor. `rimFrame` sits at the logical rim, LookVector toward the court
-- (backboard behind at local +Z); `height` is floor-to-rim. Colors: Rim, Target, Metal,
-- Net, Pad, Backboard, BackboardTransparency.
function Props.Hoop(parent, rimFrame, height, colors)
	Geometry.Arc(parent, "VisibleRim", rimFrame, 1.35, 0, 2 * math.pi, 18, 0.18, 0.18, colors.Rim)
	local backboard = Geometry.Part(parent, "Backboard", Vector3.new(8, 4.5, 0.35), rimFrame * CFrame.new(0, 1.5, 1.9), colors.Backboard, Enum.Material.Glass)
	backboard.Transparency = colors.BackboardTransparency
	Geometry.Part(parent, "RimBracket", Vector3.new(0.5, 0.18, 1), rimFrame * CFrame.new(0, 0, 1.5), colors.Rim, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		Geometry.Part(parent, "TargetSide" .. side, Vector3.new(0.1, 1.6, 0.06), rimFrame * CFrame.new(side * 1.3, 1, 1.69), colors.Target)
	end
	for _, edge in { 0.2, 1.8 } do
		Geometry.Part(parent, "TargetEdge" .. edge, Vector3.new(2.7, 0.1, 0.06), rimFrame * CFrame.new(0, edge, 1.69), colors.Target)
	end
	for index = 1, 8 do
		local angle = math.pi * 2 * index / 8
		Geometry.Line(parent, "NetStrand" .. index,
			rimFrame:PointToWorldSpace(Vector3.new(math.cos(angle) * 1.25, -0.1, math.sin(angle) * 1.25)),
			rimFrame:PointToWorldSpace(Vector3.new(math.cos(angle) * 0.75, -1.8, math.sin(angle) * 0.75)), 0.04, 0.04, colors.Net)
	end
	-- Arm from the pole to the board, and the pole down to a floor plate with a pad.
	Geometry.Part(parent, "Support", Vector3.new(0.6, 0.6, 3.5), rimFrame * CFrame.new(0, 2, 3.2), colors.Metal, Enum.Material.Metal)
	Geometry.Part(parent, "Pole", Vector3.new(0.8, height + 2.5, 0.8), rimFrame * CFrame.new(0, (2.5 - height) / 2, 4.9), colors.Metal, Enum.Material.Metal)
	Geometry.Part(parent, "Base", Vector3.new(3, 0.3, 3), rimFrame * CFrame.new(0, -height + 0.15, 4.9), colors.Metal, Enum.Material.Metal)
	Geometry.Part(parent, "PolePad", Vector3.new(1.3, 4, 1.3), rimFrame * CFrame.new(0, -height + 2.3, 4.9), colors.Pad)
end

-- Small high-top sneaker; `frame` is the sole's center on the display surface, toe at -Z.
local function sneaker(parent, frame, color, colors)
	local shoe = Geometry.Folder(parent, "Sneaker")
	Geometry.Part(shoe, "Sole", Vector3.new(0.42, 0.12, 1), frame * CFrame.new(0, 0.06, 0), colors.Light)
	Geometry.Part(shoe, "Upper", Vector3.new(0.38, 0.3, 0.8), frame * CFrame.new(0, 0.27, 0.06), color)
	Geometry.Part(shoe, "Toe", Vector3.new(0.38, 0.18, 0.3), frame * CFrame.new(0, 0.21, -0.36), colors.Light)
	Geometry.Part(shoe, "Collar", Vector3.new(0.4, 0.34, 0.36), frame * CFrame.new(0, 0.55, 0.26), color)
	Geometry.Part(shoe, "Stripe", Vector3.new(0.4, 0.08, 0.5), frame * CFrame.new(0, 0.32, 0.02) * CFrame.Angles(math.rad(-18), 0, 0), colors.Yellow)
end

-- Neon "^" made of two bars in the station's wall plane.
local function chevron(parent, name, center: CFrame, color)
	for _, side in { -1, 1 } do
		Geometry.Part(parent, name .. (side < 0 and "L" or "R"), Vector3.new(0.3, 1.3, 0.12),
			center * CFrame.new(side * 0.42, 0, 0) * CFrame.Angles(0, 0, math.rad(side * 50)), color, Enum.Material.Neon)
	end
end

-- "Upgrade Lab" around the Training Upgrades station: glowing platform, back wall with a
-- level-up screen, stacked neon chevrons, a vertical-jump tester pole with colored vanes,
-- and two lit sneaker display cases.
function Props.UpgradeLab(parent, frame, title, colors)
	local lab = Geometry.Folder(parent, "UpgradeLab")
	Geometry.Part(lab, "Platform", Vector3.new(12.4, 0.3, 9.4), frame * CFrame.new(0, 0.15, 2.5), colors.Dark)
	Geometry.Part(lab, "TrimFront", Vector3.new(12.4, 0.08, 0.2), frame * CFrame.new(0, 0.32, -2.1), colors.Accent, Enum.Material.Neon)
	for _, side in { -1, 1 } do
		Geometry.Part(lab, "TrimSide" .. side, Vector3.new(0.2, 0.08, 9.4), frame * CFrame.new(side * 6.1, 0.32, 2.5), colors.Accent, Enum.Material.Neon)
	end

	-- Back wall, stripes and title.
	Geometry.Part(lab, "BackWall", Vector3.new(12.4, 8.4, 0.4), frame * CFrame.new(0, 4.2, 7.1), colors.Dark)
	for index, height in { 0.9, 6.2 } do
		Geometry.Part(lab, "WallStripe" .. index, Vector3.new(12.4, 0.3, 0.08), frame * CFrame.new(0, height, 6.88), colors.Accent)
	end
	Geometry.Sign(lab, "Title", frame * CFrame.new(0, 7.35, 6.75), title, colors.Accent, 10.5)

	-- Level-up screen.
	local screen = Geometry.Part(lab, "LevelScreen", Vector3.new(3.6, 3.8, 0.16), frame * CFrame.new(0, 3.5, 6.82), colors.Dark)
	local light = Instance.new("PointLight")
	light.Color = colors.Accent
	light.Brightness = 1.4
	light.Range = 12
	light.Parent = screen
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(360, 380)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = screen
	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(10, 16, 34)
	backdrop.Parent = gui
	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Size = UDim2.fromScale(0.9, 0.2)
	heading.Position = UDim2.fromScale(0.05, 0.04)
	heading.Font = Enum.Font.FredokaOne
	heading.Text = "LEVEL UP"
	heading.TextScaled = true
	heading.TextColor3 = colors.Yellow
	heading.Parent = backdrop
	for index = 1, 6 do
		local bar = Instance.new("Frame")
		local height = 0.1 + index * 0.085
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromScale(0.08 + (index - 1) * 0.145, 0.92)
		bar.Size = UDim2.fromScale(0.11, height)
		bar.BackgroundColor3 = colors.Accent:Lerp(colors.Yellow, (index - 1) / 5)
		bar.BorderSizePixel = 0
		bar.Parent = backdrop
	end

	-- Neon chevrons stacked on the left of the wall.
	for index = 1, 3 do
		chevron(lab, "Chevron" .. index, frame * CFrame.new(-4.2, 1.8 + index * 1.15, 6.84),
			colors.Accent:Lerp(colors.Yellow, (index - 1) / 2))
	end

	-- Vertical-jump tester: pole with colored vanes on the right.
	Geometry.Part(lab, "TesterBase", Vector3.new(1.8, 0.3, 1.8), frame * CFrame.new(4.6, 0.45, 5.2), colors.Metal, Enum.Material.Metal)
	Geometry.Part(lab, "TesterPole", Vector3.new(0.3, 9.2, 0.3), frame * CFrame.new(4.6, 4.9, 5.2), colors.Metal, Enum.Material.Metal)
	local vaneColors = { colors.Accent, colors.Light, colors.Yellow }
	for index = 0, 12 do
		Geometry.Part(lab, "Vane" .. index, Vector3.new(1.5, 0.06, 0.26),
			frame * CFrame.new(3.85, 5.1 + index * 0.3, 5.2), vaneColors[index % 3 + 1])
	end

	-- Lit sneaker display cases at the front corners.
	for index, side in { -1, 1 } do
		local base = frame * CFrame.new(side * 4.7, 0, 0.6)
		Geometry.Part(lab, "Pedestal" .. index, Vector3.new(1.5, 2.8, 1.5), base * CFrame.new(0, 1.7, 0), colors.Light)
		Geometry.Part(lab, "PedestalBand" .. index, Vector3.new(1.54, 0.2, 1.54), base * CFrame.new(0, 2.9, 0), colors.Accent, Enum.Material.Neon)
		local case = glass(Geometry.Part(lab, "Case" .. index, Vector3.new(1.3, 1.3, 1.3), base * CFrame.new(0, 3.75, 0), colors.Glass), 0.7)
		local caseLight = Instance.new("PointLight")
		caseLight.Brightness = 0.8
		caseLight.Range = 5
		caseLight.Color = colors.Light
		caseLight.Parent = case
		sneaker(lab, base * CFrame.new(0, 3.1, 0) * CFrame.Angles(0, math.rad(side * 35), 0),
			side < 0 and colors.Accent or colors.Yellow, colors)
	end
	return lab
end

return Props
