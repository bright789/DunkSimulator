local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Feedback = require(script.Parent:WaitForChild("FeedbackController"))

local player = Players.LocalPlayer
local HUDView = require(script.Parent:WaitForChild("ui"):WaitForChild("HUDView"))
local view = HUDView.new(player:WaitForChild("PlayerGui"))
local DunkStylesController = require(script.Parent:WaitForChild("DunkStylesController"))
local styles = DunkStylesController.new(player, view)
local CourtsController = require(script.Parent:WaitForChild("CourtsController"))
local courts = CourtsController.new(player, view)
local ChallengesController = require(script.Parent:WaitForChild("ChallengesController"))
local challenges = ChallengesController.new(player, view)
local RebirthController = require(script.Parent:WaitForChild("RebirthController"))
local rebirth = RebirthController.new(player, view)
local DailyController = require(script.Parent:WaitForChild("DailyController"))
local daily = DailyController.new(player, view)
local ContestController = require(script.Parent:WaitForChild("ContestController"))
local contest = ContestController.new(player)
local LockerController = require(script.Parent:WaitForChild("LockerController"))
local locker = LockerController.new(player, view)
local InviteController = require(script.Parent:WaitForChild("InviteController"))
local invite = InviteController.new(player, view)
local MusicController = require(script.Parent:WaitForChild("MusicController"))
local music = MusicController.new(player, view)
local AutoTrainController = require(script.Parent:WaitForChild("AutoTrainController"))
local autoTrain = AutoTrainController.new(player, view)
local CodesController = require(script.Parent:WaitForChild("CodesController"))
local codes = CodesController.new(player, view)
local AbilitiesController = require(script.Parent:WaitForChild("AbilitiesController"))
local abilities = AbilitiesController.new(player, view)
-- Always-something-happening layer: rep rhythm, NEXT goal + HEAT, pickups, action feed.
local ActionFeed = require(script.Parent:WaitForChild("ActionFeed"))
task.spawn(ActionFeed.Start, player)
local TrainingRhythmController = require(script.Parent:WaitForChild("TrainingRhythmController"))
local trainingRhythm = TrainingRhythmController.new(player)
local StatusBarController = require(script.Parent:WaitForChild("StatusBarController"))
local statusBar = StatusBarController.new(player)
local PickupController = require(script.Parent:WaitForChild("PickupController"))
local pickups = PickupController.new(player)
local CrewController = require(script.Parent:WaitForChild("CrewController"))
local crew = CrewController.new(player, view)
local connections = {}
local previous = {}
local destroyed = false

table.insert(connections, ReplicatedStorage.Remotes:WaitForChild("TrainingCapNotice").OnClientEvent:Connect(function(courtId, cap)
	if typeof(courtId) == "string" and typeof(cap) == "number" then
		view.ShowTrainingCap(courtId, cap)
	end
end))

local updateJumpLimit -- defined below (needs `previous`)

local function update(name: string, value)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return
	end
	view.SetStat(name, value, previous[name])
	-- Station training only (Auto Train ticks quietly).
	if name == "Vertical" and previous[name] and value > previous[name] and player:GetAttribute("DataStatus") == "Ready"
		and player:GetAttribute("Training") == true then
		Feedback.Training()
	end
	courts.SetStat(name, value)
	challenges.SetStat(name, value)
	rebirth.SetStat(name, value)
	locker.SetStat(name, value)
	if name == "Vertical" then
		styles.SetVertical(value, previous[name])
	end
	previous[name] = value
	if name == "Vertical" then updateJumpLimit() end
end

-- The server limits the jump to the current court's cap (JumpVertical); say so on the card.
function updateJumpLimit()
	local jump = player:GetAttribute("JumpVertical")
	local vertical = previous.Vertical
	view.SetJumpLimit(typeof(jump) == "number" and typeof(vertical) == "number" and jump < vertical and jump or nil)
end
table.insert(connections, player:GetAttributeChangedSignal("JumpVertical"):Connect(updateJumpLimit))

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
	styles.Destroy()
	courts.Destroy()
	challenges.Destroy()
	rebirth.Destroy()
	invite.Destroy()
	music.Destroy()
	autoTrain.Destroy()
	codes.Destroy()
	abilities.Destroy()
	trainingRhythm.Destroy()
	statusBar.Destroy()
	pickups.Destroy()
	crew.Destroy()
	daily.Destroy()
	contest.Destroy()
	locker.Destroy()
	view.Destroy()
end)
