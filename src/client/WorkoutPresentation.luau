-- Client-only leg-day workout played on any R15 character whose server-set "Training"
-- attribute is on (they are holding the Vertical Trainer prompt). Cycles squats,
-- lunges, jump squats and calf raises. Runs after the Animator (PreSimulation).
--
-- Joint signs: hip + swings the thigh forward, knee - bends, ankle - points the toes,
-- waist - leans forward, shoulder + raises the arm forward, right roll + / left - = outward.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PresentationConfig).Workout

local WorkoutPresentation = {}

local routineSeconds = 0
for _, step in Config.Routine do routineSeconds += step.Reps * step.RepSeconds end

local function smooth(alpha: number): number
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

local function angles(pitch: number, yaw: number?, roll: number?): CFrame
	return CFrame.Angles(math.rad(pitch), math.rad(yaw or 0), math.rad(roll or 0))
end

function WorkoutPresentation.Track(player: Player, character: Model, humanoid: Humanoid, root: BasePart, crouchAngles)
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then return nil end
	local function joint(partName: string, jointName: string)
		local part = character:FindFirstChild(partName)
		local found = part and part:FindFirstChild(jointName)
		return found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) and found or nil
	end
	local upper = character:FindFirstChild("RightUpperLeg")
	local lower = character:FindFirstChild("RightLowerLeg")
	return {
		Player = player,
		Humanoid = humanoid,
		Root = root,
		Crouch = crouchAngles,
		Thigh = upper and upper.Size.Y or 1.2,
		Shin = lower and lower.Size.Y or 1.2,
		Joints = {
			Root = joint("LowerTorso", "Root"),
			Waist = joint("UpperTorso", "Waist"),
			Neck = joint("Head", "Neck"),
			RightShoulder = joint("RightUpperArm", "RightShoulder"),
			RightElbow = joint("RightLowerArm", "RightElbow"),
			LeftShoulder = joint("LeftUpperArm", "LeftShoulder"),
			LeftElbow = joint("LeftLowerArm", "LeftElbow"),
			RightHip = joint("RightUpperLeg", "RightHip"),
			RightKnee = joint("RightLowerLeg", "RightKnee"),
			RightAnkle = joint("RightFoot", "RightAnkle"),
			LeftHip = joint("LeftUpperLeg", "LeftHip"),
			LeftKnee = joint("LeftLowerLeg", "LeftKnee"),
			LeftAnkle = joint("LeftFoot", "LeftAnkle"),
		},
		Clock = 0,
		Weight = 0,
	}
end

-- Both legs bend so the pelvis drops `drop` studs with the feet planted.
local function squatLegs(state, pose, drop: number)
	local hip, knee, ankle = state.Crouch(state.Thigh, state.Shin, drop)
	for _, side in { "Right", "Left" } do
		pose[side .. "Hip"] = CFrame.Angles(hip, 0, 0)
		pose[side .. "Knee"] = CFrame.Angles(knee, 0, 0)
		pose[side .. "Ankle"] = CFrame.Angles(ankle, 0, 0)
	end
end

local EXERCISES = {
	Squat = function(state, p: number)
		local depth = math.sin(math.pi * p) ^ 2
		local drop = Config.SquatDrop * depth
		local pose = { Root = CFrame.new(0, -drop, 0), Waist = angles(-28 * depth), Neck = angles(18 * depth) }
		squatLegs(state, pose, drop)
		pose.RightShoulder = angles(10 + 80 * depth, 0, -6)
		pose.LeftShoulder = angles(10 + 80 * depth, 0, 6)
		pose.RightElbow = angles(10)
		pose.LeftElbow = angles(10)
		return pose
	end,
	Lunge = function(state, p: number, rep: number)
		local depth = math.sin(math.pi * p) ^ 2
		local front = rep % 2 == 0 and "Right" or "Left"
		local back = front == "Right" and "Left" or "Right"
		local pose = { Root = CFrame.new(0, -Config.LungeDrop * depth, 0), Waist = angles(-4 * depth) }
		pose[front .. "Hip"] = angles(72 * depth)
		pose[front .. "Knee"] = angles(-95 * depth)
		pose[front .. "Ankle"] = angles(23 * depth)
		pose[back .. "Hip"] = angles(-28 * depth)
		pose[back .. "Knee"] = angles(-82 * depth)
		pose[back .. "Ankle"] = angles(-20 * depth)
		-- Arms swing opposite the front leg for balance.
		local swing = front == "Right" and 1 or -1
		pose.RightShoulder = angles(-25 * swing * depth, 0, 8)
		pose.LeftShoulder = angles(25 * swing * depth, 0, -8)
		pose.RightElbow = angles(25 + 20 * depth)
		pose.LeftElbow = angles(25 + 20 * depth)
		return pose
	end,
	JumpSquat = function(state, p: number)
		local pose = {}
		if p < 0.4 then
			local depth = smooth(p / 0.4)
			pose.Root = CFrame.new(0, -Config.SquatDrop * 0.85 * depth, 0)
			squatLegs(state, pose, Config.SquatDrop * 0.85 * depth)
			pose.Waist = angles(-24 * depth)
			pose.RightShoulder = angles(-35 * depth, 0, 8)
			pose.LeftShoulder = angles(-35 * depth, 0, -8)
		elseif p < 0.78 then
			local air = math.sin(math.pi * (p - 0.4) / 0.38)
			pose.Root = CFrame.new(0, Config.JumpHeight * air, 0)
			pose.RightHip, pose.LeftHip = angles(18 * air), angles(18 * air)
			pose.RightKnee, pose.LeftKnee = angles(-32 * air), angles(-32 * air)
			pose.RightAnkle, pose.LeftAnkle = angles(-25 * air), angles(-25 * air)
			pose.RightShoulder = angles(160 * air, 0, 10)
			pose.LeftShoulder = angles(160 * air, 0, -10)
		else
			local land = math.sin(math.pi * (p - 0.78) / 0.22)
			pose.Root = CFrame.new(0, -0.45 * land, 0)
			squatLegs(state, pose, 0.45 * land)
			pose.Waist = angles(-12 * land)
		end
		pose.RightElbow, pose.LeftElbow = angles(15), angles(15)
		return pose
	end,
	CalfRaise = function(state, p: number)
		local lift = math.sin(math.pi * p) ^ 2
		return {
			Root = CFrame.new(0, Config.CalfRaiseHeight * lift, 0),
			RightAnkle = angles(-38 * lift), LeftAnkle = angles(-38 * lift),
			RightHip = CFrame.identity, LeftHip = CFrame.identity,
			RightKnee = CFrame.identity, LeftKnee = CFrame.identity,
			RightShoulder = angles(0, 0, 10), LeftShoulder = angles(0, 0, -10),
			Waist = CFrame.identity,
		}
	end,
}

-- Returns true while the workout owns the pose (other body layers should step aside).
function WorkoutPresentation.Update(state, deltaTime: number): boolean
	local velocity = state.Root.AssemblyLinearVelocity
	local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > Config.MaxMoveSpeed
	local active = state.Player:GetAttribute("Training") == true and not moving and state.Humanoid.Health > 0
	local rate = deltaTime / Config.BlendSeconds
	state.Weight = math.clamp(state.Weight + (active and rate or -rate), 0, 1)
	if state.Weight <= 0 then
		state.Clock = 0
		return false
	end
	if active then state.Clock = (state.Clock + deltaTime) % routineSeconds end

	-- Find the current exercise, rep and progress through the rep.
	local elapsed = state.Clock
	local pose = nil
	for _, step in Config.Routine do
		local stepSeconds = step.Reps * step.RepSeconds
		if elapsed < stepSeconds then
			local rep = math.floor(elapsed / step.RepSeconds)
			pose = EXERCISES[step.Exercise](state, (elapsed % step.RepSeconds) / step.RepSeconds, rep)
			break
		end
		elapsed -= stepSeconds
	end
	if not pose then return state.Weight > 0 end

	local weight = smooth(state.Weight)
	for name, target in pose do
		local found = state.Joints[name]
		if found then found.Transform = found.Transform:Lerp(target, weight) end
	end
	return true
end

return WorkoutPresentation
