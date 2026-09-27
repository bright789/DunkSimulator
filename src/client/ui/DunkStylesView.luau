local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Feel = require(ReplicatedStorage.Shared.Config.FeedbackConfig)
local Styles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local UI = require(script.Parent.UIComponents)

local DunkStylesView = {}

local function button(parent, name, text, size, position)
	local control = Instance.new("TextButton")
	control.Name = name
	control.Size = size
	control.Position = position
	control.Text = text
	control.BackgroundColor3 = Config.Colors.Button
	control.TextColor3 = Config.Colors.Text
	control.Font = Config.BoldFont
	control.BorderSizePixel = 0
	UI.FitText(control, 13)
	UI.Round(control, 8)
	control.Parent = parent
	UI.Interactive(control)
	return control
end

function DunkStylesView.new(playerGui: PlayerGui)
	local screen = UI.Screen("DunkStyles", 8)
	local panel = UI.Panel(screen, "Selection", UDim2.fromScale(0.78, 0.8), UDim2.fromScale(0.5, 0.5))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	local limits = Instance.new("UISizeConstraint")
	limits.MaxSize = Vector2.new(420, 420)
	limits.Parent = panel
	local title = UI.Label(panel, "Title", Config.DunkSelection.Title,
		UDim2.fromScale(0.76, 0.09), UDim2.fromScale(0.06, 0.03), 22)
	title.Font = Config.BoldFont
	title.TextColor3 = Config.Colors.Accent
	local close = button(panel, "Close", "X", UDim2.fromScale(0.08, 0.08), UDim2.fromScale(0.88, 0.04))
	-- Scrolls once there are more styles than fit (rows have a fixed pixel height).
	local list = Instance.new("ScrollingFrame")
	list.Name = "Styles"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(0.88, 0.72)
	list.Position = UDim2.fromScale(0.06, 0.15)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Config.Colors.Accent
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list
	local rows = {}
	for _, styleId in Styles.OrderedIds() do
		local definition = Styles.Get(styleId)
		local row = UI.Panel(list, styleId, UDim2.new(1, -10, 0, 66), UDim2.new())
		row.LayoutOrder = definition.Order
		row.BackgroundColor3 = Config.Colors.Inset
		local name = UI.Label(row, "Name", definition.DisplayName,
			UDim2.fromScale(0.58, 0.4), UDim2.fromScale(0.035, 0.13), 17)
		name.Font = Config.BoldFont
		local requirement = UI.Label(row, "Requirement", string.format(Config.DunkSelection.RequirementRewardFormat,
			UI.Number(definition.RequiredVertical), UI.Number(definition.Reward)),
			UDim2.fromScale(0.56, 0.4), UDim2.fromScale(0.035, 0.55), 12)
		requirement.TextColor3 = Config.Colors.Muted
		requirement.TextWrapped = true
		local equip = button(row, "Equip", "LOCKED", UDim2.fromScale(0.32, 0.56), UDim2.fromScale(0.65, 0.22))
		rows[styleId] = equip
	end
	local feedback = UI.Label(panel, "Feedback", "", UDim2.fromScale(0.88, 0.08), UDim2.fromScale(0.06, 0.89), 13)
	feedback.TextWrapped = true
	feedback.TextXAlignment = Enum.TextXAlignment.Center
	local toast = Instance.new("CanvasGroup")
	toast.Name = "Unlock"
	toast.Size = UDim2.fromScale(0.65, 0.15)
	toast.Position = UDim2.fromScale(0.5, 0.09)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Visible = false
	toast.GroupTransparency = 1
	UI.StylePanel(toast)
	toast.Parent = screen
	local toastLimit = Instance.new("UISizeConstraint")
	toastLimit.MaxSize = Vector2.new(340, 94)
	toastLimit.Parent = toast
	local toastScale = Instance.new("UIScale")
	toastScale.Parent = toast
	local toastHeading = UI.Label(toast, "Heading", Config.DunkSelection.UnlockHeading,
		UDim2.fromScale(0.9, 0.23), UDim2.fromScale(0.05, 0.08), 13)
	toastHeading.TextColor3 = Config.Colors.Accent
	toastHeading.TextXAlignment = Enum.TextXAlignment.Center
	local toastName = UI.Label(toast, "Name", "", UDim2.fromScale(0.9, 0.36), UDim2.fromScale(0.05, 0.34), 22)
	toastName.Font = Config.BoldFont
	toastName.TextXAlignment = Enum.TextXAlignment.Center
	local toastRequirement = UI.Label(toast, "Requirement", "", UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.73), 12)
	toastRequirement.TextColor3 = Config.Colors.Muted
	toastRequirement.TextXAlignment = Enum.TextXAlignment.Center
	screen.Parent = playerGui
	local view = { Panel = panel, Close = close, Buttons = rows }
	local toastTween = nil
	local scaleTween = nil
	local toastVersion = 0

	function view.Render(vertical: number, equippedId: string?, ready: boolean, busy: boolean, pending: boolean)
		for styleId, equip in rows do
			local unlocked = Styles.IsUnlocked(styleId, vertical)
			local equipped = styleId == equippedId
			local available = ready and unlocked and not equipped and not busy and not pending
			equip.Active = available
			equip.Selectable = available
			equip.AutoButtonColor = available
			equip.BackgroundColor3 = available and Config.Colors.Button or Config.Colors.Inset
			equip.TextColor3 = unlocked and equipped and Config.Colors.Gain or Config.Colors.Text
			equip.Text = not ready and "LOADING" or (not unlocked and "LOCKED"
				or (equipped and "EQUIPPED" or ((pending or busy) and "WAIT" or "EQUIP")))
		end
	end

	function view.Feedback(message: string, success: boolean)
		feedback.Text = message
		feedback.TextColor3 = success and Config.Colors.Gain or Config.Colors.Warning
	end

	function view.ShowUnlock(styleId: string?)
		toastVersion += 1
		local version = toastVersion
		if toastTween then toastTween:Cancel(); toastTween:Destroy() end
		if scaleTween then scaleTween:Cancel(); scaleTween:Destroy() end
		if styleId then
			local style = Styles.Get(styleId)
			toastName.Text = style.DisplayName:upper()
			toastRequirement.Text = style.RequiredVertical .. " VERTICAL"
			toast.GroupTransparency = 1
			toast.Position = UDim2.new(0.5, 0, 0.09, Feel.Unlock.SlidePixels)
			toastScale.Scale = 1.04
			toast.Visible = true
			scaleTween = TweenService:Create(toastScale, TweenInfo.new(Feel.Unlock.FadeSeconds), { Scale = 1 })
			scaleTween:Play()
		end
		local tween = TweenService:Create(toast, TweenInfo.new(Feel.Unlock.FadeSeconds,
			Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = styleId and 0 or 1,
				Position = styleId and UDim2.fromScale(0.5, 0.09)
					or UDim2.new(0.5, 0, 0.09, -Feel.Unlock.SlidePixels) })
		toastTween = tween
		tween.Completed:Connect(function()
			if toastVersion == version then
				toast.Visible = styleId ~= nil
				toastTween = nil
			end
			tween:Destroy()
		end)
		tween:Play()
	end

	function view.Destroy()
		if toastTween then toastTween:Cancel(); toastTween:Destroy() end
		if scaleTween then scaleTween:Cancel(); scaleTween:Destroy() end
		screen:Destroy()
	end
	return view
end

return DunkStylesView
