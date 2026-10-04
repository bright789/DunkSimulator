-- Timed events on this client (EventConfig; the server applies every bonus, this only shows them):
--   * The HUD event pill lists what's running, one line each: scheduled events
--     ("2X CASH WEEKEND  1d 4h"), Dunk Night ("DUNK NIGHT  32:10", or "DUNK NIGHT IN 3:42:10"
--     during the day before it starts) and the random server event ("OVERTIME  2:41", read
--     from the Workspace attributes ServerEventService sets).
--   * Dunk Night and server events get a big banner, a feed line and a sound when they start
--     (also when you join during one) and a feed line when they end.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Events = require(ReplicatedStorage.Shared.Config.EventConfig)
local ActionFeed = require(script.Parent:WaitForChild("ActionFeed"))
local Feedback = require(script.Parent:WaitForChild("FeedbackController"))

local EventsController = {}

local TICK_SECONDS = 0.5
local WEEKDAYS = { [0] = "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

-- "1d 4h", "4h 2m" or "2m 05s" (long scheduled events).
local function span(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days, hours, minutes = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
	if days > 0 then return string.format("%dd %dh", days, hours) end
	if hours > 0 then return string.format("%dh %dm", hours, minutes) end
	return string.format("%dm %02ds", minutes, seconds % 60)
end

-- "3:42:10" or "32:10".
local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours, minutes = seconds // 3600, (seconds % 3600) // 60
	if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, seconds % 60) end
	return string.format("%d:%02d", minutes, seconds % 60)
end

function EventsController.new(_player: Player, hud)
	local isStudio = RunService:IsStudio()
	local night = Events.DunkNight
	local wasNight: boolean? = nil
	-- "Id:Ends" of the server event already announced (nil = none).
	local shownServerEvent: string? = nil

	local function update()
		local now = Workspace:GetServerTimeNow()
		local lines = {}
		for _, event in Events.Scheduled(now, isStudio) do
			table.insert(lines, string.format("%s  %s", event.Name, span(event.Ends - now)))
		end
		local running = Events.DunkNightAt(now, isStudio)
		if running then
			table.insert(lines, string.format("%s  %s", night.Name, clock(running.Ends - now)))
		else
			local untilNight = Events.DunkNightStart(now) - now
			if untilNight > 0 and untilNight <= night.CountdownHours * 3600 then
				table.insert(lines, string.format("%s IN %s", night.Name, clock(untilNight)))
			end
		end
		local serverEvent = Events.ServerEventAt(now, Events.ReadServerEvent(Workspace))
		if serverEvent then
			table.insert(lines, string.format("%s  %s", serverEvent.Name, clock(serverEvent.Ends - now)))
		end
		hud.SetEvent(#lines > 0 and table.concat(lines, "\n") or nil)

		-- Dunk Night starting or ending.
		local isNight = running ~= nil
		if isNight ~= wasNight then
			if running then
				ActionFeed.Announce(string.format("%s! %dx CASH  %dx TRAINING", night.Name, night.CashMultiplier,
					night.TrainingMultiplier), night.Color, 3.5)
				ActionFeed.Push(string.format("%s: GOLDEN BALLS EVERY %d S AND MORE EVENTS FOR %s", night.Name,
					night.GoldenBallSeconds, clock(running.Ends - now)), night.Color)
				Feedback.Rebirth()
			elseif wasNight then
				ActionFeed.Announce(string.format("Dunk Night is over — see you next %s!", WEEKDAYS[night.Weekday] or "week"),
					night.Color, 3)
				Feedback.ChallengeReady()
			end
			wasNight = isNight
		end

		-- A server event starting or ending.
		local key = serverEvent and (serverEvent.Id .. ":" .. serverEvent.Ends) or nil
		if key ~= shownServerEvent then
			local definition = serverEvent and Events.GetServerEvent(serverEvent.Id)
			if serverEvent and definition then
				ActionFeed.Announce(string.format(definition.Banner, clock(serverEvent.Ends - now)), definition.Color, 2.5)
				ActionFeed.Push(definition.Name .. " STARTED!", definition.Color)
				Feedback.DunkUnlock()
			elseif shownServerEvent then
				local ended = Events.GetServerEvent(string.match(shownServerEvent, "^(%w+):"))
				if ended then
					ActionFeed.Push(ended.Name .. " IS OVER", ended.Color)
					Feedback.ChallengeReady()
				end
			end
			shownServerEvent = key
		end
	end

	local ticker = task.spawn(function()
		while true do
			local ok, problem = pcall(update)
			if not ok then warn("[Events] " .. tostring(problem)) end
			task.wait(TICK_SECONDS)
		end
	end)

	local controller = {}
	function controller.Destroy()
		task.cancel(ticker)
	end
	return controller
end

return EventsController
