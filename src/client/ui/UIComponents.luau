local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HUDConfig"))
local FeedbackConfig = require(ReplicatedStorage.Shared.Config.FeedbackConfig).UI
local FeedbackAudio = require(script.Parent.Parent.FeedbackAudio)

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
	stroke.Transparency = Config.Style.PanelStrokeTransparency
	stroke.Thickness = Config.Style.PanelStrokeThickness
	stroke.Parent = object
	-- A canvas group would tint its whole contents, so only plain panels get the sheen.
	if not object:IsA("CanvasGroup") and Config.Style.PanelGradientBottom < 1 then
		local shade = Config.Style.PanelGradientBottom
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(shade, shade, shade))
		gradient.Rotation = 90
		gradient.Parent = object
	end
end

-- Dark cartoon outline around text so it reads on any background.
function UI.Outline(label: TextLabel | TextButton)
	if label:FindFirstChild("TextOutline") then return end
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextOutline"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Config.Colors.TextOutline
	stroke.Thickness = Config.Style.TextOutlineThickness
	stroke.Transparency = Config.Style.TextOutlineTransparency
	stroke.Parent = label
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
	UI.Outline(label)
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

function UI.Interactive(button: TextButton)
	local scale = Instance.new("UIScale")
	scale.Name = "InteractionScale"
	scale.Parent = button
	local hovered = false
	local tween = nil
	local connections = {}
	local function animate(target: number)
		if tween then tween:Cancel(); tween:Destroy() end
		tween = TweenService:Create(scale,
			TweenInfo.new(FeedbackConfig.TweenSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = target })
		tween:Play()
	end
	table.insert(connections, button.MouseEnter:Connect(function()
		hovered = true
		if button.Active then animate(FeedbackConfig.HoverScale) end
	end))
	table.insert(connections, button.MouseLeave:Connect(function()
		hovered = false
		animate(1)
	end))
	table.insert(connections, button.SelectionGained:Connect(function()
		hovered = true
		if button.Active then animate(FeedbackConfig.HoverScale) end
	end))
	table.insert(connections, button.SelectionLost:Connect(function()
		hovered = false
		animate(1)
	end))
	table.insert(connections, button.Activated:Connect(function()
		if not button.Active then return end
		FeedbackAudio.Play("UIClick")
		scale.Scale = FeedbackConfig.PressScale
		animate(hovered and FeedbackConfig.HoverScale or 1)
	end))
	button.Destroying:Connect(function()
		for _, connection in connections do connection:Disconnect() end
		if tween then tween:Cancel(); tween:Destroy() end
	end)
end

return UI
