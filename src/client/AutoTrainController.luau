-- AUTO TRAIN toggle on the HUD for Auto Train pass owners. The server decides ownership and
-- does the training (TrainingService); this only shows the state and asks to flip it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AutoTrainController = {}

function AutoTrainController.new(player: Player, hud)
	local request = ReplicatedStorage.Remotes:WaitForChild("AutoTrainRequest")
	local connections = {}

	local function render()
		hud.SetAutoTrain(player:GetAttribute("Pass_AutoTrain") == true, player:GetAttribute("AutoTrain") == true)
	end
	table.insert(connections, player:GetAttributeChangedSignal("Pass_AutoTrain"):Connect(render))
	table.insert(connections, player:GetAttributeChangedSignal("AutoTrain"):Connect(render))
	table.insert(connections, hud.AutoTrainButton.Activated:Connect(function()
		request:FireServer(player:GetAttribute("AutoTrain") ~= true)
	end))
	render()

	local controller = {}
	function controller.Destroy()
		for _, connection in connections do connection:Disconnect() end
	end
	return controller
end

return AutoTrainController
