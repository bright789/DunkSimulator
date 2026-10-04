-- Experience notification opt-in (NotificationConfig.OptIn). Shows Roblox's "turn on
-- notifications" prompt at most once per session, at a good moment: right after the new-player
-- tutorial is finished, after the first playtime gift is claimed, or while Dunk Night is on.
-- Never in the first MinSessionSeconds of the session, during a dunk, or over another pop-up
-- or menu: after a good moment it waits up to WaitSeconds for a clear one. Tells the server
-- "Shown" / "Closed" for analytics (NotificationPrompt). The server sends the notifications.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.NotificationConfig).OptIn
local Events = require(ReplicatedStorage.Shared.Config.EventConfig)
local Milestones = require(ReplicatedStorage.Shared.Config.MilestoneConfig)
local HUDConfig = require(ReplicatedStorage.Shared.Config.HUDConfig)
local ActionFeed = require(script.Parent:WaitForChild("ActionFeed"))

local NotificationController = {}

-- Pop-ups the prompt must not cover: menus, pop-ups and the Dunk Contest banner and results
-- (ScreenGui DisplayOrder 8 and up), and the tutorial card (with its Starter Pack offer).
local POPUP_ORDER = 8
local ALSO_POPUPS = { Tutorial = true }

local function visiblePanel(object: Instance): boolean
	return object:IsA("GuiObject") and object.Visible and object.BackgroundTransparency < 1
end

-- True when a menu or pop-up is on screen: a visible, non-transparent frame directly inside
-- such a ScreenGui (or one level further down).
local function popupOpen(playerGui: PlayerGui): boolean
	for _, screen in playerGui:GetChildren() do
		if screen:IsA("ScreenGui") and screen.Enabled and (screen.DisplayOrder >= POPUP_ORDER or ALSO_POPUPS[screen.Name]) then
			for _, child in screen:GetChildren() do
				if child:IsA("GuiObject") and child.Visible then
					if visiblePanel(child) then return true end
					for _, inner in child:GetChildren() do
						if visiblePanel(inner) then return true end
					end
				end
			end
		end
	end
	return false
end

-- The fields MilestoneConfig's tutorial checks, from what the server replicates (nil until loaded).
local function tutorialSnapshot(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local vertical = leaderstats and leaderstats:FindFirstChild("Vertical")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	local trainingLevel = player:GetAttribute("TrainingLevel")
	local totalDunks = player:GetAttribute("TotalDunks")
	if not vertical or not cash or trainingLevel == nil or totalDunks == nil then return nil end
	return {
		Vertical = vertical.Value,
		BestVertical = math.max(player:GetAttribute("BestVertical") or 0, vertical.Value),
		TotalDunks = totalDunks,
		TrainingLevel = trainingLevel,
		Rebirths = player:GetAttribute("Rebirths") or 0,
		ContestWins = player:GetAttribute("ContestWins") or 0,
		Cash = cash.Value,
		HasBall = player:GetAttribute("HasBasketball") == true,
		UnlockedCourts = {},
	}
end

function NotificationController.new(player: Player)
	local remote = ReplicatedStorage.Remotes:WaitForChild("NotificationPrompt")
	local playerGui = player:WaitForChild("PlayerGui")
	local isStudio = RunService:IsStudio()
	local serviceOk, service = pcall(game.GetService, game, "ExperienceNotificationService")
	local connections = {}
	local sessionStart = os.clock()
	local asked = false
	local shown = false
	-- A good moment happened: prompt before this os.clock() time.
	local wantUntil = 0
	local tutorialWasActive = false
	local giftClaimed = false

	local function goodMoment()
		wantUntil = math.max(wantUntil, os.clock() + Config.WaitSeconds)
	end

	local function prompt()
		asked = true
		local canOk, canPrompt = pcall(service.CanPromptOptInAsync, service)
		if not canOk or canPrompt ~= true then return end
		ActionFeed.Push(Config.NudgeText, HUDConfig.Colors.Gold)
		local promptOk, problem = pcall(service.PromptOptIn, service)
		if promptOk then
			shown = true
			remote:FireServer("Shown")
		else
			warn("[Notifications] Opt-in prompt failed: " .. tostring(problem))
		end
	end

	if serviceOk and service then
		pcall(function()
			table.insert(connections, service.OptInPromptClosed:Connect(function()
				if shown then remote:FireServer("Closed") end
			end))
		end)
	end
	table.insert(connections, ReplicatedStorage.Remotes:WaitForChild("GiftState").OnClientEvent:Connect(function(_, result)
		if not giftClaimed and type(result) == "table" and result.Kind == "Claimed" then
			giftClaimed = true
			goodMoment()
		end
	end))

	local ticker = task.spawn(function()
		while not asked and serviceOk and service do
			task.wait(1)
			-- Tutorial just finished (it was on this session and now every step is done).
			local snapshot = tutorialSnapshot(player)
			if snapshot then
				local active = Milestones.TutorialActive(snapshot)
				if tutorialWasActive and not active then goodMoment() end
				tutorialWasActive = active
			end
			if Events.DunkNightAt(Workspace:GetServerTimeNow(), isStudio) then goodMoment() end
			local dunkState = player:GetAttribute("DunkState")
			if os.clock() < wantUntil and os.clock() - sessionStart >= Config.MinSessionSeconds
				and (dunkState == nil or dunkState == "Idle") and not popupOpen(playerGui) then
				local ok, problem = pcall(prompt)
				if not ok then warn("[Notifications] " .. tostring(problem)) end
			end
		end
	end)

	local controller = {}
	function controller.Destroy()
		if coroutine.status(ticker) ~= "dead" then task.cancel(ticker) end
		for _, connection in connections do connection:Disconnect() end
	end
	return controller
end

return NotificationController
