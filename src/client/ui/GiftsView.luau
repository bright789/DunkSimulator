-- FREE GIFTS panel: one row per playtime gift with its time, its reward and a CLAIM button
-- (or a countdown, or CLAIMED). Display only; GiftsController sends the claims and the server
-- decides everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Gifts = require(ReplicatedStorage.Shared.Config.GiftConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local UI = require(script.Parent.UIComponents)

local GiftsView = {}

local function button(parent, name, text, size, position)
	local control = Instance.new("TextButton")
	control.Name = name
	control.Size = size
	control.Position = position
	control.Text = text
	control.Font = Config.BoldFont
	control.TextColor3 = Config.Colors.Text
	control.BackgroundColor3 = Config.Colors.Button
	control.BorderSizePixel = 0
	UI.Round(control, 8)
	UI.FitText(control, 14)
	control.Parent = parent
	UI.Interactive(control)
	return control
end

local function setEnabled(control: TextButton, enabled: boolean)
	control.Active = enabled
	control.Selectable = enabled
	control.AutoButtonColor = enabled
	control.BackgroundColor3 = enabled and Config.Colors.Gold or Config.Colors.Inset
	control.TextColor3 = enabled and Config.Colors.Panel or Config.Colors.Muted
end

-- "0:42" / "12:30" (rounded up, so it never shows 0:00 early).
function GiftsView.Clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- What a gift gives, e.g. "$63  +  2x CASH 3 MIN  +  CREW PACK".
function GiftsView.RewardText(gift): string
	local parts = {}
	if gift.Cash > 0 then table.insert(parts, "$" .. UI.Number(gift.Cash)) end
	if gift.BoostMinutes > 0 then
		table.insert(parts, string.format("%dx CASH %d MIN", Daily.Boost.Multiplier, gift.BoostMinutes))
	end
	if gift.CrewPack then table.insert(parts, "CREW PACK") end
	return table.concat(parts, "  +  ")
end

function GiftsView.new(playerGui: PlayerGui)
	local screen = UI.Screen("Gifts", 10)
	local panel = UI.Panel(screen, "Menu", UDim2.fromScale(0.86, 0.82), UDim2.fromScale(0.5, 0.5))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(440, 540)
	limit.Parent = panel
	local title = UI.Label(panel, "Title", "FREE GIFTS", UDim2.fromScale(0.78, 0.08), UDim2.fromScale(0.05, 0.03), 23)
	title.Font = Config.BoldFont
	title.TextColor3 = Config.Colors.Gold
	local close = button(panel, "Close", "X", UDim2.fromScale(0.08, 0.08), UDim2.fromScale(0.88, 0.03))
	local note = UI.Label(panel, "Note", "Keep playing to open more gifts. They start over when you rejoin.",
		UDim2.fromScale(0.9, 0.06), UDim2.fromScale(0.05, 0.12), 12)
	note.TextColor3 = Config.Colors.Muted
	note.TextWrapped = true
	local list = Instance.new("ScrollingFrame")
	list.Name = "GiftList"
	list.Size = UDim2.fromScale(0.91, 0.7)
	list.Position = UDim2.fromScale(0.05, 0.19)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Config.Colors.Gold
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	local rows = {}
	for index, gift in Gifts.Gifts do
		local row = UI.Panel(list, "Gift" .. index, UDim2.new(1, -8, 0, 52), UDim2.new())
		row.LayoutOrder = index
		row.BackgroundColor3 = Config.Colors.Inset
		local minutes = UI.Label(row, "Time", string.format("%d MIN", gift.Minutes), UDim2.fromScale(0.2, 0.5),
			UDim2.fromScale(0.03, 0.25), 16)
		minutes.Font = Config.BoldFont
		minutes.TextColor3 = Config.Colors.Gold
		local reward = UI.Label(row, "Reward", "--", UDim2.fromScale(0.45, 0.62), UDim2.fromScale(0.24, 0.19), 14)
		reward.TextColor3 = Config.Colors.Gain
		reward.TextWrapped = true
		local claim = button(row, "Claim", "--", UDim2.fromScale(0.27, 0.7), UDim2.fromScale(0.71, 0.15))
		rows[index] = { Frame = row, Reward = reward, Button = claim }
	end
	local feedback = UI.Label(panel, "Feedback", "", UDim2.fromScale(0.9, 0.06), UDim2.fromScale(0.05, 0.91), 13)
	feedback.TextXAlignment = Enum.TextXAlignment.Center
	feedback.TextWrapped = true
	screen.Parent = playerGui

	local view = { Panel = panel, Close = close, Rows = rows }

	-- `now` is Workspace:GetServerTimeNow(); `pending` is the gift number waiting for the server.
	function view.Render(snapshot, now: number, pending: number?)
		for index, row in rows do
			local gift = snapshot and snapshot.Gifts[index]
			if not gift then
				row.Reward.Text = "Loading..."
				row.Button.Text = "--"
				setEnabled(row.Button, false)
			else
				local left = gift.UnlockAt - now
				local ready = not gift.Claimed and left <= 0
				row.Reward.Text = GiftsView.RewardText(gift)
				row.Frame.BackgroundTransparency = gift.Claimed and 0.45 or 0
				row.Button.Text = gift.Claimed and "CLAIMED" or (ready and (pending == index and "WAIT" or "CLAIM")
					or GiftsView.Clock(left))
				setEnabled(row.Button, ready and pending == nil)
				if gift.Claimed then row.Button.TextColor3 = Config.Colors.Gain end
			end
		end
	end

	function view.Feedback(message: string?, success: boolean?)
		feedback.Text = message or ""
		feedback.TextColor3 = success and Config.Colors.Gain or Config.Colors.Warning
	end

	function view.Destroy()
		screen:Destroy()
	end

	return view
end

return GiftsView
