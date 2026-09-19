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
local initialized = false

local function validateAttempt(player: Player, expectedCharacter: Model?, expectedRim: BasePart?): (string?, boolean)
	if not PlayerService.IsReady(player) then
		return "Player data is not ready.", false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or character ~= expectedCharacter or not character:IsDescendantOf(Workspace) or not humanoid or humanoid.Health <= 0
		or not rootPart or not rootPart:IsA("BasePart") then
		return "Your character is not ready.", false
	end
	if not BasketballService.HasBall(player) then
		return "Pick up a basketball first.", false
	end
	local rim = GameplayObjects.FindRim()
	if not rim or rim ~= expectedRim then
		return "The hoop is missing, changed, or its Rim is not anchored.", false
	end
	local offset = rootPart.Position - rim.Position
	local horizontalDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if not (horizontalDistance <= Config.DunkHorizontalDistance) then
		return string.format("Move closer to the rim (%.1f / %.1f studs).", horizontalDistance, Config.DunkHorizontalDistance), false
	end
	local state = humanoid:GetState()
	if humanoid.FloorMaterial ~= Enum.Material.Air
		or (state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall) then
		return "Jump first, then press F while airborne.", false
	end
	if not (offset.Y >= -Config.DunkMaxBelowRim and offset.Y <= Config.DunkMaxAboveRim) then
		local tolerance = offset.Y < 0 and Config.DunkMaxBelowRim or Config.DunkMaxAboveRim
		local insideBuffer = offset.Y >= -Config.DunkMaxBelowRim - Config.DunkBufferVerticalAllowance
			and offset.Y <= Config.DunkMaxAboveRim + Config.DunkBufferVerticalAllowance
		return string.format("%s (height gap %.1f / %.1f studs).",
			offset.Y < 0 and "Jump higher" or "Too high above the rim", math.abs(offset.Y), tolerance), insideBuffer
	end
	return nil, false
end

local function attemptDunk(player: Player): string?
	local character = player.Character
	local rim = GameplayObjects.FindRim()
	local expiresAt = os.clock() + Config.DunkInputBufferSeconds
	local lastReason = "Dunk request expired. Press F again near the rim."
	repeat
		local reason, canBuffer = validateAttempt(player, character, rim)
		if not reason and character and rim then
			PlayerService.SetDunkState(player, "Executing")
			local completed, cancellation = DunkExecution.Run(player, character, rim)
			if not completed then
				return cancellation
			end
			PlayerService.SetDunkState(player, "Completed")
			if not PlayerService.RegisterDunk(player) then
				return "Player data is not ready."
			end
			nextAttempt[player] = os.clock() + Config.DunkCooldown
			print("[DunkService] " .. player.Name .. " completed a dunk")
			remotes.DunkResult:FireClient(player, Config.DunkCashReward)
			return nil
		end
		lastReason = reason
		if not canBuffer then
			return reason
		end
		RunService.Heartbeat:Wait()
	until os.clock() > expiresAt
	return lastReason
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
	end)
	remotes.RequestDunk.OnServerEvent:Connect(function(player)
		if not PlayerService.IsReady(player) or PlayerService.GetDunkState(player) ~= "Idle" then
			return
		end
		local now = os.clock()
		if now < (nextAttempt[player] or 0) then
			return
		end
		nextAttempt[player] = now + Config.DunkCooldown
		PlayerService.SetDunkState(player, "Attempting")
		local success, message = pcall(attemptDunk, player)
		PlayerService.SetDunkState(player, "Idle")
		if player.Parent ~= Players then
			return
		end
		if not success then
			warn("[DunkService] Attempt failed: " .. tostring(message))
			remotes.DunkResult:FireClient(player, nil, "Dunk unavailable. Check Studio Output.")
		elseif message then
			remotes.DunkResult:FireClient(player, nil, message)
			if RunService:IsStudio() then
				print("[DunkService] " .. player.Name .. " rejected: " .. message)
			end
		end
	end)
	print("[DunkService] Dunk requests ready.")
end

return DunkService
