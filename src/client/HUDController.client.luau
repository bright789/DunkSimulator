local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local HUDView = require(script.Parent:WaitForChild("ui"):WaitForChild("HUDView"))
local view = HUDView.new(player:WaitForChild("PlayerGui"))
local connections = {}
local previous = {}
local destroyed = false

local function update(name: string, value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return
	end
	view.SetStat(name, value, previous[name])
	previous[name] = value
	if name == "Vertical" then
		view.SetVertical(value)
	end
end

local function updateTrainingLevel()
	update("TrainingLevel", player:GetAttribute("TrainingLevel"))
end

local function updateDataStatus()
	view.SetDataStatus(player:GetAttribute("DataStatus"))
end

table.insert(connections, player:GetAttributeChangedSignal("DataStatus"):Connect(updateDataStatus))
updateDataStatus()
table.insert(connections, player:GetAttributeChangedSignal("TrainingLevel"):Connect(updateTrainingLevel))
updateTrainingLevel()

local statsTask = task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 60)
	if not leaderstats then
		return
	end
	for _, name in { "Cash", "Vertical" } do
		local stat = leaderstats:WaitForChild(name, 60)
		if not stat then
			return
		end
		table.insert(connections, stat:GetPropertyChangedSignal("Value"):Connect(function()
			update(name, stat.Value)
		end))
		update(name, stat.Value)
	end
end)

local coreGuiTask = task.spawn(function()
	for attempt = 1, 10 do
		if destroyed then
			return
		end
		local success = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		if success then
			return
		end
		task.wait(0.5)
	end
	warn("[HUDController] Could not hide PlayerList; custom stats remain available.")
end)

script.Destroying:Connect(function()
	destroyed = true
	for _, connection in connections do
		connection:Disconnect()
	end
	for _, thread in { statsTask, coreGuiTask } do
		if coroutine.status(thread) ~= "dead" then
			task.cancel(thread)
		end
	end
	view.Destroy()
end)
