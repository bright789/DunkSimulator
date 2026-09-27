-- Brings the builder-made spectators (CollectionService tag "Spectator") to life on this
-- client only: breathing, heads that follow the action, and a cheer (arms up, bouncing)
-- whenever any player nearby slams a dunk. The rigs are anchored scenery; this script
-- re-poses their limbs locally with the saved joint layout and never touches gameplay.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PresentationConfig")).Crowd
local AudioConfig = require(ReplicatedStorage.Shared.Config.FeedbackConfig).Audio.World
local ContestConfig = require(ReplicatedStorage.Shared.Config.ContestConfig)
local WorldAudio = require(script.Parent:WaitForChild("WorldAudio"))

local localPlayer = Players.LocalPlayer
local spectators: { [Model]: any } = {}
-- Rigs that arrived incomplete (streaming); retried until every joint resolves.
local pending: { [Model]: boolean } = {}
local random = Random.new()
local R15_JOINTS = 15

local function angles(pitch: number, yaw: number?, roll: number?): CFrame
	return CFrame.Angles(math.rad(pitch), math.rad(yaw or 0), math.rad(roll or 0))
end

-- Absolute arm pose while cheering (right roll + / left roll - swings the arm outward).
local CHEER = {
	RightShoulder = angles(165, 0, 18), LeftShoulder = angles(165, 0, -18),
	RightElbow = angles(18), LeftElbow = angles(18),
}

local function jointParts(joint: Instance)
	if joint:IsA("Motor6D") then
		return joint.Part0, joint.Part1, joint.C0, joint.C1
	elseif joint:IsA("AnimationConstraint") and joint.Attachment0 and joint.Attachment1 then
		return joint.Attachment0.Parent, joint.Attachment1.Parent, joint.Attachment0.CFrame, joint.Attachment1.CFrame
	end
	return nil
end

-- Reads the rig's saved pose: joints in parent-before-child order with their current
-- transform, plus hats/props riding on a limb.
local function track(model: Model)
	if spectators[model] or not model:IsA("Model") or model.Parent == nil then return end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		pending[model] = true
		return
	end
	local unresolved = {}
	for _, joint in model:GetDescendants() do
		local parent, child, c0, c1 = jointParts(joint)
		if parent and child then
			table.insert(unresolved, { Name = joint.Name, Parent = parent, Child = child, C0 = c0, C1Inverse = c1:Inverse() })
		end
	end
	local ordered, placed = {}, { [root] = true }
	local progress = true
	while progress do
		progress = false
		for index = #unresolved, 1, -1 do
			local joint = unresolved[index]
			if placed[joint.Parent] and not placed[joint.Child] then
				joint.Base = joint.C0:Inverse() * joint.Parent.CFrame:Inverse() * joint.Child.CFrame * joint.C1Inverse:Inverse()
				table.insert(ordered, joint)
				placed[joint.Child] = true
				table.remove(unresolved, index)
				progress = true
			end
		end
	end
	if #ordered < R15_JOINTS or #unresolved > 0 then
		pending[model] = true
		return
	end
	pending[model] = nil
	local extras = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Parent and part.Parent:IsA("BasePart") then
			table.insert(extras, { Part = part, Anchor = part.Parent, Offset = part.Parent.CFrame:ToObjectSpace(part.CFrame) })
		end
	end
	local head = model:FindFirstChild("Head")
	spectators[model] = {
		Model = model,
		Root = root,
		RootBase = root.CFrame,
		Joints = ordered,
		Extras = extras,
		HeadHeight = head and head:IsA("BasePart") and root.CFrame:PointToObjectSpace(head.Position).Y or 2.5,
		Seated = model:GetAttribute("Seated") == true,
		Phase = random:NextNumber(0, 10),
		Attentive = random:NextNumber() < Config.AttentiveChance,
		Yaw = 0,
		Pitch = 0,
		CheerAt = nil,
		Parts = table.create(#ordered + #extras + 1),
		CFrames = table.create(#ordered + #extras + 1),
	}
end

local function untrack(model: Instance)
	spectators[model :: Model] = nil
	pending[model :: Model] = nil
end

for _, model in CollectionService:GetTagged("Spectator") do track(model) end
CollectionService:GetInstanceAddedSignal("Spectator"):Connect(function(model) task.defer(track, model) end)
CollectionService:GetInstanceRemovedSignal("Spectator"):Connect(untrack)
task.spawn(function()
	while true do
		task.wait(1)
		for model in pending do
			pending[model] = nil
			if model.Parent then track(model) end
		end
	end
end)

local function cheerNear(position: Vector3, hype: number?)
	local now = os.clock()
	local count, center = 0, Vector3.zero
	for _, state in spectators do
		if (state.RootBase.Position - position).Magnitude <= Config.CheerRadius then
			state.CheerAt = now + random:NextNumber(0, Config.CheerDelayMax)
			state.Hype = hype or 1
			count += 1
			center += state.RootBase.Position
		end
	end
	if count > 0 then
		local big = count >= AudioConfig.CheerCrowdSize
		WorldAudio.PlayAt(big and "CrowdCheer" or "CrowdClap", center / count, hype or 1)
	end
end

-- Every player's slam makes nearby fans cheer; a Perfect slam gets a second, bigger roar.
local function watchPlayer(player: Player)
	player:GetAttributeChangedSignal("DunkPhase"):Connect(function()
		if player:GetAttribute("DunkPhase") ~= "Slam" then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then cheerNear(root.Position) end
	end)
	player:GetAttributeChangedSignal("SlamRating"):Connect(function()
		if player:GetAttribute("SlamRating") ~= "Perfect" then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then cheerNear(root.Position, Config.PerfectHype) end
	end)
	-- Dunk Contest: the crowd erupts for a big judged score ("sequence:total").
	player:GetAttributeChangedSignal("ContestJudged"):Connect(function()
		local total = tonumber(string.match(tostring(player:GetAttribute("ContestJudged")), ":(%d+)$"))
		if not total or total < ContestConfig.HypeScore then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then cheerNear(root.Position, Config.PerfectHype) end
	end)
end
for _, player in Players:GetPlayers() do watchPlayer(player) end
Players.PlayerAdded:Connect(watchPlayer)

local function cheerAmount(state, now: number): number
	if not state.CheerAt then return 0 end
	local t = now - state.CheerAt
	if t < 0 then return 0 end
	local attack, hold, release = Config.CheerAttackSeconds, Config.CheerHoldSeconds, Config.CheerReleaseSeconds
	if t < attack then return t / attack end
	if t < attack + hold then return 1 end
	if t < attack + hold + release then return 1 - (t - attack - hold) / release end
	state.CheerAt = nil
	return 0
end

-- What the fans look at: whoever is dunking nearby, otherwise the local player.
local function focusPoint(): Vector3?
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("DunkPhase") ~= nil then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then return root.Position end
		end
	end
	local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

local function poseSpectator(state, now: number, deltaTime: number, focus: Vector3?)
	local cheer = cheerAmount(state, now)

	-- Head follows the focus when close enough; otherwise it drifts around slowly.
	local yaw = math.rad(Config.IdleLookDegrees) * math.sin(now * 0.35 + state.Phase)
	local pitch = 0
	if focus and state.Attentive then
		local relative = state.RootBase:PointToObjectSpace(focus)
		local flat = Vector2.new(relative.X, relative.Z).Magnitude
		if flat <= Config.LookDistance then
			yaw = math.clamp(math.atan2(-relative.X, -relative.Z), -math.rad(Config.LookYawDegrees), math.rad(Config.LookYawDegrees))
			pitch = math.clamp(math.atan2(relative.Y - state.HeadHeight, math.max(flat, 1)),
				-math.rad(Config.LookPitchDegrees), math.rad(Config.LookPitchDegrees))
		end
	end
	local blend = 1 - math.exp(-Config.LookRate * deltaTime)
	state.Yaw += (yaw - state.Yaw) * blend
	state.Pitch += (pitch - state.Pitch) * blend

	local beat = math.abs(math.sin((now + state.Phase) * Config.BounceSpeed))
	local bounce = cheer * (state.Seated and Config.SeatedBounce or Config.StandBounce) * beat * (state.Hype or 1)
	local breath = math.rad(Config.BreathDegrees) * math.sin(now * Config.BreathSpeed + state.Phase)
	local pump = math.rad(Config.PumpDegrees) * cheer * math.sin((now + state.Phase) * Config.BounceSpeed * 2)

	local parts, cframes = state.Parts, state.CFrames
	table.clear(parts)
	table.clear(cframes)
	local world = { [state.Root] = state.RootBase * CFrame.new(0, bounce, 0) }
	table.insert(parts, state.Root)
	table.insert(cframes, world[state.Root])
	for _, joint in state.Joints do
		local transform = joint.Base
		local name = joint.Name
		if name == "Neck" then
			transform *= CFrame.Angles(state.Pitch, state.Yaw * 0.7, 0)
		elseif name == "Waist" then
			transform *= CFrame.Angles(breath + math.rad(8) * cheer, state.Yaw * 0.3, 0)
		elseif CHEER[name] and cheer > 0 then
			transform = transform:Lerp(CHEER[name], cheer)
			if name == "RightShoulder" or name == "LeftShoulder" then transform *= CFrame.Angles(pump, 0, 0) end
		end
		local parentFrame = world[joint.Parent]
		if parentFrame then
			local childFrame = parentFrame * joint.C0 * transform * joint.C1Inverse
			world[joint.Child] = childFrame
			table.insert(parts, joint.Child)
			table.insert(cframes, childFrame)
		end
	end
	for _, extra in state.Extras do
		local anchor = world[extra.Anchor]
		if anchor then
			table.insert(parts, extra.Part)
			table.insert(cframes, anchor * extra.Offset)
		end
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Stadium crowd bed in the indoor gyms (High School, College); city night bed on the Rooftop.
local function updateAmbience()
	local court = localPlayer:GetAttribute("CurrentCourt")
	WorldAudio.SetLoop("GymAmbience", court == "HighSchool" or court == "College")
	WorldAudio.SetLoop("CityAmbience", court == "Rooftop")
end
localPlayer:GetAttributeChangedSignal("CurrentCourt"):Connect(updateAmbience)
updateAmbience()

local accumulated = 0
RunService.PreRender:Connect(function(deltaTime)
	accumulated += deltaTime
	if accumulated < 1 / Config.UpdateHz then return end
	local step = accumulated
	accumulated = 0
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local eye = camera.CFrame.Position
	local now = os.clock()
	local focus = focusPoint()
	for model, state in spectators do
		if model.Parent == nil or state.Root.Parent == nil then
			spectators[model] = nil
		elseif (state.RootBase.Position - eye).Magnitude <= Config.AnimateDistance then
			local ok, problem = pcall(poseSpectator, state, now, step, focus)
			if not ok then
				spectators[model] = nil
				if RunService:IsStudio() then warn("[CrowdPresentation] " .. model:GetFullName() .. ": " .. tostring(problem)) end
			end
		end
	end
end)
