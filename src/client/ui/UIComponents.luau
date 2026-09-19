local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HUDConfig"))

local UI = {}

function UI.Round(object: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Config.CornerRadius)
	corner.Parent = object
end

function UI.StylePanel(object: GuiObject)
	object.BackgroundColor3 = Config.Colors.Panel
	object.BackgroundTransparency = Config.PanelTransparency
	object.BorderSizePixel = 0
	UI.Round(object)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Config.Colors.Stroke
	stroke.Transparency = 0.55
	stroke.Thickness = 1
	stroke.Parent = object
end

function UI.FitText(object, maximum: number, minimum: number?)
	object.TextSize = maximum
	object.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = minimum or 10
	limit.MaxTextSize = maximum
	limit.Parent = object
end

function UI.Label(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Config.Colors.Text
	label.Font = Config.Font
	label.TextXAlignment = Enum.TextXAlignment.Left
	UI.FitText(label, textSize)
	label.Parent = parent
	return label
end

function UI.Panel(parent: Instance, name: string, size: UDim2, position: UDim2)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = size
	panel.Position = position
	UI.StylePanel(panel)
	panel.Parent = parent
	return panel
end

function UI.Screen(name: string, order: number)
	local screen = Instance.new("ScreenGui")
	screen.Name = name
	screen.ResetOnSpawn = false
	screen.DisplayOrder = order
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	return screen
end

function UI.Number(value: number): string
	local formatted = string.format("%.0f", value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return formatted
end

return UI
