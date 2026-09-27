-- Client-only posing for the dunk "Descent" phase: when a high jump drops into the
-- dunk, the player plays the server-chosen air-trick combo (DunkTricks attribute) with
-- the ball at the chest, then opens up right as the wind-up clip starts. Each trick has
-- its own rotation around the hips and body shape (tuck, layout, star, pike). The
-- physical root never rotates. Trick timing comes from shared DunkRewards config, the
-- same timeline the server uses to pay each trick.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PresentationConfig).Descent
local DunkRewards = require(ReplicatedStorage.Shared.Config.DunkRewards)

local DescentPresentation = {}

local TWO_PI = math.pi * 2

local function smooth(alpha: number): number
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

-- Body rotation (applied at the Root joint, around the hips) for each trick; every trick
-- ends back upright so combos chain without a pop.
local ROTATIONS = {
	Spin360 = function(turn: number) return CFrame.Angles(0, TWO_PI * turn, 0) end,
	Spin720 = function(turn: number) return CFrame.Angles(0, 2 * TWO_PI * turn, 0) end,
	FrontFlip = function(turn: number) return CFrame.Angles(-TWO_PI * turn, 0, 0) end,
	BackFlip = function(turn: number) return CFrame.Angles(TWO_PI * turn, 0, 0) end,
	Cartwheel = function(turn: number) return CFrame.Angles(0, 0, TWO_PI * turn) end,
	Corkscrew = function(turn: number)
		return CFrame.Angles(0, TWO_PI * turn, 0) * CFrame.Angles(-TWO_PI * turn, 0, 0)
	end,
}

-- Body shape held during each trick (see PresentationConfig.Descent.Shapes).
local SHAPE_OF = {
	Spin360 = "Layout", Spin720 = "Pike", FrontFlip = "Tuck", BackFlip = "Tuck",
	Cartwheel = "Star", Corkscrew = "Pike",
}

function DescentPresentation.Track(player: Player, character: Model, humanoid: Humanoid)
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then return nil end
	local function joint(partName: string, jointName: string)
		local part = character:FindFirstChild(partName)
		local found = part and part:FindFirstChild(jointName)
		return found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) and found or nil
	end
	return {
		Player = player,
		Joints = {
			Root = joint("LowerTorso", "Root"),
			Waist = joint("UpperTorso", "Waist"),
			Neck = joint("Head", "Neck"),
			RightShoulder = joint("RightUpperArm", "RightShoulder"),
			RightElbow = joint("RightLowerArm", "RightElbow"),
			LeftShoulder = joint("LeftUpperArm", "LeftShoulder"),
			LeftElbow = joint("LeftLowerArm", "LeftElbow"),
			RightHip = joint("RightUpperLeg", "RightHip"),
			LeftHip = joint("LeftUpperLeg", "LeftHip"),
			RightKnee = joint("RightLowerLeg", "RightKnee"),
			LeftKnee = joint("LeftLowerLeg", "LeftKnee"),
			RightAnkle = joint("RightFoot", "RightAnkle"),
			LeftAnkle = joint("LeftFoot", "LeftAnkle"),
		},
		Active = false,
		Elapsed = 0,
		Duration = 0.4,
		Combo = {},
		Weight = 0,
		Shape = table.clone(Config.Shapes.Tuck),
	}
end

-- Current trick and 0..1 progress through it, or nil between tricks.
local function currentTrick(state): (string?, number)
	local clock = DunkRewards.Tricks.TuckSeconds
	for _, trickId in state.Combo do
		local trick = DunkRewards.GetTrick(trickId)
		local seconds = trick and trick.Seconds or 0
		if state.Elapsed < clock + seconds then
			return trickId, math.max(state.Elapsed - clock, 0) / seconds
		end
		clock += seconds
	end
	return nil, 1
end

-- Runs after the Animator each frame (PreSimulation).
function DescentPresentation.Update(state, deltaTime: number)
	local player = state.Player
	local descending = player:GetAttribute("DunkPhase") == "Descent"
	if descending and not state.Active then
		state.Elapsed = 0
		state.Duration = math.max(tonumber(player:GetAttribute("DunkDescentSeconds")) or 0.4, 0.1)
		local list = player:GetAttribute("DunkTricks")
		state.Combo = type(list) == "string" and list ~= "" and string.split(list, ",") or {}
		state.Shape = table.clone(Config.Shapes.Tuck)
	end
	state.Active = descending
	local rate = deltaTime / (descending and Config.BlendInSeconds or Config.BlendOutSeconds)
	state.Weight = math.clamp(state.Weight + (descending and rate or -rate), 0, 1)
	if state.Weight <= 0 then return end
	if descending then state.Elapsed += deltaTime end

	local joints = state.Joints
	local weight = smooth(state.Weight)
	local trickId, turn = currentTrick(state)

	-- Rotation for the trick in progress (identity between tricks).
	local rotate = trickId and ROTATIONS[trickId]
	if rotate and joints.Root then
		joints.Root.Transform = CFrame.identity:Lerp(rotate(smooth(turn)), weight) * joints.Root.Transform
	end

	-- Body shape eases toward the current trick's shape, and opens up at the end.
	local progress = math.clamp(state.Elapsed / state.Duration, 0, 1)
	local open = smooth((progress - Config.UntuckStartFraction) / (1 - Config.UntuckStartFraction))
	local target = Config.Shapes[trickId and SHAPE_OF[trickId] or "Tuck"]
	local blend = 1 - math.exp(-Config.ShapeBlendRate * deltaTime)
	for key, value in target do
		state.Shape[key] += (value - state.Shape[key]) * blend
	end
	local shape = state.Shape
	local fold = 1 - (1 - Config.EndTuck) * open
	local hip = math.rad(shape.Hip) * fold
	local knee = -math.rad(shape.Knee) * fold
	local spread = math.rad(shape.Spread) * (1 - open)
	-- 0..1: how far into the star shape; the free left arm swings out with the legs.
	local star = spread / math.max(math.rad(Config.Shapes.Star.Spread), 1e-3)
	local chest = math.rad(Config.BallChestLiftDegrees)
	local elbow = math.rad(Config.BallElbowDegrees)
	local pose = {
		Waist = CFrame.Angles(-math.rad(shape.Waist) * fold, 0, 0),
		Neck = CFrame.Angles(math.rad(8) * fold, 0, 0),
		RightShoulder = CFrame.Angles(chest, 0, math.rad(-14)),
		RightElbow = CFrame.Angles(elbow, 0, 0),
		LeftShoulder = CFrame.Angles(chest * (1 - 0.6 * star), 0, math.rad(14) - math.rad(Config.StarArmDegrees) * star),
		LeftElbow = CFrame.Angles(elbow * (1 - 0.8 * star), 0, 0),
		RightHip = CFrame.Angles(hip * 0.9, 0, math.rad(5) + spread),
		LeftHip = CFrame.Angles(hip, 0, math.rad(-5) - spread),
		RightKnee = CFrame.Angles(knee * 0.9, 0, 0),
		LeftKnee = CFrame.Angles(knee, 0, 0),
		RightAnkle = CFrame.Angles(math.rad(-30), 0, 0),
		LeftAnkle = CFrame.Angles(math.rad(-30), 0, 0),
	}
	for name, goal in pose do
		local found = joints[name]
		if found then found.Transform = found.Transform:Lerp(goal, weight) end
	end
end

return DescentPresentation
