-- AFK Practice on this client (AfkService decides and pays everything). While you stand on
-- a pad (AfkOnPad) a strip shows the time left to the next reward and prize (AfkRewardIn,
-- AfkPrizeIn); payouts arrive on the AfkPractice remote and go in the action feed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AfkConfig = require(ReplicatedStorage.Shared.Config.AfkConfig)
local HUDConfig = require(ReplicatedStorage.Shared.Config.HUDConfig)
local View = require(script.Parent.ui:WaitForChild("AfkView"))
local UI = require(script.Parent.ui:WaitForChild("UIComponents"))
local ActionFeed = require(script.Parent:WaitForChild("ActionFeed"))
local Feedback = require(script.Parent:WaitForChild("FeedbackController"))

local AfkController = {}

-- "1:42" or "12:10".
local function clock(seconds): string
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function AfkController.new(player: Player)
	local remote = ReplicatedStorage.Remotes:WaitForChild("AfkPractice")
	local view = View.new(player:WaitForChild("PlayerGui"))
	local connections = {}

	local function render()
		if player:GetAttribute("AfkOnPad") == true then
			view.Show(string.format("%s  •  next reward %s  •  prize in %s", AfkConfig.Pad.Name,
				clock(player:GetAttribute("AfkRewardIn")), clock(player:GetAttribute("AfkPrizeIn"))))
		else
			view.Hide()
		end
	end

	for _, attribute in { "AfkOnPad", "AfkRewardIn", "AfkPrizeIn" } do
		table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(render))
	end
	-- ("Reward", cash) or ("Prize", prizeKind, amount, text).
	table.insert(connections, remote.OnClientEvent:Connect(function(kind, a, b, c)
		if kind == "Reward" and type(a) == "number" then
			ActionFeed.Push(string.format("%s  +$%s", AfkConfig.Pad.Name, UI.Number(a)), HUDConfig.Colors.Gain)
			Feedback.Coin()
		elseif kind == "Prize" and type(b) == "number" then
			local prize = a == "Cash" and ("+$" .. UI.Number(b)) or (type(c) == "string" and c or "")
			ActionFeed.Announce("AFK PRIZE!  " .. prize, HUDConfig.Colors.Gold, 2.5)
			Feedback.ChallengeClaim()
		end
	end))
	render()

	local controller = {}
	function controller.Destroy()
		for _, connection in connections do connection:Disconnect() end
		view.Destroy()
	end
	return controller
end

return AfkController
