local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HUDConfig"))
local UI = require(script.Parent:WaitForChild("UIComponents"))
local StatFeedback = require(script.Parent:WaitForChild("StatFeedback"))

local HUDView = {}

local function makeCard(parent: Instance, name: string, prefix: string, order: number, accent: Color3)
	local card = UI.Panel(parent, name, UDim2.new(1, 0, 0, Config.Layout.CardHeight), UDim2.new())
	card.LayoutOrder = order
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = card
	local value = UI.Label(card, "Value", "--", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 6), 28)
	value.Font = Config.BoldFont
	local caption = UI.Label(card, "Caption", name:upper(), UDim2.new(0.48, 0, 0, 18), UDim2.fromOffset(0, 44), 13)
	caption.TextColor3 = Config.Colors.Muted
	local gain = UI.Label(card, "Gain", "", UDim2.new(0.52, 0, 0, 18), UDim2.new(0.48, 0, 0, 44), 13)
	gain.Font = Config.BoldFont
	gain.TextColor3 = accent
	gain.TextXAlignment = Enum.TextXAlignment.Right
	return { Value = value, Prefix = prefix, Feedback = StatFeedback.new(gain) }
end

function HUDView.new(playerGui: PlayerGui)
	local screen = UI.Screen("NeighborhoodHUD", 1)
	local bounds = Instance.new("Frame")
	bounds.Name = "SafeArea"
	bounds.Size = UDim2.fromScale(1, 1)
	bounds.BackgroundTransparency = 1
	bounds.Parent = screen
	local dataStatus = UI.Label(bounds, "DataStatus", "Loading Player Data...",
		UDim2.fromScale(0.6, 0.045), UDim2.fromScale(0.5, 0.04), 16)
	dataStatus.AnchorPoint = Vector2.new(0.5, 0)
	dataStatus.TextXAlignment = Enum.TextXAlignment.Center
	dataStatus.TextColor3 = Config.Colors.Muted
	local columnHeight = Config.Layout.CardHeight * 3 + Config.Layout.ProgressHeight + Config.Layout.Gap * 3
	local column = Instance.new("Frame")
	column.Name = "Stats"
	column.BackgroundTransparency = 1
	column.Size = UDim2.fromOffset(Config.Layout.ColumnWidth, columnHeight)
	column.Position = UDim2.new(0.018, 4, 0.18, 0)
	column.Parent = bounds
	local scale = Instance.new("UIScale")
	scale.Parent = column
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Config.Layout.Gap)
	layout.Parent = column
	local cards = {
		Cash = makeCard(column, "Cash", "$ ", 1, Config.Colors.Gain),
		Vertical = makeCard(column, "Vertical", "↑ ", 2, Config.Colors.Accent),
		TrainingLevel = makeCard(column, "Training", "LVL ", 3, Config.Colors.Accent),
	}
	local progress = UI.Panel(column, "DunkProgress", UDim2.new(1, 0, 0, Config.Layout.ProgressHeight), UDim2.new())
	progress.LayoutOrder = 4
	local milestone = Config.Progression
	local heading = UI.Label(progress, "Heading", milestone.LockedHeading, UDim2.new(1, -28, 0, 16), UDim2.fromOffset(14, 10), 12)
	heading.TextColor3 = Config.Colors.Accent
	local title = UI.Label(progress, "Title", milestone.Name, UDim2.new(1, -28, 0, 25), UDim2.fromOffset(14, 29), 20)
	title.Font = Config.BoldFont
	local detail = UI.Label(progress, "Detail", "--", UDim2.new(1, -28, 0, 18), UDim2.fromOffset(14, 58), 12)
	detail.TextColor3 = Config.Colors.Muted
	local track = Instance.new("Frame")
	track.Name = "ProgressTrack"
	track.Size = UDim2.new(1, -28, 0, 5)
	track.Position = UDim2.fromOffset(14, 84)
	track.BackgroundColor3 = Config.Colors.Inset
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	UI.Round(track, 3)
	track.Parent = progress
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Config.Colors.Accent
	fill.BorderSizePixel = 0
	UI.Round(fill, 3)
	fill.Parent = track
	local preview = UI.Label(progress, "Preview", milestone.PreviewHeading .. "  /  " .. milestone.PreviewDetail,
		UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 101), 11)
	preview.TextColor3 = Config.Colors.Muted
	screen.Parent = playerGui

	local function resize()
		local size = bounds.AbsoluteSize
		local desired = math.clamp(math.min(size.X / Config.Layout.ReferenceSize.X,
			size.Y / Config.Layout.ReferenceSize.Y), Config.Layout.MinimumScale, 1)
		scale.Scale = math.min(desired, math.max(0.1, size.Y * 0.76 / columnHeight))
	end
	local resizeConnection = bounds:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	local view = {}

	function view.SetDataStatus(status: string?)
		dataStatus.Visible = status ~= "Ready"
		dataStatus.Text = status == "Failed" and "Player data unavailable. Please rejoin."
			or (status == "Closing" and "Saving Player Data..." or "Loading Player Data...")
	end

	function view.SetStat(name: string, value: number, previous: number?)
		local card = cards[name]
		card.Value.Text = card.Prefix .. UI.Number(value)
		if previous and value > previous then
			local change = name == "TrainingLevel" and Config.Feedback.LevelUp
				or ("+" .. (name == "Cash" and "$" or "") .. UI.Number(value - previous))
			card.Feedback.Show(change)
		end
	end

	function view.SetVertical(vertical: number)
		local required = math.max(0, milestone.BasicVertical)
		local unlocked = vertical >= required
		local fraction = required > 0 and math.clamp(vertical / required, 0, 1) or 1
		heading.Text = unlocked and milestone.UnlockedHeading or milestone.LockedHeading
		heading.TextColor3 = unlocked and Config.Colors.Gain or Config.Colors.Accent
		detail.Text = unlocked and milestone.UnlockedDetail
			or string.format(milestone.ProgressFormat, UI.Number(vertical), UI.Number(required))
		fill.Size = UDim2.fromScale(fraction, 1)
		fill.BackgroundColor3 = heading.TextColor3
	end

	function view.Destroy()
		resizeConnection:Disconnect()
		for _, card in cards do
			card.Feedback.Destroy()
		end
		screen:Destroy()
	end

	return view
end

return HUDView
