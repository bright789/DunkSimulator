-- Runs the client-only movement presentation for every character on this client:
-- smooth local basketball visuals, dribble arm/stance, jump and landing posing,
-- and the leg-day workout at the Vertical Trainer gym.
-- It reads replicated state only and never sends requests to the server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BallPresentation = require(script.Parent:WaitForChild("BallPresentation"))
local BodyPresentation = require(script.Parent:WaitForChild("BodyPresentation"))
local LocomotionFeel = require(script.Parent:WaitForChild("LocomotionFeel"))
local RimPresentation = require(script.Parent:WaitForChild("RimPresentation"))
local DescentPresentation = require(script.Parent:WaitForChild("DescentPresentation"))
local WorkoutPresentation = require(script.Parent:WaitForChild("WorkoutPresentation"))
local WorldAudio = require(script.Parent:WaitForChild("WorldAudio"))
local DunkVFX = require(script.Parent:WaitForChild("DunkVFX"))
local AbilityVFX = require(script.Parent:WaitForChild("AbilityVFX"))

local localPlayer = Players.LocalPlayer
local tracked = {}
local warned = {}

local HOLDING_ACTIONS = { Gathering = true, Holding = true, Recovering = true }

local function report(player: Player, problem)
	if RunService:IsStudio() and not warned[player] then
		warned[player] = true
		warn("[PresentationController] " .. player.Name .. ": " .. tostring(problem))
	end
end

local function untrack(player: Player)
	local entry = tracked[player]
	tracked[player] = nil
	if not entry then return end
	pcall(BallPresentation.Release, entry.Ball)
	if entry.Body then BodyPresentation.Release(entry.Body) end
	RimPresentation.Release(entry.Rim)
	if player == localPlayer then LocomotionFeel.ReleaseLocal() end
end

local function track(player: Player, character: Model)
	untrack(player)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if player.Character ~= character or not humanoid or not root then return end
		if humanoid.RigType == Enum.HumanoidRigType.R15 then
			character:WaitForChild("RightFoot", 10)
			character:WaitForChild("LeftFoot", 10)
		end
		if player.Character ~= character then return end
		tracked[player] = {
			Character = character,
			Humanoid = humanoid,
			Root = root,
			Ball = BallPresentation.Track(player, character, humanoid, root),
			Body = BodyPresentation.Track(character, humanoid, root),
			Rim = RimPresentation.Track(player, character, humanoid, root),
			Descent = DescentPresentation.Track(player, character, humanoid),
			Workout = WorkoutPresentation.Track(player, character, humanoid, root, BodyPresentation.CrouchAngles),
		}
	end)
end

local function isDunking(player: Player): boolean
	return player:GetAttribute("DunkState") == "Executing" or player:GetAttribute("BasketballAction") == "Dunking"
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character) track(player, character) end)
	player.CharacterRemoving:Connect(function() untrack(player) end)
	if player.Character then track(player, player.Character) end
end

Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(untrack)
DunkVFX.Start()
AbilityVFX.Start()
for _, player in Players:GetPlayers() do watchPlayer(player) end

-- Visual ball and IK targets, before the Animator solves this frame.
RunService.PreRender:Connect(function(deltaTime)
	for player, entry in tracked do
		if entry.Character.Parent == nil or entry.Humanoid.Health <= 0 then
			untrack(player)
			continue
		end
		local ok, released = pcall(BallPresentation.Update, entry.Ball, deltaTime)
		if not ok then
			report(player, released)
			pcall(BallPresentation.Release, entry.Ball)
		elseif released then
			local impactOk, problem = pcall(RimPresentation.Impact, player, entry.Humanoid, released)
			if not impactOk then report(player, problem) end
			if player ~= localPlayer then
				WorldAudio.PlayAt("RimClang", released)
				WorldAudio.PlayAt("RimRattle", released)
			end
		end
	end
end)

-- Procedural body layers, after the Animator has written this frame's pose.
RunService.PreSimulation:Connect(function(deltaTime)
	local hangingRims = {}
	for player, entry in tracked do
		local dunking = isDunking(player)
		if player == localPlayer then
			LocomotionFeel.UpdateLocalPhysics(entry.Humanoid, entry.Root, dunking)
		end
		if entry.Descent then
			local descentOk, problem = pcall(DescentPresentation.Update, entry.Descent, deltaTime)
			if not descentOk then
				report(player, problem)
				entry.Descent = nil
			end
		end
		if entry.Rim then
			local rimOk, problem = pcall(RimPresentation.Update, entry.Rim, deltaTime)
			if not rimOk then
				report(player, problem)
				RimPresentation.Release(entry.Rim)
				entry.Rim = nil
			else
				local rim = RimPresentation.HangingRim(entry.Rim)
				if rim then hangingRims[rim] = true end
			end
		end
		local training = false
		if entry.Workout then
			local workoutOk, result = pcall(WorkoutPresentation.Update, entry.Workout, deltaTime)
			if not workoutOk then
				report(player, result)
				entry.Workout = nil
			else
				training = result
			end
		end
		if not entry.Body then continue end
		local context = {
			Dunking = dunking,
			Training = training,
			Dribbling = BallPresentation.IsDribbling(entry.Ball),
			RunFraction = entry.Ball.RunFraction,
			HoldingBall = HOLDING_ACTIONS[player:GetAttribute("BasketballAction")] == true,
		}
		local ok, landed, impact = pcall(BodyPresentation.Update, entry.Body, deltaTime, context)
		if not ok then
			report(player, landed)
			entry.Body = nil
		elseif landed then
			LocomotionFeel.Dust(entry.Root, entry.Humanoid, impact)
			if player == localPlayer then LocomotionFeel.LocalLanded(impact) end
		end
	end
	RimPresentation.StepHoops(deltaTime, hangingRims)
end)

RunService:BindToRenderStep("LocalLandingCamera", Enum.RenderPriority.Camera.Value + 1, LocomotionFeel.ApplyCamera)
