-- CODES button and panel, plus the timed-event countdown pill (EventConfig). Sends
-- CodeRequest("Redeem", text) and shows the server's answer; the server decides everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Events = require(ReplicatedStorage.Shared.Config.EventConfig)
local View = require(script.Parent.ui:WaitForChild("CodesView"))
local Feedback = require(script.Parent.FeedbackController)

local CodesController = {}

local function span(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days, hours, minutes = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
	if days > 0 then return string.format("%dd %dh", days, hours) end
	if hours > 0 then return string.format("%dh %dm", hours, minutes) end
	return string.format("%dm %02ds", minutes, seconds % 60)
end

function CodesController.new(player: Player, hud)
	local request = ReplicatedStorage.Remotes:WaitForChild("CodeRequest")
	local view = View.new(player:WaitForChild("PlayerGui"))
	local connections = {}
	local pending = false
	local isStudio = RunService:IsStudio()

	local function submit()
		local text = view.Box.Text
		if pending or #text == 0 then return end
		pending = true
		view.SetBusy(true)
		request:FireServer("Redeem", string.sub(text, 1, 30))
		task.delay(5, function()
			if pending then
				pending = false
				view.SetBusy(false)
				view.ShowResult(false, "No answer. Try again.")
			end
		end)
	end

	table.insert(connections, request.OnClientEvent:Connect(function(ok, message)
		if type(message) ~= "string" then return end
		pending = false
		view.SetBusy(false)
		view.ShowResult(ok == true, message)
		if ok == true then
			view.Box.Text = ""
			Feedback.ChallengeClaim()
		end
	end))
	table.insert(connections, view.Redeem.Activated:Connect(submit))
	table.insert(connections, view.Box.FocusLost:Connect(function(enterPressed)
		if enterPressed then submit() end
	end))
	table.insert(connections, hud.CodesButton.Activated:Connect(function()
		view.Panel.Visible = not view.Panel.Visible
		if view.Panel.Visible then view.ShowResult(true, "") end
	end))
	table.insert(connections, view.Close.Activated:Connect(function() view.Panel.Visible = false end))

	-- Event countdown pill.
	local ticker = task.spawn(function()
		while true do
			local now = Workspace:GetServerTimeNow()
			local event = Events.Active(now, isStudio)
			hud.SetEvent(event and string.format("%s  %s", event.Name, span(event.Ends - now)) or nil)
			task.wait(1)
		end
	end)

	local controller = {}
	function controller.Destroy()
		task.cancel(ticker)
		for _, connection in connections do connection:Disconnect() end
		view.Destroy()
	end
	return controller
end

return CodesController
