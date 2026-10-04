-- Goal tracker card: the current goal from GoalService with a progress bar and its Cash
-- reward, and a short "GOAL COMPLETE!" celebration when one pays. Display only. It sits where
-- nothing else on the HUD lives:
--   Keyboard/mouse/gamepad: the top-right corner. Everything at the top centre (Dunk Contest
--     banner, NEXT goal bar and HEAT pill, tutorial card, reward toasts) is at most 470 px
--     wide, so the card shrinks to stay right of that column. The left stat/menu column, the
--     contest scorecard (right side, from 30% down), the ability hotbar (right edge, middle)
--     and the payout card (bottom right) are all elsewhere.
--   Touch (whether the HUD uses its touch layout comes from HUDView, so the two agree):
--     phones: the menu, ability row and jump/DUNK buttons fill the right side, so the card
--     sits under the stat column on the left (same width and scale as the stat cards),
--     ending above the thumbstick ring. Tablets: the stat column is tall, so the card goes
--     under the menu and ability row on the right instead, above the jump/DUNK buttons. If
--     neither fits, it hides. It has no buttons, so touches pass through it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local UI = require(script.Parent.UIComponents)

local GoalView = {}

local WIDTH = Config.Layout.ColumnWidth
local HEIGHT = 72
-- Half the width of the widest top-centre element (the Dunk Contest banner, 470 px).
local CENTRE_CLEARANCE = 235
-- Gap under the stat column on touch.
local TOUCH_GAP = 6
-- On touch the card ends above this fraction of the screen height: Roblox's thumbstick ring
-- sits below it in the lower left (the card has no buttons, so touches pass through anyway).
local TOUCH_MAX_BOTTOM = 0.76
-- Right-side placement: space kept free above the bottom for Roblox's jump button and the
-- DUNK button beside it (small vs. bigger screens, as in DunkView).
local TOUCH_BOTTOM_SMALL = 95
local TOUCH_BOTTOM_LARGE = 215
-- Below this the card would be unreadable, so it hides.
local MIN_TOUCH_SCALE = 0.35 -- the compact stat cards themselves go down to 0.4

-- `hud` is the HUDView (its stat `Column` and `TouchLayout`); on touch the card goes under
-- the stat column.
function GoalView.new(playerGui: PlayerGui, hud)
	local screen = UI.Screen("GoalTracker", 3)
	local column: GuiObject = hud.Column
	local navigation: GuiObject = hud.Navigation
	local touch = hud.TouchLayout == true
	-- The holder is placed and fitted to the screen; the card inside it pops on completion.
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	holder.Parent = screen
	local fitScale = Instance.new("UIScale")
	fitScale.Parent = holder
	-- Centred in the holder so the completion pop grows evenly and stays on screen.
	local card = UI.Panel(holder, "Card", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5))
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Visible = false
	local stroke = card:FindFirstChildOfClass("UIStroke")
	local popScale = Instance.new("UIScale")
	popScale.Parent = card
	local heading = UI.Label(card, "Heading", "NEXT GOAL", UDim2.new(1, -110, 0, 16), UDim2.fromOffset(10, 6), 13)
	heading.Font = Config.BoldFont
	heading.TextColor3 = Config.Colors.Gold
	local reward = UI.Label(card, "Reward", "", UDim2.fromOffset(96, 18), UDim2.new(1, -106, 0, 5), 16)
	reward.Font = Config.BoldFont
	reward.TextXAlignment = Enum.TextXAlignment.Right
	reward.TextColor3 = Config.Colors.Gain
	local text = UI.Label(card, "Text", "", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 23), 14)
	text.TextWrapped = true
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, -20, 0, 14)
	track.Position = UDim2.fromOffset(10, 52)
	track.BackgroundColor3 = Config.Colors.Inset
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	UI.Round(track, 5)
	track.Parent = card
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Config.Colors.Accent
	fill.BorderSizePixel = 0
	UI.Round(fill, 5)
	fill.Parent = track
	local count = UI.Label(track, "Count", "", UDim2.fromScale(1, 1), UDim2.new(), 11)
	count.Font = Config.BoldFont
	count.TextXAlignment = Enum.TextXAlignment.Center
	count.ZIndex = 2
	screen.Parent = playerGui

	local function hotbarBottom(): number?
		local abilities = playerGui:FindFirstChild("Abilities")
		local bar = abilities and abilities:FindFirstChild("Hotbar")
		if bar and bar:IsA("GuiObject") and bar.Visible then
			return bar.AbsolutePosition.Y + bar.AbsoluteSize.Y
		end
		return nil
	end

	-- Keeps the card clear of the rest of the HUD (see the top of this file).
	local function fit()
		local size = screen.AbsoluteSize
		if touch then
			local origin = screen.AbsolutePosition
			-- Left: under the stat column.
			local left = math.floor(column.AbsolutePosition.X - origin.X)
			local top = math.floor(column.AbsolutePosition.Y + column.AbsoluteSize.Y - origin.Y + TOUCH_GAP)
			local scale = math.min(column.AbsoluteSize.X / WIDTH, (size.Y * TOUCH_MAX_BOTTOM - top) / HEIGHT)
			if scale >= MIN_TOUCH_SCALE then
				holder.AnchorPoint = Vector2.new(0, 0)
				holder.Position = UDim2.fromOffset(left, top)
			else
				-- Right: under the menu buttons and the ability row, above jump/DUNK.
				local below = navigation.AbsolutePosition.Y + navigation.AbsoluteSize.Y
				local bar = hotbarBottom()
				if bar then below = math.max(below, bar) end
				top = math.floor(below - origin.Y + TOUCH_GAP)
				local bottomSpace = math.min(size.X, size.Y) <= 500 and TOUCH_BOTTOM_SMALL or TOUCH_BOTTOM_LARGE
				scale = math.min(navigation.AbsoluteSize.X / WIDTH, (size.Y - bottomSpace - top) / HEIGHT)
				holder.AnchorPoint = Vector2.new(1, 0)
				holder.Position = UDim2.new(1, -10, 0, top)
			end
			fitScale.Scale = math.max(scale, 0.1)
			holder.Visible = scale >= MIN_TOUCH_SCALE
		else
			holder.Position = UDim2.new(1, -12, 0, 8)
			fitScale.Scale = math.clamp((size.X / 2 - CENTRE_CLEARANCE - 24) / WIDTH, 0.6, 1)
		end
	end
	local connections = {}
	table.insert(connections, screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
	if touch then
		for _, frame in { column, navigation } do
			table.insert(connections, frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
			table.insert(connections, frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(fit))
		end
		local abilities = playerGui:FindFirstChild("Abilities")
		local bar = abilities and abilities:FindFirstChild("Hotbar")
		if bar and bar:IsA("GuiObject") then
			table.insert(connections, bar:GetPropertyChangedSignal("AbsolutePosition"):Connect(fit))
			table.insert(connections, bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
		end
	end
	fit()

	local view = {}
	local popTween = nil

	local function setBar(fraction: number, color: Color3)
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		fill.BackgroundColor3 = color
	end

	-- `goal` is { Text, Progress, From, Target, Reward }, or nil to hide the card.
	function view.Show(goal)
		if not goal then
			card.Visible = false
			return
		end
		card.Visible = true
		if stroke then stroke.Color = Config.Colors.Stroke end
		heading.Text = "NEXT GOAL"
		heading.TextColor3 = Config.Colors.Gold
		text.Text = goal.Text
		reward.Text = "+$" .. UI.Number(goal.Reward)
		local span = goal.Target - goal.From
		setBar(span > 0 and (goal.Progress - goal.From) / span or 0, Config.Colors.Accent)
		count.Text = goal.Target > 1 and string.format("%s / %s", UI.Number(goal.Progress), UI.Number(goal.Target)) or ""
	end

	-- A goal was just paid: show it complete with its reward and pop the card.
	function view.Celebrate(goalText: string, cash: number)
		card.Visible = true
		if stroke then stroke.Color = Config.Colors.Gain end
		heading.Text = "GOAL COMPLETE!"
		heading.TextColor3 = Config.Colors.Gain
		text.Text = goalText
		reward.Text = "+$" .. UI.Number(cash)
		setBar(1, Config.Colors.Gain)
		count.Text = ""
		if popTween then popTween:Cancel() end
		popScale.Scale = 1.08
		popTween = TweenService:Create(popScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		popTween:Play()
	end

	function view.Destroy()
		if popTween then popTween:Cancel() end
		for _, connection in connections do connection:Disconnect() end
		screen:Destroy()
	end

	return view
end

return GoalView
