local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HUDConfig"))

local StatFeedback = {}

function StatFeedback.new(label: TextLabel)
	local origin = label.Position
	local tween = nil
	local controller = {}
	label.TextTransparency = 1

	function controller.Show(text: string)
		if tween then
			tween:Cancel()
			tween:Destroy()
		end
		label.Text = text
		label.TextTransparency = 0
		label.Position = origin
		tween = TweenService:Create(label,
			TweenInfo.new(Config.Feedback.FadeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
				0, false, Config.Feedback.HoldSeconds), {
				TextTransparency = 1,
				Position = origin - UDim2.fromOffset(0, Config.Feedback.RisePixels),
			})
		tween:Play()
	end

	function controller.Destroy()
		if tween then
			tween:Cancel()
			tween:Destroy()
			tween = nil
		end
	end

	return controller
end

return StatFeedback
