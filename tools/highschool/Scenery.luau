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
local SHOP_BOARD = table.clone(SHOP)
SHOP_BOARD.Accent = Colors.Yellow

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
	local halfW, height = Config.RoomWidth / 2, Config.CeilingHeight
	local backZ, frontZ = Config.BackZ, Config.FrontZ
	local depth, midZ = frontZ - backZ, (frontZ + backZ) / 2
	local court = Geometry.Folder(parent, "Court")
	part(court, "GymFloor", Vector3.new(Config.RoomWidth, 1, depth), Vector3.new(0, -0.5, midZ), Colors.Wood, Enum.Material.WoodPlanks, true)
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
	-- Shell: tall walls so even a max-Vertical jump stays indoors. Only the walls, floor and
	-- landing collide; the door header, roof, trusses and everything overhead never do.
	local shell = Geometry.Folder(parent, "Building")
	for _, side in { -1, 1 } do
		part(shell, "SideWall" .. side, Vector3.new(1, height, depth), Vector3.new(side * halfW, height / 2, midZ), Colors.Wall, Enum.Material.Concrete, true)
		part(shell, "WallStripe" .. side, Vector3.new(0.12, 4, depth), Vector3.new(side * (halfW - 0.6), 9, midZ), Colors.Blue)
	end
	part(shell, "BackWall", Vector3.new(Config.RoomWidth, height, 1), Vector3.new(0, height / 2, backZ), Colors.Wall, Enum.Material.Concrete, true)
	for _, side in { -1, 1 } do
		part(shell, "EntranceWall" .. side, Vector3.new(halfW - 10, height, 1), Vector3.new(side * (10 + (halfW - 10) / 2), height / 2, frontZ), Colors.Wall, Enum.Material.Concrete, true)
	end
	part(shell, "DoorHeader", Vector3.new(20, height - 12, 1), Vector3.new(0, (height + 12) / 2, frontZ), Colors.Wall, Enum.Material.Concrete, false)
	part(shell, "EntranceLanding", Vector3.new(24, 1, 12), Vector3.new(0, -0.5, frontZ + 5), Colors.Metal, Enum.Material.Concrete, true)
	part(shell, "Ceiling", Vector3.new(Config.RoomWidth + 2, 1, depth + 2), Vector3.new(0, height, midZ), Colors.Wall, Enum.Material.Metal, false)
	-- Roof trusses: top chord, bottom chord and three struts each.
	local roof = Geometry.Folder(shell, "Trusses")
	for index = 1, 7 do
		local z = backZ + index * depth / 8
		part(roof, "TopChord" .. index, Vector3.new(Config.RoomWidth - 2, 2, 1.5), Vector3.new(0, height - 2, z), Colors.Metal, Enum.Material.Metal)
		part(roof, "BottomChord" .. index, Vector3.new(Config.RoomWidth - 2, 1.2, 1.2), Vector3.new(0, height - 12, z), Colors.Metal, Enum.Material.Metal)
		for _, x in { -40, 0, 40 } do
			part(roof, "Strut" .. index .. "_" .. x, Vector3.new(0.8, 10, 0.8), Vector3.new(x, height - 7, z), Colors.Metal, Enum.Material.Metal)
		end
	end

	-- Running-track balcony along both side walls, above and behind the bleachers.
	local balcony = Geometry.Folder(parent, "Balcony")
	local track = Config.Balcony
	for _, side in { -1, 1 } do
		local center = side * (halfW - track.Width / 2)
		local edge = side * (halfW - track.Width)
		part(balcony, "Deck" .. side, Vector3.new(track.Width, 1.2, depth - 2), Vector3.new(center, track.Height, midZ), Colors.Metal, Enum.Material.Concrete)
		part(balcony, "Track" .. side, Vector3.new(track.Width - 1.5, 0.1, depth - 4), Vector3.new(center + side * 0.5, track.Height + 0.65, midZ), Color3.fromRGB(196, 78, 64))
		for _, lane in { -1.6, 1.6 } do
			part(balcony, "Lane" .. side .. "_" .. lane, Vector3.new(0.15, 0.02, depth - 4), Vector3.new(center + side * 0.5 + lane, track.Height + 0.71, midZ), Colors.Lines)
		end
		part(balcony, "Fascia" .. side, Vector3.new(0.3, 1.2, depth - 2), Vector3.new(edge, track.Height, midZ), Colors.Blue, Enum.Material.Neon)
		local glass = part(balcony, "GlassRail" .. side, Vector3.new(0.2, 3.4, depth - 2), Vector3.new(edge + side * 0.25, track.Height + 2.3, midZ), Colors.Glass, Enum.Material.Glass)
		glass.Transparency = 0.5
		part(balcony, "TopRail" .. side, Vector3.new(0.4, 0.3, depth - 2), Vector3.new(edge + side * 0.25, track.Height + 4.1, midZ), Colors.Metal, Enum.Material.Metal)
		-- Support columns stand on the floor behind the bleachers, so they may collide.
		for index = 0, 4 do
			part(balcony, "Column" .. side .. "_" .. index, Vector3.new(0.9, track.Height, 0.9),
				Vector3.new(edge + side * 0.6, track.Height / 2, backZ + 14 + index * (depth - 28) / 4), Colors.Metal, Enum.Material.Metal, true)
		end
	end

	-- High clerestory windows glowing with daylight.
	local windows = Geometry.Folder(parent, "Windows")
	for _, side in { -1, 1 } do
		local x = side * (halfW - 0.6)
		for index = 1, 6 do
			local z = backZ + 18 + (index - 1) * (depth - 36) / 5
			local pane = part(windows, "Window" .. side .. "_" .. index, Vector3.new(0.2, 34, 14), Vector3.new(x, 88, z), Color3.fromRGB(210, 232, 255), Enum.Material.Neon)
			pane.Transparency = 0.35
			part(windows, "MullionV" .. side .. "_" .. index, Vector3.new(0.3, 34, 0.5), Vector3.new(x - side * 0.1, 88, z), Colors.Metal, Enum.Material.Metal)
			part(windows, "MullionH" .. side .. "_" .. index, Vector3.new(0.3, 0.5, 14), Vector3.new(x - side * 0.1, 88, z), Colors.Metal, Enum.Material.Metal)
		end
		for _, y in { 70, 106 } do
			part(windows, "Band" .. side .. "_" .. y, Vector3.new(0.4, 1, depth - 6), Vector3.new(side * (halfW - 0.7), y, midZ), Colors.Blue, Enum.Material.Metal)
		end
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
	Geometry.Sign(details, "SchoolName", frame * CFrame.new(0, 29, backZ + 0.8), "DUNK HIGH", Colors.Blue, 28)
	Geometry.Sign(details, "Scoreboard", frame * CFrame.new(0, 23, backZ + 0.9), "HOME  00     GUEST  00", Colors.Dark, 24)
	Geometry.Sign(details, "ScoreboardClock", frame * CFrame.new(0, 20, backZ + 0.9), "08:00     PRACTICE", Colors.Dark, 18)
	for _, horizontal in { -36, -22, 22, 36 } do
		part(details, "Banner" .. horizontal, Vector3.new(7, 11, 0.15), Vector3.new(horizontal, 24, backZ + 0.8), Colors.Blue)
		Geometry.Sign(details, "BannerText" .. horizontal, frame * CFrame.new(horizontal, 24, backZ + 1), "DUNK\nHIGH", Colors.Blue, 6)
	end
	Geometry.Sign(details, "EntranceBrand", frame * CFrame.new(0, 14, frontZ - 0.8), "DUNK HIGH  /  GYMNASIUM", Colors.Blue, 24)
	Geometry.Panel(details, "Motto", Vector3.new(46, 12, 0.3), frame * CFrame.new(0, 128, backZ + 0.75), Colors.Blue,
		"HOME OF THE\nHIGH FLYERS", Colors.Lines, Enum.NormalId.Back)
	-- Championship banners on the side walls, between the balcony and the windows.
	local titles = { "STATE\nCHAMPS\n2019", "DISTRICT\nCHAMPS\n2021", "STATE\nCHAMPS\n2023", "DUNK\nCONTEST\nKINGS", "UNDEFEATED\n2024" }
	for _, side in { -1, 1 } do
		for index, title in titles do
			local z = backZ + 24 + (index - 1) * (depth - 48) / 4
			local gold = (index + (side > 0 and 1 or 0)) % 2 == 0
			Geometry.Panel(details, "Pennant" .. side .. "_" .. index, Vector3.new(0.2, 13, 8), frame * CFrame.new(side * (halfW - 0.7), 50, z),
				gold and Colors.Yellow or Colors.Blue, title, gold and Colors.Dark or Colors.Lines, side < 0 and Enum.NormalId.Right or Enum.NormalId.Left)
		end
	end

	-- Vertical meter on the back wall: each line sits where your feet reach at the jump's
	-- peak with that much Vertical (from ProgressionConfig, measured by Build.Run).
	local meter = Geometry.Folder(parent, "VerticalMeter")
	for _, mark in context.Marks do
		part(meter, "Line" .. mark.Vertical, Vector3.new(2 * (halfW - 12), 0.35, 0.15), Vector3.new(0, mark.Height, backZ + 0.62), Colors.Yellow, Enum.Material.Neon)
		for _, side in { -1, 1 } do
			Geometry.Panel(meter, "Label" .. mark.Vertical .. "_" .. side, Vector3.new(14, 4, 0.2), frame * CFrame.new(side * (halfW - 20), mark.Height + 2.4, backZ + 0.75),
				Colors.Dark, string.format("%d VERTICAL", mark.Vertical), Colors.Yellow, Enum.NormalId.Back)
		end
	end

	-- Court lights hung from the roof trusses on cables.
	local lights = Geometry.Folder(parent, "Lights")
	local lightY = Config.LightHeight
	local cableLength = height - 12 - lightY
	for _, horizontal in { -24, 24 } do
		for _, z in { -40, -6, 28 } do
			local fixture = part(lights, "CourtLight" .. horizontal .. "_" .. z, Vector3.new(8, 0.4, 3), Vector3.new(horizontal, lightY, z), Colors.Light, Enum.Material.Neon)
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Angle = 130
			light.Range = 60
			light.Brightness = 1.5
			light.Shadows = false
			light.Color = Colors.Light
			light.Parent = fixture
			for _, offset in { -3, 3 } do
				part(lights, "Cable" .. horizontal .. "_" .. z .. "_" .. offset, Vector3.new(0.12, cableLength, 0.12),
					Vector3.new(horizontal + offset, lightY + cableLength / 2, z), Colors.Metal, Enum.Material.Metal)
			end
		end
	end

	-- Global leaderboards on the right, behind the baseline, facing the court.
	local boardSpot = Config.Leaderboard
	Props.Leaderboards(Geometry.Folder(parent, "LeaderboardArea"),
		CFrame.lookAt(frame * boardSpot.Position, frame * (boardSpot.Position + boardSpot.Facing)), SHOP_BOARD)

	-- Street face of the building: canopy, name, window grid and a blue parapet.
	local facade = Geometry.Folder(parent, "Facade")
	local outer = frontZ + 0.6
	part(facade, "Canopy", Vector3.new(28, 0.8, 8), Vector3.new(0, 13.5, frontZ + 4.5), Colors.Blue)
	part(facade, "CanopyEdge", Vector3.new(28, 0.3, 0.3), Vector3.new(0, 13.1, frontZ + 8.5), Colors.Yellow, Enum.Material.Neon)
	Geometry.Panel(facade, "SchoolName", Vector3.new(50, 10, 0.3), frame * CFrame.new(0, 26, outer + 0.2), Colors.Blue,
		"DUNK HIGH GYMNASIUM", Colors.Lines, Enum.NormalId.Back)
	part(facade, "Band", Vector3.new(Config.RoomWidth, 2, 0.3), Vector3.new(0, 38, outer), Colors.Blue)
	for _, y in { 56, 86, 116 } do
		for _, x in { -45, -15, 15, 45 } do
			part(facade, "Window" .. x .. "_" .. y, Vector3.new(18, 20, 0.2), Vector3.new(x, y, outer), Colors.Glass, Enum.Material.Glass)
		end
	end
	for name, spec in {
		Front = { Vector3.new(Config.RoomWidth + 2, 3, 2), Vector3.new(0, height - 1.5, frontZ) },
		Back = { Vector3.new(Config.RoomWidth + 2, 3, 2), Vector3.new(0, height - 1.5, backZ) },
		Left = { Vector3.new(2, 3, depth + 2), Vector3.new(-halfW, height - 1.5, midZ) },
		Right = { Vector3.new(2, 3, depth + 2), Vector3.new(halfW, height - 1.5, midZ) },
	} do
		part(facade, "Parapet" .. name, spec[1], spec[2], Colors.Blue, Enum.Material.Concrete)
	end
	-- Street outside the entrance for the return bus.
	local outside = Geometry.Folder(parent, "Exterior")
	part(outside, "Sidewalk", Vector3.new(90, 0.4, 6), Vector3.new(0, -0.2, 84), Colors.Concrete, Enum.Material.Concrete, true)
	part(outside, "Road", Vector3.new(220, 0.5, 16), Vector3.new(0, -0.45, 95), Colors.Road, Enum.Material.Asphalt, true)
	for index = -5, 5 do
		part(outside, "RoadDash" .. index, Vector3.new(8, 0.02, 0.3), Vector3.new(index * 20, -0.19, 95), Colors.Lines)
	end
	part(outside, "Lawn", Vector3.new(220, 0.4, 40), Vector3.new(0, -0.5, 123), Colors.Grass, Enum.Material.Grass, true)
	-- Grounds under and around the whole gym so its sides don't float over nothing.
	part(outside, "Grounds", Vector3.new(Config.RoomWidth + 160, 0.4, depth + 140), Vector3.new(0, -0.7, midZ + 20), Colors.Grass, Enum.Material.Grass, true)
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
	Props.TransitStop(parent, station, text, busDistance, roadDrop, SHOP)
end

return Scenery
