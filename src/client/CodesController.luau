-- CODES button and panel. Sends CodeRequest("Redeem", text) and shows the server's answer;
-- the server decides everything. (The event countdown pill moved to EventsController.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local View = require(script.Parent.ui:WaitForChild("CodesView"))
local Feedback = require(script.Parent.FeedbackController)

local CodesController = {}

function CodesController.new(player: Player, hud)
	local request = ReplicatedStorage.Remotes:WaitForChild("CodeRequest")
	local view = View.new(player:WaitForChild("PlayerGui"))
	local connections = {}
	local pending = false

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

	local controller = {}
	function controller.Destroy()
		for _, connection in connections do connection:Disconnect() end
		view.Destroy()
	end
	return controller
end

return CodesController
