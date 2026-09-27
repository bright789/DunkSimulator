local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Styles = require(ReplicatedStorage.Shared.Config:WaitForChild("DunkStyles"))
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig).DunkSelection
local Feel = require(ReplicatedStorage.Shared.Config.FeedbackConfig)
local Feedback = require(script.Parent.FeedbackController)
local View = require(script.Parent.ui:WaitForChild("DunkStylesView"))

local DunkStylesController = {}

function DunkStylesController.new(player: Player, hud)
	local view = View.new(player:WaitForChild("PlayerGui"))
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EquipDunkStyle")
	local connections = {}
	local vertical = 0
	local pending = false
	local nextRequest = 0
	local responseTask = nil
	local unlockTask = nil
	local unlockQueue = {}
	local announced = {}
	local controller = {}

	local function render()
		local equipped = player:GetAttribute("EquippedDunkStyle")
		view.Render(vertical, equipped, player:GetAttribute("DataStatus") == "Ready",
			player:GetAttribute("DunkState") ~= "Idle", pending)
		hud.SetDunkProgress(vertical, equipped)
	end

	for _, attribute in { "EquippedDunkStyle", "DataStatus", "DunkState" } do
		table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(render))
	end
	table.insert(connections, hud.DunksButton.Activated:Connect(function()
		view.Panel.Visible = not view.Panel.Visible
		view.Feedback("", true)
	end))
	local function close()
		view.Panel.Visible = false
	end
	table.insert(connections, view.Close.Activated:Connect(close))
	table.insert(connections, player.CharacterRemoving:Connect(function()
		close()
		if unlockTask then task.cancel(unlockTask); unlockTask = nil end
		table.clear(unlockQueue)
		view.ShowUnlock(nil)
	end))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			close()
		end
	end))
	for styleId, button in view.Buttons do
		table.insert(connections, button.Activated:Connect(function()
			if pending or not button.Active or os.clock() < nextRequest then
				return
			end
			nextRequest = os.clock() + Styles.EquipCooldownSeconds
			pending = true
			render()
			responseTask = task.delay(Config.ResponseTimeoutSeconds, function()
				responseTask = nil
				pending = false
				view.Feedback("No confirmation yet. Please try again.", false)
				render()
			end)
			remote:FireServer(styleId)
		end))
	end
	table.insert(connections, remote.OnClientEvent:Connect(function(accepted, message)
		if responseTask then
			task.cancel(responseTask)
			responseTask = nil
		end
		pending = false
		view.Feedback(message or "Invalid request.", accepted == true)
		render()
	end))

	function controller.SetVertical(value: number, previous: number?)
		vertical = value
		render()
		for _, styleId in Styles.OrderedIds() do
			local requirement = Styles.Get(styleId).RequiredVertical
			if value >= requirement and not announced[styleId] then
				announced[styleId] = true
				if previous and previous < requirement then
					table.insert(unlockQueue, styleId)
				end
			end
		end
		if not unlockTask and #unlockQueue > 0 then
			unlockTask = task.spawn(function()
				while #unlockQueue > 0 do
					view.ShowUnlock(table.remove(unlockQueue, 1))
					Feedback.DunkUnlock()
					task.wait(Feel.Unlock.DunkHoldSeconds)
				end
				view.ShowUnlock(nil)
				unlockTask = nil
			end)
		end
	end

	function controller.Destroy()
		for _, connection in connections do
			connection:Disconnect()
		end
		if responseTask then task.cancel(responseTask) end
		if unlockTask then task.cancel(unlockTask) end
		view.Destroy()
	end
	return controller
end

return DunkStylesController
