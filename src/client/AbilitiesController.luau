-- Ability hotbar + ABILITIES panel. Keys 1 / 2 / 3 (D-pad left / up / right, or tap a slot)
-- send AbilityRequest("Use", id); the panel sends "Unlock" (buy early) and "Upgrade". Levels,
-- recharge and ARMED come from the server's AbilityLevel_/AbilityReadyAt_/AbilityArmed_
-- attributes; the client never decides anything.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Abilities = require(ReplicatedStorage.Shared.Config.AbilityConfig)
local View = require(script.Parent.ui:WaitForChild("AbilitiesView"))
local Feedback = require(script.Parent.FeedbackController)
local UI = require(script.Parent.ui:WaitForChild("UIComponents"))
local ActionFeed = require(script.Parent:WaitForChild("ActionFeed"))

local AbilitiesController = {}

function AbilitiesController.new(player: Player, hud)
	local request = ReplicatedStorage.Remotes:WaitForChild("AbilityRequest")
	local view = View.new(player:WaitForChild("PlayerGui"), hud.Navigation)
	local connections = {}
	local ids = Abilities.Ids()

	local function level(abilityId: string): number
		return tonumber(player:GetAttribute("AbilityLevel_" .. abilityId)) or 0
	end

	local function cash(): number
		local stats = player:FindFirstChild("leaderstats")
		local value = stats and stats:FindFirstChild("Cash")
		return value and value.Value or 0
	end

	local function render()
		local now = Workspace:GetServerTimeNow()
		for _, abilityId in ids do
			local definition = Abilities.Abilities[abilityId]
			local current = level(abilityId)
			local readyAt = tonumber(player:GetAttribute("AbilityReadyAt_" .. abilityId)) or 0
			view.SetSlot(abilityId, {
				Level = current,
				Armed = player:GetAttribute("AbilityArmed_" .. abilityId) == true,
				Remaining = math.max(0, readyAt - now),
				Cooldown = Abilities.Cooldown(abilityId, math.max(current, 1)),
			})
			if view.Panel.Visible then
				if current < 1 then
					view.SetRow(abilityId, {
						Text = string.format("FREE AT %d VERTICAL", definition.UnlockVertical),
						ActionText = "BUY NOW\n$" .. UI.Number(definition.UnlockPrice),
						Enabled = cash() >= definition.UnlockPrice,
					})
				else
					local price = Abilities.UpgradePrice(abilityId, current)
					view.SetRow(abilityId, {
						Text = string.format("LEVEL %d/%d   RECHARGE %ds", current, Abilities.MaxLevel, Abilities.Cooldown(abilityId, current)),
						ActionText = price and ("UPGRADE\n$" .. UI.Number(price)) or "MAX",
						Enabled = price ~= nil and cash() >= price,
					})
				end
			end
		end
	end

	local function openPanel(visible: boolean)
		view.Panel.Visible = visible
		if visible then view.ShowResult(true, "") end
		render()
	end

	local function use(abilityId: string)
		if level(abilityId) < 1 then
			openPanel(true)
			return
		end
		request:FireServer("Use", abilityId)
	end

	-- Keyboard / gamepad. Bound actions don't fire while typing in a text box.
	for _, abilityId in ids do
		local definition = Abilities.Abilities[abilityId]
		ContextActionService:BindAction("Ability_" .. abilityId, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then use(abilityId) end
			return Enum.ContextActionResult.Sink
		end, false, definition.Key, definition.GamepadKey)
		table.insert(connections, view.Slots[abilityId].Button.Activated:Connect(function() use(abilityId) end))
		table.insert(connections, view.Rows[abilityId].Action.Activated:Connect(function()
			if not view.Rows[abilityId].Action.Active then return end
			request:FireServer(level(abilityId) < 1 and "Unlock" or "Upgrade", abilityId)
		end))
	end

	table.insert(connections, request.OnClientEvent:Connect(function(ok, message, abilityId)
		if type(message) ~= "string" then return end
		local definition = Abilities.Get(abilityId)
		local color = ok and (definition and definition.Color or Color3.new(1, 1, 1)) or Color3.fromRGB(255, 178, 64)
		if view.Panel.Visible then
			view.ShowResult(ok == true, message)
		elseif ok == true and string.find(message, "UNLOCKED") then
			ActionFeed.Announce((string.gsub(message, "\n.*", "")), color)
			ActionFeed.Push((string.gsub(message, "^.-\n", "")), color)
		else
			ActionFeed.Push((string.gsub(message, "\n", "  ")), color)
		end
		if ok == true then
			if string.find(message, "UNLOCKED") or string.find(message, "LEVEL") then
				Feedback.DunkUnlock()
			else
				Feedback.ChallengeReady()
			end
		end
		render()
	end))
	table.insert(connections, hud.AbilitiesButton.Activated:Connect(function() openPanel(not view.Panel.Visible) end))
	table.insert(connections, view.Close.Activated:Connect(function() openPanel(false) end))

	local ticker = task.spawn(function()
		while true do
			render()
			task.wait(0.1)
		end
	end)

	local controller = {}
	function controller.Destroy()
		task.cancel(ticker)
		for _, abilityId in ids do ContextActionService:UnbindAction("Ability_" .. abilityId) end
		for _, connection in connections do connection:Disconnect() end
		view.Destroy()
	end
	return controller
end

return AbilitiesController
