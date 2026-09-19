local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.DunkConfig)
local PlayerService = require(script.Parent.PlayerService)
local BasketballService = require(script.Parent.BasketballService)
local DunkExecution = require(script.Parent.DunkExecution)
local GameplayObjects = require(script.Parent.GameplayObjects)
local remotes = ReplicatedStorage.Remotes

local DunkService = {}
local nextAttempt: { [Player]: number } = {}
local nextDebugLog: { [Player]: number } = {}
local initialized = false

local function debugRejection(player: Player, code: string?, message: string?)
	if not Config.DebugDunkValidation or not RunService:IsStudio() then
		return
	end
	local now = os.clock()
	if now < (nextDebugLog[player] or 0) then
		return
	end
	nextDebugLog[player] = now + Config.DunkCooldown
	print("[DunkValidation] " .. player.Name .. " " .. (code or "REJECTED") .. ": " .. (message or "Request ignored."))
end

local function validateAttempt(player: Player, expectedCharacter: Model?, expectedRim: BasePart?): (string?, boolean, string?)
	if not PlayerService.IsReady(player) then
		return "Player data is not ready.", false, "PLAYER_NOT_READY"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or character ~= expectedCharacter or not character:IsDescendantOf(Workspace) or not humanoid or humanoid.Health <= 0
		or not rootPart or not rootPart:IsA("BasePart") or rootPart.Anchored then
		return "Your character is not ready.", false, "INVALID_CHARACTER"
	end
	if not BasketballService.HasBall(player) then
		return "Pick up a basketball first.", false, "NO_BALL"
	end
	local vertical = PlayerService.GetVertical(player)
	if not vertical or not (vertical >= Config.DunkMinimumVertical) then
		return string.format("Basic Dunk unlocks at Vertical %d.", Config.DunkMinimumVertical), false, "VERTICAL_TOO_LOW"
	end
	local rim = GameplayObjects.FindRim()
	if not rim or rim ~= expectedRim then
		return "The hoop is missing, changed, or its Rim is not anchored.", false, "INVALID_RIM"
	end
	local offset = rootPart.Position - rim.Position
	local horizontalDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if not (horizontalDistance <= Config.DunkHorizontalDistance) then
		return string.format("Move closer to the rim (%.1f / %.1f studs).", horizontalDistance, Config.DunkHorizontalDistance), false, "TOO_FAR"
	end
	local state = humanoid:GetState()
	if humanoid.FloorMaterial ~= Enum.Material.Air
		or (state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall) then
		return "Jump first, then press F while airborne.", false, "NOT_AIRBORNE"
	end
	if horizontalDistance > Config.DunkApproachDirectionEpsilon then
		local towardRim = Vector3.new(-offset.X, 0, -offset.Z).Unit
		local speedTowardRim = rootPart.AssemblyLinearVelocity:Dot(towardRim)
		local facing = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
		local facingBasket = facing.Magnitude > Config.DunkApproachDirectionEpsilon
			and facing.Unit:Dot(towardRim) >= math.cos(math.rad(Config.DunkMaxFacingAngleDegrees))
		if not (speedTowardRim >= -Config.DunkMaxRetreatSpeed) or (not facingBasket and speedTowardRim <= 0) then
			return "Jump toward the basket rather than away from it.", false, "BAD_APPROACH"
		end
	end
	local maxAboveRim = Config.GetMaxAboveRim(vertical)
	if not (offset.Y >= -Config.DunkMaxBelowRim and offset.Y <= maxAboveRim) then
		local tolerance = offset.Y < 0 and Config.DunkMaxBelowRim or maxAboveRim
		local insideBuffer = offset.Y >= -Config.DunkMaxBelowRim - Config.DunkBufferVerticalAllowance
			and offset.Y <= maxAboveRim + Config.DunkBufferVerticalAllowance
		return string.format("%s (height gap %.1f / %.1f studs).",
			offset.Y < 0 and "Jump higher" or "Too high above the rim", math.abs(offset.Y), tolerance), insideBuffer,
			offset.Y < 0 and "TOO_LOW" or "TOO_HIGH"
	end
	return nil, false, nil
end

local function attemptDunk(player: Player): (string?, string?)
	local character = player.Character
	local rim = GameplayObjects.FindRim()
	local expiresAt = os.clock() + Config.DunkInputBufferSeconds
	local lastReason = "Dunk request expired. Press F again near the rim."
	local lastCode = "BUFFER_EXPIRED"
	repeat
		local reason, canBuffer, code = validateAttempt(player, character, rim)
		if not reason and character and rim then
			PlayerService.SetDunkState(player, "Executing")
			local completed, cancellation = DunkExecution.Run(player, character, rim)
			if not completed then
				return cancellation, "EXECUTION_CANCELLED"
			end
			PlayerService.SetDunkState(player, "Completed")
			if not PlayerService.RegisterDunk(player) then
				return "Player data is not ready.", "PLAYER_NOT_READY"
			end
			nextAttempt[player] = os.clock() + Config.DunkCooldown
			print("[DunkService] " .. player.Name .. " completed a dunk")
			remotes.DunkResult:FireClient(player, Config.DunkCashReward)
			return nil, nil
		end
		lastReason = reason or lastReason
		lastCode = code or lastCode
		if not canBuffer then
			return reason, code
		end
		RunService.Heartbeat:Wait()
	until os.clock() > expiresAt
	return lastReason, lastCode
end

function DunkService.Init()
	if initialized then
		return
	end
	initialized = true
	if not GameplayObjects.FindRim() then
		warn("[DunkService] Missing valid rim: create Workspace.Gameplay (Folder), containing DunkHoop (Model) with a direct anchored Rim Part. Legacy Workspace.DunkHoop.Rim is also supported.")
	end
	Players.PlayerRemoving:Connect(function(player)
		nextAttempt[player] = nil
		nextDebugLog[player] = nil
	end)
	remotes.RequestDunk.OnServerEvent:Connect(function(player, ...)
		if not PlayerService.IsReady(player) then
			debugRejection(player, "PLAYER_NOT_READY")
			return
		end
		if PlayerService.GetDunkState(player) ~= "Idle" then
			debugRejection(player, "BUSY")
			return
		end
		local now = os.clock()
		if now < (nextAttempt[player] or 0) then
			debugRejection(player, "COOLDOWN")
			return
		end
		nextAttempt[player] = now + Config.DunkCooldown
		if select("#", ...) ~= 0 then
			debugRejection(player, "INVALID_REQUEST", "RequestDunk accepts input intent only, with no arguments.")
			return
		end
		PlayerService.SetDunkState(player, "Attempting")
		local success, message, code = pcall(attemptDunk, player)
		PlayerService.SetDunkState(player, "Idle")
		if player.Parent ~= Players then
			return
		end
		if not success then
			warn("[DunkService] Attempt failed: " .. tostring(message))
			remotes.DunkResult:FireClient(player, nil, "Dunk unavailable. Check Studio Output.")
		elseif message then
			remotes.DunkResult:FireClient(player, nil, message)
			debugRejection(player, code, message)
		end
	end)
	print("[DunkService] Dunk requests ready.")
end

return DunkService
