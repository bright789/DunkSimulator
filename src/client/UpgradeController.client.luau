local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("TrainingUpgradeRequest")
local stateRemote = remotes:WaitForChild("TrainingUpgradeState")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UpgradeConfig"))

local screen = Instance.new("ScreenGui")
screen.Name = "TrainingUpgrades"
screen.ResetOnSpawn = false
screen.DisplayOrder = 10
screen.Enabled = false

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.9, 0, 0.85, 0)
panel.BackgroundColor3 = Color3.fromRGB(29, 42, 47)
panel.BorderSizePixel = 0
panel.Parent = screen
local limits = Instance.new("UISizeConstraint")
limits.MaxSize = Vector2.new(440, 480)
limits.Parent = panel
local corners = Instance.new("UICorner")
corners.CornerRadius = UDim.new(0, 12)
corners.Parent = panel

local function label(name, position, height, textSize)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Position = UDim2.fromScale(0.06, position)
	text.Size = UDim2.fromScale(0.88, height)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(238, 233, 218)
	text.Font = Enum.Font.Gotham
	text.TextSize = textSize
	text.TextWrapped = true
	text.Text = ""
	text.Parent = panel
	return text
end

local title = label("Title", 0.04, 0.08, 22)
title.Text = "TRAINING UPGRADES"
title.Font = Enum.Font.GothamBold
title.Size = UDim2.fromScale(0.78, 0.08)
local cash = label("Cash", 0.14, 0.06, 18)
local current = label("CurrentLevel", 0.23, 0.15, 24)
current.Font = Enum.Font.GothamBold
local gain = label("CurrentTraining", 0.38, 0.07, 20)
local nextLevel = label("NextLevel", 0.48, 0.13, 20)
local cost = label("Cost", 0.62, 0.07, 22)
local feedback = label("Feedback", 0.84, 0.13, 18)

local buy = Instance.new("TextButton")
buy.Name = "Upgrade"
buy.Position = UDim2.fromScale(0.1, 0.73)
buy.Size = UDim2.fromScale(0.8, 0.1)
buy.Font = Enum.Font.GothamBold
buy.TextSize = 20
buy.TextColor3 = Color3.fromRGB(255, 255, 255)
buy.BorderSizePixel = 0
buy.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -6, 0, 6)
closeButton.Size = UDim2.fromOffset(36, 36)
closeButton.BackgroundTransparency = 1
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 26
closeButton.Text = "X"
closeButton.Parent = panel
screen.Parent = player:WaitForChild("PlayerGui")

local snapshot = nil
local pending = false
local feedbackVersion = 0

local function money(amount)
	local formatted = tostring(amount):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "$" .. formatted
end

local function render()
	if not snapshot then
		return
	end
	cash.Text = "Cash: " .. money(snapshot.Cash)
	current.Text = "Training Level\nLevel " .. snapshot.TrainingLevel
	gain.Text = "+" .. snapshot.VerticalGain .. " Vertical / Tick"
	if not snapshot.NextLevel then
		nextLevel.Text = "MAX LEVEL"
		cost.Text = ""
		buy.Visible = false
		return
	end
	nextLevel.Text = "Next: Level " .. snapshot.NextLevel .. "\n+" .. snapshot.NextGain .. " Vertical / Tick"
	cost.Text = "Cost: " .. money(snapshot.Price)
	buy.Visible = true
	local available = snapshot.CanAfford and snapshot.CanPurchase and not pending
	buy.Active = available
	buy.Selectable = available
	buy.AutoButtonColor = available
	buy.BackgroundColor3 = available and Color3.fromRGB(57, 125, 99) or Color3.fromRGB(77, 83, 85)
	buy.Text = pending and "UPGRADING..." or (not snapshot.CanAfford and "NOT ENOUGH CASH" or (not snapshot.CanPurchase and "PLEASE WAIT" or "UPGRADE"))
end

local function close()
	screen.Enabled = false
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

closeButton.Activated:Connect(requestClose)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape then
		requestClose()
	end
end)
player.CharacterRemoving:Connect(requestClose)

buy.Activated:Connect(function()
	if not screen.Enabled or not snapshot or not snapshot.NextLevel or pending
		or not snapshot.CanAfford or not snapshot.CanPurchase then
		return
	end
	pending = true
	render()
	request:FireServer("Buy", snapshot.OfferId)
end)

stateRemote.OnClientEvent:Connect(function(kind, updated, message, purchased)
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
		feedback.Text = message or "Invalid request."
		feedback.TextColor3 = purchased and Color3.fromRGB(147, 229, 171) or Color3.fromRGB(255, 191, 153)
		task.delay(Config.FeedbackSeconds, function()
			if feedbackVersion == version then
				feedback.Text = ""
			end
		end)
	end
end)
