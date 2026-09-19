local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"):WaitForChild("DunkConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestDunk = remotes:WaitForChild("RequestDunk")
local dunkResult = remotes:WaitForChild("DunkResult")

local screen = Instance.new("ScreenGui")
screen.Name = "DunkPrototype"
screen.ResetOnSpawn = false

local hint = Instance.new("TextLabel")
hint.Name = "DunkHint"
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.fromScale(0.5, 0.9)
hint.Size = UDim2.fromOffset(180, 40)
hint.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
hint.BackgroundTransparency = 0.25
hint.TextColor3 = Color3.new(1, 1, 1)
hint.TextSize = 22
hint.Font = Enum.Font.GothamBold
hint.Text = "F - Dunk"
hint.Visible = false
hint.Parent = screen

local result = Instance.new("TextLabel")
result.Name = "DunkResult"
result.AnchorPoint = Vector2.new(0.5, 0.5)
result.Position = UDim2.fromScale(0.5, 0.3)
result.Size = UDim2.new(0.8, 0, 0, 100)
result.TextWrapped = true
result.BackgroundTransparency = 1
result.TextColor3 = Color3.fromRGB(255, 190, 60)
result.TextStrokeTransparency = 0.3
result.TextSize = 32
result.Font = Enum.Font.GothamBold
result.Visible = false
result.Parent = screen
screen.Parent = player:WaitForChild("PlayerGui")

local feedbackVersion = 0
local nextRequest = 0

local function updateHint()
	hint.Visible = player:GetAttribute("HasBasketball") == true and player:GetAttribute("DunkState") ~= "Executing"
end

player:GetAttributeChangedSignal("HasBasketball"):Connect(updateHint)
player:GetAttributeChangedSignal("DunkState"):Connect(updateHint)
updateHint()

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() or input.KeyCode ~= Enum.KeyCode.F then
		return
	end
	if player:GetAttribute("HasBasketball") ~= true or os.clock() < nextRequest then
		return
	end
	if player:GetAttribute("DunkState") == "Executing" then
		return
	end
	nextRequest = os.clock() + Config.DunkCooldown
	requestDunk:FireServer()
end)

dunkResult.OnClientEvent:Connect(function(cashReward, rejectionReason)
	feedbackVersion += 1
	local version = feedbackVersion
	if typeof(cashReward) == "number" then
		result.Text = "DUNK!\n+$" .. tostring(cashReward)
		result.TextColor3 = Color3.fromRGB(255, 190, 60)
		result.TextSize = 32
	else
		result.Text = rejectionReason or "Dunk unavailable."
		result.TextColor3 = Color3.new(1, 1, 1)
		result.TextSize = 22
	end
	result.Visible = true
	task.delay(Config.FeedbackDuration, function()
		if feedbackVersion == version then
			result.Visible = false
		end
	end)
end)

if RunService:IsStudio() then
	print("[DunkController] Ready: pick up a ball, jump near the rim, and press F.")
end

player.CharacterRemoving:Connect(function()
	feedbackVersion += 1
	hint.Visible = false
	result.Visible = false
end)
