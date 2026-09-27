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
GYM.Accent = Colors.Blue
local LAB = table.clone(SHOP)
LAB.Accent = Colors.Lab

-- Crowd looks. Home side (-X) wears school blue/white, guest side (+X) orange/red.
local SKINS = {
	Color3.fromRGB(255, 219, 172), Color3.fromRGB(241, 194, 125), Color3.fromRGB(224, 172, 105),
	Color3.fromRGB(198, 134, 66), Color3.fromRGB(141, 85, 36), Color3.fromRGB(94, 56, 30),
}
local SHIRTS = {
	[-1] = { Color3.fromRGB(28, 112, 230), Color3.fromRGB(245, 247, 252), Color3.fromRGB(20, 60, 150), Color3.fromRGB(90, 170, 255) },
	[1] = { Color3.fromRGB(255, 128, 28), Color3.fromRGB(220, 50, 50), Color3.fromRGB(30, 30, 36), Color3.fromRGB(255, 196, 24) },
}
local PANTS = { Color3.fromRGB(46, 62, 110), Color3.fromRGB(34, 36, 44), Color3.fromRGB(150, 130, 100), Color3.fromRGB(90, 94, 104) }
local SHOES = { Color3.fromRGB(245, 245, 245), Color3.fromRGB(26, 26, 30), Color3.fromRGB(220, 50, 50), Color3.fromRGB(28, 112, 230) }
local HAIR = { Color3.fromRGB(30, 22, 16), Color3.fromRGB(88, 56, 30), Color3.fromRGB(196, 150, 80), Color3.fromRGB(140, 60, 30) }
local HATS = { "Cap", "BackwardsCap", "Beanie", "Headband", "ShortHair", "ShortHair", "Puff" }
local SEATED_POSES = { "Sit", "SitLean", "SitClap", "Sit" }

function Scenery.Gym(parent, context)
	local frame = context.Frame
	local function part(folder, name, size, offset, color, material, collide)
		return Geometry.Part(folder, name, size, frame * CFrame.new(offset), color, material, collide)
	end
	local court = Geometry.Folder(parent, "Court")
	part(court, "GymFloor", Vector3.new(Config.RoomWidth, 1, Config.RoomDepth), Vector3.new(0, -0.5, 0), Colors.Wood, Enum.Material.WoodPlanks, true)
	for index = 1, 20 do
		part(court, string.format("HardwoodStrip%02d", index), Vector3.new(3, 0.025, Config.CourtDepth),
			Vector3.new(-31.5 + index * 3, 0.015, 0), index % 2 == 0 and Colors.Wood or Colors.WoodLight, Enum.Material.WoodPlanks)
	end
	part(court, "Paint", Vector3.new(16, 0.03, 20), Vector3.new(0, 0.04, -42), Colors.Paint)
	local lines = Geometry.Folder(court, "Lines")
	local function line(name, first, last)
		Geometry.Line(lines, name, frame:PointToWorldSpace(first), frame:PointToWorldSpace(last), 0.24, 0.04, Colors.Lines)
	end
	line("Baseline", Vector3.new(-30, 0.085, -52), Vector3.new(30, 0.085, -52))
	line("Endline", Vector3.new(-30, 0.085, 52), Vector3.new(30, 0.085, 52))
	for _, side in { -1, 1 } do
		line("Sideline" .. side, Vector3.new(30 * side, 0.085, -52), Vector3.new(30 * side, 0.085, 52))
		line("Lane" .. side, Vector3.new(8 * side, 0.085, -52), Vector3.new(8 * side, 0.085, -32))
		line("CornerThree" .. side, Vector3.new(25 * side, 0.085, -52), Vector3.new(25 * side, 0.085, -45))
	end
	line("FreeThrow", Vector3.new(-8, 0.085, -32), Vector3.new(8, 0.085, -32))
	line("CenterLine", Vector3.new(-30, 0.085, 0), Vector3.new(30, 0.085, 0))
	Geometry.Arc(lines, "ThreePointArc", frame * CFrame.new(0, 0.085, -45), 25, math.pi, 2 * math.pi, 28, 0.24, 0.04, Colors.Lines)
	Geometry.Arc(lines, "FreeThrowCircle", frame * CFrame.new(0, 0.085, -32), 8, 0, math.pi * 2, 20, 0.24, 0.04, Colors.Lines)
	Geometry.Arc(lines, "CenterCircle", frame * CFrame.new(0, 0.085, 0), 7, 0, math.pi * 2, 20, 0.24, 0.04, Colors.Lines)
	local shell = Geometry.Folder(parent, "Building")
	for _, side in { -1, 1 } do
		part(shell, "SideWall" .. side, Vector3.new(1, Config.CeilingHeight, Config.RoomDepth),
			Vector3.new(side * Config.RoomWidth / 2, Config.CeilingHeight / 2, 0), Colors.Wall, Enum.Material.Concrete, true)
		part(shell, "WallStripe" .. side, Vector3.new(0.12, 4, Config.RoomDepth), Vector3.new(side * (Config.RoomWidth / 2 - 0.6), 9, 0), Colors.Blue)
	end
	part(shell, "BackWall", Vector3.new(Config.RoomWidth, Config.CeilingHeight, 1), Vector3.new(0, Config.CeilingHeight / 2, -70), Colors.Wall, Enum.Material.Concrete, true)
	for _, side in { -1, 1 } do
		part(shell, "EntranceWall" .. side, Vector3.new(45, Config.CeilingHeight, 1), Vector3.new(side * 32.5, Config.CeilingHeight / 2, 70), Colors.Wall, Enum.Material.Concrete, true)
	end
	part(shell, "DoorHeader", Vector3.new(20, Config.CeilingHeight - 12, 1), Vector3.new(0, (Config.CeilingHeight + 12) / 2, 70), Colors.Wall, Enum.Material.Concrete, false)
	part(shell, "EntranceLanding", Vector3.new(24, 1, 12), Vector3.new(0, -0.5, 75), Colors.Metal, Enum.Material.Concrete, true)
	part(shell, "Ceiling", Vector3.new(112, 1, 142), Vector3.new(0, Config.CeilingHeight, 0), Colors.Wall, Enum.Material.Metal, false)
	for index = 1, 5 do
		part(shell, "RoofBeam" .. index, Vector3.new(108, 2, 1.5), Vector3.new(0, Config.CeilingHeight - 2, -60 + index * 20), Colors.Metal, Enum.Material.Metal)
	end
	local seating = Geometry.Folder(parent, "Bleachers")
	for _, side in { -1, 1 } do
		for row = 1, 4 do
			part(seating, "Bench" .. side .. "Row" .. row, Vector3.new(3.5, 0.7, 58), Vector3.new(side * (33 + row * 4), row * 1.8, -4), Colors.Blue, Enum.Material.Metal, true)
			part(seating, "Riser" .. side .. "Row" .. row, Vector3.new(3.5, row * 1.8, 58), Vector3.new(side * (33 + row * 4), row * 0.9 - 0.35, -4), Colors.Metal, Enum.Material.Concrete, true)
		end
	end
	-- About 20 fans spread over both bleachers (deterministic, so rebuilds match).
	local crowd = Geometry.Folder(parent, "Crowd")
	local random = Random.new(Config.Crowd.Seed)
	for _, side in { -1, 1 } do
		local slots = {}
		for z = Config.Crowd.FirstZ, Config.Crowd.LastZ, Config.Crowd.Spacing do
			table.insert(slots, z)
		end
		for count = 1, Config.Crowd.PerSide do
			if #slots == 0 then break end
			local z = table.remove(slots, random:NextInteger(1, #slots)) + random:NextNumber(-0.8, 0.8)
			local row = random:NextInteger(1, 4)
			local benchX = side * (33 + row * 4)
			local seat = Vector3.new(benchX - side * 0.55, row * 1.8 + 0.35, z)
			local shirts = SHIRTS[side]
			local look = {
				Skin = SKINS[random:NextInteger(1, #SKINS)], Shirt = shirts[random:NextInteger(1, #shirts)],
				Pants = PANTS[random:NextInteger(1, #PANTS)], Shoes = SHOES[random:NextInteger(1, #SHOES)],
				LongSleeves = random:NextNumber() < 0.3, Hat = HATS[random:NextInteger(1, #HATS)],
				HatColor = shirts[random:NextInteger(1, #shirts)], HairColor = HAIR[random:NextInteger(1, #HAIR)],
			}
			if random:NextNumber() < Config.Crowd.FoamFingerChance then
				look.Prop, look.PropColor = "FoamFinger", shirts[1]
			end
			Crowd.Spectator(crowd, string.format("Fan%s%02d", side < 0 and "Home" or "Guest", count),
				CFrame.lookAt(frame * seat, frame * (seat - Vector3.new(side, 0, 0))),
				SEATED_POSES[random:NextInteger(1, #SEATED_POSES)], look)
		end
	end
	local details = Geometry.Folder(parent, "SchoolDetails")
	Geometry.Sign(details, "SchoolName", frame * CFrame.new(0, 29, -69.2), "DUNK HIGH", Colors.Blue, 28)
	Geometry.Sign(details, "Scoreboard", frame * CFrame.new(0, 23, -69.1), "HOME  00     GUEST  00", Colors.Dark, 24)
	Geometry.Sign(details, "ScoreboardClock", frame * CFrame.new(0, 20, -69.1), "08:00     PRACTICE", Colors.Dark, 18)
	for _, horizontal in { -36, -22, 22, 36 } do
		part(details, "Banner" .. horizontal, Vector3.new(7, 11, 0.15), Vector3.new(horizontal, 24, -69.2), Colors.Blue)
		Geometry.Sign(details, "BannerText" .. horizontal, frame * CFrame.new(horizontal, 24, -69), "DUNK\nHIGH", Colors.Blue, 6)
	end
	Geometry.Sign(details, "EntranceBrand", frame * CFrame.new(0, 14, 69.2), "DUNK HIGH  /  GYMNASIUM", Colors.Blue, 24)
	local lights = Geometry.Folder(parent, "Lights")
	for _, horizontal in { -22, 22 } do
		for _, depth in { -32, 28 } do
			local fixture = part(lights, "CourtLight" .. horizontal .. "_" .. depth, Vector3.new(8, 0.4, 3), Vector3.new(horizontal, 34, depth), Colors.Light, Enum.Material.Neon)
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Angle = 130
			light.Range = 60
			light.Brightness = 1.5
			light.Shadows = false
			light.Color = Colors.Light
			light.Parent = fixture
		end
	end
	-- Street outside the entrance for the return bus.
	local outside = Geometry.Folder(parent, "Exterior")
	part(outside, "Sidewalk", Vector3.new(90, 0.4, 6), Vector3.new(0, -0.2, 84), Colors.Concrete, Enum.Material.Concrete, true)
	part(outside, "Road", Vector3.new(220, 0.5, 16), Vector3.new(0, -0.45, 95), Colors.Road, Enum.Material.Asphalt, true)
	for index = -5, 5 do
		part(outside, "RoadDash" .. index, Vector3.new(8, 0.02, 0.3), Vector3.new(index * 20, -0.19, 95), Colors.Lines)
	end
	part(outside, "Lawn", Vector3.new(220, 0.4, 40), Vector3.new(0, -0.5, 123), Colors.Grass, Enum.Material.Grass, true)
	for _, side in { -1, 1 } do
		part(outside, "SideLawn" .. side, Vector3.new(65, 0.4, 18), Vector3.new(side * 77.5, -0.3, 78), Colors.Grass, Enum.Material.Grass, true)
	end
end

-- Shared regulation hoop; the gym's court runs toward +Z from the rim.
function Scenery.Hoop(parent, rim, height)
	Props.Hoop(parent, CFrame.lookAt(rim.Position, rim.Position + Vector3.zAxis), height, {
		Rim = Colors.Orange, Target = Colors.Blue, Metal = Colors.Metal, Net = Colors.Lines, Pad = Colors.Blue,
		Backboard = Colors.Backboard, BackboardTransparency = Colors.BackboardTransparency,
	})
end

function Scenery.UpgradeLab(parent, station, title)
	local frame = station.CFrame * CFrame.new(0, -station.Size.Y / 2, 0)
	Props.UpgradeLab(Geometry.Folder(parent, station.Name .. "Dressing"), frame, title, LAB)
end

function Scenery.Shop(parent, station)
	Props.BallShop(parent, station.CFrame * CFrame.new(0, -station.Size.Y / 2, 0), SHOP)
end

function Scenery.Gymnasium(parent, station)
	Props.LegGym(parent, station.CFrame * CFrame.new(0, -station.Size.Y / 2, 0), GYM)
end

-- Bus stop around a travel station (which faces the road) plus a school bus parked at the
-- curb with its door beside the stop. The bus faces along the road.
function Scenery.TransitStop(parent, station, text, busDistance, roadDrop)
	local frame = station.CFrame * CFrame.new(0, -station.Size.Y / 2, 0)
	Props.BusStop(parent, frame, text, SHOP)
	local roadward = Vector3.new(frame.LookVector.X, 0, frame.LookVector.Z).Unit
	local along = Vector3.new(frame.RightVector.X, 0, frame.RightVector.Z).Unit
	local center = frame.Position + roadward * busDistance - along * 8 - Vector3.new(0, roadDrop, 0)
	Props.SchoolBus(parent, CFrame.lookAt(center, center + along), SHOP)
end

return Scenery
