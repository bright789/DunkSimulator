-- "Boost that payout!" card: a title, what you just won, one Robux button per payout boost
-- (x2 / x4 / x7) and a close button. PayoutOfferController shows it for a few seconds after a
-- big payout. It sits where nothing else on the HUD lives:
--   Keyboard/mouse: the bottom-right corner, under the ability hotbar (right edge, middle) and
--     right of the bottom-centre column (action feed, slam meter, training ring, contest results;
--     all at most 400 px wide).
--   Touch: the bottom edge between Roblox's thumbstick area (left 40% of the screen) and the
--     jump / DUNK buttons (bottom-right). The touch menu and ability row are higher up on the right.
-- A UIScale shrinks the card on small screens so those gaps hold. Display only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Monetization = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local UI = require(script.Parent.UIComponents)

local PayoutOfferView = {}

local WIDTH, HEIGHT = 300, 124
-- Half the width of the bottom-centre column (400 px) plus a gap.
local CENTRE_CLEARANCE = 208
-- AbilitiesView's desktop hotbar: 3 slots of 58 px and 2 gaps of 8 px, centred at 52% height.
local HOTBAR_HALF_HEIGHT = 95
local POP_SECONDS = 0.2

local function button(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number)
	local control = Instance.new("TextButton")
	control.Name = name
	control.Size = size
	control.Position = position
	control.Text = text
	control.Font = Config.BoldFont
	control.TextColor3 = Config.Colors.Panel
	control.BackgroundColor3 = Config.Colors.Gold
	control.BorderSizePixel = 0
	UI.Round(control, 8)
	UI.FitText(control, textSize)
	control.Parent = parent
	UI.Interactive(control)
	return control
end

function PayoutOfferView.new(playerGui: PlayerGui)
	-- Above the HUD, action feed and contest results (8); below full-screen menus (10).
	local screen = UI.Screen("PayoutOffer", 9)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	-- The holder is placed and fitted to the screen; the card inside it pops in and out.
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	holder.Parent = screen
	local fitScale = Instance.new("UIScale")
	fitScale.Parent = holder
	local card = Instance.new("CanvasGroup")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.Visible = false
	card.GroupTransparency = 1
	UI.StylePanel(card)
	card.Parent = holder
	local popScale = Instance.new("UIScale")
	popScale.Parent = card
	local title = UI.Label(card, "Title", "BOOST THAT PAYOUT!", UDim2.fromOffset(240, 26), UDim2.fromOffset(12, 8), 20)
	title.Font = Config.BoldFont
	title.TextColor3 = Config.Colors.Gold
	local close = button(card, "Close", "X", UDim2.fromOffset(28, 28), UDim2.fromOffset(WIDTH - 38, 8), 14)
	close.BackgroundColor3 = Config.Colors.Button
	close.TextColor3 = Config.Colors.Text
	local detail = UI.Label(card, "Detail", "", UDim2.fromOffset(WIDTH - 24, 30), UDim2.fromOffset(12, 36), 14)
	detail.TextWrapped = true
	local buttons = {}
	local products = Monetization.PayoutProducts()
	for index, product in products do
		local control = button(card, product.Key, "", UDim2.fromOffset(88, 44), UDim2.fromOffset(10 + (index - 1) * 96, 72), 18)
		-- The biggest boost stands out in orange.
		if index == #products then control.BackgroundColor3 = Config.Colors.Warning end
		table.insert(buttons, { Button = control, Product = product })
	end
	screen.Parent = playerGui

	local view = { Buttons = buttons, Close = close }
	local tween = nil
	local version = 0

	-- Keeps the card clear of the rest of the HUD (see the top of this file).
	local function fit()
		local size = screen.AbsoluteSize
		local scale
		if touch then
			-- Mirrors DunkView's DUNK button, which sits just left of Roblox's jump button.
			local small = math.min(size.X, size.Y) <= 500
			local right = small and 177 or 289
			holder.Position = UDim2.new(1, -right, 1, -10)
			scale = (size.X - right - size.X * 0.4 - 8) / WIDTH
		else
			holder.Position = UDim2.new(1, -12, 1, -16)
			local hotbarBottom = size.Y * 0.52 + HOTBAR_HALF_HEIGHT
			scale = math.min((size.X / 2 - CENTRE_CLEARANCE - 12) / WIDTH, (size.Y - 16 - hotbarBottom - 8) / HEIGHT)
		end
		fitScale.Scale = math.clamp(scale, 0.5, 1)
	end
	local resizeConnection = screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	local function animate(goal: { [string]: any }, seconds: number, style: Enum.EasingStyle, target: Instance)
		local created = TweenService:Create(target, TweenInfo.new(seconds, style, Enum.EasingDirection.Out), goal)
		created:Play()
		return created
	end

	-- `prices[key]` = live Robux price (SuggestedRobux until Roblox answers).
	function view.Show(detailText: string, prices: { [string]: number })
		version += 1
		if tween then tween:Cancel() end
		detail.Text = detailText
		for _, entry in buttons do
			local product = entry.Product
			entry.Button.Text = string.format("x%d  R$%s", product.Multiplier, UI.Number(prices[product.Key] or product.SuggestedRobux))
		end
		fit()
		card.Visible = true
		card.GroupTransparency = 1
		popScale.Scale = 0.8
		tween = animate({ GroupTransparency = 0 }, POP_SECONDS, Enum.EasingStyle.Quad, card)
		animate({ Scale = 1 }, POP_SECONDS + 0.1, Enum.EasingStyle.Back, popScale)
	end

	function view.Hide()
		if not card.Visible then return end
		version += 1
		local thisVersion = version
		if tween then tween:Cancel() end
		tween = animate({ GroupTransparency = 1 }, POP_SECONDS, Enum.EasingStyle.Quad, card)
		animate({ Scale = 0.85 }, POP_SECONDS, Enum.EasingStyle.Quad, popScale)
		tween.Completed:Once(function()
			if thisVersion == version then card.Visible = false end
		end)
	end

	function view.Destroy()
		if tween then tween:Cancel() end
		resizeConnection:Disconnect()
		screen:Destroy()
	end

	return view
end

return PayoutOfferView
