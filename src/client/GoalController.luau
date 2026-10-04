-- Goal tracker on this client (GoalService decides and pays everything). GoalState sends
-- ("Goal", goal or nil): the card shows it, or hides (no goals until the new-player tutorial
-- is finished). ("Complete", { Text, Cash }) celebrates a paid goal in the card for a moment,
-- one at a time, before the current goal comes back. Display only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Feedback = require(script.Parent.FeedbackController)
local View = require(script.Parent.ui:WaitForChild("GoalView"))

local GoalController = {}

local CELEBRATE_SECONDS = 2.2
-- Celebrations waiting at once (several goals can finish together right after the tutorial).
local MAX_QUEUED = 6

local function validGoal(goal): boolean
	return type(goal) == "table" and type(goal.Text) == "string" and type(goal.Progress) == "number"
		and type(goal.From) == "number" and type(goal.Target) == "number" and type(goal.Reward) == "number"
end

function GoalController.new(player: Player, hud)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GoalState")
	local view = View.new(player:WaitForChild("PlayerGui"), hud)
	local connections = {}
	local current = nil
	local queue = {}
	local celebrating = false
	local celebrateTask: thread? = nil

	local function celebrate()
		if celebrating or #queue == 0 then return end
		celebrating = true
		celebrateTask = task.spawn(function()
			while #queue > 0 do
				local item = table.remove(queue, 1)
				view.Celebrate(item.Text, item.Cash)
				Feedback.ChallengeClaim()
				task.wait(CELEBRATE_SECONDS)
			end
			celebrating = false
			celebrateTask = nil
			view.Show(current)
		end)
	end

	table.insert(connections, remote.OnClientEvent:Connect(function(kind, data)
		if kind == "Goal" then
			current = validGoal(data) and data or nil
			if not celebrating then view.Show(current) end
		elseif kind == "Complete" and type(data) == "table" and type(data.Text) == "string" and type(data.Cash) == "number" then
			if #queue < MAX_QUEUED then table.insert(queue, data) end
			celebrate()
		end
	end))

	local controller = {}
	function controller.Destroy()
		if celebrateTask and coroutine.status(celebrateTask) ~= "dead" then task.cancel(celebrateTask) end
		for _, connection in connections do connection:Disconnect() end
		view.Destroy()
	end
	return controller
end

return GoalController
