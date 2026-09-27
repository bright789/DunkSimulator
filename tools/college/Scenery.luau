-- College Arena scenery (edit-mode builder). Everything here is anchored decoration; only
-- floors, walls, stands and the outside ground collide. The shell is tall enough that a
-- max College jump stays indoors (Build.Run checks it), and anything overhead (roof,
-- trusses, jumbotron, lights, high banners) is still non-collidable and non-queryable so
-- jumps and the camera are never blocked.
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
GYM.Accent = Colors.Purple
local LAB = table.clone(SHOP)
LAB.Accent = Colors.Lab
local TRANSIT = table.clone(SHOP)
TRANSIT.Accent = Colors.Purple
local BOARD = table.clone(SHOP)
BOARD.Accent = Colors.Gold

-- Crowd looks. Home side (-X) wears purple/gold/white, visitors (+X) red/black/gray.
local SKINS = {
	Color3.fromRGB(255, 219, 172), Color3.fromRGB(241, 194, 125), Color3.fromRGB(224, 172, 105),
	Color3.fromRGB(198, 134, 66), Color3.fromRGB(141, 85, 36), Color3.fromRGB(94, 56, 30),
}
local SHIRTS = {
	[-1] = { Colors.Purple, Colors.Gold, Color3.fromRGB(245, 247, 252), Color3.fromRGB(140, 90, 230) },
	[1] = { Color3.fromRGB(210, 40, 50), Color3.fromRGB(30, 30, 36), Color3.fromRGB(150, 154, 164), Color3.fromRGB(255, 120, 60) },
}
local PANTS = { Color3.fromRGB(46, 62, 110), Color3.fromRGB(34, 36, 44), Color3.fromRGB(150, 130, 100), Color3.fromRGB(90, 94, 104) }
local SHOES = { Color3.fromRGB(245, 245, 245), Color3.fromRGB(26, 26, 30), Colors.Gold, Colors.Purple }
local HAIR = { Color3.fromRGB(30, 22, 16), Color3.fromRGB(88, 56, 30), Color3.fromRGB(196, 150, 80), Color3.fromRGB(140, 60, 30) }
local HATS = { "Cap", "BackwardsCap", "Beanie", "Headband", "ShortHair", "ShortHair", "Puff" }
local SEATED_POSES = { "Sit", "SitLean", "SitClap", "Sit" }

-- Screen text on a part face, styled like the HUD (white FredokaOne with outline).
local function screen(part, face, text, color, background)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(600, 340)
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = part
	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = background or Color3.fromRGB(10, 8, 24)
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = backdrop
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(6, 10, 30)
	outline.Thickness = 4
	outline.Parent = label
end

function Scenery.Arena(parent, context)
	local frame = context.Frame
	local function part(folder, name, size, offset, color, material, collide)
		return Geometry.Part(folder, name, size, frame * CFrame.new(offset), color, material, collide)
	end
	local halfW, halfD, height = Config.RoomWidth / 2, Config.RoomDepth / 2, Config.CeilingHeight

	-- Floor, apron and hardwood court.
	local court = Geometry.Folder(parent, "Court")
	part(court, "ArenaFloor", Vector3.new(Config.RoomWidth, 1, Config.RoomDepth), Vector3.new(0, -0.5, 0), Colors.Floor, Enum.Material.Concrete, true)
	part(court, "Apron", Vector3.new(Config.CourtWidth + 10, 0.05, Config.CourtDepth + 10), Vector3.new(0, 0.02, 0), Colors.Purple)
	for index = 1, 20 do
		part(court, string.format("HardwoodStrip%02d", index), Vector3.new(3, 0.03, Config.CourtDepth),
			Vector3.new(-31.5 + index * 3, 0.04, 0), index % 2 == 0 and Colors.Wood or Colors.WoodLight, Enum.Material.WoodPlanks)
	end
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
	-- Keys, free-throw circles and three-point arcs at both ends (only the -Z hoop is live).
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
	local logo = part(court, "CenterLogo", Vector3.new(14, 0.02, 14), Vector3.new(0, 0.07, 0), Colors.Purple)
	logo.Shape = Enum.PartType.Cylinder
	logo.Size = Vector3.new(0.02, 14, 14)
	logo.CFrame = frame * CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.rad(90))
	local logoText = part(court, "CenterLogoText", Vector3.new(11, 0.02, 4), Vector3.new(0, 0.09, 0), Colors.Purple)
	logoText.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(550, 200)
	gui.LightInfluence = 0.3
	gui.Parent = logoText
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.Text = "DUNK U"
	text.TextScaled = true
	text.TextColor3 = Colors.Gold
	text.Rotation = 180
	text.Parent = gui

	-- Shell: tall walls so even a max-Vertical jump stays indoors. Walls, floor and stands
	-- collide; the door header, roof and everything overhead never do.
	local shell = Geometry.Folder(parent, "Building")
	for _, side in { -1, 1 } do
		part(shell, "SideWall" .. side, Vector3.new(1, height, Config.RoomDepth), Vector3.new(side * halfW, height / 2, 0), Colors.Wall, Enum.Material.Concrete, true)
	end
	part(shell, "BackWall", Vector3.new(Config.RoomWidth, height, 1), Vector3.new(0, height / 2, -halfD), Colors.Wall, Enum.Material.Concrete, true)
	for _, side in { -1, 1 } do
		part(shell, "EntranceWall" .. side, Vector3.new(halfW - 12, height, 1), Vector3.new(side * (12 + (halfW - 12) / 2), height / 2, halfD), Colors.Wall, Enum.Material.Concrete, true)
	end
	part(shell, "DoorHeader", Vector3.new(24, height - 14, 1), Vector3.new(0, (height + 14) / 2, halfD), Colors.Wall, Enum.Material.Concrete, false)
	Geometry.Sign(shell, "EntranceBrand", frame * CFrame.new(0, 17, halfD - 0.7) * CFrame.Angles(0, math.pi, 0), "DUNK UNIVERSITY\nARENA", Colors.Purple, 24)
	part(shell, "EntranceLanding", Vector3.new(26, 1, 12), Vector3.new(0, -0.5, halfD + 6), Colors.Metal, Enum.Material.Concrete, true)
	part(shell, "Ceiling", Vector3.new(Config.RoomWidth + 2, 1, Config.RoomDepth + 2), Vector3.new(0, height, 0), Colors.Dark, Enum.Material.Metal, false)
	-- Neon rings around the inside: one just above the upper deck, one near the roof.
	for _, band in { { Y = 62, Color = Colors.Purple, Size = 1.6 }, { Y = 276, Color = Colors.Gold, Size = 1.2 } } do
		for _, side in { -1, 1 } do
			part(shell, "Band" .. band.Y .. "Side" .. side, Vector3.new(0.3, band.Size, Config.RoomDepth - 2), Vector3.new(side * (halfW - 0.65), band.Y, 0), band.Color, Enum.Material.Neon)
		end
		for _, endSign in { -1, 1 } do
			part(shell, "Band" .. band.Y .. "End" .. endSign, Vector3.new(Config.RoomWidth - 2, band.Size, 0.3), Vector3.new(0, band.Y, endSign * (halfD - 0.65)), band.Color, Enum.Material.Neon)
		end
	end
	-- Roof trusses with a purple glow under each bottom chord, and a gold ring at the center.
	local roof = Geometry.Folder(shell, "Trusses")
	local chord = height - 20.8 -- underside of the trusses; cables hang from here
	for index = 1, 9 do
		local z = -halfD + index * Config.RoomDepth / 10
		part(roof, "TopChord" .. index, Vector3.new(Config.RoomWidth - 2, 3, 2), Vector3.new(0, height - 4, z), Colors.Metal, Enum.Material.Metal)
		part(roof, "BottomChord" .. index, Vector3.new(Config.RoomWidth - 2, 1.6, 1.6), Vector3.new(0, height - 20, z), Colors.Metal, Enum.Material.Metal)
		part(roof, "Glow" .. index, Vector3.new(Config.RoomWidth - 6, 0.3, 0.6), Vector3.new(0, chord - 0.15, z), Colors.Purple, Enum.Material.Neon)
		for _, x in { -70, -35, 0, 35, 70 } do
			part(roof, "Strut" .. index .. "_" .. x, Vector3.new(1, 15, 1), Vector3.new(x, height - 12, z), Colors.Metal, Enum.Material.Metal)
		end
	end
	local oculus = part(roof, "OculusRing", Vector3.new(0.4, 44, 44), Vector3.zero, Colors.Gold, Enum.Material.Neon)
	oculus.Shape = Enum.PartType.Cylinder
	oculus.CFrame = frame * CFrame.new(0, height - 1, 0) * CFrame.Angles(0, 0, math.rad(90))
	local oculusCenter = part(roof, "OculusCenter", Vector3.new(0.5, 40, 40), Vector3.zero, Colors.Dark, Enum.Material.Metal)
	oculusCenter.Shape = Enum.PartType.Cylinder
	oculusCenter.CFrame = frame * CFrame.new(0, height - 1.2, 0) * CFrame.Angles(0, 0, math.rad(90))

	-- Lower bowl: six tiers on each sideline with an LED ribbon on the front rail.
	local stands = Geometry.Folder(parent, "Stands")
	local cfg = Config.Stands
	for _, side in { -1, 1 } do
		for row = 1, cfg.Rows do
			local x = side * (cfg.FirstX + (row - 1) * cfg.RowStep)
			part(stands, "Bench" .. side .. "Row" .. row, Vector3.new(cfg.RowStep - 0.4, 0.7, cfg.Length), Vector3.new(x, row * cfg.RowRise, 0),
				row % 2 == 0 and Colors.Purple or Colors.WallLight, Enum.Material.Metal, true)
			part(stands, "Riser" .. side .. "Row" .. row, Vector3.new(cfg.RowStep - 0.4, row * cfg.RowRise, cfg.Length),
				Vector3.new(x, row * cfg.RowRise / 2 - 0.35, 0), Colors.Metal, Enum.Material.Concrete, true)
		end
		part(stands, "Ribbon" .. side, Vector3.new(0.3, 1.1, cfg.Length), Vector3.new(side * (cfg.FirstX - cfg.RowStep / 2 - 0.1), 1.2, 0), Colors.Purple, Enum.Material.Neon)
		part(stands, "RibbonGold" .. side, Vector3.new(0.32, 0.3, cfg.Length), Vector3.new(side * (cfg.FirstX - cfg.RowStep / 2 - 0.12), 1.9, 0), Colors.Gold, Enum.Material.Neon)
	end

	-- Suite level: a solid block behind the lower bowl with lit suite windows and an LED
	-- ribbon board facing the court. The upper deck climbs from its top to the side walls.
	local suites, deck = Config.Suites, Config.UpperDeck
	for _, side in { -1, 1 } do
		local inward = side < 0 and Enum.NormalId.Right or Enum.NormalId.Left
		local blockWidth = halfW - suites.FrontX
		part(stands, "SuiteBlock" .. side, Vector3.new(blockWidth, suites.Top, suites.Length),
			Vector3.new(side * (suites.FrontX + blockWidth / 2), suites.Top / 2, 0), Colors.Dark, Enum.Material.Concrete, true)
		local face = side * (suites.FrontX - 0.2)
		local glass = part(stands, "SuiteGlass" .. side, Vector3.new(0.3, 6, suites.Length - 4), Vector3.new(face, 15, 0), Color3.fromRGB(255, 214, 150), Enum.Material.Neon)
		glass.Transparency = 0.25
		for index = 0, 15 do
			part(stands, "SuiteMullion" .. side .. "_" .. index, Vector3.new(0.4, 6, 0.4),
				Vector3.new(face - side * 0.1, 15, -suites.Length / 2 + 4 + index * (suites.Length - 8) / 15), Colors.Dark, Enum.Material.Metal)
		end
		part(stands, "SuiteTrim" .. side, Vector3.new(0.45, 0.6, suites.Length - 4), Vector3.new(face, 11.6, 0), Colors.Purple, Enum.Material.Neon)
		Geometry.Panel(stands, "RibbonBoard" .. side, Vector3.new(0.4, 3.2, suites.Length - 4), frame * CFrame.new(face, 20.6, 0), Colors.Dark,
			"DUNK U          SLAM CITY          DUNK U          SLAM CITY", Colors.Gold, inward)
		part(stands, "RibbonBoardTop" .. side, Vector3.new(0.45, 0.4, suites.Length - 4), Vector3.new(face, 22.4, 0), Colors.Gold, Enum.Material.Neon)
		part(stands, "RibbonBoardLow" .. side, Vector3.new(0.45, 0.4, suites.Length - 4), Vector3.new(face, 18.8, 0), Colors.Purple, Enum.Material.Neon)
		local rail = part(stands, "DeckRail" .. side, Vector3.new(0.2, 2.6, suites.Length), Vector3.new(side * (suites.FrontX + 0.3), suites.Top + 1.3, 0), Colors.Glass, Enum.Material.Glass)
		rail.Transparency = 0.5
		for row = 1, deck.Rows do
			local x = side * (deck.FirstX + (row - 1) * deck.RowStep)
			part(stands, "UpperBench" .. side .. "Row" .. row, Vector3.new(deck.RowStep - 0.4, 0.7, deck.Length), Vector3.new(x, suites.Top + row * deck.RowRise, 0),
				row % 2 == 0 and Colors.Purple or Colors.WallLight, Enum.Material.Metal, true)
			part(stands, "UpperRiser" .. side .. "Row" .. row, Vector3.new(deck.RowStep - 0.4, row * deck.RowRise, deck.Length),
				Vector3.new(x, suites.Top + row * deck.RowRise / 2 - 0.35, 0), Colors.Metal, Enum.Material.Concrete, true)
		end
	end

	-- Crowd: lower bowl first, then the upper deck (one Random, so lower fans never change).
	local crowd = Geometry.Folder(parent, "Crowd")
	local random = Random.new(Config.Crowd.Seed)
	local function fan(side, name, seat)
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
		Crowd.Spectator(crowd, name, CFrame.lookAt(frame * seat, frame * (seat - Vector3.new(side, 0, 0))),
			SEATED_POSES[random:NextInteger(1, #SEATED_POSES)], look)
	end
	local function slots(first, last, spacing)
		local result = {}
		for z = first, last, spacing do table.insert(result, z) end
		return result
	end
	for _, side in { -1, 1 } do
		local free = slots(Config.Crowd.FirstZ, Config.Crowd.LastZ, Config.Crowd.Spacing)
		for count = 1, Config.Crowd.PerSide do
			if #free == 0 then break end
			local z = table.remove(free, random:NextInteger(1, #free)) + random:NextNumber(-0.8, 0.8)
			local row = random:NextInteger(1, cfg.Rows)
			local benchX = side * (cfg.FirstX + (row - 1) * cfg.RowStep)
			fan(side, string.format("Fan%s%02d", side < 0 and "Home" or "Away", count), Vector3.new(benchX - side * 0.55, row * cfg.RowRise + 0.35, z))
		end
	end
	for _, side in { -1, 1 } do
		local free = slots(Config.Crowd.UpperFirstZ, Config.Crowd.UpperLastZ, Config.Crowd.UpperSpacing)
		for count = 1, Config.Crowd.UpperPerSide do
			if #free == 0 then break end
			local z = table.remove(free, random:NextInteger(1, #free)) + random:NextNumber(-0.8, 0.8)
			local row = random:NextInteger(1, deck.Rows)
			local benchX = side * (deck.FirstX + (row - 1) * deck.RowStep)
			fan(side, string.format("UpperFan%s%02d", side < 0 and "Home" or "Away", count),
				Vector3.new(benchX - side * 0.55, suites.Top + row * deck.RowRise + 0.35, z))
		end
	end

	-- Center-hung jumbotron with four screens and neon rings, on cables from the roof.
	local board = Geometry.Folder(parent, "Jumbotron")
	local boardY = 72
	local core = part(board, "Core", Vector3.new(22, 12, 22), Vector3.new(0, boardY, 0), Colors.Dark, Enum.Material.Metal)
	for index, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		screen(core, face, index % 2 == 1 and "DUNK U\nHOME 00  -  AWAY 00" or "SLAM IT!", index % 2 == 1 and Colors.Gold or Colors.Lines)
	end
	-- Neon edge frames around the bottom (purple) and top (gold) of the board.
	for _, y in { -6.3, 6.3 } do
		local color, tag = y < 0 and Colors.Purple or Colors.Gold, y < 0 and "Bottom" or "Top"
		for _, offset in { -11.2, 11.2 } do
			part(board, "Ring" .. tag .. "X" .. offset, Vector3.new(23, 0.6, 0.6), Vector3.new(0, boardY + y, offset), color, Enum.Material.Neon)
			part(board, "Ring" .. tag .. "Z" .. offset, Vector3.new(0.6, 0.6, 22), Vector3.new(offset, boardY + y, 0), color, Enum.Material.Neon)
		end
	end
	local cableBottom = boardY + 6.6
	for index, corner in { Vector3.new(-8, 0, -8), Vector3.new(8, 0, -8), Vector3.new(-8, 0, 8), Vector3.new(8, 0, 8) } do
		part(board, "Cable" .. index, Vector3.new(0.2, chord - cableBottom, 0.2),
			corner + Vector3.new(0, (chord + cableBottom) / 2, 0), Colors.Metal, Enum.Material.Metal)
	end

	-- Back wall: brand, banners and a giant crest; championship banners on the side walls;
	-- a crest over the entrance.
	local details = Geometry.Folder(parent, "ArenaDetails")
	Geometry.Sign(details, "BackWallBrand", frame * CFrame.new(0, 34, -halfD + 0.7), "DUNK UNIVERSITY", Colors.Purple, 40)
	for index, x in { -54, -38, 38, 54 } do
		part(details, "Banner" .. index, Vector3.new(10, 16, 0.15), Vector3.new(x, 40, -halfD + 0.8), index % 2 == 0 and Colors.Purple or Colors.Gold)
		Geometry.Sign(details, "BannerText" .. index, frame * CFrame.new(x, 40, -halfD + 1), index % 2 == 0 and "DUNK U\nCHAMPS" or "SLAM\n2026", Colors.Dark, 9)
	end
	Geometry.Panel(details, "Crest", Vector3.new(64, 26, 0.3), frame * CFrame.new(0, 145, -halfD + 0.75), Colors.Purple, "DUNK U", Colors.Gold, Enum.NormalId.Back)
	Geometry.Panel(details, "EntranceCrest", Vector3.new(64, 26, 0.3), frame * CFrame.new(0, 145, halfD - 0.75), Colors.Purple, "SLAM CITY", Colors.Gold, Enum.NormalId.Front)
	local titles = { "NATIONAL\nCHAMPS\n2019", "FINAL\nFOUR\n2021", "CONFERENCE\nCHAMPS\n2022", "NATIONAL\nCHAMPS\n2024", "23", "32" }
	for _, side in { -1, 1 } do
		for index, title in titles do
			local gold = (index + (side > 0 and 1 or 0)) % 2 == 0
			Geometry.Panel(details, "Honor" .. side .. "_" .. index, Vector3.new(0.2, 22, 12), frame * CFrame.new(side * (halfW - 0.7), 88, -70 + (index - 1) * 28),
				gold and Colors.Gold or Colors.Purple, title, gold and Colors.Dark or Colors.Lines, side < 0 and Enum.NormalId.Right or Enum.NormalId.Left)
		end
	end

	-- Tall clerestory windows glowing with daylight high on the side walls.
	local windows = Geometry.Folder(parent, "Windows")
	for _, side in { -1, 1 } do
		local x = side * (halfW - 0.6)
		for index = 1, 8 do
			local z = -84 + (index - 1) * 24
			local pane = part(windows, "Window" .. side .. "_" .. index, Vector3.new(0.2, 90, 14), Vector3.new(x, 200, z), Color3.fromRGB(200, 215, 255), Enum.Material.Neon)
			pane.Transparency = 0.45
			part(windows, "MullionV" .. side .. "_" .. index, Vector3.new(0.3, 90, 0.6), Vector3.new(x - side * 0.1, 200, z), Colors.Metal, Enum.Material.Metal)
			part(windows, "MullionH" .. side .. "_" .. index, Vector3.new(0.3, 0.6, 14), Vector3.new(x - side * 0.1, 200, z), Colors.Metal, Enum.Material.Metal)
		end
	end

	-- Vertical meter on the back wall: each line sits where your feet reach at the jump's
	-- peak with that much Vertical (from ProgressionConfig, measured by Build.Run).
	local meter = Geometry.Folder(parent, "VerticalMeter")
	for _, mark in context.Marks do
		part(meter, "Line" .. mark.Vertical, Vector3.new(Config.RoomWidth - 20, 0.5, 0.15), Vector3.new(0, mark.Height, -halfD + 0.62), Colors.Gold, Enum.Material.Neon)
		for _, side in { -1, 1 } do
			Geometry.Panel(meter, "Label" .. mark.Vertical .. "_" .. side, Vector3.new(22, 6, 0.2), frame * CFrame.new(side * (halfW - 26), mark.Height + 3.5, -halfD + 0.75),
				Colors.Dark, string.format("%d VERTICAL", mark.Vertical), Colors.Gold, Enum.NormalId.Back)
		end
	end

	-- Hanging light rigs: four trusses over the court (the middle two frame the jumbotron
	-- instead of crossing under it) and one over each upper deck.
	local rig = Config.LightRig
	local lights = Geometry.Folder(parent, "Lights")
	local function spot(name, position, angle, brightness)
		local fixture = part(lights, name, Vector3.new(3, 1, 3), position, Colors.Light, Enum.Material.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Angle = angle
		light.Brightness = brightness
		light.Range = 60
		light.Color = Colors.Light
		light.Parent = fixture
	end
	local function truss(name, x, y, length)
		part(lights, name, Vector3.new(1.4, 1.4, length), Vector3.new(x, y + 1.2, 0), Colors.Metal, Enum.Material.Metal)
		for index, z in { -length / 2 + 6, length / 2 - 6 } do
			part(lights, name .. "Cable" .. index, Vector3.new(0.15, chord - (y + 1.9), 0.15), Vector3.new(x, (chord + y + 1.9) / 2, z), Colors.Metal, Enum.Material.Metal)
		end
	end
	for _, x in { -36, -13, 13, 36 } do
		truss("CourtTruss" .. x, x, rig.Height, 144)
		for index, z in { -60, -20, 20, 60 } do
			spot("Light" .. index .. "_" .. x, Vector3.new(x, rig.Height, z), 100, 1.3)
		end
	end
	for _, side in { -1, 1 } do
		truss("DeckTruss" .. side, side * rig.DeckX, rig.DeckHeight, 124)
		for index, z in { -52, -26, 0, 26, 52 } do
			spot("DeckLight" .. side .. "_" .. index, Vector3.new(side * rig.DeckX, rig.DeckHeight, z), 110, 1)
		end
	end

	-- Global leaderboards behind the hoop (left of it), facing the court.
	local boardSpot = Config.Leaderboard
	Props.Leaderboards(Geometry.Folder(parent, "LeaderboardArea"),
		CFrame.lookAt(frame * boardSpot.Position, frame * (boardSpot.Position + boardSpot.Facing)), BOARD)

	-- Street face: canopy, arena name, glass curtain wall between purple fins, gold crown.
	local facade = Geometry.Folder(parent, "Facade")
	local outer = halfD + 0.6
	part(facade, "Canopy", Vector3.new(34, 1, 10), Vector3.new(0, 15, halfD + 5.5), Colors.Purple)
	part(facade, "CanopyEdge", Vector3.new(34, 0.4, 0.4), Vector3.new(0, 14.4, halfD + 10.5), Colors.Gold, Enum.Material.Neon)
	-- Signs sit in front of the fins; the middle fin starts above the entrance.
	Geometry.Panel(facade, "ArenaName", Vector3.new(110, 18, 0.4), frame * CFrame.new(0, 25, outer + 3), Colors.Purple,
		"DUNK UNIVERSITY ARENA", Colors.Gold, Enum.NormalId.Back)
	Geometry.Panel(facade, "Crest", Vector3.new(100, 34, 0.4), frame * CFrame.new(0, 250, outer + 3), Colors.Purple,
		"DUNK U", Colors.Gold, Enum.NormalId.Back)
	local bay = Config.RoomWidth / 6
	for fin = 0, 6 do
		local bottom = fin == 3 and 34 or 0
		part(facade, "Fin" .. fin, Vector3.new(2.5, height - bottom, 3), Vector3.new(-halfW + fin * bay, (height + bottom) / 2, outer + 1.2), Colors.Purple, Enum.Material.Concrete)
	end
	for column = 1, 6 do
		for row = 1, 5 do
			part(facade, "Glass" .. column .. "_" .. row, Vector3.new(bay - 3, 48, 0.2), Vector3.new(-halfW + (column - 0.5) * bay, 61.4 + (row - 1) * 50.8, outer),
				Color3.fromRGB(120, 100, 200), Enum.Material.Glass)
		end
	end
	for name, spec in {
		Front = { Vector3.new(Config.RoomWidth + 3, 5, 3), Vector3.new(0, height - 2.5, halfD + 0.5) },
		Back = { Vector3.new(Config.RoomWidth + 3, 5, 3), Vector3.new(0, height - 2.5, -halfD - 0.5) },
		Left = { Vector3.new(3, 5, Config.RoomDepth + 3), Vector3.new(-halfW - 0.5, height - 2.5, 0) },
		Right = { Vector3.new(3, 5, Config.RoomDepth + 3), Vector3.new(halfW + 0.5, height - 2.5, 0) },
	} do
		part(facade, "Crown" .. name, spec[1], spec[2], Colors.Gold)
	end
	part(facade, "CrownGlow", Vector3.new(Config.RoomWidth + 3, 0.6, 0.4), Vector3.new(0, height - 6, outer + 1.4), Colors.Gold, Enum.Material.Neon)

	-- Street outside the entrance for the bus back to the High School.
	local outside = Geometry.Folder(parent, "Exterior")
	part(outside, "Sidewalk", Vector3.new(140, 0.4, 6), Vector3.new(0, -0.2, halfD + 15), Colors.Concrete, Enum.Material.Concrete, true)
	part(outside, "Road", Vector3.new(300, 0.5, 16), Vector3.new(0, -0.45, halfD + 26), Colors.Road, Enum.Material.Asphalt, true)
	for index = -7, 7 do
		part(outside, "RoadDash" .. index, Vector3.new(8, 0.02, 0.3), Vector3.new(index * 20, -0.19, halfD + 26), Colors.Lines)
	end
	part(outside, "Lawn", Vector3.new(300, 0.4, 40), Vector3.new(0, -0.5, halfD + 54), Colors.Grass, Enum.Material.Grass, true)
	-- Grounds under and around the whole building so its sides don't float over nothing.
	part(outside, "Grounds", Vector3.new(Config.RoomWidth + 200, 0.4, Config.RoomDepth + 160), Vector3.new(0, -0.7, -20), Colors.Grass, Enum.Material.Grass, true)
	for _, side in { -1, 1 } do
		part(outside, "SideLawn" .. side, Vector3.new(75, 0.4, 20), Vector3.new(side * 92.5, -0.3, halfD + 8), Colors.Grass, Enum.Material.Grass, true)
	end
end

function Scenery.Hoop(parent, rim, height)
	Props.Hoop(parent, CFrame.lookAt(rim.Position, rim.Position + Vector3.zAxis), height, {
		Rim = Colors.Orange, Target = Colors.Purple, Metal = Colors.Metal, Net = Colors.Lines, Pad = Colors.Purple,
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

function Scenery.TransitStop(parent, station, text)
	Props.TransitStop(parent, station, text, Config.Transit.BusDistance, Config.Transit.RoadDrop, TRANSIT)
end

return Scenery
