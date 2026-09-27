local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Feel = require(ReplicatedStorage.Shared.Config.FeedbackConfig).Challenge
local UI = require(script.Parent.UIComponents)

local RewardPresentation = {}

function RewardPresentation.new(screen: ScreenGui)
	local card = Instance.new("CanvasGroup")
	card.Name = "RewardPresentation"
	card.Size = UDim2.fromScale(0.82, 0.17)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.fromScale(0.5, 0.1)
	card.GroupTransparency = 1
	card.Visible = false
	UI.StylePanel(card)
	card.Parent = screen
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(410, 120)
	limit.Parent = card
	local scale = Instance.new("UIScale")
	scale.Parent = card
	local heading = UI.Label(card, "Heading", "", UDim2.fromScale(0.9, 0.22), UDim2.fromScale(0.05, 0.08), 13)
	heading.TextXAlignment = Enum.TextXAlignment.Center
	local title = UI.Label(card, "Title", "", UDim2.fromScale(0.9, 0.36), UDim2.fromScale(0.05, 0.3), 22)
	title.Font = Config.BoldFont
	title.TextXAlignment = Enum.TextXAlignment.Center
	local detail = UI.Label(card, "Detail", "", UDim2.fromScale(0.9, 0.22), UDim2.fromScale(0.05, 0.7), 14)
	detail.TextXAlignment = Enum.TextXAlignment.Center
	local tween = nil
	local scaleTween = nil
	local timer = nil
	local version = 0
	local presentation = {}

	local function cancel()
		if tween then tween:Cancel(); tween = nil end
		if scaleTween then scaleTween:Cancel(); scaleTween = nil end
		if timer then task.cancel(timer); timer = nil end
	end

	function presentation.Hide()
		version += 1
		cancel()
		card.Visible = false
		card.GroupTransparency = 1
	end

	function presentation.Show(headingText: string, titleText: string, detailText: string, claimed: boolean)
		version += 1
		local thisVersion = version
		cancel()
		heading.Text = headingText
		heading.TextColor3 = claimed and Config.Colors.Gain or Config.Colors.Accent
		title.Text = titleText
		detail.Text = detailText
		detail.TextColor3 = claimed and Config.Colors.Gain or Config.Colors.Muted
		local positionY = claimed and 0.25 or 0.09
		card.GroupTransparency = 1
		card.Position = UDim2.new(0.5, 0, positionY, Feel.SlidePixels)
		scale.Scale = claimed and 0.9 or 0.97
		card.Visible = true
		local enter = TweenService:Create(card, TweenInfo.new(Feel.FadeSeconds, Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out), { GroupTransparency = 0, Position = UDim2.fromScale(0.5, positionY) })
		tween = enter
		enter.Completed:Once(function()
			if tween == enter then tween = nil end
			enter:Destroy()
		end)
		enter:Play()
		local grow = TweenService:Create(scale, TweenInfo.new(Feel.FadeSeconds, Enum.EasingStyle.Back,
			Enum.EasingDirection.Out), { Scale = 1 })
		scaleTween = grow
		grow.Completed:Once(function()
			if scaleTween == grow then scaleTween = nil end
			grow:Destroy()
		end)
		grow:Play()
		timer = task.delay(claimed and Feel.ClaimHoldSeconds or Feel.CompletionHoldSeconds, function()
			timer = nil
			if thisVersion ~= version then return end
			local leave = TweenService:Create(card, TweenInfo.new(Feel.FadeSeconds), {
				GroupTransparency = 1,
				Position = UDim2.new(0.5, 0, positionY, -Feel.SlidePixels),
			})
			tween = leave
			leave.Completed:Once(function()
				if thisVersion == version then card.Visible = false end
				if tween == leave then tween = nil end
				leave:Destroy()
			end)
			leave:Play()
		end)
	end

	function presentation.Destroy()
		presentation.Hide()
		card:Destroy()
	end

	return presentation
end

return RewardPresentation
