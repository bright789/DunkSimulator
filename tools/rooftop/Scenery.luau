-- Skyline Rooftop scenery (edit-mode builder). Everything here is anchored decoration; only
-- the roof deck, parapet, glass rail, bleachers and the invisible edge walls collide. The sky
-- is open, so a max-Vertical jump never hits anything; the edge walls are taller than that
-- jump (Build.Run checks it) so nobody drifts off the building.
local Geometry = require(script.Parent.Geometry)
local Props = require(script.Parent.Props)
local Crowd = require(script.Parent.Crowd)
local Config = require(script.Parent.Config)
local Colors = Config.Colors
local Scenery = {}

-- Palettes handed to the shared props.
local SHOP = { Wood = Colors.Wood, Accent = Colors.Orange, Light = Colors.Light, Metal = Colors.Metal, Dark = Colors.Dark,
	Rubber = Colors.Rubber, Glass = Colors.Glass, Yellow = Colors.Yellow }
local GYM = table.clone(SHOP)
GYM.Accent = Colors.Magenta
local LAB = table.clone(SHOP)
LAB.Accent = Colors.Lab
local TRANSIT = table.clone(SHOP)
TRANSIT.Accent = Colors.Cyan
local BOARD = table.clone(SHOP)
BOARD.Accent = Colors.Cyan

-- Night crowd looks.
local SKINS = {
	Color3.fromRGB(255, 219, 172), Color3.fromRGB(241, 194, 125), Color3.fromRGB(224, 172, 105),
	Color3.fromRGB(198, 134, 66), Color3.fromRGB(141, 85, 36), Color3.fromRGB(94, 56, 30),
}
local SHIRTS = { Colors.Magenta, Colors.Cyan, Color3.fromRGB(30, 30, 36), Color3.fromRGB(245, 247, 252), Colors.Gold }
local PANTS = { Color3.fromRGB(46, 62, 110), Color3.fromRGB(34, 36, 44), Color3.fromRGB(90, 94, 104) }
local SHOES = { Color3.fromRGB(245, 245, 245), Color3.fromRGB(26, 26, 30), Colors.Cyan, Colors.Magenta }
local HAIR = { Color3.fromRGB(30, 22, 16), Color3.fromRGB(88, 56, 30), Color3.fromRGB(196, 150, 80), Color3.fromRGB(140, 60, 30) }
local HATS = { "Cap", "BackwardsCap", "Beanie", "Headband", "ShortHair", "ShortHair", "Puff" }
local SEATED_POSES = { "Sit", "SitLean", "SitClap", "Sit" }

function Scenery.Roof(parent, context)
	local frame = context.Frame
	local function part(folder, name, size, offset, color, material, collide)
		return Geometry.Part(folder, name, size, frame * CFrame.new(offset), color, material, collide)
	end
	local halfW, halfD = Config.RoofWidth / 2, Config.RoofDepth / 2

	-- Roof deck and a teal sport court with magenta paint.
	local court = Geometry.Folder(parent, "Court")
	part(court, "RoofDeck", Vector3.new(Config.RoofWidth, 1, Config.RoofDepth), Vector3.new(0, -0.5, 0), Colors.Roof, Enum.Material.Concrete, true)
	part(court, "Apron", Vector3.new(Config.CourtWidth + 10, 0.05, Config.CourtDepth + 10), Vector3.new(0, 0.02, 0), Colors.CourtLight, Enum.Material.SmoothPlastic)
	part(court, "CourtSurface", Vector3.new(Config.CourtWidth, 0.05, Config.CourtDepth), Vector3.new(0, 0.04, 0), Colors.Court, Enum.Material.SmoothPlastic)
	local lines = Geometry.Folder(court, "Lines")
	local function line(name, first, last)
		Geometry.Line(lines, name, frame:PointToWorldSpace(first), frame:PointToWorldSpace(last), 0.24, 0.04, Colors.Lines)
	end
	local baseline = Config.CourtDepth / 2
	line("Baseline", Vector3.new(-30, 0.085, -baseline), Vector3.new(30, 0.085, -baseline))
	line("Endline", Vector3.new(-30, 0.085, baseline), Vector3.new(30, 0.085, baseline))
	line("CenterLine", Vector3.new(-30, 0.085, 0), Vector3.new(30, 0.085, 0))
	for _, side in { -1, 1 } do
		line("Sideline" .. side, Vector3.new(30 * side, 0.085, -baseline), Vector3.new(30 * side, 0.085, baseline))
	end
	for _, endSign in { -1, 1 } do
		local tag = endSign < 0 and "Home" or "Away"
		part(court, "Paint" .. tag, Vector3.new(16, 0.03, 20), Vector3.new(0, 0.06, endSign * (baseline - 10)), Colors.Paint)
		for _, side in { -1, 1 } do
			line("Lane" .. tag .. side, Vector3.new(8 * side, 0.085, endSign * baseline), Vector3.new(8 * side, 0.085, endSign * (baseline - 20)))
			line("CornerThree" .. tag .. side, Vector3.new(25 * side, 0.085, endSign * baseline), Vector3.new(25 * side, 0.085, endSign * (baseline - 7)))
		end
		line("FreeThrow" .. tag, Vector3.new(-8, 0.085, endSign * (baseline - 20)), Vector3.new(8, 0.085, endSign * (baseline - 20)))
		local start = endSign < 0 and math.pi or 0
		Geometry.Arc(lines, "ThreePointArc" .. tag, frame * CFrame.new(0, 0.085, endSign * (baseline - 7)), 25, start, start + math.pi, 28, 0.24, 0.04, Colors.Lines)
		Geometry.Arc(lines, "FreeThrowCircle" .. tag, frame * CFrame.new(0, 0.085, endSign * (baseline - 20)), 8, 0, math.pi * 2, 20, 0.24, 0.04, Colors.Lines)
	end
	Geometry.Arc(lines, "CenterCircle", frame * CFrame.new(0, 0.085, 0), 8, 0, math.pi * 2, 22, 0.24, 0.04, Colors.Lines)
	local logoText = part(court, "CenterLogoText", Vector3.new(14, 0.02, 4), Vector3.new(0, 0.09, 0), Colors.Magenta)
	logoText.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(700, 200)
	gui.LightInfluence = 0.2
	gui.Parent = logoText
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.Text = "SKYLINE"
	text.TextScaled = true
	text.TextColor3 = Colors.Magenta
	text.Rotation = 180
	text.Parent = gui

	-- Parapet with a neon cap and a glass rail on top; invisible walls reach far above any
	-- jump so nobody can drift off the building.
	local edge = Geometry.Folder(parent, "Edge")
	local walls = {
		{ "North", Vector3.new(Config.RoofWidth + 3, 0, 1.5), Vector3.new(0, 0, -halfD - 0.75) },
		{ "South", Vector3.new(Config.RoofWidth + 3, 0, 1.5), Vector3.new(0, 0, halfD + 0.75) },
		{ "West", Vector3.new(1.5, 0, Config.RoofDepth), Vector3.new(-halfW - 0.75, 0, 0) },
		{ "East", Vector3.new(1.5, 0, Config.RoofDepth), Vector3.new(halfW + 0.75, 0, 0) },
	}
	for _, wall in walls do
		local name, size, offset = wall[1], wall[2], wall[3]
		part(edge, "Parapet" .. name, size + Vector3.new(0, 3.5, 0), offset + Vector3.new(0, 1.75, 0), Colors.Parapet, Enum.Material.Concrete, true)
		part(edge, "ParapetGlow" .. name, size + Vector3.new(0.1, 0.35, 0.1), offset + Vector3.new(0, 3.6, 0), Colors.Cyan, Enum.Material.Neon)
		local rail = part(edge, "GlassRail" .. name, size + Vector3.new(0, 3, 0) - Vector3.new(size.X > 2 and 0 or 1.2, 0, size.Z > 2 and 0 or 1.2),
			offset + Vector3.new(0, 5.3, 0), Colors.Glass, Enum.Material.Glass, true)
		rail.Transparency = 0.6
		local barrier = part(edge, "Barrier" .. name, size + Vector3.new(0, Config.BarrierHeight, 0), offset + Vector3.new(0, Config.BarrierHeight / 2, 0),
			Colors.Glass, Enum.Material.SmoothPlastic, true)
		barrier.Transparency = 1
		barrier.CanQuery = false
		barrier.CastShadow = false
		-- Locked so a click or drag in Studio's 3D view can't grab and move it (an invisible
		-- wall dragged onto the court blocked players on 2026-09-27).
		barrier.Locked = true
	end

	-- The skyscraper under the roof, with lit window bands fading into the night haze.
	local tower = Geometry.Folder(parent, "Skyscraper")
	part(tower, "Body", Vector3.new(Config.RoofWidth + 4, Config.TowerDepth, Config.RoofDepth + 4), Vector3.new(0, -Config.TowerDepth / 2 - 1, 0), Colors.Tower, Enum.Material.Glass)
	for index = 1, math.floor(Config.TowerDepth / 16) - 1 do
		local y = -6 - index * 16
		part(tower, "WindowBand" .. index, Vector3.new(Config.RoofWidth + 4.4, 1.4, Config.RoofDepth + 4.4), Vector3.new(0, y, 0),
			index % 5 == 0 and Colors.Cyan or Colors.Warm, Enum.Material.Neon)
	end
	part(tower, "Crown", Vector3.new(Config.RoofWidth + 5, 0.6, Config.RoofDepth + 5), Vector3.new(0, -1.4, 0), Colors.Magenta, Enum.Material.Neon)

	-- Height gates: a neon bar over the back of the court at the height your feet reach at the
	-- jump's peak with that much Vertical, strung between two antenna masts.
	local gates = Geometry.Folder(parent, "VerticalGates")
	local top = context.Marks[#context.Marks].Height + 30
	for _, side in { -1, 1 } do
		local x = side * 60
		part(gates, "Mast" .. side, Vector3.new(1.6, top, 1.6), Vector3.new(x, top / 2, -halfD + 6), Colors.Metal, Enum.Material.Metal)
		for index = 1, math.floor(top / 100) do
			part(gates, "MastLight" .. side .. "_" .. index, Vector3.new(2.2, 1.2, 2.2), Vector3.new(x, index * 100, -halfD + 6), Colors.Red, Enum.Material.Neon)
		end
		part(gates, "MastTop" .. side, Vector3.new(2.6, 2.6, 2.6), Vector3.new(x, top + 1.3, -halfD + 6), Colors.Red, Enum.Material.Neon)
	end
	for index, mark in context.Marks do
		local color = index == #context.Marks and Colors.Gold or (index % 2 == 0 and Colors.Magenta or Colors.Cyan)
		part(gates, "Gate" .. mark.Vertical, Vector3.new(118, 1, 1), Vector3.new(0, mark.Height, -halfD + 6), color, Enum.Material.Neon)
		for _, side in { -1, 1 } do
			Geometry.Panel(gates, "Label" .. mark.Vertical .. "_" .. side, Vector3.new(26, 7, 0.3), frame * CFrame.new(side * 44, mark.Height + 4.5, -halfD + 6),
				Colors.Dark, string.format("%d VERTICAL", mark.Vertical), color, Enum.NormalId.Back)
		end
	end

	-- Big sign on a frame behind the hoop, facing the court.
	local sign = Geometry.Folder(parent, "SkylineSign")
	Geometry.Panel(sign, "Sign", Vector3.new(84, 16, 0.5), frame * CFrame.new(0, 44, -halfD + 3), Colors.Dark, "SKYLINE ROOFTOP", Colors.Magenta, Enum.NormalId.Back)
	part(sign, "SignGlowTop", Vector3.new(86, 0.6, 0.6), Vector3.new(0, 52.3, -halfD + 3.2), Colors.Cyan, Enum.Material.Neon)
	part(sign, "SignGlowBottom", Vector3.new(86, 0.6, 0.6), Vector3.new(0, 35.7, -halfD + 3.2), Colors.Cyan, Enum.Material.Neon)
	for _, x in { -30, 30 } do
		part(sign, "SignLeg" .. x, Vector3.new(1.2, 36, 1.2), Vector3.new(x, 18, -halfD + 3.8), Colors.Metal, Enum.Material.Metal)
	end

	-- Flood lights at the court corners aimed at center court.
	local lights = Geometry.Folder(parent, "FloodLights")
	local flood = Config.FloodLights
	for _, corner in { Vector3.new(-40, 0, -58), Vector3.new(40, 0, -58), Vector3.new(-40, 0, 58), Vector3.new(40, 0, 58) } do
		local tag = string.format("%d_%d", corner.X, corner.Z)
		part(lights, "Pole" .. tag, Vector3.new(0.9, flood.Height, 0.9), corner + Vector3.new(0, flood.Height / 2, 0), Colors.Metal, Enum.Material.Metal)
		local headPosition = frame * (corner + Vector3.new(0, flood.Height, 0))
		local head = Geometry.Part(lights, "Lamp" .. tag, Vector3.new(7, 3, 1), CFrame.lookAt(headPosition, frame * Vector3.new(0, 0, 0)), Colors.Light, Enum.Material.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Angle = 75
		light.Brightness = flood.Brightness
		light.Range = flood.Range
		light.Color = Colors.Light
		light.Shadows = true
		light.Parent = head
	end

	-- Short bleachers on both sidelines with a neon ribbon, and a small night crowd.
	local stands = Geometry.Folder(parent, "Stands")
	local cfg = Config.Stands
	for _, side in { -1, 1 } do
		for row = 1, cfg.Rows do
			local x = side * (cfg.FirstX + (row - 1) * cfg.RowStep)
			part(stands, "Bench" .. side .. "Row" .. row, Vector3.new(cfg.RowStep - 0.4, 0.7, cfg.Length), Vector3.new(x, row * cfg.RowRise, 0),
				row % 2 == 0 and Colors.Magenta or Colors.Metal, Enum.Material.Metal, true)
			part(stands, "Riser" .. side .. "Row" .. row, Vector3.new(cfg.RowStep - 0.4, row * cfg.RowRise, cfg.Length),
				Vector3.new(x, row * cfg.RowRise / 2 - 0.35, 0), Colors.RoofDark, Enum.Material.Concrete, true)
		end
		part(stands, "Ribbon" .. side, Vector3.new(0.3, 0.8, cfg.Length), Vector3.new(side * (cfg.FirstX - cfg.RowStep / 2 - 0.1), 0.9, 0), Colors.Cyan, Enum.Material.Neon)
	end
	local crowd = Geometry.Folder(parent, "Crowd")
	local random = Random.new(Config.Crowd.Seed)
	for _, side in { -1, 1 } do
		local free = {}
		for z = Config.Crowd.FirstZ, Config.Crowd.LastZ, Config.Crowd.Spacing do table.insert(free, z) end
		for count = 1, Config.Crowd.PerSide do
			if #free == 0 then break end
			local z = table.remove(free, random:NextInteger(1, #free)) + random:NextNumber(-0.8, 0.8)
			local row = random:NextInteger(1, cfg.Rows)
			local benchX = side * (cfg.FirstX + (row - 1) * cfg.RowStep)
			local seat = Vector3.new(benchX - side * 0.55, row * cfg.RowRise + 0.35, z)
			local look = {
				Skin = SKINS[random:NextInteger(1, #SKINS)], Shirt = SHIRTS[random:NextInteger(1, #SHIRTS)],
				Pants = PANTS[random:NextInteger(1, #PANTS)], Shoes = SHOES[random:NextInteger(1, #SHOES)],
				LongSleeves = random:NextNumber() < 0.5, Hat = HATS[random:NextInteger(1, #HATS)],
				HatColor = SHIRTS[random:NextInteger(1, #SHIRTS)], HairColor = HAIR[random:NextInteger(1, #HAIR)],
			}
			if random:NextNumber() < Config.Crowd.FoamFingerChance then
				look.Prop, look.PropColor = "FoamFinger", Colors.Magenta
			end
			Crowd.Spectator(crowd, string.format("Fan%s%02d", side < 0 and "West" or "East", count),
				CFrame.lookAt(frame * seat, frame * (seat - Vector3.new(side, 0, 0))), SEATED_POSES[random:NextInteger(1, #SEATED_POSES)], look)
		end
	end

	-- Rooftop clutter: a water tower and AC units near the back corners.
	local clutter = Geometry.Folder(parent, "RoofProps")
	local tank = part(clutter, "WaterTank", Vector3.new(14, 12, 12), Vector3.new(58, 17, -62), Colors.Wood, Enum.Material.WoodPlanks)
	tank.Shape = Enum.PartType.Cylinder
	tank.CFrame = frame * CFrame.new(58, 17, -62) * CFrame.Angles(0, 0, math.rad(90))
	part(clutter, "WaterTankRoof", Vector3.new(13, 1, 13), Vector3.new(58, 23.5, -62), Colors.RoofDark, Enum.Material.Metal)
	for _, leg in { Vector3.new(-4, 0, -4), Vector3.new(4, 0, -4), Vector3.new(-4, 0, 4), Vector3.new(4, 0, 4) } do
		part(clutter, "WaterTankLeg" .. leg.X .. leg.Z, Vector3.new(0.8, 11, 0.8), Vector3.new(58, 5.5, -62) + leg, Colors.Metal, Enum.Material.Metal)
	end
	for index, spot in { Vector3.new(62, 2, -30), Vector3.new(62, 2, -12), Vector3.new(-62, 2, -30) } do
		part(clutter, "ACUnit" .. index, Vector3.new(10, 4, 8), spot, Colors.Metal, Enum.Material.DiamondPlate, true)
		part(clutter, "ACFan" .. index, Vector3.new(5, 0.3, 5), spot + Vector3.new(0, 2.1, 0), Colors.RoofDark, Enum.Material.Metal)
	end

	-- Global leaderboards behind the hoop (left of it), facing the court.
	local boardSpot = Config.Leaderboard
	Props.Leaderboards(Geometry.Folder(parent, "LeaderboardArea"),
		CFrame.lookAt(frame * boardSpot, frame * (boardSpot + Vector3.zAxis)), BOARD)

	-- The skyline: a ring of towers below and around the roof. Most sit lower so the roof
	-- feels high; a few rise above it. Deterministic from City.Seed.
	local city = Geometry.Folder(parent, "Skyline")
	local cityRandom = Random.new(Config.City.Seed)
	local bandColors = { Colors.Warm, Colors.Warm, Colors.Warm, Colors.Warm, Colors.Cyan, Colors.Cyan, Colors.Magenta }
	local bodyColors = { Colors.Tower, Colors.TowerLight, Color3.fromRGB(30, 36, 64), Color3.fromRGB(44, 40, 70) }
	for index = 1, Config.City.Buildings do
		local angle = (index / Config.City.Buildings) * math.pi * 2 + cityRandom:NextNumber(-0.06, 0.06)
		local radius = cityRandom:NextNumber(Config.City.InnerRadius, Config.City.OuterRadius)
		local width, depth = cityRandom:NextNumber(40, 90), cityRandom:NextNumber(40, 90)
		local tall = cityRandom:NextNumber() < 0.22
		local topY = tall and cityRandom:NextNumber(40, 220) or cityRandom:NextNumber(-260, -30)
		local height = topY - Config.City.BaseY
		local base = frame * CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local yaw = CFrame.Angles(0, cityRandom:NextNumber(0, math.pi), 0)
		local center = base * CFrame.new(0, Config.City.BaseY + height / 2, 0) * yaw
		Geometry.Part(city, "Tower" .. index, Vector3.new(width, height, depth), center, bodyColors[cityRandom:NextInteger(1, #bodyColors)], Enum.Material.Glass)
		local bands = math.min(4, math.floor(height / 60))
		for band = 1, bands do
			local y = topY - 8 - (band - 1) * (height * 0.5 / bands)
			Geometry.Part(city, "Tower" .. index .. "Band" .. band, Vector3.new(width + 0.4, 1.2, depth + 0.4),
				base * CFrame.new(0, y, 0) * yaw, bandColors[cityRandom:NextInteger(1, #bandColors)], Enum.Material.Neon)
		end
		if tall then
			Geometry.Part(city, "Tower" .. index .. "Beacon", Vector3.new(2.5, 2.5, 2.5), base * CFrame.new(0, topY + 1.25, 0), Colors.Red, Enum.Material.Neon)
		end
	end
end

function Scenery.Hoop(parent, rim, height)
	Props.Hoop(parent, CFrame.lookAt(rim.Position, rim.Position + Vector3.zAxis), height, {
		Rim = Colors.Orange, Target = Colors.Magenta, Metal = Colors.Metal, Net = Colors.Lines, Pad = Colors.Magenta,
		Backboard = Colors.Backboard, BackboardTransparency = Colors.BackboardTransparency,
	})
end

local function floorFrame(station)
	return station.CFrame * CFrame.new(0, -station.Size.Y / 2, 0)
end

function Scenery.Stations(parent, trainer, pickup, upgrade)
	Props.LegGym(Geometry.Folder(parent, "TrainerGym"), floorFrame(trainer), GYM)
	Props.BallShop(Geometry.Folder(parent, "PickupShop"), floorFrame(pickup), SHOP)
	Props.UpgradeLab(Geometry.Folder(parent, "UpgradeStationDressing"), floorFrame(upgrade), "TRAINING UPGRADES", LAB)
end

-- Elevator lobby behind the return station (the station faces the court).
function Scenery.Elevator(parent, station, text)
	local frame = floorFrame(station)
	local function part(name, size, offset, color, material, collide)
		return Geometry.Part(parent, name, size, frame * CFrame.new(offset), color, material, collide)
	end
	part("Shaft", Vector3.new(12, 16, 7), Vector3.new(0, 8, 5.5), Colors.RoofDark, Enum.Material.Concrete, true)
	part("ShaftCap", Vector3.new(12.6, 0.6, 7.6), Vector3.new(0, 16.3, 5.5), Colors.Cyan, Enum.Material.Neon)
	for _, side in { -1, 1 } do
		part("Door" .. side, Vector3.new(2.7, 9, 0.3), Vector3.new(side * 1.4, 4.5, 1.9), Colors.Metal, Enum.Material.Metal)
		part("DoorFrame" .. side, Vector3.new(0.4, 9.6, 0.4), Vector3.new(side * 3, 4.8, 1.85), Colors.Cyan, Enum.Material.Neon)
	end
	part("DoorFrameTop", Vector3.new(6.4, 0.4, 0.4), Vector3.new(0, 9.6, 1.85), Colors.Cyan, Enum.Material.Neon)
	Geometry.Panel(parent, "ElevatorSign", Vector3.new(10, 2.6, 0.3), frame * CFrame.new(0, 12.2, 1.85), Colors.Dark, "ELEVATOR", Colors.Cyan, Enum.NormalId.Front)
	Geometry.Panel(parent, "Destination", Vector3.new(8, 1.6, 0.3), frame * CFrame.new(0, 14.4, 1.85), Colors.Dark, text, Colors.Gold, Enum.NormalId.Front)
end

function Scenery.TransitStop(parent, station, text)
	Props.TransitStop(parent, station, text, Config.Transit.BusDistance, Config.Transit.RoadDrop, TRANSIT)
end

return Scenery
