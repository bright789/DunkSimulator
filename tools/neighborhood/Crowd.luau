-- Builder-made spectators shared by the Neighborhood and High School builders (edit mode
-- only). Each one is a real R15 avatar from a HumanoidDescription, recolored into
-- clothes, dressed with part-built hats/props, posed by forward kinematics and fully
-- anchored. The Humanoid, scripts and physics constraints are stripped; the joint
-- AnimationConstraints stay so CrowdPresentation (client) can animate the pose.
local Players = game:GetService("Players")
local Geometry = require(script.Parent.Geometry)

local Crowd = {}

-- Joint angles in degrees {pitch, yaw, roll}. Signs (measured): hip/shoulder + swings
-- forward, knee - bends, ankle - points toes, waist/neck + leans back,
-- shoulder roll: right - / left + moves the arm inward.
local POSES = {
	Stand = {
		RightShoulder = { 0, 0, 5 }, LeftShoulder = { 0, 0, -5 }, RightElbow = { 12 }, LeftElbow = { 12 },
	},
	-- Arms folded: upper arms twisted inward (yaw) so the bent forearms cross the chest.
	StandCrossed = {
		RightShoulder = { 18, 72, -8 }, LeftShoulder = { 22, -72, 8 }, RightElbow = { 98 }, LeftElbow = { 92 },
		Neck = { -4 },
	},
	Sit = {
		RightHip = { 90, 0, 3 }, LeftHip = { 90, 0, -3 }, RightKnee = { -82 }, LeftKnee = { -82 },
		RightShoulder = { 28, 0, -6 }, LeftShoulder = { 28, 0, 6 }, RightElbow = { 55 }, LeftElbow = { 55 },
		Waist = { -4 },
	},
	SitLean = {
		RightHip = { 92, 0, 5 }, LeftHip = { 92, 0, -5 }, RightKnee = { -88 }, LeftKnee = { -88 },
		Waist = { -20 }, Neck = { 14 },
		RightShoulder = { 48, 0, -8 }, LeftShoulder = { 48, 0, 8 }, RightElbow = { 88 }, LeftElbow = { 88 },
	},
	SitClap = {
		RightHip = { 90, 0, 3 }, LeftHip = { 90, 0, -3 }, RightKnee = { -80 }, LeftKnee = { -80 },
		RightShoulder = { 62, 0, -26 }, LeftShoulder = { 62, 0, 26 }, RightElbow = { 72 }, LeftElbow = { 72 },
	},
}

local SEATED = { Sit = true, SitLean = true, SitClap = true }

local function angles(values)
	if not values then return CFrame.identity end
	return CFrame.Angles(math.rad(values[1] or 0), math.rad(values[2] or 0), math.rad(values[3] or 0))
end

local function jointParts(joint: Instance)
	if joint:IsA("Motor6D") then
		return joint.Part0, joint.Part1, joint.C0, joint.C1
	elseif joint:IsA("AnimationConstraint") and joint.Attachment0 and joint.Attachment1 then
		return joint.Attachment0.Parent, joint.Attachment1.Parent, joint.Attachment0.CFrame, joint.Attachment1.CFrame
	end
	return nil
end

-- Places every limb from the root outward: child = parent * C0 * pose * C1^-1.
local function applyPose(model: Model, root: BasePart, pose)
	local joints = {}
	for _, joint in model:GetDescendants() do
		if jointParts(joint) then table.insert(joints, joint) end
	end
	local placed = { [root] = true }
	local progress = true
	while progress do
		progress = false
		for _, joint in joints do
			local parent, child, c0, c1 = jointParts(joint)
			if placed[parent] and child and not placed[child] then
				child.CFrame = parent.CFrame * c0 * angles(pose[joint.Name]) * c1:Inverse()
				placed[child] = true
				progress = true
			end
		end
	end
end

local function lowestY(part: BasePart): number
	local cf, half = part.CFrame, part.Size / 2
	local reach = math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z
	return cf.Position.Y - reach
end

local function translate(model: Model, offset: Vector3)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then part.CFrame += offset end
	end
end

-- Part-built headwear and hand props, parented to the part they ride on.
local function dress(model: Model, look)
	local head = model:FindFirstChild("Head")
	if head and look.Hat then
		local w, h, d = head.Size.X, head.Size.Y, head.Size.Z
		local top = head.CFrame * CFrame.new(0, h / 2, 0)
		local color = look.HatColor or look.Shirt
		if look.Hat == "Cap" or look.Hat == "BackwardsCap" then
			local brimZ = look.Hat == "Cap" and -1 or 1
			Geometry.Part(head, "CapCrown", Vector3.new(w * 1.04, h * 0.32, d * 1.04), top * CFrame.new(0, -h * 0.08, 0), color)
			Geometry.Part(head, "CapBrim", Vector3.new(w * 0.86, 0.08, d * 0.5), top * CFrame.new(0, -h * 0.2, brimZ * d * 0.7), color)
		elseif look.Hat == "Beanie" then
			Geometry.Part(head, "Beanie", Vector3.new(w * 1.08, h * 0.5, d * 1.08), top * CFrame.new(0, -h * 0.14, 0), color, Enum.Material.Fabric)
			Geometry.Part(head, "BeanieCuff", Vector3.new(w * 1.12, h * 0.14, d * 1.12), top * CFrame.new(0, -h * 0.38, 0), look.HatTrim or color:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Fabric)
		elseif look.Hat == "Headband" then
			Geometry.Part(head, "Hair", Vector3.new(w * 1.04, h * 0.22, d * 1.04), top * CFrame.new(0, -h * 0.05, 0), look.HairColor)
			Geometry.Part(head, "Headband", Vector3.new(w * 1.07, h * 0.16, d * 1.07), top * CFrame.new(0, -h * 0.24, 0), color)
		elseif look.Hat == "ShortHair" then
			Geometry.Part(head, "Hair", Vector3.new(w * 1.05, h * 0.26, d * 1.05), top * CFrame.new(0, -h * 0.06, 0), look.HairColor)
			Geometry.Part(head, "HairBack", Vector3.new(w * 1.05, h * 0.5, d * 0.22), head.CFrame * CFrame.new(0, h * 0.12, d * 0.46), look.HairColor)
		elseif look.Hat == "Puff" then
			local puff = Geometry.Part(head, "Hair", Vector3.new(w * 1.5, w * 1.5, w * 1.5), top * CFrame.new(0, h * 0.02, d * 0.08), look.HairColor, Enum.Material.Fabric)
			puff.Shape = Enum.PartType.Ball
		end
	end
	local hand = model:FindFirstChild("RightHand")
	if hand and look.Prop == "FoamFinger" then
		local color = look.PropColor or Color3.fromRGB(255, 132, 34)
		local palm = Geometry.Part(hand, "FoamHand", Vector3.new(0.7, 0.8, 0.35), hand.CFrame * CFrame.new(0, -0.55, 0), color, Enum.Material.Foil)
		Geometry.Part(hand, "FoamFinger", Vector3.new(0.24, 0.9, 0.3), palm.CFrame * CFrame.new(0.12, -0.8, 0), color, Enum.Material.Foil)
	end
end

-- look = { Skin, Shirt, Pants, Shoes, LongSleeves?, Hat?, HatColor?, HairColor?, Prop?, PropColor? }
-- Stand poses: `frame` is the floor point under the feet, facing LookVector.
-- Seated poses: `frame` is the seat-top point under the hips, facing LookVector.
function Crowd.Spectator(parent: Instance, name: string, frame: CFrame, poseName: string, look)
	local model = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	model.Name = name
	local root = model:FindFirstChild("HumanoidRootPart")
	assert(root and root:IsA("BasePart"), "Spectator rig has no HumanoidRootPart")
	model.PrimaryPart = root
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Humanoid") or item:IsA("BodyColors")
			or item:IsA("BallSocketConstraint") or item:IsA("NoCollisionConstraint") or item:IsA("WrapTarget") then
			item:Destroy()
		end
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		end
	end
	local colors = {
		Head = look.Skin, UpperTorso = look.Shirt, LowerTorso = look.Pants,
		LeftUpperArm = look.Shirt, RightUpperArm = look.Shirt,
		LeftLowerArm = look.LongSleeves and look.Shirt or look.Skin, RightLowerArm = look.LongSleeves and look.Shirt or look.Skin,
		LeftHand = look.Skin, RightHand = look.Skin,
		LeftUpperLeg = look.Pants, RightUpperLeg = look.Pants, LeftLowerLeg = look.Pants, RightLowerLeg = look.Pants,
		LeftFoot = look.Shoes, RightFoot = look.Shoes,
	}
	for partName, color in colors do
		local part = model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then part.Color = color end
	end

	root.CFrame = CFrame.lookAt(Vector3.zero, frame.LookVector * Vector3.new(1, 0, 1))
	applyPose(model, root, POSES[poseName] or POSES.Stand)
	dress(model, look)

	-- Settle the posed body onto the floor or seat.
	local floorY = frame.Position.Y
	if SEATED[poseName] then
		local contact = math.huge
		for _, partName in { "LowerTorso", "LeftUpperLeg", "RightUpperLeg" } do
			local part = model:FindFirstChild(partName)
			if part then contact = math.min(contact, lowestY(part)) end
		end
		local hips = model:FindFirstChild("LowerTorso")
		local horizontal = hips and (frame.Position - hips.Position) * Vector3.new(1, 0, 1) or Vector3.zero
		translate(model, horizontal + Vector3.new(0, floorY - contact, 0))
	else
		local contact = math.huge
		for _, partName in { "LeftFoot", "RightFoot" } do
			local part = model:FindFirstChild(partName)
			if part then contact = math.min(contact, lowestY(part)) end
		end
		translate(model, (frame.Position - root.Position) * Vector3.new(1, 0, 1) + Vector3.new(0, floorY - contact, 0))
	end
	-- CrowdPresentation (client) finds spectators by this tag; atomic streaming delivers
	-- each rig whole so its joints can be read in one go.
	model:AddTag("Spectator")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Seated", SEATED[poseName] == true)
	model.Parent = parent
	return model
end

return Crowd
