-- Playtime gifts on this client (GiftService decides everything). The GIFTS button shows how
-- many gifts are ready ("GIFTS (2)") or counts down to the next one, a short feed message
-- and sound say when a gift opens, and the panel claims them. The panel never opens by
-- itself: joining already shows the daily reward and welcome-back pop-ups.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Gifts = require(ReplicatedStorage.Shared.Config.GiftConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local HUDConfig = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Feedback = require(script.Parent.FeedbackController)
local ActionFeed = require(script.Parent:WaitForChild("ActionFeed"))
local View = require(script.Parent.ui:WaitForChild("GiftsView"))
local UI = require(script.Parent.ui:WaitForChild("UIComponents"))

local GiftsController = {}

local TICK_SECONDS = 0.5

function GiftsController.new(player: Player, hud)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild("GiftRequest")
	local state = remotes:WaitForChild("GiftState")
	local view = View.new(player:WaitForChild("PlayerGui"))
	local connections = {}
	local snapshot = nil
	local pending: number? = nil
	local responseTask = nil
	-- Gifts already announced as ready this session.
	local announced: { [number]: boolean } = {}
	local nextClaim = 0
	local controller = {}

	local function read()
		if player:GetAttribute("DataStatus") == "Ready" then request:FireServer("Read") end
	end

	local function render()
		local now = Workspace:GetServerTimeNow()
		view.Render(snapshot, now, pending)
		if not snapshot then
			hud.SetGifts("GIFTS", false)
			return
		end
		local ready, nextLeft = 0, nil
		for index, gift in snapshot.Gifts do
			if not gift.Claimed then
				local left = gift.UnlockAt - now
				if left <= 0 then
					ready += 1
					if not announced[index] then
						announced[index] = true
						ActionFeed.Push("FREE GIFT READY! OPEN GIFTS TO CLAIM IT", HUDConfig.Colors.Gold)
						Feedback.ChallengeReady()
					end
				elseif not nextLeft or left < nextLeft then
					nextLeft = left
				end
			end
		end
		if ready > 0 then
			hud.SetGifts(string.format("GIFTS (%d)", ready), true)
		elseif nextLeft then
			hud.SetGifts("NEXT GIFT  " .. View.Clock(nextLeft), false)
		else
			hud.SetGifts("GIFTS", false)
		end
	end

	local function claim(index: number)
		local gift = snapshot and snapshot.Gifts[index]
		if pending or not gift or gift.Claimed or gift.UnlockAt > Workspace:GetServerTimeNow()
			or os.clock() < nextClaim then
			return
		end
		nextClaim = os.clock() + Gifts.ClaimCooldownSeconds
		pending = index
		view.Feedback(nil)
		render()
		responseTask = task.delay(HUDConfig.ChallengeMenu.ResponseTimeoutSeconds, function()
			responseTask = nil
			pending = nil
			view.Feedback("No claim confirmation. Please try again.", false)
			render()
		end)
		request:FireServer("Claim", index)
	end

	table.insert(connections, hud.GiftsButton.Activated:Connect(function()
		view.Panel.Visible = not view.Panel.Visible
		if view.Panel.Visible then read() end
	end))
	table.insert(connections, view.Close.Activated:Connect(function() view.Panel.Visible = false end))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then view.Panel.Visible = false end
	end))
	table.insert(connections, player:GetAttributeChangedSignal("DataStatus"):Connect(read))
	for index, row in view.Rows do
		table.insert(connections, row.Button.Activated:Connect(function()
			if row.Button.Active then claim(index) end
		end))
	end
	table.insert(connections, state.OnClientEvent:Connect(function(updated, result)
		if type(updated) == "table" and type(updated.Gifts) == "table" then snapshot = updated end
		if type(result) == "table" and (result.Kind == "Claimed" or result.Kind == "Rejected") then
			if responseTask then task.cancel(responseTask); responseTask = nil end
			pending = nil
			if result.Kind == "Claimed" then
				view.Feedback("Gift claimed!", true)
				local parts = {}
				if type(result.Cash) == "number" and result.Cash > 0 then table.insert(parts, "+$" .. UI.Number(result.Cash)) end
				if type(result.BoostMinutes) == "number" and result.BoostMinutes > 0 then
					table.insert(parts, string.format("%dx CASH %d MIN", Daily.Boost.Multiplier, result.BoostMinutes))
				end
				if result.CrewPack == true then table.insert(parts, "CREW PACK") end
				ActionFeed.Announce("FREE GIFT!  " .. table.concat(parts, "  "), HUDConfig.Colors.Gain)
				Feedback.ChallengeClaim()
			else
				view.Feedback(type(result.Message) == "string" and result.Message or "Claim unavailable.", false)
			end
		end
		render()
	end))

	-- Countdowns run on the local copy of the server clock between updates.
	local ticker = task.spawn(function()
		while true do
			local ok, problem = pcall(render)
			if not ok then warn("[Gifts] " .. tostring(problem)) end
			task.wait(TICK_SECONDS)
		end
	end)

	function controller.Destroy()
		task.cancel(ticker)
		if responseTask then task.cancel(responseTask) end
		for _, connection in connections do connection:Disconnect() end
		view.Destroy()
	end

	read()
	return controller
end

return GiftsController
