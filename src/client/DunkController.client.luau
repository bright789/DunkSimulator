local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"):WaitForChild("DunkConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestDunk = remotes:WaitForChild("RequestDunk")
local dunkResult = remotes:WaitForChild("DunkResult")
local dunkPresentation = remotes:WaitForChild("DunkPresentation")
local dunkTrick = remotes:WaitForChild("DunkTrick")
local slamTiming = remotes:WaitForChild("SlamTiming")
local DunkRewards = require(shared.Config:WaitForChild("DunkRewards"))
local Styles = require(shared.Config:WaitForChild("DunkStyles"))
local DunkView = require(script.Parent:WaitForChild("ui"):WaitForChild("DunkView"))
local Feel = require(shared.Config.FeedbackConfig)
local Feedback = require(script.Parent:WaitForChild("FeedbackController"))
local Animation = require(script.Parent:WaitForChild("DunkAnimationController"))
local VFX = require(script.Parent:WaitForChild("DunkVFX"))
local Abilities = require(shared.Config:WaitForChild("AbilityConfig"))
local view = DunkView.new(player:WaitForChild("PlayerGui"))
local connections = {}

local feedbackVersion = 0
local lastResultAt = -math.huge
local nextRequest = 0
local hadBall = player:GetAttribute("HasBasketball") == true
local presentationCues = {}

local function showCue(styleId: string, moment: string)
	if (moment == "Gather" or moment == "Slam") and presentationCues[moment] then return end
	presentationCues[moment] = true
	Feedback.DunkPhase(styleId, moment)
end

Animation.Init(function(styleId, marker)
	if marker == "Recover" then
		Animation.FadeOut(player.Character)
	else
		showCue(styleId, marker)
	end
end)

-- One dunk control for every device: F on a keyboard, RT on a gamepad (the X button
-- is left to the E-style ProximityPrompts), and an on-screen DUNK button on touch screens.
-- During the slam meter the same press is the slam-timing press.
local DUNK_ACTION = "Dunk"
local HINT_KEYS = { Keyboard = "F", Gamepad = "RT" }
local SLAM_CAPTIONS = { Keyboard = "PRESS F TO SLAM!", Gamepad = "PRESS RT TO SLAM!", Touch = "TAP TO SLAM!" }

local function readInputMode(): string
	local lastInput = UserInputService:GetLastInputType()
	if lastInput == Enum.UserInputType.Touch then return "Touch" end
	if string.find(lastInput.Name, "^Gamepad") then return "Gamepad" end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return "Touch" end
	return "Keyboard"
end

local inputMode = readInputMode()
local actionBound = false
local refreshControls -- defined once the slam meter exists (below)

local function updateHint()
	view.SetHintKey(HINT_KEYS[inputMode] or "F")
	view.SetHint(inputMode ~= "Touch" and player:GetAttribute("HasBasketball") == true
		and player:GetAttribute("DunkState") ~= "Executing")
	refreshControls()
end

table.insert(connections, player:GetAttributeChangedSignal("HasBasketball"):Connect(function()
	local hasBall = player:GetAttribute("HasBasketball") == true
	if hasBall and not hadBall then Feedback.Pickup() end
	hadBall = hasBall
	updateHint()
end))
table.insert(connections, player:GetAttributeChangedSignal("DunkState"):Connect(updateHint))
table.insert(connections, UserInputService.LastInputTypeChanged:Connect(function()
	local mode = readInputMode()
	if mode ~= inputMode then
		inputMode = mode
		updateHint()
	end
end))

-- Perfect-slam meter for this player's dunk. The client only predicts when the slam
-- lands (to draw the needle); the server times the press itself and decides the rating.
local meter = { Active = false, Pressed = false, Start = 0, Total = 1 }

local function latency(): number
	return math.clamp(player:GetNetworkPing(), 0, DunkRewards.Timing.MaxLatencyCompensationSeconds)
end

local function gatherSeconds(): number
	local style = Styles.Get(player:GetAttribute("EquippedDunkStyle"))
	return style and style.GatherSeconds or 0.4
end

-- Slow-Mo Slam widens the timing windows for this dunk (the server judges with the same scale).
local function timingWindows()
	if Abilities.InList(player:GetAttribute("DunkAbilities"), "SlowMo") then
		return Abilities.ScaledTiming(DunkRewards.Timing, Abilities.Abilities.SlowMo.TimingScale)
	end
	return DunkRewards.Timing
end

local function localRating(delta: number): string
	local timing = timingWindows()
	if delta >= -timing.PerfectEarlySeconds and delta <= timing.PerfectLateSeconds then return "Perfect" end
	if delta >= -timing.GoodEarlySeconds and delta <= timing.GoodLateSeconds then return "Good" end
	return delta < 0 and "Early" or "Late"
end

local function pressSlam()
	if not meter.Active or meter.Pressed then return end
	meter.Pressed = true
	slamTiming:FireServer()
	local elapsed = os.clock() - meter.Start
	local rating = localRating(elapsed - meter.Total)
	view.MeterPressed(elapsed, rating)
	VFX.SetPrediction(rating)
	if rating == "Perfect" then Feedback.PerfectSlam() end
end

table.insert(connections, player:GetAttributeChangedSignal("DunkPhase"):Connect(function()
	local phase = player:GetAttribute("DunkPhase")
	local now = os.clock()
	if phase == "Descent" and not meter.Active then
		meter.Active, meter.Pressed, meter.Start = true, false, now
		meter.Total = (tonumber(player:GetAttribute("DunkDescentSeconds")) or 0.3) + Feel.SlamMeter.SettleSeconds
			+ gatherSeconds() - latency()
		local caption = SLAM_CAPTIONS[inputMode] or SLAM_CAPTIONS.Keyboard
		if timingWindows() ~= DunkRewards.Timing then caption = "SLOW-MO!  " .. caption end
		view.StartMeter(meter.Total, timingWindows(), caption)
		refreshControls()
	elseif meter.Active and phase == "Gather" then
		meter.Total = (now - meter.Start) + gatherSeconds() - latency()
		view.SetMeterTotal(meter.Total, timingWindows())
	elseif meter.Active and phase == "Slam" then
		meter.Total = (now - meter.Start) - latency()
		view.SetMeterTotal(meter.Total, timingWindows())
	elseif phase == nil and meter.Active then
		meter.Active = false
		refreshControls()
		local started = meter.Start
		task.delay(Feel.SlamMeter.HideDelaySeconds, function()
			if not meter.Active or meter.Start ~= started then view.HideMeter() end
		end)
	end
end))

table.insert(connections, RunService.RenderStepped:Connect(function()
	if meter.Active and not meter.Pressed then view.UpdateMeter(os.clock() - meter.Start) end
end))
table.insert(connections, view.MeterButton.Activated:Connect(pressSlam))

-- The dunk press from any device. The server still checks the ball, the rim distance,
-- being airborne and the cooldown; this only avoids sending requests that can't work.
local function pressDunk()
	if meter.Active then
		pressSlam()
		return
	end
	if player:GetAttribute("HasBasketball") ~= true or os.clock() < nextRequest then
		return
	end
	if player:GetAttribute("DunkState") == "Executing" then
		return
	end
	nextRequest = os.clock() + Config.DunkCooldown
	requestDunk:FireServer()
end

local function onDunkAction(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		pressDunk()
	end
	return Enum.ContextActionResult.Sink
end

-- F / RT are only bound while holding a ball or during the slam meter, so they don't
-- swallow those keys the rest of the time. The touch button follows the same rule.
function refreshControls()
	local wanted = meter.Active or player:GetAttribute("HasBasketball") == true
	if wanted ~= actionBound then
		actionBound = wanted
		if wanted then
			ContextActionService:BindAction(DUNK_ACTION, onDunkAction, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
		else
			ContextActionService:UnbindAction(DUNK_ACTION)
		end
	end
	view.SetDunkButton(wanted and inputMode == "Touch", meter.Active and "SLAM!" or "DUNK")
end

table.insert(connections, view.DunkButton.Activated:Connect(pressDunk))
updateHint()

-- Server-paid air tricks while dropping into the dunk (display only).
table.insert(connections, dunkTrick.OnClientEvent:Connect(function(trickId, comboIndex, cash, comboSize)
	local trick = DunkRewards.GetTrick(trickId)
	if not trick or typeof(cash) ~= "number" or typeof(comboIndex) ~= "number" or typeof(comboSize) ~= "number" then
		return
	end
	view.ShowTrick(trick.DisplayName, cash, comboIndex, comboSize)
	Feedback.AirTrick(comboIndex)
end))

table.insert(connections, dunkResult.OnClientEvent:Connect(function(cashReward, rejectionReason, styleId, trickCash, rating)
	lastResultAt = os.clock()
	feedbackVersion += 1
	local version = feedbackVersion
	view.ShowResult(cashReward, rejectionReason, styleId, trickCash, rating == "Perfect" and "Perfect" or rating == "Good" and "Good" or nil)
	Animation.Stop(player.Character)
	if typeof(cashReward) == "number" then Feedback.OnDunkCompleted(styleId) else Feedback.StopCamera() end
	task.delay(Feel.Dunk.PopupHoldSeconds, function()
		if feedbackVersion == version then
			view.HideResult()
		end
	end)
end))

table.insert(connections, dunkPresentation.OnClientEvent:Connect(function(styleId, moment, character, useTrack, serverStartedAt)
	if moment == "AnimationStart" then
		table.clear(presentationCues)
		if useTrack == true then Animation.Start(styleId, character, serverStartedAt) end
		return
	elseif moment == "AnimationFadeOut" then
		Animation.FadeOut(character)
		return
	elseif moment == "AnimationStop" then
		Animation.Stop(character)
		return
	end
	if os.clock() - lastResultAt >= Feel.Dunk.StaleCueGuardSeconds
		and typeof(styleId) == "string" and typeof(moment) == "string" then
		showCue(styleId, moment)
	end
end))

if RunService:IsStudio() then
	print("[DunkController] Ready: pick up a ball, jump near the rim, and press F (RT on a gamepad, DUNK on touch).")
end

table.insert(connections, player.CharacterRemoving:Connect(function()
	feedbackVersion += 1
	hadBall = false
	view.SetHint(false, true)
	view.HideResult(true)
	Animation.Stop(player.Character)
	Feedback.StopCamera()
end))

script.Destroying:Connect(function()
	feedbackVersion += 1
	ContextActionService:UnbindAction(DUNK_ACTION)
	Feedback.StopCamera()
	Animation.Destroy()
	for _, connection in connections do
		connection:Disconnect()
	end
	view.Destroy()
end)
