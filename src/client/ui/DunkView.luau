local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HUDConfig"))
local UI = require(script.Parent:WaitForChild("UIComponents"))

local DunkView = {}

function DunkView.new(playerGui: PlayerGui)
	local screen = UI.Screen("DunkFeedback", 2)
	local hint = UI.Panel(screen, "DunkHint", UDim2.fromOffset(142, 40), UDim2.fromScale(0.5, 0.94))
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Visible = false
	local key = UI.Label(hint, "Key", "F", UDim2.fromOffset(26, 26), UDim2.fromOffset(8, 7), 16)
	key.Font = Config.BoldFont
	key.TextXAlignment = Enum.TextXAlignment.Center
	key.BackgroundTransparency = 0
	key.BackgroundColor3 = Config.Colors.Inset
	UI.Round(key, 5)
	local action = UI.Label(hint, "Action", "DUNK", UDim2.fromOffset(88, 26), UDim2.fromOffset(44, 7), 15)
	action.Font = Config.BoldFont
	local panel = UI.Panel(screen, "DunkResult", UDim2.fromScale(0.64, 0.17), UDim2.fromScale(0.5, 0.3))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(320, 100)
	limit.Parent = panel
	local title = UI.Label(panel, "Title", "DUNK!", UDim2.fromScale(0.9, 0.45), UDim2.fromScale(0.05, 0.08), 30)
	title.Font = Config.BoldFont
	title.TextXAlignment = Enum.TextXAlignment.Center
	local detail = UI.Label(panel, "Detail", "", UDim2.fromScale(0.9, 0.3), UDim2.fromScale(0.05, 0.57), 20)
	detail.TextXAlignment = Enum.TextXAlignment.Center
	screen.Parent = playerGui
	local view = { Hint = hint, Result = panel }

	function view.ShowResult(cashReward, rejectionReason: string?)
		local success = typeof(cashReward) == "number"
		title.Text = success and "DUNK!" or (rejectionReason or "Dunk unavailable.")
		title.Size = success and UDim2.fromScale(0.9, 0.45) or UDim2.fromScale(0.9, 0.84)
		title.TextWrapped = not success
		title.TextColor3 = success and Config.Colors.Text or Config.Colors.Muted
		detail.Visible = success
		if success then
			detail.Text = "+$" .. UI.Number(cashReward)
			detail.TextColor3 = Config.Colors.Gain
		end
		panel.Visible = true
	end

	function view.Destroy()
		screen:Destroy()
	end

	return view
end

return DunkView
