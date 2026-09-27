-- Draws a local copy of each player's basketball so dribbling and dunks look smooth.
-- The server's HeldBasketball stays authoritative; this module only hides it on this
-- client and renders a visual ball that follows the character every frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DunkConfig = require(ReplicatedStorage.Shared.Config.DunkConfig)
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local Config = require(ReplicatedStorage.Shared.Config.PresentationConfig)
local BallConfig = Config.Ball
local DribbleConfig = Config.Dribble

local WorldAudio = require(script.Parent:WaitForChild("WorldAudio"))

local BallPresentation = {}

local RADIUS = DunkConfig.BallDiameter / 2
local visualFolder: Folder? = nil
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude
floorParams.IgnoreWater = true

local function smooth(alpha: number): number
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

local function getFolder(): Folder
	if not visualFolder or visualFolder.Parent ~= Workspace then
		local folder = Instance.new("Folder")
		folder.Name = "LocalBallVisuals"
		folder.Parent = Workspace
		visualFolder = folder
	end
	return visualFolder :: Folder
end

local function heldCFrame(hand: BasePart): CFrame
	return hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, -RADIUS)
end

local function flatRootCFrame(root: BasePart): CFrame
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(root.Position, root.Position + flat.Unit)
end

local function destroyArm(state)
	if state.ArmControl then state.ArmControl:Destroy() end
	if state.ArmTarget then state.ArmTarget:Destroy() end
	state.ArmControl = nil
	state.ArmTarget = nil
	state.ArmWeight = 0
end

local function ensureArm(state)
	if state.ArmControl and state.ArmControl.Parent == state.Humanoid then return true end
	destroyArm(state)
	local character = state.Character
	local upperArm = character:FindFirstChild("RightUpperArm")
	local hand = character:FindFirstChild("RightHand")
	if state.Humanoid.RigType ~= Enum.HumanoidRigType.R15 or not upperArm or not hand then return false end
	local target = Instance.new("Attachment")
	target.Name = "LocalDribbleHandTarget"
	target.Parent = Workspace.Terrain
	local control = Instance.new("IKControl")
	control.Name = "LocalDribbleArm"
	control.Type = Enum.IKControlType.Position
	control.ChainRoot = upperArm
	control.EndEffector = hand
	control.Target = target
	control.SmoothTime = 0
	control.Weight = 0
	control.Priority = 2
	control.Parent = state.Humanoid
	state.ArmTarget = target
	state.ArmControl = control
	return true
end

local function visualPart(parent: Instance?, name: string, shape: Enum.PartType, size: Vector3, color: Color3,
	material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

-- Two great-circle seams plus the two curved side seams of a real basketball. Each is a
-- thin disc slightly wider than the ball, so only its edge shows as a dark line.
local function addSeams(state, visual: Part)
	local diameter = DunkConfig.BallDiameter
	local width = math.max(diameter * BallConfig.SeamWidth, 0.04)
	local curveHeight = RADIUS * 0.62
	local curveDiameter = 2 * math.sqrt(RADIUS * RADIUS - curveHeight * curveHeight) + diameter * 0.02
	local seams = {
		SeamA = { Diameter = diameter * 1.02, Offset = CFrame.identity },
		SeamB = { Diameter = diameter * 1.02, Offset = CFrame.Angles(0, math.rad(90), 0) },
		CurveTop = { Diameter = curveDiameter, Offset = CFrame.new(0, curveHeight, 0) * CFrame.Angles(0, 0, math.rad(90)) },
		CurveBottom = { Diameter = curveDiameter, Offset = CFrame.new(0, -curveHeight, 0) * CFrame.Angles(0, 0, math.rad(90)) },
	}
	state.Seams = {}
	for name, seam in seams do
		local part = visualPart(visual, name, Enum.PartType.Cylinder, Vector3.new(width, seam.Diameter, seam.Diameter),
			BallConfig.SeamColor, Enum.Material.SmoothPlastic)
		part.CastShadow = false
		table.insert(state.Seams, { Part = part, Offset = seam.Offset })
	end
end

local function ensureVisual(state): Part
	local visual = state.Visual
	if visual and visual.Parent then return visual end
	local diameter = DunkConfig.BallDiameter
	visual = visualPart(nil, state.Player.Name .. "_Basketball", Enum.PartType.Ball,
		Vector3.new(diameter, diameter, diameter), DunkConfig.BallColor, Enum.Material.Leather)
	visual.CastShadow = true
	addSeams(state, visual)
	if BallConfig.TrailLifetime > 0 then
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, RADIUS * 0.35, 0)
		top.Parent = visual
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(0, -RADIUS * 0.35, 0)
		bottom.Parent = visual
		local trail = Instance.new("Trail")
		trail.Name = "DunkTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Lifetime = BallConfig.TrailLifetime
		trail.Color = ColorSequence.new(BallConfig.TrailColor, Color3.new(1, 1, 1))
		trail.Transparency = NumberSequence.new(0.55, 1)
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.LightEmission = 0.4
		trail.FaceCamera = true
		trail.Enabled = false
		trail.Parent = visual
	end
	visual.Parent = getFolder()
	state.Visual = visual
	return visual
end

local function trackServerBall(state, serverBall: BasePart?)
	if state.ServerBall == serverBall then return end
	if state.BallConnection then state.BallConnection:Disconnect() end
	if state.ServerBall and state.ServerBall.Parent then
		state.ServerBall.Transparency = 0
	end
	state.BallConnection = nil
	state.ServerBall = serverBall
	table.clear(state.Snapshots)
	if serverBall then
		table.insert(state.Snapshots, { Time = os.clock(), CFrame = serverBall.CFrame })
		state.BallConnection = serverBall:GetPropertyChangedSignal("CFrame"):Connect(function()
			local snapshots = state.Snapshots
			table.insert(snapshots, { Time = os.clock(), CFrame = serverBall.CFrame })
			while #snapshots > BallConfig.MaxSnapshots do table.remove(snapshots, 1) end
		end)
	end
end

-- Server-moved ball during dunks: render slightly in the past and interpolate
-- between received updates so the path is smooth instead of stepping.
local function interpolatedServerCFrame(state): CFrame
	local snapshots = state.Snapshots
	local serverBall = state.ServerBall
	if #snapshots == 0 then return serverBall.CFrame end
	local renderTime = os.clock() - BallConfig.InterpolationDelaySeconds
	if renderTime <= snapshots[1].Time then return snapshots[1].CFrame end
	for index = #snapshots, 2, -1 do
		local older = snapshots[index - 1]
		local newer = snapshots[index]
		if renderTime >= older.Time then
			if renderTime >= newer.Time then return newer.CFrame end
			local alpha = (renderTime - older.Time) / math.max(newer.Time - older.Time, 1e-3)
			return older.CFrame:Lerp(newer.CFrame, alpha)
		end
	end
	return snapshots[#snapshots].CFrame
end

local function findRim(player: Player): BasePart?
	local court = Courts.Get(player:GetAttribute("CurrentCourt"))
	if not court then return nil end
	local container: Instance? = Workspace
	for _, name in court.GameplayPath do
		container = container and container:FindFirstChild(name)
	end
	local hoop = container and container:FindFirstChild("DunkHoop")
	local rim = hoop and hoop:FindFirstChild("Rim")
	return rim and rim:IsA("BasePart") and rim or nil
end

local function floorHeight(state, position: Vector3): number?
	floorParams.FilterDescendantsInstances = { state.Character, getFolder() }
	local hit = Workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), floorParams)
	return hit and hit.Position.Y or nil
end

-- Loose ball after the slam: falls through the net, bounces and settles.
local function stepLoose(state, deltaTime: number): CFrame
	local loose = state.Loose
	loose.Elapsed += deltaTime
	loose.Velocity += Vector3.new(0, -Workspace.Gravity, 0) * deltaTime
	local position = loose.Position + loose.Velocity * deltaTime
	local floorY = floorHeight(state, position)
	if floorY and position.Y - RADIUS < floorY then
		position = Vector3.new(position.X, floorY + RADIUS, position.Z)
		local impact = math.abs(loose.Velocity.Y)
		if impact > BallConfig.BounceSoundMinSpeed then
			WorldAudio.PlayAt("BallBounce", position, math.clamp(impact / 60, 0.3, 1))
		end
		loose.Velocity = Vector3.new(loose.Velocity.X * BallConfig.FloorFriction,
			impact * BallConfig.Restitution, loose.Velocity.Z * BallConfig.FloorFriction)
		loose.Bounced = true
	end
	loose.Position = position
	return CFrame.new(position)
end

-- During a dunk the ball rides the animated hand. On the slam it is steered over
-- the ring centre and let go once the hand drives down to the rim.
local function dunkCFrame(state, hand: BasePart): (CFrame, Vector3?)
	local rim = state.Rim
	if not rim or not rim.Parent then
		rim = findRim(state.Player)
		state.Rim = rim
	end
	if not rim then return interpolatedServerCFrame(state), nil end
	local held = heldCFrame(hand).Position
	local phase = state.Player:GetAttribute("DunkPhase")
	if phase == "Slam" or phase == "Hang" then
		local rimPosition = rim.Position
		local closeness = 1 - math.clamp((held.Y - rimPosition.Y) / 3, 0, 1)
		local pull = BallConfig.SlamCenterPull * smooth(closeness)
		held = Vector3.new(held.X + (rimPosition.X - held.X) * pull, held.Y, held.Z + (rimPosition.Z - held.Z) * pull)
		if phase == "Hang" or held.Y - RADIUS <= rimPosition.Y + BallConfig.ReleaseAboveRim then
			local release = Vector3.new(rimPosition.X, math.max(held.Y, rimPosition.Y + RADIUS * 0.5), rimPosition.Z)
			state.Loose = { Position = release, Velocity = Vector3.new(0, -BallConfig.ReleaseSpeed, 0),
				Elapsed = 0, Bounced = false }
			return CFrame.new(release), release
		end
	end
	return CFrame.new(held), nil
end

-- Rolls the ball with its motion (and a forward spin while dribbling) so it reads as a
-- spinning ball instead of a sliding one. `rolling` = the ball is on or near the floor.
local function spin(state, position: Vector3, rolling: boolean, dribbling: boolean)
	local last = state.LastPosition or position
	state.LastPosition = position
	local delta = position - last
	if delta.Magnitude > BallConfig.MaxSpinStep then return end
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if rolling and flat.Magnitude > 1e-4 then
		state.Spin = CFrame.fromAxisAngle(Vector3.yAxis:Cross(flat.Unit), flat.Magnitude / RADIUS) * state.Spin
	end
	if dribbling then
		local forwardAxis = -state.Root.CFrame.RightVector
		state.Spin = CFrame.fromAxisAngle(forwardAxis, math.abs(delta.Y) * BallConfig.DribbleSpin / RADIUS) * state.Spin
	end
	state.Spin = state.Spin:Orthonormalize()
end

local function place(state, visual: Part, position: Vector3)
	local cframe = CFrame.new(position) * state.Spin
	visual.CFrame = cframe
	for _, seam in state.Seams do seam.Part.CFrame = cframe * seam.Offset end
end

-- Floor spot beside the player where the ball waits during a workout.
local function restCFrame(state, root: BasePart): CFrame
	local spot = flatRootCFrame(root):PointToWorldSpace(Vector3.new(BallConfig.RestSide, 0, -BallConfig.RestForward))
	local floorY = floorHeight(state, spot) or (root.Position.Y - state.Humanoid.HipHeight - root.Size.Y / 2)
	return CFrame.new(spot.X, floorY + RADIUS, spot.Z)
end

local function dribbleCFrame(state, root: BasePart, deltaTime: number): (CFrame, number)
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	state.Speed += (speed - state.Speed) * (1 - math.exp(-DribbleConfig.SpeedSmoothing * deltaTime))
	local runFraction = math.clamp(state.Speed / DribbleConfig.RunSpeed, 0, 1)
	local bounces = DribbleConfig.IdleBouncesPerSecond
		+ (DribbleConfig.RunBouncesPerSecond - DribbleConfig.IdleBouncesPerSecond) * runFraction
	local before = state.Phase
	state.Phase = (state.Phase + bounces * deltaTime) % 1
	-- The ball meets the floor when the cycle crosses DownFraction.
	local hitFloor = before < DribbleConfig.DownFraction and state.Phase >= DribbleConfig.DownFraction

	local forward = DribbleConfig.IdleForwardOffset
		+ (DribbleConfig.RunForwardOffset - DribbleConfig.IdleForwardOffset) * runFraction
	local anchor = flatRootCFrame(root):PointToWorldSpace(Vector3.new(DribbleConfig.SideOffset, 0, -forward))
	floorParams.FilterDescendantsInstances = { state.Character, getFolder() }
	local hit = Workspace:Raycast(anchor + Vector3.new(0, 1, 0),
		Vector3.new(0, -DribbleConfig.FloorProbeDistance, 0), floorParams)
	local floorY = (hit and hit.Position.Y
		or root.Position.Y - state.Humanoid.HipHeight - root.Size.Y / 2) + RADIUS
	local topY = math.max(root.Position.Y - DribbleConfig.TopBelowRoot, floorY + 0.5)

	local phase = state.Phase
	local down = DribbleConfig.DownFraction
	local y
	if phase < down then
		-- Pushed out of the hand: speeds up on the way to the floor.
		y = topY - (topY - floorY) * (phase / down) ^ 1.7
	else
		-- Rebounds and slows as it rises back into the palm.
		local rise = (phase - down) / (1 - down)
		y = floorY + (topY - floorY) * (1 - (1 - rise) ^ 2)
	end
	if hitFloor then
		WorldAudio.PlayAt("Dribble", Vector3.new(anchor.X, floorY - RADIUS, anchor.Z), 0.7 + 0.3 * runFraction, 0.95 + 0.1 * runFraction)
	end
	return CFrame.new(anchor.X, y, anchor.Z), topY
end

function BallPresentation.Track(player: Player, character: Model, humanoid: Humanoid, root: BasePart)
	return {
		Player = player,
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Visual = nil,
		ServerBall = nil,
		BallConnection = nil,
		Snapshots = {},
		Source = "None",
		BlendFrom = nil,
		BlendElapsed = 0,
		GatherFrom = nil,
		GatherElapsed = 0,
		Phase = 0,
		Speed = 0,
		ArmControl = nil,
		ArmTarget = nil,
		ArmWeight = 0,
		RunFraction = 0,
		Rim = nil,
		Loose = nil,
		BlendSeconds = BallConfig.SourceBlendSeconds,
		Seams = {},
		Spin = CFrame.identity,
		LastPosition = nil,
		Rest = nil,
	}
end

-- Returns the release point on the frame a dunked ball leaves the hand.
function BallPresentation.Update(state, deltaTime: number): Vector3?
	local character = state.Character
	local root = state.Root
	local mode = state.Player:GetAttribute("BasketballAction")
	local serverBall = character:FindFirstChild("HeldBasketball")
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not serverBall or not serverBall:IsA("BasePart") or not hand or not hand:IsA("BasePart")
		or mode == nil or mode == "NoBall" then
		BallPresentation.Release(state)
		return nil
	end
	trackServerBall(state, serverBall)
	serverBall.Transparency = 1
	local visual = ensureVisual(state)

	local training = state.Player:GetAttribute("Training") == true
	local source = mode == "Dunking" and "Dunk"
		or training and "Rest"
		or mode == "Dribbling" and "Dribble"
		or mode == "Gathering" and "Gather"
		or "Hand"
	if source ~= state.Source then
		state.Rest = nil
		if source == "Rest" or state.Source == "Rest" then
			state.BlendSeconds = BallConfig.RestBlendSeconds
		end
		if source == "Gather" then
			state.GatherFrom = visual.CFrame
			state.GatherElapsed = 0
			state.BlendFrom = nil
		elseif state.Source ~= "None" then
			state.BlendFrom = visual.CFrame
			state.BlendElapsed = 0
		end
		if source == "Dribble" then state.Phase = 0 end
		state.Source = source
	end

	-- After a dunk the loose ball keeps bouncing until the player has landed,
	-- then it is caught back into the dribble/hand.
	local released = nil
	if state.Loose and source ~= "Dunk" then
		local grounded = state.Humanoid.FloorMaterial ~= Enum.Material.Air
		if grounded and state.Loose.Elapsed >= BallConfig.CatchDelaySeconds then
			state.BlendFrom = visual.CFrame
			state.BlendElapsed = 0
			state.BlendSeconds = BallConfig.CatchBlendSeconds
			state.Loose = nil
		else
			local position = stepLoose(state, deltaTime).Position
			spin(state, position, state.Loose.Bounced, false)
			place(state, visual, position)
			return nil
		end
	end

	local target
	local handTargetY = nil
	if source == "Dribble" then
		local topY
		target, topY = dribbleCFrame(state, root, deltaTime)
		handTargetY = math.max(target.Position.Y + RADIUS, topY + RADIUS - DribbleConfig.HandFollowDepth)
	elseif source == "Gather" then
		state.GatherElapsed += deltaTime
		target = state.GatherFrom:Lerp(heldCFrame(hand),
			smooth(state.GatherElapsed / DribbleConfig.GatherSeconds))
	elseif source == "Rest" then
		state.Rest = state.Rest or restCFrame(state, root)
		target = state.Rest
	elseif source == "Dunk" then
		if state.Loose then
			target = stepLoose(state, deltaTime)
		else
			target, released = dunkCFrame(state, hand)
			if released then state.BlendFrom = nil end
		end
	else
		target = heldCFrame(hand)
	end
	state.RunFraction = math.clamp(state.Speed / DribbleConfig.RunSpeed, 0, 1)

	if state.BlendFrom then
		state.BlendElapsed += deltaTime
		local alpha = smooth(state.BlendElapsed / state.BlendSeconds)
		target = state.BlendFrom:Lerp(target, alpha)
		if alpha >= 1 then
			state.BlendFrom = nil
			state.BlendSeconds = BallConfig.SourceBlendSeconds
		end
	end
	spin(state, target.Position, source == "Dribble" or source == "Rest", source == "Dribble")
	place(state, visual, target.Position)
	local trail = visual:FindFirstChild("DunkTrail")
	if trail then trail.Enabled = state.Player:GetAttribute("DunkPhase") ~= nil or state.Loose ~= nil end

	-- Right hand follows the top of the ball while dribbling.
	local wantArm = source == "Dribble" and ensureArm(state)
	local blendRate = deltaTime / DribbleConfig.ArmBlendSeconds
	state.ArmWeight = math.clamp(state.ArmWeight + (wantArm and blendRate or -blendRate), 0, 1)
	if state.ArmControl then
		if handTargetY then
			local ballPosition = target.Position
			state.ArmTarget.WorldPosition = Vector3.new(ballPosition.X, handTargetY + hand.Size.Y / 2, ballPosition.Z)
		end
		state.ArmControl.Weight = state.ArmWeight * DribbleConfig.ArmWeight
		if state.ArmWeight <= 0 and not wantArm then destroyArm(state) end
	end
	return released
end

function BallPresentation.IsDribbling(state): boolean
	return state.Source == "Dribble"
end

function BallPresentation.Release(state)
	trackServerBall(state, nil)
	if state.Visual then state.Visual:Destroy() end
	state.Visual = nil
	state.Seams = {}
	state.LastPosition = nil
	state.Rest = nil
	state.Source = "None"
	state.BlendFrom = nil
	state.Loose = nil
	destroyArm(state)
end

return BallPresentation
