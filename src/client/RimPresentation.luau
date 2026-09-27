-- Client-only dunk finish: hands grab the front of the ring while the server holds
-- the player in the "Hang" phase, the legs swing, the ring bends and springs back,
-- and the slam gets sparks plus a short hit-stop. Reads replicated attributes only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local Styles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local Config = require(ReplicatedStorage.Shared.Config.PresentationConfig).Rim

local RimPresentation = {}

local hoops = {}
local localPlayer = Players.LocalPlayer

local function smooth(alpha: number): number
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
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

-- Ring parts (Segment##, NetStrand##) bend together around the back of the ring.
local function getHoop(rim: BasePart)
	local hoop = hoops[rim]
	if hoop then return hoop end
	local parts, originals = {}, {}
	local radius = 0
	for _, part in (rim.Parent :: Instance):GetDescendants() do
		if part:IsA("BasePart") and (part.Name:match("^Segment%d+$") or part.Name:match("^NetStrand%d+$")) then
			table.insert(parts, part)
			originals[part] = part.CFrame
			if part.Name:match("^Segment") then
				local offset = part.Position - rim.Position
				radius = math.max(radius, Vector3.new(offset.X, 0, offset.Z).Magnitude)
			end
		end
	end
	local bracket = (rim.Parent :: Instance):FindFirstChild("RimBracket", true)
	local back = bracket and bracket:IsA("BasePart") and (bracket.Position - rim.Position) or Vector3.new(0, 0, -1)
	back = Vector3.new(back.X, 0, back.Z)
	back = back.Magnitude > 1e-3 and back.Unit or Vector3.new(0, 0, -1)
	radius = radius > 0 and radius or 1.3
	local pivot = rim.Position + back * radius
	local axis = back:Cross(Vector3.yAxis).Unit
	-- Pick the rotation direction that drops the front of the ring.
	local front = rim.Position - back * radius
	local test = CFrame.new(pivot) * CFrame.fromAxisAngle(axis, 0.2) * CFrame.new(-pivot)
	local sign = (test * front).Y < front.Y and 1 or -1
	hoop = {
		Rim = rim, Parts = parts, Originals = originals, Radius = radius, Back = back,
		Pivot = pivot, Axis = axis, Sign = sign, Angle = 0, Velocity = 0, Applied = false,
	}
	hoops[rim] = hoop
	return hoop
end

local function applyBend(hoop)
	local rotation = CFrame.new(hoop.Pivot) * CFrame.fromAxisAngle(hoop.Axis, hoop.Sign * hoop.Angle)
		* CFrame.new(-hoop.Pivot)
	for _, part in hoop.Parts do
		if part.Parent then part.CFrame = rotation * hoop.Originals[part] end
	end
end

local function sparks(position: Vector3, strength: number)
	local attachment = Instance.new("Attachment")
	attachment.Name = "LocalRimImpact"
	attachment.WorldPosition = position
	attachment.Parent = Workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Config.SparkColor)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.2, 0.4)
	emitter.Speed = NumberRange.new(14, 26)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 5
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(math.floor(Config.Sparks * strength))
	task.delay(1, function() attachment:Destroy() end)
end

-- Freezes the local player's dunk pose for a few frames at the moment of impact.
local function hitStop(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	local frozen = {}
	for _, track in animator:GetPlayingAnimationTracks() do
		if track.Priority == Enum.AnimationPriority.Action then
			table.insert(frozen, { Track = track, Speed = track.Speed })
			track:AdjustSpeed(0)
		end
	end
	task.delay(Config.HitStopSeconds, function()
		for _, entry in frozen do
			if entry.Track.IsPlaying then entry.Track:AdjustSpeed(entry.Speed) end
		end
	end)
end

function RimPresentation.Track(player: Player, character: Model, humanoid: Humanoid, root: BasePart)
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then return nil end
	local function joint(partName: string, jointName: string)
		local part = character:FindFirstChild(partName)
		local found = part and part:FindFirstChild(jointName)
		return found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) and found or nil
	end
	return {
		Player = player,
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Joints = {
			Waist = joint("UpperTorso", "Waist"),
			RightHip = joint("RightUpperLeg", "RightHip"),
			LeftHip = joint("LeftUpperLeg", "LeftHip"),
			RightKnee = joint("RightLowerLeg", "RightKnee"),
			LeftKnee = joint("LeftLowerLeg", "LeftKnee"),
			RightAnkle = joint("RightFoot", "RightAnkle"),
			LeftAnkle = joint("LeftFoot", "LeftAnkle"),
		},
		Grips = {},
		GripWeight = 0,
		HangElapsed = 0,
		Hanging = false,
		Hoop = nil,
	}
end

local function ensureGrip(state, side: string)
	local grip = state.Grips[side]
	if grip and grip.Control.Parent == state.Humanoid then return grip end
	local upper = state.Character:FindFirstChild(side .. "UpperArm")
	local hand = state.Character:FindFirstChild(side .. "Hand")
	if not upper or not hand then return nil end
	local target = Instance.new("Attachment")
	target.Name = "LocalRimGrip" .. side
	target.Parent = Workspace.Terrain
	local control = Instance.new("IKControl")
	control.Name = "LocalRimGrip" .. side
	control.Type = Enum.IKControlType.Position
	control.ChainRoot = upper
	control.EndEffector = hand
	control.Target = target
	control.SmoothTime = 0
	control.Weight = 0
	control.Priority = 3
	control.Parent = state.Humanoid
	grip = { Control = control, Target = target, Hand = hand }
	state.Grips[side] = grip
	return grip
end

local function clearGrips(state)
	for side, grip in state.Grips do
		grip.Control:Destroy()
		grip.Target:Destroy()
		state.Grips[side] = nil
	end
	state.GripWeight = 0
end

-- Called when this player's dunked ball leaves the hand at the rim.
function RimPresentation.Impact(player: Player, humanoid: Humanoid, releasePosition: Vector3)
	local rim = findRim(player)
	if rim then
		local hoop = getHoop(rim)
		hoop.Velocity += math.rad(Config.ImpactKickDegreesPerSecond)
	end
	local style = Styles.Get(player:GetAttribute("EquippedDunkStyle"))
	sparks(releasePosition, style and math.clamp(style.Order / 3, 0.6, 1.4) or 1)
	if player == localPlayer then hitStop(humanoid) end
end

-- Runs after the Animator each frame (PreSimulation) so it can override the legs.
function RimPresentation.Update(state, deltaTime: number)
	local hanging = state.Player:GetAttribute("DunkPhase") == "Hang"
	if hanging and not state.Hanging then state.HangElapsed = 0 end
	state.Hanging = hanging
	local rim = hanging and findRim(state.Player) or nil
	if rim then state.Hoop = getHoop(rim) end

	local rate = deltaTime / (hanging and Config.GripBlendInSeconds or Config.GripBlendOutSeconds)
	state.GripWeight = math.clamp(state.GripWeight + (hanging and rate or -rate), 0, 1)
	if state.GripWeight <= 0 and not hanging then
		clearGrips(state)
		return
	end

	local hoop = state.Hoop
	if not hoop then return end
	state.HangElapsed += deltaTime
	local style = Styles.Get(state.Player:GetAttribute("EquippedDunkStyle"))
	local twoHands = style and table.find(style.Pose.Hands, "Left") ~= nil
	local toward = Vector3.new(state.Root.Position.X - hoop.Rim.Position.X, 0, state.Root.Position.Z - hoop.Rim.Position.Z)
	toward = toward.Magnitude > 1e-3 and toward.Unit or -hoop.Back
	local side = toward:Cross(Vector3.yAxis)
	local frontEdge = hoop.Rim.Position + toward * hoop.Radius
	for _, handSide in (twoHands and { "Right", "Left" } or { "Right" }) do
		local grip = ensureGrip(state, handSide)
		if grip then
			local spread = twoHands and Config.GripHandSpacing * (handSide == "Right" and -1 or 1) or 0
			grip.Target.WorldPosition = frontEdge + side * spread + Vector3.new(0, grip.Hand.Size.Y / 2, 0)
			grip.Control.Weight = smooth(state.GripWeight)
		end
	end

	-- Legs swing under the rim and settle.
	local weight = smooth(state.GripWeight)
	local t = state.HangElapsed
	local swing = math.sin(t * Config.HangSwingSpeed) * math.exp(-t * Config.HangSwingDecay)
	local hip = math.rad(Config.HangHipDegrees + Config.HangSwingDegrees * swing)
	local knee = -math.rad(Config.HangKneeDegrees + Config.HangSwingDegrees * 0.6 * swing)
	local joints = state.Joints
	local pose = {
		RightHip = CFrame.Angles(hip * 0.8, 0, math.rad(6)),
		LeftHip = CFrame.Angles(hip, 0, math.rad(-6)),
		RightKnee = CFrame.Angles(knee * 1.2, 0, 0),
		LeftKnee = CFrame.Angles(knee, 0, 0),
		RightAnkle = CFrame.Angles(math.rad(-25), 0, 0),
		LeftAnkle = CFrame.Angles(math.rad(-25), 0, 0),
		Waist = CFrame.Angles(math.rad(6) - hip * 0.2, 0, 0),
	}
	for name, target in pose do
		local found = joints[name]
		if found then found.Transform = found.Transform:Lerp(target, weight) end
	end
end

-- Spring every bent ring back toward rest (or toward the hang bend).
function RimPresentation.StepHoops(deltaTime: number, hangingRims: { [BasePart]: boolean })
	for rim, hoop in hoops do
		if not rim.Parent then
			hoops[rim] = nil
			continue
		end
		local target = hangingRims[rim] and math.rad(Config.HangBendDegrees) or 0
		hoop.Velocity += ((target - hoop.Angle) * Config.Stiffness - hoop.Velocity * Config.Damping) * deltaTime
		hoop.Angle += hoop.Velocity * deltaTime
		local resting = math.abs(hoop.Angle) < 1e-3 and math.abs(hoop.Velocity) < 1e-2 and target == 0
		if resting then
			if hoop.Applied then
				hoop.Angle, hoop.Velocity = 0, 0
				applyBend(hoop)
				hoop.Applied = false
			end
		else
			applyBend(hoop)
			hoop.Applied = true
		end
	end
end

function RimPresentation.HangingRim(state): BasePart?
	return state and state.Hanging and state.Hoop and state.Hoop.Rim or nil
end

function RimPresentation.Release(state)
	if state then clearGrips(state) end
end

return RimPresentation
