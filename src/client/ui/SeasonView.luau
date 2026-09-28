-- DUNK PASS screen: the season header and countdown, the XP bar, a scrolling row of 30 tier
-- cards (FREE reward on top, PREMIUM reward underneath), CLAIM ALL and the premium pass button.
-- Display only; SeasonController fills it from the server's attributes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Season = require(ReplicatedStorage.Shared.Config.SeasonConfig)
local UI = require(script.Parent.UIComponents)

local SeasonView = {}

local GOLD = Color3.fromRGB(255, 196, 40)
local CARD_W, CARD_H = 104, 250

local function label(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number, center: boolean?)
	local created = UI.Label(parent, name, text, size, position, textSize)
	if center then created.TextXAlignment = Enum.TextXAlignment.Center end
	return created
end

local function button(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number)
	local created = Instance.new("TextButton")
	created.Name = name
	created.Size = size
	created.Position = position
	created.Text = text
	created.Font = Config.BoldFont
	created.TextColor3 = Config.Colors.Text
	created.BackgroundColor3 = Config.Colors.Button
	created.BorderSizePixel = 0
	UI.Round(created, 8)
	UI.FitText(created, textSize)
	created.Parent = parent
	UI.Interactive(created)
	return created
end

local function setEnabled(target: TextButton, enabled: boolean, color: Color3?)
	target.Active = enabled
	target.AutoButtonColor = enabled
	target.BackgroundColor3 = enabled and (color or Config.Colors.Button) or Config.Colors.Inset
	target.TextColor3 = enabled and Config.Colors.Text or Config.Colors.Muted
end

-- One reward box inside a tier card.
local function rewardBox(card: Frame, name: string, y: number, premium: boolean)
	local box = Instance.new("Frame")
	box.Name = name
	box.Size = UDim2.new(1, -10, 0, 104)
	box.Position = UDim2.fromOffset(5, y)
	box.BackgroundColor3 = premium and Color3.fromRGB(60, 44, 16) or Config.Colors.Panel
	box.BorderSizePixel = 0
	UI.Round(box, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Color = premium and GOLD or Config.Colors.Stroke
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = box
	box.Parent = card
	local tag = label(box, "Tag", premium and "PREMIUM" or "FREE", UDim2.new(1, -8, 0, 12), UDim2.fromOffset(4, 3), 10, true)
	tag.TextColor3 = premium and GOLD or Config.Colors.Muted
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.new(1, 0, 0, 30)
	icon.Position = UDim2.fromOffset(0, 16)
	icon.TextScaled = true
	icon.Font = Enum.Font.GothamBold
	icon.Parent = box
	local text = label(box, "Text", "", UDim2.new(1, -8, 0, 26), UDim2.fromOffset(4, 47), 12, true)
	text.Font = Config.BoldFont
	text.TextWrapped = true
	local action = button(box, "Action", "", UDim2.new(1, -12, 0, 24), UDim2.new(0, 6, 1, -28), 12)
	return { Box = box, Icon = icon, Text = text, Action = action, Stroke = stroke }
end

function SeasonView.new(playerGui: PlayerGui)
	local screen = UI.Screen("DunkPass", 10)
	local panel = UI.Panel(screen, "Menu", UDim2.fromScale(0.86, 0.8), UDim2.fromScale(0.5, 0.5))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(760, 470)
	limit.MinSize = Vector2.new(330, 300)
	limit.Parent = panel
	local title = label(panel, "Title", "DUNK PASS", UDim2.new(0.5, 0, 0, 30), UDim2.fromOffset(14, 8), 26)
	title.Font = Config.BoldFont
	title.TextColor3 = GOLD
	local subtitle = label(panel, "Season", "", UDim2.new(0.8, 0, 0, 18), UDim2.fromOffset(14, 38), 13)
	subtitle.TextColor3 = Config.Colors.Muted
	local close = button(panel, "Close", "X", UDim2.fromOffset(34, 30), UDim2.new(1, -46, 0, 10), 14)

	-- XP bar.
	local tierLabel = label(panel, "Tier", "", UDim2.fromOffset(110, 24), UDim2.fromOffset(14, 62), 18)
	tierLabel.Font = Config.BoldFont
	local barBack = Instance.new("Frame")
	barBack.Name = "XpBar"
	barBack.Size = UDim2.new(1, -150, 0, 20)
	barBack.Position = UDim2.fromOffset(130, 64)
	barBack.BackgroundColor3 = Config.Colors.Inset
	barBack.BorderSizePixel = 0
	UI.Round(barBack, 10)
	barBack.Parent = panel
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = GOLD
	barFill.BorderSizePixel = 0
	UI.Round(barFill, 10)
	barFill.Parent = barBack
	local xpText = label(barBack, "Xp", "", UDim2.fromScale(1, 1), UDim2.new(), 13, true)
	xpText.Font = Config.BoldFont
	xpText.ZIndex = 2

	-- Tier cards.
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Tiers"
	scroll.Size = UDim2.new(1, -24, 1, -150)
	scroll.Position = UDim2.fromOffset(12, 94)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.ScrollingDirection = Enum.ScrollingDirection.X
	scroll.CanvasSize = UDim2.fromOffset(Season.MaxTiers * (CARD_W + 8), 0)
	scroll.Parent = panel
	-- The cards sit in one row frame that gets scaled to fit the scroll height. (A UIScale
	-- scales its parent too, so it must not go on the ScrollingFrame itself, or the whole
	-- scroll area grows past the panel.)
	local rowWidth = Season.MaxTiers * (CARD_W + 8)
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(rowWidth, CARD_H)
	row.Parent = scroll
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	local scale = Instance.new("UIScale")
	scale.Parent = row

	local cards = {}
	for tier = 1, Season.MaxTiers do
		local card = Instance.new("Frame")
		card.Name = "Tier" .. tier
		card.LayoutOrder = tier
		card.Size = UDim2.fromOffset(CARD_W, CARD_H)
		card.BackgroundColor3 = Config.Colors.Inset
		card.BorderSizePixel = 0
		UI.Round(card, 10)
		card.Parent = row
		local number = label(card, "Number", "TIER " .. tier, UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 4), 15, true)
		number.Font = Config.BoldFont
		cards[tier] = {
			Card = card,
			Number = number,
			Free = rewardBox(card, "Free", 28, false),
			Premium = rewardBox(card, "Premium", 138, true),
		}
	end
	-- Fit the cards to the scroll height (the scroll frame itself is never scaled).
	local function fit()
		local height = scroll.AbsoluteSize.Y - 12
		scale.Scale = math.clamp(height / CARD_H, 0.55, 1.2)
		scroll.CanvasSize = UDim2.fromOffset(rowWidth * scale.Scale, 0)
	end
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	local claimAll = button(panel, "ClaimAll", "CLAIM ALL", UDim2.fromOffset(150, 36), UDim2.new(0, 14, 1, -48), 16)
	local passButton = button(panel, "GetPass", "GET DUNK PASS", UDim2.fromOffset(220, 36), UDim2.new(1, -234, 1, -48), 16)
	local result = label(panel, "Result", "", UDim2.new(1, -420, 0, 36), UDim2.new(0, 172, 1, -48), 13, true)
	result.TextWrapped = true
	screen.Parent = playerGui
	fit()

	local view = { Panel = panel, Close = close, ClaimAll = claimAll, PassButton = passButton, Cards = cards, Scroll = scroll }

	function view.SetHeader(seasonText: string, tier: number, into: number, need: number)
		subtitle.Text = seasonText
		tierLabel.Text = "TIER " .. tier
		if need > 0 then
			xpText.Text = string.format("%d / %d XP", into, need)
			barFill.Size = UDim2.fromScale(math.clamp(into / need, 0, 1), 1)
		else
			xpText.Text = "MAX TIER!"
			barFill.Size = UDim2.fromScale(1, 1)
		end
	end

	-- `state`: Icon, Text, TextColor, Status ("Claim", "Claimed", "Locked", "Pass"), Reached.
	function view.SetReward(tier: number, track: string, state)
		local box = cards[tier][track]
		box.Icon.Text = state.Icon
		box.Text.Text = state.Text
		box.Text.TextColor3 = state.TextColor or Config.Colors.Text
		local status = state.Status
		box.Action.Text = status == "Claim" and "CLAIM" or status == "Claimed" and "✓" or status == "Pass" and "🔒 PASS"
			or ("TIER " .. tier)
		setEnabled(box.Action, status == "Claim", Config.Colors.Gain)
		if status == "Claimed" then box.Action.TextColor3 = Config.Colors.Gain end
		box.Box.BackgroundTransparency = state.Reached and 0 or 0.35
	end

	function view.SetTierReached(tier: number, reached: boolean, current: boolean)
		local card = cards[tier]
		card.Card.BackgroundColor3 = current and Color3.fromRGB(70, 90, 160) or Config.Colors.Inset
		card.Number.TextColor3 = reached and GOLD or Config.Colors.Muted
	end

	function view.SetButtons(claimable: number, passText: string, passEnabled: boolean)
		claimAll.Text = claimable > 0 and string.format("CLAIM ALL (%d)", claimable) or "CLAIM ALL"
		setEnabled(claimAll, claimable > 0, Config.Colors.Gain)
		passButton.Text = passText
		setEnabled(passButton, passEnabled, Color3.fromRGB(230, 150, 20))
	end

	function view.ShowResult(ok: boolean, message: string)
		result.Text = message
		result.TextColor3 = ok and Config.Colors.Gain or Config.Colors.Warning
	end

	-- Scrolls so `tier` is near the left edge.
	function view.ScrollTo(tier: number)
		scroll.CanvasPosition = Vector2.new(math.max(0, (tier - 2) * (CARD_W + 8) * scale.Scale), 0)
	end

	function view.Destroy()
		screen:Destroy()
	end

	return view
end

return SeasonView
