-- Procedural, client-only posing layered on top of each R15 character's normal
-- animations: an athletic dribble stance, a cleaner jump/fall pose, and a landing
-- crouch. It runs after the Animator each frame and never changes physics or state.
--
-- Joint sign reminder (R15 Motor6D.Transform, rotation about X):
--   torso/neck: positive leans BACK, negative leans FORWARD
--   shoulder/hip: positive swings the limb FORWARD
--   elbow: positive bends it (forearm forward); knee: negative bends it (shin back)
--   ankle: negative points the toes down
--   shoulder roll (Z): right arm negative / left arm positive moves it inward
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PresentationConfig)
local DribbleConfig = Config.Dribble
local AirConfig = Config.Air
local LandingConfig = Config.Landing

local BodyPresentation = {}

local AIR_STATES = {
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
}

local function smooth(alpha: number): number
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

local function approach(current: number, target: number, rate: number, deltaTime: number): number
	return current + (target - current) * (1 - math.exp(-rate * deltaTime))
end

-- Classic rigs use Motor6D joints; rigs with the avatar joint upgrade use
-- AnimationConstraint. Both expose the Animator-written Transform property.
local function motor(character: Model, partName: string, jointName: string): Instance?
	local part = character:FindFirstChild(partName)
	local joint = part and part:FindFirstChild(jointName)
	return joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) and joint or nil
end

local function legLength(character: Model, side: string): (number, number)
	local upper = character:FindFirstChild(side .. "UpperLeg")
	local lower = character:FindFirstChild(side .. "LowerLeg")
	return upper and upper.Size.Y or 1.2, lower and lower.Size.Y or 1.2
end

-- Hip/knee/ankle angles that lower the pelvis by `drop` studs while the foot
-- stays planted and flat (two-bone solve).
local function crouchAngles(thigh: number, shin: number, drop: number): (number, number, number)
	local full = thigh + shin
	local reach = math.clamp(full - drop, math.abs(thigh - shin) + 0.05, full)
	local kneeInner = math.acos(math.clamp((thigh * thigh + shin * shin - reach * reach) / (2 * thigh * shin), -1, 1))
	local knee = math.pi - kneeInner
	local hip = math.acos(math.clamp((thigh * thigh + reach * reach - shin * shin) / (2 * thigh * reach), -1, 1))
	return hip, -knee, knee - hip
end

BodyPresentation.CrouchAngles = crouchAngles

function BodyPresentation.Track(character: Model, humanoid: Humanoid, root: BasePart)
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then return nil end
	local joints = {
		Root = motor(character, "LowerTorso", "Root"),
		Waist = motor(character, "UpperTorso", "Waist"),
		Neck = motor(character, "Head", "Neck"),
		RightShoulder = motor(character, "RightUpperArm", "RightShoulder"),
		RightElbow = motor(character, "RightLowerArm", "RightElbow"),
		LeftShoulder = motor(character, "LeftUpperArm", "LeftShoulder"),
		LeftElbow = motor(character, "LeftLowerArm", "LeftElbow"),
		RightHip = motor(character, "RightUpperLeg", "RightHip"),
		RightKnee = motor(character, "RightLowerLeg", "RightKnee"),
		RightAnkle = motor(character, "RightFoot", "RightAnkle"),
		LeftHip = motor(character, "LeftUpperLeg", "LeftHip"),
		LeftKnee = motor(character, "LeftLowerLeg", "LeftKnee"),
		LeftAnkle = motor(character, "LeftFoot", "LeftAnkle"),
	}
	for _, name in { "Root", "Waist", "Neck", "RightShoulder", "RightElbow", "LeftShoulder", "LeftElbow",
		"RightHip", "RightKnee", "RightAnkle", "LeftHip", "LeftKnee", "LeftAnkle" } do
		if not joints[name] then return nil end
	end
	local thigh, shin = legLength(character, "Right")
	return {
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Joints = joints,
		Thigh = thigh,
		Shin = shin,
		AirWeight = 0,
		WasAirborne = false,
		LastVerticalSpeed = 0,
		LandingElapsed = math.huge,
		LandingDip = 0,
		StanceWeight = 0,
		Lean = 0,
	}
end

-- Called when a tracked character touches down; returns the impact speed.
function BodyPresentation.OnLanded(body, impactSpeed: number)
	if impactSpeed < LandingConfig.MinImpactSpeed then return end
	local strength = math.clamp((impactSpeed - LandingConfig.MinImpactSpeed)
		/ (LandingConfig.HeavyImpactSpeed - LandingConfig.MinImpactSpeed), 0, 1)
	body.LandingDip = LandingConfig.MaxDipStuds * (0.3 + 0.7 * strength)
	body.LandingElapsed = 0
end

local function landingDrop(body, deltaTime: number): number
	if body.LandingElapsed == math.huge then return 0 end
	body.LandingElapsed += deltaTime
	local t = body.LandingElapsed
	local compress = 0.07
	if t >= LandingConfig.RecoverSeconds then
		body.LandingElapsed = math.huge
		return 0
	elseif t < compress then
		return body.LandingDip * smooth(t / compress)
	end
	return body.LandingDip * (1 - smooth((t - compress) / (LandingConfig.RecoverSeconds - compress)))
end

-- Returns true when the character just landed (with its impact speed).
function BodyPresentation.Update(body, deltaTime: number, context): (boolean, number)
	local joints = body.Joints
	local humanoid = body.Humanoid
	local verticalSpeed = body.Root.AssemblyLinearVelocity.Y
	local airborne = AIR_STATES[humanoid:GetState()] == true
	local landed, impact = false, 0
	if context.Dunking or context.Training then
		-- The dunk track / workout owns the pose; reset layers so nothing pops afterwards.
		body.AirWeight = 0
		body.WasAirborne = false
		body.LandingElapsed = math.huge
		body.LastVerticalSpeed = verticalSpeed
		return false, 0
	end
	if body.WasAirborne and not airborne then
		landed, impact = true, math.max(0, -body.LastVerticalSpeed)
		BodyPresentation.OnLanded(body, impact)
	end
	body.WasAirborne = airborne
	body.LastVerticalSpeed = verticalSpeed

	-- Air layer weight.
	local airRate = deltaTime / (airborne and AirConfig.BlendInSeconds or AirConfig.BlendOutSeconds)
	body.AirWeight = math.clamp(body.AirWeight + (airborne and airRate or -airRate), 0, 1)

	-- Dribble stance weight and lean.
	local stanceTarget = context.Dribbling and not airborne and 1 or 0
	body.StanceWeight = approach(body.StanceWeight, stanceTarget, 10, deltaTime)
	local leanTarget = DribbleConfig.IdleLeanDegrees
		+ (DribbleConfig.RunLeanDegrees - DribbleConfig.IdleLeanDegrees) * context.RunFraction
	body.Lean = approach(body.Lean, leanTarget, DribbleConfig.LeanSmoothing, deltaTime)

	-- Pelvis drop from landing plus a small athletic crouch while dribbling.
	local drop = landingDrop(body, deltaTime) + 0.18 * body.StanceWeight
	if drop > 1e-3 then
		local hip, knee, ankle = crouchAngles(body.Thigh, body.Shin, drop)
		joints.Root.Transform = CFrame.new(0, -drop, 0) * joints.Root.Transform
		for _, side in { "Right", "Left" } do
			joints[side .. "Hip"].Transform *= CFrame.Angles(hip, 0, 0)
			joints[side .. "Knee"].Transform *= CFrame.Angles(knee, 0, 0)
			joints[side .. "Ankle"].Transform *= CFrame.Angles(ankle, 0, 0)
		end
		-- Chest folds forward a little with the crouch.
		joints.Waist.Transform *= CFrame.Angles(-drop * 0.5, 0, 0)
	end

	if body.StanceWeight > 1e-3 then
		local lean = math.rad(body.Lean) * body.StanceWeight
		joints.Waist.Transform *= CFrame.Angles(-lean, 0, 0)
		joints.Neck.Transform *= CFrame.Angles(lean * 0.6, 0, 0)
		local guard = math.rad(DribbleConfig.OffArmGuardDegrees) * body.StanceWeight
		joints.LeftShoulder.Transform *= CFrame.Angles(guard, 0, -guard * 0.6)
		joints.LeftElbow.Transform *= CFrame.Angles(guard * 1.2, 0, 0)
	end

	if body.AirWeight > 1e-3 then
		local weight = smooth(body.AirWeight)
		local rising = math.clamp(verticalSpeed / AirConfig.TuckSpeedReference, 0, 1)
		local falling = math.clamp(-verticalSpeed / AirConfig.TuckSpeedReference, 0, 1)
		local tuck = math.rad(AirConfig.RiseTuckDegrees) * rising
		local reach = math.rad(AirConfig.FallReachDegrees) * falling
		local hip = tuck + reach
		local knee = -(tuck * 1.7 + reach * 0.6)
		local airPose = {
			RightHip = CFrame.Angles(hip * 0.85, 0, math.rad(4)),
			LeftHip = CFrame.Angles(hip, 0, math.rad(-4)),
			RightKnee = CFrame.Angles(knee * 0.85, 0, 0),
			LeftKnee = CFrame.Angles(knee, 0, 0),
			RightAnkle = CFrame.Angles(math.rad(-18), 0, 0),
			LeftAnkle = CFrame.Angles(math.rad(-18), 0, 0),
			Waist = CFrame.Angles(-tuck * 0.25, 0, 0),
		}
		local armLift = math.rad(AirConfig.ArmLiftDegrees) * (0.4 + 0.6 * rising)
		if context.HoldingBall then
			-- Ball tucked at the chest in both hands.
			local chest = math.rad(AirConfig.HeldBallChestLift)
			airPose.RightShoulder = CFrame.Angles(chest, 0, math.rad(-12))
			airPose.RightElbow = CFrame.Angles(math.rad(75), 0, 0)
			airPose.LeftShoulder = CFrame.Angles(chest, 0, math.rad(22))
			airPose.LeftElbow = CFrame.Angles(math.rad(80), 0, 0)
		else
			airPose.RightShoulder = CFrame.Angles(armLift, 0, math.rad(18))
			airPose.RightElbow = CFrame.Angles(math.rad(25), 0, 0)
			airPose.LeftShoulder = CFrame.Angles(armLift, 0, math.rad(-18))
			airPose.LeftElbow = CFrame.Angles(math.rad(25), 0, 0)
		end
		for name, pose in airPose do
			local joint = joints[name]
			joint.Transform = joint.Transform:Lerp(pose, weight)
		end
	end
	return landed, impact
end

function BodyPresentation.Release(body)
	-- Transforms are rewritten by the Animator every frame, so nothing to undo.
	body.AirWeight = 0
	body.StanceWeight = 0
end

return BodyPresentation
