local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.DunkConfig)
local Styles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local PlayerService = require(script.Parent.PlayerService)
local BasketballService = require(script.Parent.BasketballService)
local DunkExecution = require(script.Parent.DunkExecution)
local GameplayObjects = require(script.Parent.GameplayObjects)
local ChallengeService = require(script.Parent.ChallengeService)
local DailyService = require(script.Parent.DailyService)
local ContestService = require(script.Parent.ContestService)
local AbilityService = require(script.Parent.AbilityService)
local HeatService = require(script.Parent.HeatService)
local PickupService = require(script.Parent.PickupService)
local Analytics = require(script.Parent.AnalyticsReporter)
local SeasonXp = require(script.Parent.SeasonXp)
local SeasonXpValues = require(ReplicatedStorage.Shared.Config.SeasonConfig).XP
local PayoutOffer = require(script.Parent.PayoutOfferService)
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

local function validateAttempt(player: Player, expectedCharacter: Model?, expectedRim: BasePart?, styleId: string?): (string?, boolean, string?)
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
	local style = Styles.Get(styleId)
	if not style or PlayerService.GetEquippedDunkStyle(player) ~= styleId then
		return "Dunk selection is unavailable.", false, "INVALID_STYLE"
	end
	if not vertical or not Styles.IsUnlocked(styleId, vertical) then
		return string.format("%s unlocks at Vertical %d.", style.DisplayName, style.RequiredVertical), false, "VERTICAL_TOO_LOW"
	end
	local rim = GameplayObjects.FindRim(PlayerService.GetCurrentCourt(player))
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
		return "Jump first, then dunk while airborne.", false, "NOT_AIRBORNE"
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
		-- A press near the top of a very high jump waits (within the normal input buffer)
		-- until the player falls into range instead of being rejected outright.
		local insideBuffer = offset.Y >= -Config.DunkMaxBelowRim - Config.DunkBufferVerticalAllowance
			and offset.Y <= maxAboveRim + math.max(Config.DunkBufferVerticalAllowance, Config.DunkHighBufferStuds)
		return string.format("%s (height gap %.1f / %.1f studs).",
			offset.Y < 0 and "Jump higher" or "Too high above the rim", math.abs(offset.Y), tolerance), insideBuffer,
			offset.Y < 0 and "TOO_LOW" or "TOO_HIGH"
	end
	return nil, false, nil
end

local function attemptDunk(player: Player): (string?, string?)
	local character = player.Character
	local rim = GameplayObjects.FindRim(PlayerService.GetCurrentCourt(player))
	local requestedAt = os.clock()
	local expiresAt = requestedAt + Config.DunkInputBufferSeconds
	local styleId = PlayerService.GetEquippedDunkStyle(player)
	local lastReason = "Dunk request expired. Dunk again near the rim."
	local lastCode = "BUFFER_EXPIRED"
	repeat
		local reason, canBuffer, code = validateAttempt(player, character, rim, styleId)
		if not reason and character and rim and styleId then
			local courtId = PlayerService.GetCurrentCourt(player)
			-- Abilities armed right now are used by this dunk; a cancelled dunk keeps them armed.
			local armed = AbilityService.ArmedFor(player)
			PlayerService.SetDunkState(player, "Executing")
			local completed, cancellation, trickCash, rating, tricks, landedTricks = DunkExecution.Run(player, character, rim, styleId, armed)
			if not completed then
				return cancellation, "EXECUTION_CANCELLED"
			end
			PlayerService.SetDunkState(player, "Completed")
			-- HEAT (dunk streak) and Fireball both multiply this dunk's Cash.
			local heatMultiplier = HeatService.OnDunk(player)
			-- RegisterDunk updates the BestDunkCash stat; compared below to spot a personal best.
			local statsBefore = PlayerService.GetStats(player)
			local registered, cashReward = PlayerService.RegisterDunk(player, styleId, rating, trickCash,
				AbilityService.CashMultiplier(armed) * heatMultiplier)
			if not registered then
				return "Player data is not ready.", "PLAYER_NOT_READY"
			end
			AbilityService.Consume(player, armed)
			-- Dunk Pass XP: every dunk, more for a PERFECT or GOOD slam, plus each air trick.
			SeasonXp.Add(player, SeasonXpValues.Dunk + (rating == "Perfect" and SeasonXpValues.Perfect
				or rating == "Good" and SeasonXpValues.Good or 0) + (tricks or 0) * SeasonXpValues.AirTrick)
			local spilled, spillProblem = pcall(PickupService.SpillForDunk, player, cashReward or 0)
			if not spilled then warn("[DunkService] Cash bills failed: " .. tostring(spillProblem)) end
			nextAttempt[player] = os.clock() + Config.DunkCooldown
			local tracked, trackingProblem = pcall(ChallengeService.OnSuccessfulDunk, player, styleId, courtId)
			if not tracked then warn("[DunkService] Challenge tracking failed: " .. tostring(trackingProblem)) end
			local dailyTracked, dailyProblem = pcall(DailyService.OnDunk, player, {
				StyleId = styleId, CourtId = courtId, Rating = rating, Tricks = tricks or 0, Cash = (cashReward or 0) + (trickCash or 0),
			})
			if not dailyTracked then warn("[DunkService] Daily tracking failed: " .. tostring(dailyProblem)) end
			local judged, contestProblem = pcall(ContestService.OnDunk, player, styleId, rating, landedTricks or {})
			if not judged then warn("[DunkService] Contest judging failed: " .. tostring(contestProblem)) end
			-- Payout offer: only a big dunk (Fireball, or a new personal-best dunk payout) is
			-- reported. Ordinary dunks are not, so they never replace a bigger payout on the card.
			local statsAfter = PlayerService.GetStats(player)
			local personalBest = statsBefore ~= nil and statsAfter ~= nil and statsAfter.BestDunkCash > statsBefore.BestDunkCash
			if AbilityService.CashMultiplier(armed) > 1 or personalBest then
				local offered, offerProblem = pcall(PayoutOffer.OnPayout, player, (cashReward or 0) + (trickCash or 0), "Dunk")
				if not offered then warn("[DunkService] Payout offer failed: " .. tostring(offerProblem)) end
			end
			print("[DunkService] " .. player.Name .. " completed " .. styleId)
			remotes.DunkResult:FireClient(player, cashReward, nil, styleId, trickCash, rating)
			return nil, nil
		end
		lastReason = reason or lastReason
		lastCode = code or lastCode
		-- A dunk tapped right after jumping can arrive before the server has seen the jump
		-- (network delay). Wait briefly for takeoff instead of rejecting; the attempt still
		-- only runs once the server itself sees the player airborne.
		if code == "NOT_AIRBORNE" and os.clock() - requestedAt <= Config.DunkTakeoffGraceSeconds then
			canBuffer = true
			expiresAt = math.max(expiresAt, requestedAt + Config.DunkTakeoffGraceSeconds)
		end
		if not canBuffer then
			return reason, code
		end
		if code == "TOO_HIGH" then
			-- Near the apex of a very high jump, wait long enough to fall into range.
			expiresAt = math.max(expiresAt, requestedAt + Config.DunkHighBufferSeconds)
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
			Analytics.Custom(player, "DunkRejected_ERROR")
		elseif message then
			remotes.DunkResult:FireClient(player, nil, message)
			debugRejection(player, code, message)
			-- Counted per reason so the dashboard shows how often real players get refused
			-- (e.g. NOT_AIRBORNE would mean their jump reaches the server too late).
			Analytics.Custom(player, "DunkRejected_" .. tostring(code or "UNKNOWN"))
		end
	end)
	print("[DunkService] Dunk requests ready.")
end

return DunkService
