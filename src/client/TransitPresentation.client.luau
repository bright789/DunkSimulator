-- Bus ride presentation for every player on this client. When a player boards
-- (server-set TransitRide attribute), the nearest TransitBus opens its doors, the rider
-- fades out, and the bus drives away. The rider's own screen follows the bus and fades
-- to black until the server finishes the normal court travel. Purely visual.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local WorldAudio = require(script.Parent:WaitForChild("WorldAudio"))
local shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Courts = require(shared:WaitForChild("CourtConfig"))
local Config = require(shared:WaitForChild("PresentationConfig")).Transit

local localPlayer = Players.LocalPlayer
local buses: { [Model]: boolean } = {}
local busyBuses: { [Model]: boolean } = {}
local riders: { [Player]: { Started: number } } = {}

local function consider(instance: Instance)
	if instance:IsA("Model") and instance.Name == "TransitBus" then buses[instance] = true end
end
for _, descendant in Workspace:GetDescendants() do consider(descendant) end
Workspace.DescendantAdded:Connect(consider)
Workspace.DescendantRemoving:Connect(function(instance) buses[instance] = nil end)

local function nearestBus(position: Vector3): Model?
	local best, bestDistance = nil, Config.BusSearchRadius
	for bus in buses do
		if bus.Parent and bus.PrimaryPart then
			local distance = (bus:GetPivot().Position - position).Magnitude
			if distance < bestDistance then best, bestDistance = bus, distance end
		end
	end
	return best
end

local function setHidden(model: Instance, amount: number)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then part.LocalTransparencyModifier = amount end
	end
end

local function smooth(alpha: number): number
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

-- Doors open, close, then the bus accelerates away, vanishes, and later returns home.
local function animateBus(bus: Model)
	if busyBuses[bus] then return end
	busyBuses[bus] = true
	local home = bus:GetPivot()
	local doors = {}
	for name, direction in { DoorFront = -1, DoorRear = 1 } do
		local door = bus:FindFirstChild(name)
		if door and door:IsA("BasePart") then
			table.insert(doors, { Part = door, Offset = home:ToObjectSpace(door.CFrame), Direction = direction })
		end
	end
	local driveStart = Config.DoorOpenSeconds + Config.BoardSeconds + Config.DoorOpenSeconds
	local driveSeconds = math.max(Courts.RideSeconds - driveStart + Config.DriveOverrunSeconds, 0.5)
	local started = os.clock()
	local door = doors[1] and doors[1].Part or bus.PrimaryPart
	if door then WorldAudio.PlayAt("BusDoor", door.Position) end
	local departed = false
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if not departed and t >= driveStart then
			departed = true
			WorldAudio.PlayAt("BusBrake", bus:GetPivot().Position)
		end
		local open
		if t < Config.DoorOpenSeconds then
			open = smooth(t / Config.DoorOpenSeconds)
		elseif t < Config.DoorOpenSeconds + Config.BoardSeconds then
			open = 1
		else
			open = 1 - smooth((t - Config.DoorOpenSeconds - Config.BoardSeconds) / Config.DoorOpenSeconds)
		end
		local drive = math.clamp((t - driveStart) / driveSeconds, 0, 1)
		local pivot = home * CFrame.new(0, 0, -Config.DriveDistance * drive * drive)
		bus:PivotTo(pivot)
		for _, door in doors do
			door.Part.CFrame = pivot * door.Offset * CFrame.new(0, 0, door.Direction * 1.05 * open)
		end
		if drive >= 1 then
			setHidden(bus, 1)
			if t >= driveStart + driveSeconds + Config.ReturnDelaySeconds then
				connection:Disconnect()
				bus:PivotTo(home)
				for _, door in doors do door.Part.CFrame = home * door.Offset end
				setHidden(bus, 0)
				busyBuses[bus] = nil
			end
		end
	end)
end

-- Rider's own screen: watch the bus from the curb, then fade out until arrival.
local fadeGui = Instance.new("ScreenGui")
fadeGui.Name = "BusRideFade"
fadeGui.IgnoreGuiInset = true
fadeGui.DisplayOrder = 50
fadeGui.ResetOnSpawn = false
local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1, 1)
fade.BackgroundColor3 = Color3.new(0, 0, 0)
fade.BackgroundTransparency = 1
fade.Parent = fadeGui
local caption = Instance.new("TextLabel")
caption.AnchorPoint = Vector2.new(0.5, 0.5)
caption.Position = UDim2.fromScale(0.5, 0.5)
caption.Size = UDim2.fromScale(0.6, 0.08)
caption.BackgroundTransparency = 1
caption.Font = Enum.Font.FredokaOne
caption.TextScaled = true
caption.TextColor3 = Color3.fromRGB(255, 214, 64)
caption.TextTransparency = 1
caption.Parent = fade
fadeGui.Parent = localPlayer:WaitForChild("PlayerGui")

local cameraBound = false
local function tweenFade(target: number, seconds: number)
	TweenService:Create(fade, TweenInfo.new(seconds), { BackgroundTransparency = target }):Play()
	TweenService:Create(caption, TweenInfo.new(seconds), { TextTransparency = target }):Play()
end

-- Camera spot watching the bus: across the road first, then the curb side; walls or
-- houses in the way pull the camera in front of them.
local function cameraEye(bus: Model): Vector3
	local home = bus:GetPivot()
	local target = home.Position + Vector3.new(0, 2, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { bus }
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(ignore, player.Character) end
	end
	params.FilterDescendantsInstances = ignore
	local best, bestDistance = nil, -1
	for _, side in { -1, 1 } do
		local eye = home.Position + home.RightVector * side * Config.CameraSide
			+ home.LookVector * Config.CameraAhead + Vector3.new(0, Config.CameraHeight, 0)
		local hit = Workspace:Raycast(target, eye - target, params)
		if not hit then return eye end
		local distance = (hit.Position - target).Magnitude
		if distance > bestDistance then
			best, bestDistance = target + (eye - target).Unit * math.max(distance - 1, 2), distance
		end
	end
	return best
end

local function startLocalCinematic(bus: Model?, courtId: string)
	local court = Courts.Get(courtId)
	caption.Text = "Riding the bus to " .. (court and court.DisplayName or "the next court") .. "..."
	local camera = Workspace.CurrentCamera
	if bus and camera then
		local eye = cameraEye(bus)
		camera.CameraType = Enum.CameraType.Scriptable
		if cameraBound then RunService:UnbindFromRenderStep("BusRideCamera") end
		cameraBound = true
		RunService:BindToRenderStep("BusRideCamera", Enum.RenderPriority.Camera.Value + 2, function()
			local target = bus:GetPivot().Position + Vector3.new(0, 2, 0)
			camera.CFrame = CFrame.lookAt(eye, target)
		end)
	end
	task.delay(math.max(Courts.RideSeconds - Config.ScreenFadeOutSeconds, 0), function()
		if riders[localPlayer] then tweenFade(0, Config.ScreenFadeOutSeconds) end
	end)
end

local function endLocalCinematic()
	if cameraBound then
		RunService:UnbindFromRenderStep("BusRideCamera")
		cameraBound = false
	end
	local camera = Workspace.CurrentCamera
	local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then camera.CameraSubject = humanoid end
	end
	tweenFade(1, Config.ScreenFadeInSeconds)
end

local function onRideChanged(player: Player)
	local courtId = player:GetAttribute("TransitRide")
	if courtId and not riders[player] then
		riders[player] = { Started = os.clock() }
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local bus = root and nearestBus(root.Position) or nil
		if bus then animateBus(bus) end
		if player == localPlayer then startLocalCinematic(bus, courtId) end
	elseif not courtId and riders[player] then
		riders[player] = nil
		if player.Character then setHidden(player.Character, 0) end
		if player == localPlayer then endLocalCinematic() end
	end
end

-- Riders fade out as they board and stay hidden (with their ball) for the whole ride.
RunService.RenderStepped:Connect(function()
	for player, ride in riders do
		local amount = smooth((os.clock() - ride.Started - Config.DoorOpenSeconds) / Config.RiderFadeSeconds)
		if player.Character then setHidden(player.Character, amount) end
		local visuals = Workspace:FindFirstChild("LocalBallVisuals")
		local ball = visuals and visuals:FindFirstChild(player.Name .. "_Basketball")
		if ball then setHidden(ball, amount); ball.LocalTransparencyModifier = amount end
	end
end)

local function watch(player: Player)
	player:GetAttributeChangedSignal("TransitRide"):Connect(function() onRideChanged(player) end)
	onRideChanged(player)
end
for _, player in Players:GetPlayers() do watch(player) end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(player) riders[player] = nil end)
