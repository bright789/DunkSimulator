local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DunkConfig = require(ReplicatedStorage.Shared.Config.DunkConfig)
local Styles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local DunkRewards = require(ReplicatedStorage.Shared.Config.DunkRewards)
local Config = DunkConfig.Execution
local BasketballService = require(script.Parent.BasketballService)
local DunkAnimationController = require(script.Parent.DunkAnimationController)
local DunkStyleMotion = require(script.Parent.DunkStyleMotion)
local DunkPose = require(script.Parent.DunkPose)
local GameplayObjects = require(script.Parent.GameplayObjects)
local PlayerService = require(script.Parent.PlayerService)
local SlamTiming = require(script.Parent.SlamTiming)

local DunkExecution = {}
local random = Random.new()

-- Returns (completed, cancellation message, Cash already paid for air tricks, slam rating,
-- number of air tricks paid, the ids of those tricks in order).
function DunkExecution.Run(player: Player, character: Model, rim: BasePart, styleId: string): (boolean, string?, number, string?, number, { string })
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local ball = BasketballService.GetBall(player)
	local trickCash = 0
	local tricksLanded = 0
	local landedTricks: { string } = {}
	local rating: string? = nil
	if not humanoid or not root or not root:IsA("BasePart") or root.Anchored or not ball then
		return false, "Dunk execution could not start.", trickCash
	end

	local saved = {
		WalkSpeed = humanoid.WalkSpeed,
		AutoRotate = humanoid.AutoRotate,
		JumpHeight = humanoid.JumpHeight,
		JumpPower = humanoid.JumpPower,
		UseJumpPower = humanoid.UseJumpPower,
	}
	local jumpingEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
	local resources = {}
	local changedOwnership = false
	local ballDetachOwnershipPending = false
	local automaticOwnership = false
	local originalOwner: Player? = nil
	local rimPosition = rim.Position
	local startingPosition = root.Position
	local targetHeight = rimPosition.Y - Config.RootBelowRim
	local vertical = PlayerService.GetVertical(player)
	local style = Styles.Get(styleId)
	if not style or not vertical or not Styles.IsUnlocked(styleId, vertical) then
		return false, "Dunk style is not unlocked.", trickCash
	end
	local motionTimeout = math.max(Config.TimeoutSeconds,
		style.GatherSeconds + style.FinishSeconds + style.HangSeconds + Styles.ExecutionSlackSeconds)
	local lowestHeight = rimPosition.Y - DunkConfig.DunkMaxBelowRim - Config.PositionTolerance
	-- Entry height is validated by DunkService; this extra slack only absorbs upward
	-- momentum that continues during the network-ownership handoff.
	local highestHeight = rimPosition.Y + DunkConfig.GetMaxAboveRim(vertical) + Config.PositionTolerance
		+ Config.HandoffOvershootStuds
	local startedAt = os.clock()
	local deadline = startedAt + Config.OwnershipSettleSeconds + Config.NormalizeTimeoutSeconds
		+ Config.AlignmentTimeoutSeconds + Config.TimeoutSeconds
	local completed = false
	local animationSession = nil
	local poseSession = nil
	local phase = "setup"

	-- Presentation-only mirror so every client can pose the rim grab and impact.
	local function setDunkPhase(value: string?)
		if player.Parent == Players then player:SetAttribute("DunkPhase", value) end
	end

	-- Radius of the visible ring, measured from the hoop's Segment parts.
	local function measureRimRadius(): number
		local radius = 0
		local hoop = rim.Parent
		if hoop then
			for _, part in hoop:GetDescendants() do
				if part:IsA("BasePart") and part.Name:match("^Segment%d+$") then
					local offset = part.Position - rimPosition
					radius = math.max(radius, Vector3.new(offset.X, 0, offset.Z).Magnitude)
				end
			end
		end
		return radius > 0 and radius or Config.DefaultRimRadius
	end

	local function ensureValid()
		assert(PlayerService.IsReady(player) and PlayerService.GetDunkState(player) == "Executing"
			and PlayerService.GetEquippedDunkStyle(player) == styleId, "Dunk session ended")
		assert(player.Parent == Players and player.Character == character and character:IsDescendantOf(Workspace), "Character removed")
		assert(humanoid.Parent == character and humanoid.Health > 0 and root.Parent == character and not root.Anchored, "Character unavailable")
		assert(GameplayObjects.FindRim(PlayerService.GetCurrentCourt(player)) == rim, "Hoop removed or changed")
		assert((rim.Position - rimPosition).Magnitude <= Config.RimMovementTolerance, "Hoop moved")
		assert(BasketballService.GetBall(player) == ball, "Ball possession lost")
		local displacement = root.Position - startingPosition
		assert(Vector3.new(displacement.X, 0, displacement.Z).Magnitude <= Config.MaxAssistDistance + Config.PositionTolerance, "Character left horizontal execution area")
		assert(root.Position.Y >= lowestHeight and root.Position.Y <= highestHeight, "Character left vertical engagement envelope")
		if changedOwnership then
			if ballDetachOwnershipPending then
				assert(root:CanSetNetworkOwnership(), "Character ownership unavailable after ball detachment")
				root:SetNetworkOwner(nil)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				ballDetachOwnershipPending = false
			end
			assert(root:GetNetworkOwner() == nil, "Character server ownership lost")
		end
		assert(os.clock() <= deadline, "Dunk execution timed out")
	end

	local function waitForAlignment(destination: Vector3, timeoutSeconds: number)
		local expiresAt = os.clock() + timeoutSeconds
		local settledAt: number? = nil
		repeat
			RunService.Heartbeat:Wait()
			ensureValid()
			humanoid.Jump = false
			local now = os.clock()
			assert(now <= expiresAt, phase .. " timed out")
			if (root.Position - destination).Magnitude <= Config.PositionTolerance
				and root.AssemblyLinearVelocity.Magnitude <= Config.AlignmentSettleSpeed then
				settledAt = settledAt or now
				if now - settledAt >= Config.AlignmentSettleSeconds then
					return
				end
			else
				settledAt = nil
			end
		until false
	end

	SlamTiming.Begin(player)
	local success, failure = pcall(function()
		ensureValid()
		assert(startingPosition.Y >= rimPosition.Y - DunkConfig.DunkMaxBelowRim
			and startingPosition.Y <= rimPosition.Y + DunkConfig.DunkMaxEngagementAboveRim, "Outside height normalization bounds")
		local canSetOwnership = root:CanSetNetworkOwnership()
		assert(canSetOwnership, "Character network ownership unavailable")
		automaticOwnership = root:GetNetworkOwnershipAuto()
		originalOwner = root:GetNetworkOwner()
		root:SetNetworkOwner(nil)
		changedOwnership = true
		humanoid.WalkSpeed = 0
		humanoid.AutoRotate = false
		humanoid.JumpHeight = 0
		humanoid.JumpPower = 0
		humanoid.Jump = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero

		phase = "server handoff"
		local handoffStarted = os.clock()
		repeat
			RunService.Heartbeat:Wait()
			ensureValid()
			humanoid.Jump = false
			-- Bleed off momentum (a quick apex pause) instead of a hard mid-air stop.
			root.AssemblyLinearVelocity *= Config.HandoffVelocityDamping
			root.AssemblyAngularVelocity = Vector3.zero
		until os.clock() - handoffStarted >= Config.OwnershipSettleSeconds
		local capturedPosition = root.Position
		local towardRim = Vector3.new(rimPosition.X - capturedPosition.X, 0, rimPosition.Z - capturedPosition.Z)
		assert(towardRim.Magnitude <= DunkConfig.DunkHorizontalDistance, "Character left engagement range during handoff")
		local heightTarget = Vector3.new(capturedPosition.X, targetHeight, capturedPosition.Z)
		local target = heightTarget
		if towardRim.Magnitude > Config.RimStandOff then
			target += towardRim.Unit * math.min(towardRim.Magnitude - Config.RimStandOff, Config.MaxAssistDistance)
		end
		local attachment = Instance.new("Attachment")
		table.insert(resources, attachment)
		attachment.Name = "DunkAlignmentAttachment"
		attachment.Parent = root
		local alignment = Instance.new("AlignPosition")
		table.insert(resources, alignment)
		alignment.Name = "DunkAlignment"
		alignment.Mode = Enum.PositionAlignmentMode.OneAttachment
		alignment.Attachment0 = attachment
		alignment.ApplyAtCenterOfMass = true
		alignment.RigidityEnabled = false
		alignment.MaxForce = Config.MaxForce
		alignment.MaxVelocity = Config.NormalizeMaxVelocity
		alignment.Responsiveness = Config.Responsiveness
		alignment.Position = capturedPosition
		alignment.Parent = root

		local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if towardRim.Magnitude > Config.FacingDirectionEpsilon then
			facing = towardRim.Unit
		elseif facing.Magnitude <= Config.FacingDirectionEpsilon then
			facing = Vector3.new(0, 0, -1)
		end
		local orientation = Instance.new("AlignOrientation")
		table.insert(resources, orientation)
		orientation.Name = "DunkFacing"
		orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		orientation.Attachment0 = attachment
		orientation.RigidityEnabled = false
		orientation.MaxTorque = Config.FacingMaxTorque
		orientation.MaxAngularVelocity = Config.FacingMaxAngularVelocity
		orientation.Responsiveness = Config.FacingResponsiveness
		orientation.CFrame = CFrame.lookAt(Vector3.zero, facing)
		orientation.Parent = root

		-- Descent: one eased move from the captured point to the wind-up start. High
		-- entries drop from above the rim with an air-trick combo; the higher the drop, the
		-- more tricks fit, and each finished trick pays Cash on the way down.
		local windupLift = style.Motion.HeightLift
		local dropHeight = capturedPosition.Y - target.Y
		local startLifted = dropHeight > windupLift
		local descentEnd = startLifted and target + Vector3.new(0, windupLift, 0) or target
		local combo = DunkRewards.PlanCombo(style.DescentTrick, vertical, dropHeight, random)
		-- The eased path peaks at 1.5x its average speed; long drops from huge jumps get
		-- enough time that it never outruns DescentMaxVelocity.
		local descentSeconds = math.max(math.clamp(Config.DescentBaseSeconds + math.abs(dropHeight) * Config.DescentSecondsPerStud,
			Config.DescentBaseSeconds, Config.DescentMaxSeconds), DunkRewards.ComboSeconds(combo),
			math.abs(dropHeight) * 1.6 / Config.DescentMaxVelocity)
		-- Server moment each trick finishes (seconds into the descent).
		local trickEnds = {}
		local trickClock = DunkRewards.Tricks.TuckSeconds
		for index, trickId in combo do
			trickClock += DunkRewards.GetTrick(trickId).Seconds
			trickEnds[index] = trickClock
		end
		deadline = math.max(deadline, os.clock() + descentSeconds + Config.AlignmentTimeoutSeconds + Config.TimeoutSeconds)
		if player.Parent == Players then
			player:SetAttribute("DunkTricks", table.concat(combo, ","))
			player:SetAttribute("DunkDescentSeconds", descentSeconds)
		end
		local trickRemote = ReplicatedStorage.Remotes:FindFirstChild("DunkTrick")
		local tricksPaid = 0
		local function payFinishedTricks(elapsed: number)
			while tricksPaid < #combo and elapsed >= trickEnds[tricksPaid + 1] do
				tricksPaid += 1
				local trickId = combo[tricksPaid]
				local cash = PlayerService.AwardDunkTrick(player, trickId, tricksPaid)
				if cash then
					trickCash += cash
					tricksLanded += 1
					table.insert(landedTricks, trickId)
					if trickRemote then trickRemote:FireClient(player, trickId, tricksPaid, cash, #combo) end
				end
			end
		end
		setDunkPhase("Descent")
		phase = "descent"
		alignment.MaxVelocity = Config.DescentMaxVelocity
		alignment.Responsiveness = Config.DescentResponsiveness
		local descentStart = root.Position
		local descentStarted = os.clock()
		local descentProgress = 0
		repeat
			RunService.Heartbeat:Wait()
			ensureValid()
			humanoid.Jump = false
			descentProgress = math.clamp((os.clock() - descentStarted) / descentSeconds, 0, 1)
			alignment.Position = descentStart:Lerp(descentEnd, DunkStyleMotion.Descent(descentProgress))
			-- Checked right after ensureValid; every trick ends before the descent does.
			payFinishedTricks(os.clock() - descentStarted)
		until descentProgress >= 1
		alignment.MaxVelocity = Config.MaxVelocity
		alignment.Responsiveness = Config.Responsiveness
		alignment.Position = descentEnd
		phase = "alignment settle"
		waitForAlignment(descentEnd, Config.AlignmentTimeoutSeconds)
		deadline = os.clock() + motionTimeout

		-- Hang spot: under the front edge of the ring with the arms overhead.
		local flatToRim = Vector3.new(rimPosition.X - target.X, 0, rimPosition.Z - target.Z)
		local towardUnit = flatToRim.Magnitude > Config.FacingDirectionEpsilon and flatToRim.Unit or facing
		local hangStandOff = measureRimRadius() + Config.HangStandOffPadding
		local hangReach = math.clamp(flatToRim.Magnitude - hangStandOff, -Config.MaxHangReach, Config.MaxHangReach)
		local hangOffset = Vector3.new(0, Config.RootBelowRim - Config.HangRootBelowRim, 0) + towardUnit * hangReach

		animationSession = DunkAnimationController.Start(player, humanoid, styleId)

		BasketballService.BeginDunkMotion(player)
		if root:CanSetNetworkOwnership() then
			root:SetNetworkOwner(nil)
		end
		ballDetachOwnershipPending = true
		if not animationSession.UsingTrack() then
			poseSession = DunkPose.Start(character, humanoid, root, ball, style.Pose)
		end
		local function present(moment: string)
			local remote = ReplicatedStorage.Remotes:FindFirstChild("DunkPresentation")
			if remote then
				remote:FireClient(player, styleId, moment)
			end
		end
		local function moveBall(motionPhase: string, duration: number, destination)
			local start = ball.CFrame
			local phaseStarted = os.clock()
			local windupSent = false
			local contactSent = false
			repeat
				RunService.Heartbeat:Wait()
				ensureValid()
				humanoid.Jump = false
				local progress = math.clamp((os.clock() - phaseStarted) / duration, 0, 1)
				local eased = progress * progress * (3 - 2 * progress)
				local bodyPhase = motionPhase == "Return" and "Hang" or motionPhase
				alignment.Position = target
					+ DunkStyleMotion.RootOffset(style.Motion, bodyPhase, progress, towardUnit, hangOffset, startLifted)
				local approach = CFrame.lookAt(root.Position, root.Position + facing)
				if motionPhase == "Gather" then
					if style.Path.Kind == "Direct" then
						local held = assert(BasketballService.GetHeldCFrame(player), "Hand unavailable")
						local reach = math.clamp((progress - Config.HandFollowFraction) / (1 - Config.HandFollowFraction), 0, 1)
						reach = reach * reach * (3 - 2 * reach)
						ball.CFrame = held:Lerp(destination(), reach)
					else
						ball.CFrame = DunkStyleMotion.Gather(style.Path, progress, start, approach, destination())
					end
					if not windupSent and style.Presentation.WindupCueFraction
						and progress >= style.Presentation.WindupCueFraction then
						windupSent = true
						present("Windup")
					end
				elseif motionPhase == "Finish" then
					ball.CFrame = start:Lerp(destination(), DunkStyleMotion.Finish(style.Motion, progress))
				else
					ball.CFrame = start:Lerp(destination(), eased)
				end
				if motionPhase == "Finish" and not contactSent and ball.Position.Y < rimPosition.Y then
					contactSent = true
					present("Contact")
				end
				local armWeight = motionPhase == "Gather" and math.clamp(progress / style.Pose.BlendFraction, 0, 1)
					or (motionPhase == "Finish" and 1 - 0.8 * progress or 0.2 * (1 - progress))
				if not animationSession.UsingTrack() then
					if not poseSession then
						poseSession = DunkPose.Start(character, humanoid, root, ball, style.Pose)
					end
					poseSession.Update(ball.Position, approach.RightVector, armWeight,
						motionPhase == "Hang" and "Return" or motionPhase, progress)
				end
			until progress >= 1
		end

		phase = "ball gather"
		setDunkPhase("Gather")
		present("Gather")
		moveBall("Gather", style.GatherSeconds, function()
			return CFrame.new(rimPosition + Vector3.new(0, Config.BallAboveRim, 0))
		end)
		local windupPosition = target
			+ DunkStyleMotion.RootOffset(style.Motion, "Gather", 1, towardUnit, hangOffset, startLifted)
		assert((root.Position - windupPosition).Magnitude <= Config.PositionTolerance + Config.WindupTolerance,
			"Dunk alignment was obstructed")
		phase = "rim pass"
		local slamAt = os.clock()
		setDunkPhase("Slam")
		present("Slam")
		moveBall("Finish", style.FinishSeconds, function()
			return CFrame.new(rimPosition - Vector3.new(0, Config.BallBelowRim, 0))
		end)
		assert(ball.Position.Y < rimPosition.Y, "Ball did not pass through the rim")
		phase = "rim hang"
		setDunkPhase("Hang")
		moveBall("Hang", math.max(style.HangSeconds - style.ReturnSeconds, 0.05), function()
			return CFrame.new(rimPosition - Vector3.new(0, Config.BallBelowRim, 0))
		end)
		-- Judge the slam timing once late presses have had time to arrive.
		rating = SlamTiming.Judge(player, slamAt)
		if rating and player.Parent == Players then player:SetAttribute("SlamRating", rating) end
		animationSession.FadeOut()
		phase = "ball return"
		moveBall("Return", style.ReturnSeconds, function()
			return assert(BasketballService.GetHeldCFrame(player), "Hand unavailable")
		end)
		ensureValid()
		completed = true
	end)

	local cleanupSucceeded = true
	setDunkPhase(nil)
	SlamTiming.End(player)
	if player.Parent == Players then
		player:SetAttribute("SlamRating", nil)
		player:SetAttribute("DunkTricks", nil)
		player:SetAttribute("DunkDescentSeconds", nil)
	end
	local function restore(action)
		local restored, message = pcall(action)
		if not restored then
			cleanupSucceeded = false
			warn("[DunkExecution] Cleanup: " .. tostring(message))
		end
	end
	if animationSession then
		restore(function() animationSession.Destroy() end)
	end
	if poseSession then
		restore(function() poseSession.Destroy() end)
	end
	for _, resource in resources do
		restore(function() resource:Destroy() end)
	end
	for property, value in saved do
		restore(function() humanoid[property] = value end)
	end
	restore(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, jumpingEnabled) end)
	restore(function() BasketballService.EndDunkMotion(player, ball) end)
	restore(function()
		if root.Parent and not root.Anchored then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			if changedOwnership then
				if automaticOwnership or (originalOwner and originalOwner.Parent ~= Players) then
					root:SetNetworkOwnershipAuto()
				else
					root:SetNetworkOwner(originalOwner)
				end
			end
		end
	end)
	if not success or not completed or not cleanupSucceeded then
		if Config.DebugLogging or RunService:IsStudio() then
			warn(string.format("[DunkExecution] Cancelled during %s after %.2fs: %s (entry Y %.2f, target Y %.2f, current Y %.2f)",
				phase, os.clock() - startedAt, tostring(failure or "cleanup failed"), startingPosition.Y, targetHeight, root.Position.Y))
		end
		return false, "Dunk cancelled. Try again.", trickCash, nil, tricksLanded, landedTricks
	end
	return true, nil, trickCash, rating, tricksLanded, landedTricks
end

return DunkExecution
