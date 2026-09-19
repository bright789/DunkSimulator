local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.DunkConfig).Execution
local BasketballService = require(script.Parent.BasketballService)
local DunkAnimationController = require(script.Parent.DunkAnimationController)
local GameplayObjects = require(script.Parent.GameplayObjects)

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
	local resources = {}
	local changedOwnership = false
	local automaticOwnership = false
	local originalOwner: Player? = nil
	local rimPosition = rim.Position
	local startingPosition = root.Position
	local startedAt = os.clock()
	local completed = false
	local animationSession = nil

	local function ensureValid()
		assert(player.Parent == Players and player.Character == character and character:IsDescendantOf(Workspace), "Character removed")
		assert(humanoid.Parent == character and humanoid.Health > 0 and root.Parent == character and not root.Anchored, "Character unavailable")
		assert(GameplayObjects.FindRim() == rim, "Hoop removed or changed")
		assert((rim.Position - rimPosition).Magnitude <= Config.RimMovementTolerance, "Hoop moved")
		assert(BasketballService.GetBall(player) == ball, "Ball possession lost")
		assert((root.Position - startingPosition).Magnitude <= Config.MaxAssistDistance + Config.PositionTolerance, "Character left execution area")
		assert(os.clock() - startedAt <= Config.TimeoutSeconds, "Dunk execution timed out")
	end

	local success, failure = pcall(function()
		ensureValid()
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
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero

		local towardRim = Vector3.new(rimPosition.X - startingPosition.X, 0, rimPosition.Z - startingPosition.Z)
		local target = startingPosition
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
		alignment.MaxVelocity = Config.MaxVelocity
		alignment.Responsiveness = Config.Responsiveness
		alignment.Position = target
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

		animationSession = DunkAnimationController.Start(humanoid, Config.AnimationName)
		animationSession.Cue("Takeoff")

		BasketballService.BeginDunkMotion(player)
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

		moveBall(Config.GatherSeconds, function()
			return CFrame.new(rimPosition + Vector3.new(0, Config.BallAboveRim, 0))
		end, true)
		animationSession.Cue("BallAboveRim")
		assert((root.Position - target).Magnitude <= Config.PositionTolerance, "Dunk alignment was obstructed")
		animationSession.Cue("BallRelease")
		moveBall(Config.FinishSeconds, function()
			return CFrame.new(rimPosition - Vector3.new(0, Config.BallBelowRim, 0))
		end)
		assert(ball.Position.Y < rimPosition.Y, "Ball did not pass through the rim")
		animationSession.Cue("DunkComplete")
		animationSession.FadeOut()
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
		if Config.DebugLogging then
			warn("[DunkExecution] Cancelled: " .. tostring(failure or "cleanup failed"))
		end
		return false, "Dunk cancelled. Try again."
	end
	return true, nil
end

return DunkExecution
