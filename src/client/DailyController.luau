-- Daily menu controller: opens from the HUD (and once per session by itself when today's
-- login reward is waiting), sends claim requests, and shows the Cash Boost countdown on the
-- HUD. Everything shown comes from the server's DailyState snapshot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local HUDConfig = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Feedback = require(script.Parent.FeedbackController)
local View = require(script.Parent.ui:WaitForChild("DailyView"))
local UI = require(script.Parent.ui:WaitForChild("UIComponents"))

local DailyController = {}

function DailyController.new(player: Player, hud)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild("DailyRequest")
	local state = remotes:WaitForChild("DailyState")
	local view = View.new(player:WaitForChild("PlayerGui"))
	local connections = {}
	local snapshot = nil
	local pending = nil
	local responseTask = nil
	local autoOpened = false
	local refreshedDay = nil
	local nextClaim = 0
	local controller = {}

	local function now(): number
		return Workspace:GetServerTimeNow()
	end

	local function resetIn(): number
		return snapshot and (snapshot.Day + 1) * Daily.SecondsPerDay - now() or 0
	end

	local function read()
		if player:GetAttribute("DataStatus") == "Ready" then request:FireServer("Read") end
	end

	local function render()
		view.Render(snapshot, pending, resetIn())
		local count = 0
		if snapshot then
			if snapshot.CanClaim then count += 1 end
			for _, entry in snapshot.Challenges do
				if entry.Progress >= entry.Target and not entry.Claimed then count += 1 end
			end
		end
		hud.SetDailyBadge(count)
	end

	local function renderBoost()
		local boostUntil = player:GetAttribute("CashBoostUntil")
		local left = typeof(boostUntil) == "number" and boostUntil - now() or 0
		if left > 0 then
			local multiplier = snapshot and snapshot.BoostMultiplier or Daily.Boost.Multiplier
			hud.SetBoost(string.format("%dx CASH  %d:%02d", multiplier, left // 60, math.floor(left % 60)))
		else
			hud.SetBoost(nil)
		end
	end

	local function send(kind, slot: number?)
		if pending or os.clock() < nextClaim then return end
		nextClaim = os.clock() + Daily.ClaimCooldownSeconds
		pending = kind == "Reward" and "Reward" or slot
		view.Feedback(nil)
		render()
		responseTask = task.delay(HUDConfig.ChallengeMenu.ResponseTimeoutSeconds, function()
			responseTask = nil
			pending = nil
			view.Feedback("No claim confirmation. Please try again.", false)
			render()
		end)
		if kind == "Reward" then request:FireServer("Reward") else request:FireServer("Challenge", slot) end
	end

	local function boostText(minutes: number): string
		return minutes > 0 and string.format("  +  %dx Cash for %d min", Daily.Boost.Multiplier, minutes) or ""
	end

	table.insert(connections, state.OnClientEvent:Connect(function(updated, result, readySlots)
		if type(updated) == "table" then snapshot = updated end
		if type(result) == "table" then
			if responseTask then task.cancel(responseTask); responseTask = nil end
			pending = nil
			if result.Kind == "Reward" then
				view.Toast(string.format("DAY %d REWARD", result.Day), string.format("STREAK: %d", result.Streak),
					"+$" .. UI.Number(result.Cash) .. boostText(result.BoostMinutes), true)
				view.Feedback("Daily reward claimed!", true)
				Feedback.ChallengeClaim()
			elseif result.Kind == "Challenge" then
				view.Toast(result.Sweep and "ALL DAILY CHALLENGES DONE" or "DAILY CHALLENGE", result.Sweep and "SWEEP BONUS!" or "REWARD",
					"+$" .. UI.Number(result.Cash) .. boostText(result.BoostMinutes), true)
				view.Feedback("Reward claimed!", true)
				Feedback.ChallengeClaim()
			elseif result.Kind == "Rejected" then
				view.Feedback(type(result.Message) == "string" and result.Message or "Claim unavailable.", false)
			end
		end
		if type(readySlots) == "table" and snapshot and #readySlots > 0 then
			local entry = snapshot.Challenges[readySlots[1]]
			local definition = entry and Daily.Challenges.Pool[entry.Id]
			if definition then
				view.Toast("DAILY CHALLENGE COMPLETE", definition.Title:upper(), "Open DAILY to claim $" .. UI.Number(entry.Reward), false)
				Feedback.ChallengeReady()
			end
		end
		if snapshot and snapshot.CanClaim and not autoOpened then
			autoOpened = true
			view.Panel.Visible = true
		end
		render()
	end))
	table.insert(connections, hud.DailyButton.Activated:Connect(function()
		view.Panel.Visible = not view.Panel.Visible
		if view.Panel.Visible then read() end
	end))
	table.insert(connections, view.Close.Activated:Connect(function() view.Panel.Visible = false end))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then view.Panel.Visible = false end
	end))
	table.insert(connections, view.ClaimButton.Activated:Connect(function()
		if snapshot and snapshot.CanClaim and view.ClaimButton.Active then send("Reward") end
	end))
	for slot, row in view.Rows do
		table.insert(connections, row.Button.Activated:Connect(function()
			if row.Button.Active then send("Challenge", slot) end
		end))
	end
	table.insert(connections, player:GetAttributeChangedSignal("DataStatus"):Connect(read))
	table.insert(connections, player:GetAttributeChangedSignal("CashBoostUntil"):Connect(renderBoost))

	-- Once a second: countdowns, and a fresh read when the UTC day rolls over.
	local ticker = task.spawn(function()
		while true do
			task.wait(1)
			renderBoost()
			if snapshot then
				if resetIn() <= 0 and refreshedDay ~= snapshot.Day then
					refreshedDay = snapshot.Day
					read()
				end
				if view.Panel.Visible then render() end
			end
		end
	end)

	function controller.Destroy()
		for _, connection in connections do connection:Disconnect() end
		if responseTask then task.cancel(responseTask) end
		task.cancel(ticker)
		view.Destroy()
	end

	read()
	render()
	renderBoost()
	return controller
end

return DailyController
