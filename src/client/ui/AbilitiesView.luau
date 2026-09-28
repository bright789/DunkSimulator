-- Ability hotbar (right edge: one slot per ability with its key, icon, recharge cover and an
-- ARMED glow) plus the ABILITIES panel (unlock, buy early, upgrade). Messages go to ActionFeed.
-- Display only; the server checks and pays for everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Abilities = require(ReplicatedStorage.Shared.Config.AbilityConfig)
local UI = require(script.Parent.UIComponents)

local AbilitiesView = {}

local function label(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number)
	local created = UI.Label(parent, name, text, size, position, textSize)
	created.TextXAlignment = Enum.TextXAlignment.Center
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

function AbilitiesView.new(playerGui: PlayerGui)
	local screen = UI.Screen("Abilities", 6)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local slotSize = touch and 50 or 58
	local ids = Abilities.Ids()

	-- Hotbar: right edge, just below the middle (clear of the touch menu and jump button).
	local bar = Instance.new("Frame")
	bar.Name = "Hotbar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(1, 0.5)
	bar.Position = UDim2.new(1, -10, 0.52, 0)
	bar.Size = UDim2.fromOffset(slotSize, slotSize * #ids + 8 * (#ids - 1))
	bar.Parent = screen
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = bar

	local slots = {}
	for _, abilityId in ids do
		local definition = Abilities.Abilities[abilityId]
		local slot = Instance.new("TextButton")
		slot.Name = abilityId
		slot.LayoutOrder = definition.Order
		slot.Size = UDim2.fromOffset(slotSize, slotSize)
		slot.Text = ""
		slot.AutoButtonColor = false
		UI.StylePanel(slot)
		slot.Parent = bar
		local stroke = slot:FindFirstChildOfClass("UIStroke")
		local icon = Instance.new("TextLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromScale(0.72, 0.62)
		icon.Position = UDim2.fromScale(0.14, 0.1)
		icon.Text = definition.Icon
		icon.TextScaled = true
		icon.Font = Enum.Font.GothamBold
		icon.TextColor3 = Color3.new(1, 1, 1)
		icon.Parent = slot
		local cover = Instance.new("Frame")
		cover.Name = "Recharge"
		cover.AnchorPoint = Vector2.new(0, 1)
		cover.Position = UDim2.fromScale(0, 1)
		cover.Size = UDim2.fromScale(1, 0)
		cover.BackgroundColor3 = Color3.new(0, 0, 0)
		cover.BackgroundTransparency = 0.35
		cover.BorderSizePixel = 0
		cover.ZIndex = 2
		UI.Round(cover, Config.CornerRadius)
		cover.Parent = slot
		local timer = label(slot, "Timer", "", UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0.18), 20)
		timer.Font = Config.BoldFont
		timer.ZIndex = 3
		local status = label(slot, "Status", "", UDim2.new(1, 0, 0.3, 0), UDim2.fromScale(0, 0.68), 11)
		status.Font = Config.BoldFont
		status.ZIndex = 3
		local key = label(slot, "Key", definition.KeyLabel, UDim2.fromOffset(16, 16), UDim2.fromOffset(3, 1), 12)
		key.Font = Config.BoldFont
		key.TextColor3 = Config.Colors.Gold
		key.Visible = not touch
		key.ZIndex = 3
		UI.Interactive(slot)
		slots[abilityId] = { Button = slot, Icon = icon, Cover = cover, Timer = timer, Status = status, Stroke = stroke }
	end

	-- ABILITIES panel.
	local panel = UI.Panel(screen, "Menu", UDim2.fromScale(0.72, 0.66), UDim2.fromScale(0.5, 0.5))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(460, 400)
	constraint.MinSize = Vector2.new(300, 300)
	constraint.Parent = panel
	local title = UI.Label(panel, "Title", "ABILITIES", UDim2.fromScale(0.7, 0.09), UDim2.fromScale(0.05, 0.03), 24)
	title.Font = Config.BoldFont
	title.TextColor3 = Config.Colors.Gold
	local close = button(panel, "Close", "X", UDim2.fromScale(0.08, 0.08), UDim2.fromScale(0.88, 0.03), 13)
	local hint = UI.Label(panel, "Hint", "Earn each one at its Vertical, or buy it early. Press to arm, then dunk!",
		UDim2.fromScale(0.9, 0.06), UDim2.fromScale(0.05, 0.12), 11)
	hint.TextColor3 = Config.Colors.Muted

	local rows = {}
	for index, abilityId in ids do
		local definition = Abilities.Abilities[abilityId]
		local row = Instance.new("Frame")
		row.Name = abilityId
		row.Size = UDim2.fromScale(0.9, 0.22)
		row.Position = UDim2.fromScale(0.05, 0.19 + (index - 1) * 0.24)
		row.BackgroundColor3 = Config.Colors.Inset
		row.BorderSizePixel = 0
		UI.Round(row, 10)
		row.Parent = panel
		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromScale(0.12, 0.6)
		icon.Position = UDim2.fromScale(0.02, 0.2)
		icon.Text = definition.Icon
		icon.TextScaled = true
		icon.Font = Enum.Font.GothamBold
		icon.Parent = row
		local name = UI.Label(row, "Name", definition.DisplayName, UDim2.fromScale(0.58, 0.28), UDim2.fromScale(0.16, 0.06), 16)
		name.Font = Config.BoldFont
		name.TextColor3 = definition.Color
		local description = UI.Label(row, "Description", definition.Description, UDim2.fromScale(0.58, 0.4),
			UDim2.fromScale(0.16, 0.34), 11)
		description.TextWrapped = true
		description.TextYAlignment = Enum.TextYAlignment.Top
		description.TextColor3 = Config.Colors.Muted
		local info = UI.Label(row, "Info", "", UDim2.fromScale(0.58, 0.22), UDim2.fromScale(0.16, 0.74), 11)
		info.TextColor3 = Config.Colors.Gold
		local action = button(row, "Action", "", UDim2.fromScale(0.22, 0.62), UDim2.fromScale(0.76, 0.19), 14)
		rows[abilityId] = { Info = info, Action = action }
	end
	local result = UI.Label(panel, "Result", "", UDim2.fromScale(0.9, 0.07), UDim2.fromScale(0.05, 0.91), 13)
	result.TextXAlignment = Enum.TextXAlignment.Center

	screen.Parent = playerGui

	local view = { Panel = panel, Close = close, Slots = slots, Rows = rows }

	-- `state`: Level, Armed, Remaining (seconds) and Cooldown (seconds at this level).
	function view.SetSlot(abilityId: string, state)
		local slot = slots[abilityId]
		if not slot then return end
		local definition = Abilities.Abilities[abilityId]
		local locked = state.Level < 1
		slot.Icon.TextTransparency = locked and 0.6 or 0
		if locked then
			slot.Cover.Size = UDim2.fromScale(1, 1)
			slot.Timer.Text = "🔒"
			slot.Status.Text = tostring(definition.UnlockVertical) .. " VERT"
			slot.Status.TextColor3 = Config.Colors.Muted
		elseif state.Armed then
			slot.Cover.Size = UDim2.fromScale(1, 0)
			slot.Timer.Text = ""
			slot.Status.Text = "ARMED"
			slot.Status.TextColor3 = definition.Color
		elseif state.Remaining > 0 then
			slot.Cover.Size = UDim2.fromScale(1, math.clamp(state.Remaining / math.max(state.Cooldown, 1), 0, 1))
			slot.Timer.Text = tostring(math.ceil(state.Remaining))
			slot.Status.Text = ""
		else
			slot.Cover.Size = UDim2.fromScale(1, 0)
			slot.Timer.Text = ""
			slot.Status.Text = "READY"
			slot.Status.TextColor3 = Config.Colors.Gain
		end
		if slot.Stroke then
			slot.Stroke.Color = state.Armed and definition.Color or Config.Colors.Stroke
			slot.Stroke.Thickness = state.Armed and 4 or Config.Style.PanelStrokeThickness
			slot.Stroke.Transparency = state.Armed and 0 or Config.Style.PanelStrokeTransparency
		end
	end

	-- `info`: Text (info line), ActionText, Enabled (false = greyed out / max level).
	function view.SetRow(abilityId: string, info)
		local row = rows[abilityId]
		if not row then return end
		row.Info.Text = info.Text
		row.Action.Text = info.ActionText
		row.Action.Active = info.Enabled
		row.Action.AutoButtonColor = info.Enabled
		row.Action.BackgroundColor3 = info.Enabled and Config.Colors.Button or Config.Colors.Inset
		row.Action.TextColor3 = info.Enabled and Config.Colors.Text or Config.Colors.Muted
	end

	function view.ShowResult(ok: boolean, message: string)
		result.Text = message:gsub("\n", "  ")
		result.TextColor3 = ok and Config.Colors.Gain or Config.Colors.Warning
	end

	function view.Destroy()
		screen:Destroy()
	end

	return view
end

return AbilitiesView
