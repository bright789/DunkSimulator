local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DunkConfig = require(ReplicatedStorage.Shared.Config.DunkConfig)
local Config = DunkConfig.Execution
local BasketballService = require(script.Parent.BasketballService)
local DunkAnimationController = require(script.Parent.DunkAnimationController)
local GameplayObjects = require(script.Parent.GameplayObjects)
local PlayerService = require(script.Parent.PlayerService)

local DunkExecution = {}

function DunkExecution.Run(player: Player, character: Model, rim: BasePart): (boolean, string?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local ball = BasketballService.GetBall(player)
	if not humanoid or not root or not root:IsA("BasePart") or root.Anchored or not ball then
		return false, "Dunk execution could not start."
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
	if not vertical or vertical < DunkConfig.DunkMinimumVertical then
		return false, "Basic Dunk is not unlocked."
	end
	local lowestHeight = rimPosition.Y - DunkConfig.DunkMaxBelowRim - Config.PositionTolerance
	local highestHeight = rimPosition.Y + DunkConfig.GetMaxAboveRim(vertical) + Config.PositionTolerance
	local startedAt = os.clock()
	local deadline = startedAt + Config.OwnershipSettleSeconds + Config.NormalizeTimeoutSeconds
		+ Config.AlignmentTimeoutSeconds + Config.TimeoutSeconds
	local completed = false
	local animationSession = nil
	local phase = "setup"

	local function ensureValid()
		assert(player.Parent == Players and player.Character == character and character:IsDescendantOf(Workspace), "Character removed")
		assert(humanoid.Parent == character and humanoid.Health > 0 and root.Parent == character and not root.Anchored, "Character unavailable")
		assert(GameplayObjects.FindRim() == rim, "Hoop removed or changed")
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
			root.AssemblyLinearVelocity = Vector3.zero
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
		alignment.Position = heightTarget
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

		phase = "height normalization"
		waitForAlignment(heightTarget, Config.NormalizeTimeoutSeconds)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		alignment.MaxVelocity = Config.MaxVelocity
		alignment.Position = target
		phase = "horizontal alignment"
		waitForAlignment(target, Config.AlignmentTimeoutSeconds)
		deadline = os.clock() + Config.TimeoutSeconds

		animationSession = DunkAnimationController.Start(humanoid, Config.AnimationName)
		animationSession.Cue("Takeoff")

		BasketballService.BeginDunkMotion(player)
		if root:CanSetNetworkOwnership() then
			root:SetNetworkOwner(nil)
		end
		ballDetachOwnershipPending = true
		local function moveBall(duration: number, destination, followHand: boolean?)
			local start = ball.CFrame
			local phaseStarted = os.clock()
			repeat
				RunService.Heartbeat:Wait()
				ensureValid()
				humanoid.Jump = false
				local progress = math.clamp((os.clock() - phaseStarted) / duration, 0, 1)
				local eased = progress * progress * (3 - 2 * progress)
				if followHand then
					local held = assert(BasketballService.GetHeldCFrame(player), "Hand unavailable")
					local reach = math.clamp((progress - Config.HandFollowFraction) / (1 - Config.HandFollowFraction), 0, 1)
					reach = reach * reach * (3 - 2 * reach)
					ball.CFrame = held:Lerp(destination(), reach)
				else
					ball.CFrame = start:Lerp(destination(), eased)
				end
			until progress >= 1
		end

		phase = "ball gather"
		moveBall(Config.GatherSeconds, function()
			return CFrame.new(rimPosition + Vector3.new(0, Config.BallAboveRim, 0))
		end, true)
		animationSession.Cue("BallAboveRim")
		assert((root.Position - target).Magnitude <= Config.PositionTolerance, "Dunk alignment was obstructed")
		animationSession.Cue("BallRelease")
		phase = "rim pass"
		moveBall(Config.FinishSeconds, function()
			return CFrame.new(rimPosition - Vector3.new(0, Config.BallBelowRim, 0))
		end)
		assert(ball.Position.Y < rimPosition.Y, "Ball did not pass through the rim")
		animationSession.Cue("DunkComplete")
		animationSession.FadeOut()
		phase = "ball return"
		moveBall(Config.ReturnSeconds, function()
			return assert(BasketballService.GetHeldCFrame(player), "Hand unavailable")
		end)
		ensureValid()
		completed = true
	end)

	local cleanupSucceeded = true
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
		return false, "Dunk cancelled. Try again."
	end
	return true, nil
end

return DunkExecution
