local Geometry = {}

function Geometry.Folder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Geometry.Part(parent, name, size, frame, color, material, collision)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = frame
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = collision == true
	part.CanTouch = false
	part.CanQuery = collision == true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function Geometry.Line(parent, name, first, last, width, thickness, color)
	local length = (last - first).Magnitude
	assert(length > 0, "Line endpoints must differ")
	return Geometry.Part(parent, name, Vector3.new(width, thickness, length),
		CFrame.lookAt((first + last) / 2, last), color)
end

function Geometry.Arc(parent, name, frame, radius, startAngle, endAngle, segments, width, thickness, color)
	local folder = Geometry.Folder(parent, name)
	for index = 1, segments do
		local firstAngle = startAngle + (endAngle - startAngle) * (index - 1) / segments
		local lastAngle = startAngle + (endAngle - startAngle) * index / segments
		local first = frame:PointToWorldSpace(Vector3.new(radius * math.cos(firstAngle), 0, -radius * math.sin(firstAngle)))
		local last = frame:PointToWorldSpace(Vector3.new(radius * math.cos(lastAngle), 0, -radius * math.sin(lastAngle)))
		Geometry.Line(folder, string.format("Segment%02d", index), first, last, width, thickness, color)
	end
	return folder
end

-- Signs share the HUD look (mirrors src/shared/Config/HUDConfig.luau): a deep-navy
-- rounded panel with a sign-colored rim, white FredokaOne text with a dark cartoon
-- outline, unaffected by scene lighting. Very dark sign colors use the HUD's light-blue
-- panel stroke for the rim instead.
local SIGN_PANEL = Color3.fromRGB(18, 24, 52)
local SIGN_STROKE = Color3.fromRGB(110, 190, 255)
local SIGN_TEXT = Color3.fromRGB(255, 255, 255)
local SIGN_OUTLINE = Color3.fromRGB(6, 10, 30)
local PIXELS_PER_STUD = 64

function Geometry.Sign(parent, name, frame, text, color, width)
	local _, _, brightness = color:ToHSV()
	local rim = brightness < 0.35 and SIGN_STROKE or color
	local board = Geometry.Part(parent, name, Vector3.new(width, 2.5, 0.2), frame, rim)
	local canvas = Vector2.new(math.floor(width * PIXELS_PER_STUD + 0.5), math.floor(2.5 * PIXELS_PER_STUD + 0.5))
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = face.Name .. "Label"
		gui.Face = face
		gui.CanvasSize = canvas
		gui.LightInfluence = 0
		gui.MaxDistance = 220
		gui.Parent = board
		local panel = Instance.new("Frame")
		panel.Name = "Panel"
		panel.Size = UDim2.new(1, -20, 1, -20)
		panel.Position = UDim2.fromOffset(10, 10)
		panel.BackgroundColor3 = SIGN_PANEL
		panel.BorderSizePixel = 0
		panel.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 18)
		corner.Parent = panel
		local shade = Instance.new("UIGradient")
		shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.72, 0.72, 0.72))
		shade.Rotation = 90
		shade.Parent = panel
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -40, 1, -26)
		label.Position = UDim2.fromOffset(20, 13)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = SIGN_TEXT
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.Parent = panel
		local outline = Instance.new("UIStroke")
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		outline.Color = SIGN_OUTLINE
		outline.Thickness = 5
		outline.Transparency = 0.15
		outline.Parent = label
	end
	return board
end

-- Big text panel for banners and wall markings: one face carries FredokaOne text with a
-- dark outline, unaffected by scene lighting and readable from far across an arena.
-- `face` must point into the room (parts here are axis-aligned with the court frame).
function Geometry.Panel(parent, name, size, frame, color, text, textColor, face)
	local board = Geometry.Part(parent, name, size, frame, color)
	local sideways = face == Enum.NormalId.Left or face == Enum.NormalId.Right
	local width = sideways and size.Z or size.X
	-- Scaled text tops out at 100 px, so big panels get a coarser canvas (about 110 px per
	-- line of text) and the words still fill them.
	local _, breaks = string.gsub(text, "\n", "")
	local pixelsPerStud = math.min(24, 110 * (breaks + 1) / size.Y)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = face
	gui.CanvasSize = Vector2.new(math.floor(width * pixelsPerStud + 0.5), math.floor(size.Y * pixelsPerStud + 0.5))
	gui.LightInfluence = 0
	gui.MaxDistance = 900
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.84)
	label.Position = UDim2.fromScale(0.05, 0.08)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Color = SIGN_OUTLINE
	outline.Thickness = 4
	outline.Parent = label
	return board
end

return Geometry
