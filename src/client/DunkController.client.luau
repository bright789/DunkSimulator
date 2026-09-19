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
local DunkView = require(script.Parent:WaitForChild("ui"):WaitForChild("DunkView"))
local view = DunkView.new(player:WaitForChild("PlayerGui"))
local hint = view.Hint
local result = view.Result
local connections = {}

local feedbackVersion = 0
local nextRequest = 0

local function updateHint()
	hint.Visible = player:GetAttribute("HasBasketball") == true and player:GetAttribute("DunkState") ~= "Executing"
end

table.insert(connections, player:GetAttributeChangedSignal("HasBasketball"):Connect(updateHint))
table.insert(connections, player:GetAttributeChangedSignal("DunkState"):Connect(updateHint))
updateHint()

table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
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
end))

table.insert(connections, dunkResult.OnClientEvent:Connect(function(cashReward, rejectionReason)
	feedbackVersion += 1
	local version = feedbackVersion
	view.ShowResult(cashReward, rejectionReason)
	task.delay(Config.FeedbackDuration, function()
		if feedbackVersion == version then
			result.Visible = false
		end
	end)
end))

if RunService:IsStudio() then
	print("[DunkController] Ready: pick up a ball, jump near the rim, and press F.")
end

table.insert(connections, player.CharacterRemoving:Connect(function()
	feedbackVersion += 1
	hint.Visible = false
	result.Visible = false
end))

script.Destroying:Connect(function()
	feedbackVersion += 1
	for _, connection in connections do
		connection:Disconnect()
	end
	view.Destroy()
end)
