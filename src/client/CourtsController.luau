local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local Courts = require(ReplicatedStorage.Shared.Config:WaitForChild("CourtConfig"))
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig).CourtMenu
local Feel = require(ReplicatedStorage.Shared.Config.FeedbackConfig)
local Feedback = require(script.Parent.FeedbackController)
local View = require(script.Parent.ui:WaitForChild("CourtsView"))
local CourtsController = {}

function CourtsController.new(player: Player, hud)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild("CourtRequest")
	local state = remotes:WaitForChild("CourtState")
	local view = View.new(player:WaitForChild("PlayerGui"))
	local connections = {}
	local snapshot = nil
	local observed = {}
	local pending = false
	local pendingTask = nil
	local toastTask = nil
	local arrivalTask = nil
	local nextRequest = 0
	local portal = nil
	local portalTarget = nil
	local controller = {}

	local function render()
		if snapshot then
			snapshot.Cash = observed.Cash or snapshot.Cash
			snapshot.Vertical = observed.Vertical or snapshot.Vertical
		end
		local court = Courts.Get(player:GetAttribute("CurrentCourt"))
		hud.SetCourt(court and court.DisplayName or "Loading...")
		view.Render(snapshot, pending or player:GetAttribute("CourtTransition") == true or player:GetAttribute("DunkState") ~= "Idle")
		view.Portal(portal, portalTarget, snapshot)
	end

	for _, attribute in { "CurrentCourt", "CourtTransition", "DunkState" } do
		table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(render))
	end
	local function read()
		if player:GetAttribute("DataStatus") == "Ready" then request:FireServer("Read") end
	end
	table.insert(connections, player:GetAttributeChangedSignal("DataStatus"):Connect(read))
	table.insert(connections, hud.CourtsButton.Activated:Connect(function()
		view.Panel.Visible = not view.Panel.Visible
		if view.Panel.Visible then read() end
	end))
	local function close() view.Panel.Visible = false end
	table.insert(connections, view.Close.Activated:Connect(close))
	table.insert(connections, player.CharacterRemoving:Connect(function()
		close(); portal = nil; portalTarget = nil
		if toastTask then task.cancel(toastTask); toastTask = nil end
		if arrivalTask then task.cancel(arrivalTask); arrivalTask = nil end
		view.ShowUnlock(nil, true)
		view.HideArrival(true)
		render()
	end))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then close() end
	end))
	for courtId, row in view.Rows do
		table.insert(connections, row.Button.Activated:Connect(function()
			if not row.Button.Active or pending or os.clock() < nextRequest then return end
			nextRequest = os.clock() + Courts.RequestCooldownSeconds
			pending = true
			render()
			pendingTask = task.delay(Config.ResponseTimeoutSeconds, function()
				pendingTask = nil; pending = false
				view.Feedback("No travel confirmation. Please try again.")
				render()
			end)
			request:FireServer("Travel", courtId)
		end))
	end
	table.insert(connections, state.OnClientEvent:Connect(function(updated, message, unlockedId, fromPortal)
		local oldCourt = snapshot and snapshot.CurrentCourt
		if updated then snapshot = updated end
		if pendingTask then task.cancel(pendingTask); pendingTask = nil end
		pending = false
		view.Feedback(message)
		if updated and oldCourt ~= updated.CurrentCourt then close() end
		if fromPortal and updated and oldCourt == updated.CurrentCourt and not unlockedId then view.Panel.Visible = true end
		if unlockedId and Courts.Get(unlockedId) then
			if toastTask then task.cancel(toastTask) end
			view.ShowUnlock(unlockedId)
			Feedback.CourtUnlock()
			toastTask = task.delay(Feel.Unlock.CourtHoldSeconds, function() toastTask = nil; view.ShowUnlock(nil) end)
		end
		if updated and oldCourt and oldCourt ~= updated.CurrentCourt and Courts.Get(updated.CurrentCourt) then
			if toastTask then task.cancel(toastTask); toastTask = nil; view.ShowUnlock(nil, true) end
			if arrivalTask then task.cancel(arrivalTask) end
			view.ShowArrival(updated.CurrentCourt)
			Feedback.CourtArrival()
			arrivalTask = task.delay(Feel.Arrival.HoldSeconds, function() arrivalTask = nil; view.HideArrival() end)
		end
		render()
	end))
	table.insert(connections, ProximityPromptService.PromptShown:Connect(function(prompt)
		for _, sourceId in Courts.OrderedIds() do
			local definition = Courts.Get(sourceId)
			local container = Workspace
			for _, name in definition.GameplayPath do container = container and container:FindFirstChild(name) end
			for targetId, name in definition.Portals do
				if container and prompt.Parent == container:FindFirstChild(name) then
					portal = prompt; portalTarget = targetId; render(); return
				end
			end
		end
	end))
	table.insert(connections, ProximityPromptService.PromptHidden:Connect(function(prompt)
		if portal == prompt then portal = nil; portalTarget = nil; render() end
	end))
	function controller.SetStat(name: string, value: number)
		if name == "Cash" or name == "Vertical" then observed[name] = value; render() end
	end
	function controller.Destroy()
		for _, connection in connections do connection:Disconnect() end
		if pendingTask then task.cancel(pendingTask) end
		if toastTask then task.cancel(toastTask) end
		if arrivalTask then task.cancel(arrivalTask) end
		view.Destroy()
	end
	read(); render()
	return controller
end

return CourtsController
