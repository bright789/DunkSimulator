local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("TrainingUpgradeRequest")
local stateRemote = remotes:WaitForChild("TrainingUpgradeState")
local HUDConfig = require(ReplicatedStorage.Shared.Config:WaitForChild("HUDConfig"))
local Feel = require(ReplicatedStorage.Shared.Config.FeedbackConfig)
local Feedback = require(script.Parent.FeedbackController)
local UI = require(script.Parent:WaitForChild("ui"):WaitForChild("UIComponents"))
local colors = HUDConfig.Colors

local screen = UI.Screen("TrainingUpgrades", 10)
screen.Enabled = false

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.9, 0, 0.85, 0)
UI.StylePanel(panel)
panel.BackgroundTransparency = 0.03
panel.Parent = screen
local limits = Instance.new("UISizeConstraint")
limits.MaxSize = Vector2.new(440, 480)
limits.Parent = panel
local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

local function label(name, position, height, textSize)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Position = UDim2.fromScale(0.06, position)
	text.Size = UDim2.fromScale(0.88, height)
	text.BackgroundTransparency = 1
	text.TextColor3 = colors.Text
	text.Font = HUDConfig.Font
	UI.FitText(text, textSize)
	text.TextWrapped = true
	text.Text = ""
	text.Parent = panel
	return text
end

local title = label("Title", 0.04, 0.08, 22)
title.Text = "TRAINING UPGRADES"
title.Font = HUDConfig.BoldFont
title.TextColor3 = colors.Accent
title.Size = UDim2.fromScale(0.78, 0.08)
local cash = label("Cash", 0.14, 0.06, 18)
cash.TextColor3 = colors.Gain
local current = label("CurrentLevel", 0.23, 0.15, 24)
current.Font = HUDConfig.BoldFont
local gain = label("CurrentTraining", 0.38, 0.07, 20)
local nextLevel = label("NextLevel", 0.48, 0.13, 20)
nextLevel.TextColor3 = colors.Muted
local cost = label("Cost", 0.62, 0.07, 22)
local feedback = label("Feedback", 0.84, 0.13, 18)

local buy = Instance.new("TextButton")
buy.Name = "Upgrade"
buy.Position = UDim2.fromScale(0.1, 0.73)
buy.Size = UDim2.fromScale(0.8, 0.1)
buy.Font = HUDConfig.BoldFont
UI.FitText(buy, 20)
buy.TextColor3 = colors.Text
buy.BorderSizePixel = 0
UI.Round(buy)
buy.Parent = panel
UI.Interactive(buy)

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -6, 0, 6)
closeButton.Size = UDim2.fromOffset(36, 36)
closeButton.BackgroundColor3 = colors.Inset
closeButton.BorderSizePixel = 0
closeButton.TextColor3 = colors.Muted
closeButton.Font = HUDConfig.BoldFont
closeButton.TextSize = 18
UI.Round(closeButton, 8)
closeButton.Text = "X"
closeButton.Parent = panel
UI.Interactive(closeButton)
screen.Parent = player:WaitForChild("PlayerGui")

local snapshot = nil
local pending = false
local feedbackVersion = 0
local connections = {}
local panelPulse = nil

local function pulsePurchase()
	if panelPulse then panelPulse:Cancel(); panelPulse:Destroy() end
	panelScale.Scale = Feel.Unlock.UpgradePulseScale
	panelPulse = TweenService:Create(panelScale,
		TweenInfo.new(Feel.Stats.PulseSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
	panelPulse:Play()
end

local function money(amount)
	return "$" .. UI.Number(amount)
end

-- Vertical per rep with up to two decimals ("0.15", "0.2", "1").
local function perRep(amount: number): string
	return (string.format("%.2f", amount):gsub("%.?0+$", ""))
end

local function render()
	if not snapshot then
		return
	end
	cash.Text = "Cash: " .. money(snapshot.Cash)
	current.Text = "Training Level\nLevel " .. snapshot.TrainingLevel
	gain.Text = string.format("Current: +%s Vertical / rep", perRep(snapshot.VerticalPerRep))
	if not snapshot.NextLevel then
		nextLevel.Text = "MAX LEVEL"
		cost.Text = ""
		buy.Visible = false
		return
	end
	nextLevel.Text = string.format("Next: Level %d\n+%s Vertical / rep", snapshot.NextLevel, perRep(snapshot.NextVerticalPerRep))
	cost.Text = "Cost: " .. money(snapshot.Price)
	buy.Visible = true
	local available = snapshot.CanAfford and snapshot.CanPurchase and not pending
	buy.Active = available
	buy.Selectable = available
	buy.AutoButtonColor = available
	buy.BackgroundColor3 = available and colors.Button or colors.Inset
	buy.Text = pending and "UPGRADING..." or (not snapshot.CanAfford and "NOT ENOUGH CASH" or (not snapshot.CanPurchase and "PLEASE WAIT" or "UPGRADE"))
end

local function close()
	screen.Enabled = false
	if panelPulse then panelPulse:Cancel(); panelPulse:Destroy(); panelPulse = nil end
	panelScale.Scale = 1
	snapshot = nil
	pending = false
	feedbackVersion += 1
	feedback.Text = ""
end

local function requestClose()
	if screen.Enabled then
		request:FireServer("Close")
	end
	close()
end

table.insert(connections, closeButton.Activated:Connect(requestClose))
table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape then
		requestClose()
	end
end))
table.insert(connections, player.CharacterRemoving:Connect(requestClose))

table.insert(connections, buy.Activated:Connect(function()
	if not screen.Enabled or not snapshot or not snapshot.NextLevel or pending
		or not snapshot.CanAfford or not snapshot.CanPurchase then
		return
	end
	pending = true
	render()
	request:FireServer("Buy", snapshot.OfferId)
end))

table.insert(connections, stateRemote.OnClientEvent:Connect(function(kind, updated, message, purchased)
	if kind == "Close" then
		close()
		return
	end
	if kind == "Open" then
		feedbackVersion += 1
		feedback.Text = ""
		screen.Enabled = true
	elseif not screen.Enabled then
		return
	end
	snapshot = updated
	if kind == "Open" or kind == "Result" then
		pending = false
	end
	render()
	if kind == "Result" then
		feedbackVersion += 1
		local version = feedbackVersion
		feedback.Text = purchased and updated and ("TRAINING LEVEL UP!  LEVEL " .. tostring(updated.TrainingLevel))
			or (message or "Invalid request.")
		feedback.TextColor3 = purchased and colors.Gain or colors.Warning
		if purchased then
			pulsePurchase()
			Feedback.Upgrade()
		end
		task.delay(Feel.Unlock.UpgradeHoldSeconds, function()
			if feedbackVersion == version then
				feedback.Text = ""
			end
		end)
	end
end))

script.Destroying:Connect(function()
	feedbackVersion += 1
	if panelPulse then panelPulse:Cancel(); panelPulse:Destroy() end
	for _, connection in connections do
		connection:Disconnect()
	end
	screen:Destroy()
end)
