-- Local "game feel" for jumping and landing: extra fall gravity for the local
-- player's own physics, a short camera dip on landing, and a dust puff for any
-- character that lands hard. Server jump height and dunk rules are unchanged.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.PresentationConfig)
local AirConfig = Config.Air
local LandingConfig = Config.Landing

local LocomotionFeel = {}

local fallForce: VectorForce? = nil
local fallAttachment: Attachment? = nil
local cameraDip = 0
local cameraDipElapsed = math.huge

local function clearFallForce()
	if fallForce then fallForce:Destroy() end
	if fallAttachment then fallAttachment:Destroy() end
	fallForce = nil
	fallAttachment = nil
end

-- Adds gravity while the local character falls so jumps feel less floaty.
function LocomotionFeel.UpdateLocalPhysics(humanoid: Humanoid, root: BasePart, dunking: boolean)
	if not fallForce or fallForce.Parent ~= root then
		clearFallForce()
		local attachment = Instance.new("Attachment")
		attachment.Name = "LocalFallAttachment"
		attachment.Parent = root
		local force = Instance.new("VectorForce")
		force.Name = "LocalFallGravity"
		force.Attachment0 = attachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = true
		force.Force = Vector3.zero
		force.Parent = root
		fallAttachment = attachment
		fallForce = force
	end
	local falling = not dunking and humanoid:GetState() == Enum.HumanoidStateType.Freefall
		and root.AssemblyLinearVelocity.Y < 0
	local extra = falling and root.AssemblyMass * Workspace.Gravity * (AirConfig.FallGravityMultiplier - 1) or 0
	fallForce.Force = Vector3.new(0, -extra, 0)
end

function LocomotionFeel.ReleaseLocal()
	clearFallForce()
	cameraDipElapsed = math.huge
end

function LocomotionFeel.LocalLanded(impactSpeed: number)
	if impactSpeed < LandingConfig.MinImpactSpeed then return end
	local strength = math.clamp((impactSpeed - LandingConfig.MinImpactSpeed)
		/ (LandingConfig.HeavyImpactSpeed - LandingConfig.MinImpactSpeed), 0, 1)
	cameraDip = LandingConfig.CameraDipStuds * (0.35 + 0.65 * strength)
	cameraDipElapsed = 0
end

-- Applied after the camera scripts each frame; purely additive.
function LocomotionFeel.ApplyCamera(deltaTime: number)
	if cameraDipElapsed == math.huge then return end
	cameraDipElapsed += deltaTime
	local t = cameraDipElapsed
	local down, total = 0.06, LandingConfig.RecoverSeconds + 0.08
	local amount
	if t >= total then
		cameraDipElapsed = math.huge
		return
	elseif t < down then
		amount = cameraDip * (t / down)
	else
		local alpha = (t - down) / (total - down)
		amount = cameraDip * (1 - alpha * alpha * (3 - 2 * alpha))
	end
	local camera = Workspace.CurrentCamera
	if camera and camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CFrame *= CFrame.new(0, -amount, 0)
	end
end

function LocomotionFeel.Dust(root: BasePart, humanoid: Humanoid, impactSpeed: number)
	if impactSpeed < LandingConfig.MinImpactSpeed then return end
	local strength = math.clamp((impactSpeed - LandingConfig.MinImpactSpeed)
		/ (LandingConfig.HeavyImpactSpeed - LandingConfig.MinImpactSpeed), 0, 1)
	local feetY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
	local attachment = Instance.new("Attachment")
	attachment.Name = "LocalLandingDust"
	attachment.WorldPosition = Vector3.new(root.Position.X, feetY + 0.1, root.Position.Z)
	attachment.Parent = Workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(LandingConfig.DustColor)
	emitter.LightEmission = 0
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 2.2 + 1.5 * strength),
	})
	emitter.Lifetime = NumberRange.new(0.35, 0.6)
	emitter.Speed = NumberRange.new(6 + 8 * strength, 10 + 12 * strength)
	emitter.SpreadAngle = Vector2.new(85, 85)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -8, 0)
	emitter.Drag = 6
	emitter.Rate = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Parent = attachment
	emitter:Emit(math.floor(LandingConfig.DustParticles
		+ (LandingConfig.HeavyDustParticles - LandingConfig.DustParticles) * strength))
	task.delay(1, function() attachment:Destroy() end)
end

return LocomotionFeel
