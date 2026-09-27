local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Config = require(script.Parent.Config)
local Poses = require(script.Parent.Poses)

local Build = {}

local hierarchy = {
	Name = "HumanoidRootPart",
	Children = {
		{
			Name = "LowerTorso",
			Children = {
				{
					Name = "UpperTorso",
					Children = {
						{ Name = "Head" },
						{ Name = "RightUpperArm", Children = { { Name = "RightLowerArm", Children = { { Name = "RightHand" } } } } },
						{ Name = "LeftUpperArm", Children = { { Name = "LeftLowerArm", Children = { { Name = "LeftHand" } } } } },
					},
				},
				{ Name = "RightUpperLeg", Children = { { Name = "RightLowerLeg", Children = { { Name = "RightFoot" } } } } },
				{ Name = "LeftUpperLeg", Children = { { Name = "LeftLowerLeg", Children = { { Name = "LeftFoot" } } } } },
			},
		},
	},
}

local jointNames = {}
local function collectJoints(node)
	if node.Name ~= "HumanoidRootPart" then
		jointNames[node.Name] = true
	end
	for _, child in node.Children or {} do
		collectJoints(child)
	end
end
collectJoints(hierarchy)

local function findUnique(parent, name)
	local found = nil
	for _, child in parent:GetChildren() do
		if child.Name == name then
			assert(not found, "Duplicate " .. parent:GetFullName() .. "." .. name)
			found = child
		end
	end
	return found
end

local function checkTimeline(style, frames)
	assert(type(frames) == "table" and #frames >= 7, style.Id .. " needs a complete pose timeline")
	assert(frames[1].Time == 0 and frames[#frames].Time == style.Duration, style.Id .. " has an unexpected duration")
	-- Clips end reaching up; the client rim grab takes over from the last pose.
	local times = {}
	local animatedJoints = {}
	local lastTime = -1
	local rightArmMin = math.huge
	local rightArmMax = -math.huge
	local leftArmMax = -math.huge
	for _, frame in frames do
		assert(type(frame.Time) == "number" and frame.Time > lastTime and frame.Time <= style.Duration, style.Id .. " frame times must increase")
		lastTime = frame.Time
		times[frame.Time] = true
		for jointName, angles in frame.Joints or {} do
			assert(jointNames[jointName], style.Id .. " has unknown R15 joint " .. tostring(jointName))
			assert(typeof(angles) == "Vector3", style.Id .. " joint " .. jointName .. " needs degree angles")
			for _, value in { angles.X, angles.Y, angles.Z } do
				assert(value == value and math.abs(value) <= 180, style.Id .. " joint " .. jointName .. " has invalid rotation")
			end
			if angles.Magnitude > 0 then animatedJoints[jointName] = true end
			if jointName == "RightUpperArm" then
				rightArmMin = math.min(rightArmMin, angles.X)
				rightArmMax = math.max(rightArmMax, angles.X)
			elseif jointName == "LeftUpperArm" then
				leftArmMax = math.max(leftArmMax, angles.X)
			end
		end
	end
	for jointName in jointNames do
		assert(animatedJoints[jointName], style.Id .. " does not animate " .. jointName)
	end
	for markerName, markerTime in style.Markers do
		assert(times[markerTime], style.Id .. " marker " .. markerName .. " needs a frame at " .. tostring(markerTime))
	end
	assert(rightArmMax >= 160, style.Id .. " lacks a high overhead cock before the slam")
	if style.Id == "TwoHandPower" then
		assert(leftArmMax >= 160, "TwoHandPower needs both arms loaded overhead")
	elseif style.Id == "Tomahawk" then
		assert(rightArmMin <= -140, "Tomahawk needs the ball cocked far behind the head")
	elseif style.Id == "Windmill" then
		assert(rightArmMin <= -150, "Windmill needs a full backward arm circle")
	end
end

local function addPose(parent, node, anglesByJoint, easingDirection)
	local pose = Instance.new("Pose")
	pose.Name = node.Name
	pose.Weight = node.Name == "HumanoidRootPart" and 0 or 1
	pose.CFrame = CFrame.Angles(
		math.rad((anglesByJoint[node.Name] or Vector3.zero).X),
		math.rad((anglesByJoint[node.Name] or Vector3.zero).Y),
		math.rad((anglesByJoint[node.Name] or Vector3.zero).Z)
	)
	pose.EasingStyle = Enum.PoseEasingStyle.Cubic
	pose.EasingDirection = easingDirection
	if parent:IsA("Keyframe") then
		parent:AddPose(pose)
	else
		parent:AddSubPose(pose)
	end
	for _, child in node.Children or {} do
		addPose(pose, child, anglesByJoint, easingDirection)
	end
end

local function generate(style)
	local frames = Poses[style.Id]
	checkTimeline(style, frames)
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = style.Id
	sequence.Loop = false
	sequence.Priority = Enum.AnimationPriority.Action
	sequence:SetAttribute("BuilderOwner", Config.Owner)
	local success, problem = pcall(function()
		local activeAngles = {}
		for _, frameData in frames do
			if frameData.Reset then
				activeAngles = {}
			end
			for jointName, angles in frameData.Joints or {} do
				activeAngles[jointName] = angles
			end
			local keyframe = Instance.new("Keyframe")
			keyframe.Time = frameData.Time
			keyframe.Name = string.format("%.2f", frameData.Time)
			addPose(keyframe, hierarchy, activeAngles, frameData.EasingDirection)
			for markerName, markerTime in style.Markers do
				if markerTime == frameData.Time then
					local marker = Instance.new("KeyframeMarker")
					marker.Name = markerName
					keyframe:AddMarker(marker)
				end
			end
			sequence:AddKeyframe(keyframe)
		end
	end)
	if not success then
		sequence:Destroy()
		error(problem)
	end
	return sequence
end

function Build.Run()
	assert(RunService:IsStudio() and not RunService:IsRunning(), "DunkAnimationBuilder is Studio EDIT MODE only; stop Play first.")
	local previousFolder = findUnique(ServerStorage, Config.OutputName)
	assert(not previousFolder or previousFolder:IsA("Folder"), "ServerStorage." .. Config.OutputName .. " must be a Folder")
	local previousById = {}
	if previousFolder then
		for _, style in Config.Styles do
			local previous = findUnique(previousFolder, style.Id)
			assert(not previous or (previous:IsA("KeyframeSequence") and previous:GetAttribute("BuilderOwner") == Config.Owner),
				"Refusing to replace unowned " .. previousFolder:GetFullName() .. "." .. style.Id)
			previousById[style.Id] = previous
		end
	end
	local stage = Instance.new("Folder")
	local generated = {}
	local buildOk, buildError = pcall(function()
		for _, style in Config.Styles do
			local sequence = generate(style)
			sequence.Parent = stage
			generated[style.Id] = sequence
		end
	end)
	if not buildOk then
		stage:Destroy()
		error(buildError)
	end
	local folder = previousFolder or Instance.new("Folder")
	if not previousFolder then
		folder.Name = Config.OutputName
		folder:SetAttribute("BuilderOwner", Config.Owner)
		folder.Parent = ServerStorage
	end
	local installed = {}
	local installOk, installError = pcall(function()
		for _, style in Config.Styles do
			local previous = previousById[style.Id]
			if previous then previous.Parent = nil end
			local sequence = generated[style.Id]
			sequence.Parent = folder
			table.insert(installed, sequence)
		end
	end)
	if not installOk then
		for _, sequence in installed do sequence.Parent = stage end
		for _, style in Config.Styles do
			local previous = previousById[style.Id]
			if previous then previous.Parent = folder end
		end
		if not previousFolder then folder:Destroy() end
		stage:Destroy()
		error(installError)
	end
	for _, style in Config.Styles do
		local previous = previousById[style.Id]
		if previous then previous:Destroy() end
		print(string.format("[DunkAnimationBuilder] %s: %d keyframes, %.2fs, Gather/Slam/Release/Recover.",
			style.Id, #Poses[style.Id], style.Duration))
	end
	stage:Destroy()
	print("[DunkAnimationBuilder] Generated editable R15 clips at " .. folder:GetFullName() .. ". No animations were published.")
	return folder
end

function Build.CopyToRig(rig: Model)
	assert(RunService:IsStudio() and not RunService:IsRunning(), "DunkAnimationBuilder is Studio EDIT MODE only; stop Play first.")
	assert(typeof(rig) == "Instance" and rig:IsA("Model") and rig:IsDescendantOf(Workspace),
		"Pass an R15 preview rig from Workspace.")
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	assert(humanoid and humanoid.RigType == Enum.HumanoidRigType.R15, "Preview rig must use R15.")
	local animationSaves = rig:FindFirstChild("AnimSaves")
	-- Current Studio stores Clip Editor saves under ServerStorage.RBX_ANIMSAVES.<RigName>,
	-- which may be a Folder or an ObjectValue depending on the Studio version.
	assert(animationSaves and animationSaves:IsA("ObjectValue") and animationSaves.Value
		and (animationSaves.Value:IsA("Folder") or animationSaves.Value:IsA("ObjectValue"))
		and animationSaves.Value:IsDescendantOf(ServerStorage),
		"Save a blank clip in Clip Editor first to initialize this rig's AnimSaves folder.")
	local folder = assert(findUnique(ServerStorage, Config.OutputName), "Run Build.Run() to generate clips first.")
	assert(folder:IsA("Folder"), "GeneratedDunkAnimations must be a Folder.")
	local copies = {}
	for _, style in Config.Styles do
		local source = assert(findUnique(folder, style.Id), "Missing generated clip " .. style.Id)
		assert(source:IsA("KeyframeSequence") and source:GetAttribute("BuilderOwner") == Config.Owner,
			"Refusing to copy an unowned generated clip " .. style.Id)
		if not findUnique(animationSaves.Value, style.Id) then
			table.insert(copies, source:Clone())
		end
	end
	for _, copy in copies do
		copy.Parent = animationSaves.Value
	end
	print(string.format("[DunkAnimationBuilder] Copied %d clips to %s; existing preview saves preserved.",
		#copies, rig:GetFullName()))
	return animationSaves.Value
end

return Build
