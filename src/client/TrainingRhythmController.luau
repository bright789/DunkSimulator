-- Active training: while you train at the Leg Day Gym, press on the beat (click, tap the PUMP
-- ring, or RB) for a bigger rep. Sends TrainingPulse (no data); the server stamps and judges
-- the press and answers with (grade, Vertical gained, combo) for every rep it pays. The
-- PERFECT/GOOD/MISS shown on the press is only a local guess.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Training = require(ReplicatedStorage.Shared.Config.ProgressionConfig).Training
local View = require(script.Parent.ui:WaitForChild("TrainingRhythmView"))
local Feedback = require(script.Parent.FeedbackController)

local TrainingRhythmController = {}

local CAPTIONS = {
	Keyboard = "CLICK ON THE BEAT!",
	Gamepad = "PRESS RB ON THE BEAT!",
	Touch = "TAP PUMP ON THE BEAT!",
}

local function inputMode(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then return "Touch" end
	if string.find(last.Name, "Gamepad") then return "Gamepad" end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and "Touch" or "Keyboard"
end

function TrainingRhythmController.new(player: Player)
	local remote = ReplicatedStorage.Remotes:WaitForChild("TrainingPulse")
	local view = View.new(player:WaitForChild("PlayerGui"))
	local interval = Training.TickIntervalSeconds
	local rhythm = Training.Rhythm
	local connections = {}
	local active = false
	local lastPress = 0

	local function firstBeat(): number?
		return tonumber(player:GetAttribute("TrainingBeatAt"))
	end

	local function press()
		local first = firstBeat()
		if not active or not first or os.clock() - lastPress < rhythm.MinPressGapSeconds then return end
		lastPress = os.clock()
		remote:FireServer()
		local now = Workspace:GetServerTimeNow()
		local beat = math.floor((now - first) / interval + 0.5)
		local delta = math.abs(now - (first + beat * interval))
		view.Press(delta <= rhythm.PerfectSeconds and "Perfect" or delta <= rhythm.GoodSeconds and "Good" or "Miss")
	end

	local function refresh()
		active = player:GetAttribute("Training") == true
		view.SetVisible(active, CAPTIONS[inputMode()])
	end

	table.insert(connections, player:GetAttributeChangedSignal("Training"):Connect(refresh))
	table.insert(connections, view.Button.Activated:Connect(press))
	-- Mouse clicks and RB anywhere (clicks on other buttons are "game processed" and ignored).
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not active then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR1 then
			press()
		end
	end))
	table.insert(connections, remote.OnClientEvent:Connect(function(grade, gain, combo)
		if typeof(gain) ~= "number" or typeof(combo) ~= "number" then return end
		view.Gain(gain, grade)
		view.SetCombo(combo)
		if grade == "Perfect" or grade == "Good" then Feedback.AirTrick(math.clamp(combo, 1, 8)) end
	end))
	table.insert(connections, RunService.RenderStepped:Connect(function()
		local first = firstBeat()
		if not active or not first then return end
		local elapsed = Workspace:GetServerTimeNow() - first
		view.SetPhase(elapsed < 0 and 1 + elapsed / interval or (elapsed % interval) / interval)
	end))
	refresh()

	local controller = {}
	function controller.Destroy()
		for _, connection in connections do connection:Disconnect() end
		view.Destroy()
	end
	return controller
end

return TrainingRhythmController
