-- Top-centre status stack, under the Dunk Contest banner: the always-on NEXT goal bar and the
-- HEAT pill (dunk streak) with a draining timer. Display only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local UI = require(script.Parent.UIComponents)

local StatusBarView = {}

local function bar(parent: Instance, name: string, height: number, order: number)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromOffset(380, height)
	frame.LayoutOrder = order
	UI.StylePanel(frame)
	frame.Parent = parent
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundTransparency = 0.55
	fill.Size = UDim2.fromScale(0, 1)
	UI.Round(fill, Config.CornerRadius)
	fill.Parent = frame
	local text = UI.Label(frame, "Text", "", UDim2.new(0.62, -12, 1, -6), UDim2.fromOffset(10, 3), 16)
	text.Font = Config.BoldFont
	text.ZIndex = 2
	local right = UI.Label(frame, "Right", "", UDim2.new(0.38, -10, 1, -6), UDim2.new(0.62, 0, 0, 3), 15)
	right.TextXAlignment = Enum.TextXAlignment.Right
	right.Font = Config.BoldFont
	right.ZIndex = 2
	return frame, fill, text, right
end

function StatusBarView.new(playerGui: PlayerGui)
	local screen = UI.Screen("StatusBar", 3)
	local stack = Instance.new("Frame")
	stack.Name = "Stack"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(0.5, 0)
	-- Just under the Dunk Contest banner (0.012 of the height + at most 60 px).
	stack.Position = UDim2.new(0.5, 0, 0.012, 66)
	stack.Size = UDim2.fromOffset(380, 80)
	stack.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = stack
	local scale = Instance.new("UIScale")
	scale.Parent = stack

	local goal, goalFill, goalText, goalRight = bar(stack, "Goal", 32, 1)
	goalFill.BackgroundColor3 = Config.Colors.Accent
	goalText.TextColor3 = Config.Colors.Text
	goalRight.TextColor3 = Config.Colors.Gold
	local heat, heatFill, heatText, heatRight = bar(stack, "Heat", 30, 2)
	heat.Size = UDim2.fromOffset(300, 30)
	heat.Visible = false
	screen.Parent = playerGui

	-- Phones: shrink the stack so it fits between the stats and the menu.
	local function resize()
		local width = screen.AbsoluteSize.X
		scale.Scale = math.clamp((width - 460) / 380, 0.6, 1)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()

	local view = {}

	function view.SetGoal(visible: boolean, title: string?, progress: string?, fraction: number?)
		goal.Visible = visible
		if not visible then return end
		goalText.Text = title or ""
		goalRight.Text = progress or ""
		goalFill.Size = UDim2.fromScale(math.clamp(fraction or 0, 0, 1), 1)
	end

	function view.SetHeat(level: number?, name: string?, multiplier: number?, fraction: number?, color: Color3?)
		heat.Visible = level ~= nil
		if not level then return end
		heatText.Text = string.format("🔥 HEAT %d  %s", level, name or "")
		heatText.TextColor3 = color or Config.Colors.Gold
		heatRight.Text = "x" .. tostring(multiplier) .. " CASH"
		heatRight.TextColor3 = color or Config.Colors.Gold
		heatFill.BackgroundColor3 = color or Config.Colors.Gold
		heatFill.Size = UDim2.fromScale(math.clamp(fraction or 0, 0, 1), 1)
	end

	function view.Destroy()
		screen:Destroy()
	end

	return view
end

return StatusBarView
