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

function Geometry.Sign(parent, name, frame, text, color, width)
	local board = Geometry.Part(parent, name, Vector3.new(width, 2.5, 0.2), frame, color)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = face.Name .. "Label"
		gui.Face = face
		gui.CanvasSize = Vector2.new(768, 160)
		gui.LightInfluence = 0.5
		gui.MaxDistance = 160
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Color3.fromRGB(242, 235, 215)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = gui
	end
	return board
end

return Geometry
