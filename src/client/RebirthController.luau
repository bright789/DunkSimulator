-- Opens the Rebirth menu from the HUD, asks the server for the player's rebirth state and
-- sends a Rebirth request after a second confirming press. The server decides everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Feedback = require(script.Parent.FeedbackController)
local View = require(script.Parent.ui:WaitForChild("RebirthView"))

local CONFIRM_SECONDS = 4

local RebirthController = {}

function RebirthController.new(player: Player, hud)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild("RebirthRequest")
	local state = remotes:WaitForChild("RebirthState")
	local view = View.new(player:WaitForChild("PlayerGui"))
	local connections = {}
	local snapshot = nil
	local confirmingUntil = 0
	local pending = false
	local controller = {}

	local function busy(): boolean
		return pending or player:GetAttribute("DunkState") ~= "Idle" or player:GetAttribute("CourtTransition") == true
	end

	local function render()
		view.Render(snapshot, os.clock() < confirmingUntil, busy())
		hud.SetRebirths(player:GetAttribute("Rebirths") or 0)
	end

	local function read()
		if player:GetAttribute("DataStatus") == "Ready" then request:FireServer("Read") end
	end

	table.insert(connections, state.OnClientEvent:Connect(function(updated, message, rebirthed)
		pending = false
		if type(updated) == "table" then snapshot = updated end
		view.Feedback(typeof(message) == "string" and message or nil)
		if rebirthed == true and snapshot then
			view.Panel.Visible = false
			view.Celebrate(snapshot)
			Feedback.Rebirth()
		end
		render()
	end))
	table.insert(connections, hud.RebirthButton.Activated:Connect(function()
		view.Panel.Visible = not view.Panel.Visible
		confirmingUntil = 0
		view.Feedback(nil)
		if view.Panel.Visible then read() end
		render()
	end))
	table.insert(connections, view.Close.Activated:Connect(function()
		view.Panel.Visible = false
		confirmingUntil = 0
	end))
	table.insert(connections, view.Button.Activated:Connect(function()
		if not snapshot or not snapshot.CanRebirth or busy() then return end
		if os.clock() < confirmingUntil then
			confirmingUntil = 0
			pending = true
			request:FireServer("Rebirth")
		else
			confirmingUntil = os.clock() + CONFIRM_SECONDS
			task.delay(CONFIRM_SECONDS, render)
		end
		render()
	end))
	for _, attribute in { "Rebirths", "DunkState", "CourtTransition" } do
		table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(render))
	end
	table.insert(connections, player:GetAttributeChangedSignal("DataStatus"):Connect(read))
	read()
	render()

	-- Keep the requirement lines live while the menu is open.
	function controller.SetStat(name: string, value: number)
		if snapshot and (name == "Cash" or name == "Vertical") then
			snapshot[name] = value
			snapshot.CanRebirth = snapshot.Rebirths < snapshot.MaxRebirths and snapshot.Vertical >= snapshot.RequiredVertical
				and snapshot.Cash >= snapshot.RequiredCash
			render()
		end
	end

	function controller.Destroy()
		for _, connection in connections do connection:Disconnect() end
		view.Destroy()
	end

	return controller
end

return RebirthController
