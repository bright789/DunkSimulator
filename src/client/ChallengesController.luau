local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config.ChallengeConfig)
local HUDConfig = require(ReplicatedStorage.Shared.Config.HUDConfig).ChallengeMenu
local Feel = require(ReplicatedStorage.Shared.Config.FeedbackConfig).Challenge
local Feedback = require(script.Parent.FeedbackController)
local View = require(script.Parent.ui.ChallengesView)

local ChallengesController = {}

function ChallengesController.new(player: Player, hud)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild("ChallengeRequest")
	local state = remotes:WaitForChild("ChallengeState")
	local courtState = remotes:WaitForChild("CourtState")
	local view = View.new(player:WaitForChild("PlayerGui"))
	local connections = {}
	local snapshot = nil
	local observedVertical = nil
	local observedUnlocks = nil
	local pendingId = nil
	local responseTask = nil
	local readyTask = nil
	local readyQueue = {}
	local nextClaim = 0
	local controller = {}

	local function render()
		if snapshot then
			if observedVertical then snapshot.Vertical = math.max(snapshot.Vertical, observedVertical) end
			if observedUnlocks then snapshot.UnlockedCourts = observedUnlocks end
		end
		view.Render(snapshot, pendingId)
		local readyCount = 0
		if snapshot then
			for challengeId, entry in snapshot.Challenges do
				local definition = Config.Get(challengeId)
				if definition and entry.Progress >= Config.Target(definition) and not entry.Completed then
					readyCount += 1
				end
			end
		end
		hud.SetChallengeBadge(readyCount)
	end

	local function read()
		if player:GetAttribute("DataStatus") == "Ready" then request:FireServer() end
	end

	local function close()
		view.Panel.Visible = false
	end

	local function announceReady()
		if readyTask or #readyQueue == 0 then return end
		readyTask = task.spawn(function()
			while #readyQueue > 0 do
				local challengeId = table.remove(readyQueue, 1)
				view.ShowReady(challengeId)
				Feedback.ChallengeReady()
				task.wait(Feel.CompletionHoldSeconds + Feel.FadeSeconds * 2)
			end
			view.HideToast()
			readyTask = nil
		end)
	end

	table.insert(connections, hud.ChallengesButton.Activated:Connect(function()
		view.Panel.Visible = not view.Panel.Visible
		if view.Panel.Visible then read() end
	end))
	table.insert(connections, view.Close.Activated:Connect(close))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then close() end
	end))
	table.insert(connections, player.CharacterRemoving:Connect(function()
		close()
		if readyTask then task.cancel(readyTask); readyTask = nil end
		table.clear(readyQueue)
		view.HideToast()
	end))
	table.insert(connections, player:GetAttributeChangedSignal("DataStatus"):Connect(read))
	for challengeId, row in view.Rows do
		table.insert(connections, row.Button.Activated:Connect(function()
			if pendingId or not row.Button.Active or os.clock() < nextClaim then return end
			nextClaim = os.clock() + Config.ClaimCooldownSeconds
			pendingId = challengeId
			view.Feedback()
			render()
			responseTask = task.delay(HUDConfig.ResponseTimeoutSeconds, function()
				responseTask = nil
				pendingId = nil
				view.Feedback("No claim confirmation. Please try again.", false)
				render()
			end)
			request:FireServer(challengeId)
		end))
	end
	table.insert(connections, state.OnClientEvent:Connect(function(updated, readyIds, resultKind, resultId, resultValue)
		if type(updated) == "table" then snapshot = updated end
		if type(readyIds) == "table" then
			for _, challengeId in readyIds do
				if Config.Get(challengeId) then table.insert(readyQueue, challengeId) end
			end
			announceReady()
		end
		if resultKind == "Claimed" or resultKind == "Rejected" then
			if responseTask then task.cancel(responseTask); responseTask = nil end
			pendingId = nil
			if resultKind == "Claimed" and Config.Get(resultId) and type(resultValue) == "number" then
				if readyTask then task.cancel(readyTask); readyTask = nil end
				table.clear(readyQueue)
				view.ShowClaim(resultId, resultValue)
				Feedback.ChallengeClaim()
				view.Feedback("Reward claimed!", true)
			else
				view.Feedback(type(resultValue) == "string" and resultValue or "Claim unavailable.", false)
			end
		end
		render()
	end))
	table.insert(connections, courtState.OnClientEvent:Connect(function(courtSnapshot)
		if type(courtSnapshot) == "table" and type(courtSnapshot.UnlockedCourts) == "table" then
			observedUnlocks = courtSnapshot.UnlockedCourts
			render()
		end
	end))

	function controller.SetStat(name: string, value: number)
		if name == "Vertical" then observedVertical = value; render() end
	end

	function controller.Destroy()
		for _, connection in connections do connection:Disconnect() end
		if responseTask then task.cancel(responseTask) end
		if readyTask then task.cancel(readyTask) end
		view.Destroy()
	end

	read()
	render()
	return controller
end

return ChallengesController
