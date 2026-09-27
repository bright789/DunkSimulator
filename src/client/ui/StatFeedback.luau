-- Gain popup for a HUD stat card: a bright pill badge ("+$375", "+8", "LEVEL UP!") in the
-- card's accent color with dark text, popping in at the right of the value row, holding
-- long enough to read, then rising and fading as one piece. The card pulses too.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Config = require(Shared:WaitForChild("FeedbackConfig")).Stats
local HUD = require(Shared:WaitForChild("HUDConfig"))

local StatFeedback = {}

function StatFeedback.new(card: Frame, accent: Color3, pulseScale: number, rowCenterY: number)
	local badge = Instance.new("CanvasGroup")
	badge.Name = "GainBadge"
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.Size = UDim2.fromOffset(Config.BadgeWidth, Config.BadgeHeight)
	badge.BackgroundColor3 = accent
	badge.BorderSizePixel = 0
	badge.GroupTransparency = 1
	badge.Visible = false
	badge.ZIndex = 5
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = badge
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, -12, 1, -4)
	text.Position = UDim2.fromOffset(6, 2)
	text.Font = HUD.BoldFont
	text.TextColor3 = HUD.Colors.Panel
	text.TextScaled = true
	text.ZIndex = 6
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = Config.BadgeTextSize
	limit.MinTextSize = 10
	limit.Parent = text
	text.Parent = badge
	local scale = Instance.new("UIScale")
	scale.Parent = badge
	badge.Parent = card

	local home = UDim2.new(1, 0, 0, rowCenterY)
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card
	local tweens = {}
	local version = 0
	local controller = {}

	local function stop()
		for _, tween in tweens do tween:Cancel(); tween:Destroy() end
		table.clear(tweens)
	end

	local function play(object, info, goal)
		local tween = TweenService:Create(object, info, goal)
		table.insert(tweens, tween)
		tween:Play()
		return tween
	end

	function controller.Show(message: string)
		version += 1
		local current = version
		stop()
		text.Text = message
		badge.Visible = true
		badge.GroupTransparency = 0
		badge.Position = home
		scale.Scale = Config.BadgePopScale
		play(scale, TweenInfo.new(Config.BadgePopSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		play(badge, TweenInfo.new(Config.GainFadeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false,
			Config.GainHoldSeconds), {
			GroupTransparency = 1,
			Position = home - UDim2.fromOffset(0, Config.GainRisePixels),
		}).Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and version == current then badge.Visible = false end
		end)
		cardScale.Scale = pulseScale
		play(cardScale, TweenInfo.new(Config.PulseSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
	end

	function controller.Destroy()
		stop()
	end

	return controller
end

return StatFeedback
