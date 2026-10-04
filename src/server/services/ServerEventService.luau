-- Random server events (EventConfig.ServerEvents): OVERTIME (2x Cash), TRAINING FRENZY
-- (2x training reps), GOLDEN BALL STORM (Golden Balls every ~10 s) and CASH RAIN (bills
-- fall around every player). While at least one player is in the server, one event starts
-- every 15-20 minutes (every ~5 minutes during Dunk Night), never two at once, and never in
-- the last seconds of a Dunk Contest round.
-- The running event is published as Workspace attributes ServerEvent (its Id, "" when none)
-- and ServerEventEnds (Unix seconds). PlayerService and PickupService read the bonuses from
-- there through EventConfig; clients only draw the banner, feed line and HUD pill.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Events = require(ReplicatedStorage.Shared.Config.EventConfig)
local PickupConfig = require(ReplicatedStorage.Shared.Config.PickupConfig)
local PlayerService = require(script.Parent.PlayerService)
local PickupService = require(script.Parent.PickupService)
local Analytics = require(script.Parent.AnalyticsReporter)

local ServerEventService = {}
local initialized = false
local isStudio = RunService:IsStudio()
local random = Random.new()
local Config = Events.ServerEvents

-- The running event ({ Id, Ends }) and when the next one may start (Unix seconds, nil = no
-- players yet). os.time() is whole seconds, which is plenty for minutes-long events.
local current: { Id: string, Ends: number }? = nil
local nextAt: number? = nil
local studioForced = false

-- Players who are in a court and can take part (data loaded, not riding the bus).
local function participants(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if PlayerService.IsReady(player) and not player:GetAttribute("TransitRide") then table.insert(list, player) end
	end
	return list
end

-- Shortest and longest wait between events right now (shorter during Dunk Night).
function ServerEventService.Gap(now: number): (number, number)
	if isStudio and Config.StudioIntervalSeconds > 0 then
		return Config.StudioIntervalSeconds, Config.StudioIntervalSeconds
	end
	if Events.DunkNightAt(now, isStudio) then
		return Events.DunkNight.ServerEventMinSeconds, Events.DunkNight.ServerEventMaxSeconds
	end
	return Config.MinSeconds, Config.MaxSeconds
end

-- An event picked by weight (`roll` is 0-1).
function ServerEventService.Pick(roll: number)
	local total = 0
	for _, event in Config.List do total += event.Weight end
	local pick = roll * total
	for _, event in Config.List do
		pick -= event.Weight
		if pick <= 0 then return event end
	end
	return Config.List[#Config.List]
end

-- True while a Dunk Contest round is open with ContestQuietSeconds or fewer left.
local function contestEnding(): boolean
	local contest = ReplicatedStorage:FindFirstChild("Contest")
	local endsAt = contest and contest:GetAttribute("EndsAt")
	return contest ~= nil and contest:GetAttribute("Phase") == "Open" and type(endsAt) == "number"
		and endsAt - Workspace:GetServerTimeNow() <= Config.ContestQuietSeconds
end

local function start(event, now: number, players: { Player })
	current = { Id = event.Id, Ends = now + event.DurationSeconds }
	Workspace:SetAttribute("ServerEventEnds", current.Ends)
	Workspace:SetAttribute("ServerEvent", event.Id)
	for _, player in players do Analytics.Custom(player, "ServerEvent_" .. event.Id) end
	print(string.format("[ServerEventService] %s started (%d s).", event.Name, event.DurationSeconds))
end

local function finish()
	current = nil
	Workspace:SetAttribute("ServerEvent", "")
end

-- One step of the scheduler (every second). Returns the event it started, if any.
function ServerEventService.Step(now: number)
	local players = participants()
	if current and now >= current.Ends then finish() end
	if #players == 0 then
		-- Nobody here: the next event waits until someone has played a while.
		nextAt = nil
		return nil
	end
	local shortest, longest = ServerEventService.Gap(now)
	if not nextAt then
		nextAt = now + random:NextInteger(shortest, longest)
		if isStudio and Config.StudioForceNext ~= "" and not studioForced then nextAt = now + 10 end
	elseif not current and nextAt > now + longest then
		-- Dunk Night just started (or the Studio interval changed): don't wait out a long gap.
		nextAt = now + random:NextInteger(shortest, longest)
	end
	if current then
		if current.Id == "CashRain" then
			for _, player in players do
				local ok, problem = pcall(PickupService.RainBills, player, PickupConfig.Rain.BillsPerSecond)
				if not ok then warn("[ServerEventService] Cash Rain: " .. tostring(problem)) end
			end
		end
		return nil
	end
	if now < nextAt or contestEnding() then return nil end
	local event = nil
	if isStudio and not studioForced and Config.StudioForceNext ~= "" then
		studioForced = true
		event = Events.GetServerEvent(Config.StudioForceNext)
		if not event then warn("[ServerEventService] StudioForceNext: unknown event " .. Config.StudioForceNext) end
	end
	event = event or ServerEventService.Pick(random:NextNumber())
	start(event, now, players)
	nextAt = current.Ends + random:NextInteger(shortest, longest)
	return event
end

function ServerEventService.Init()
	if initialized then return end
	initialized = true
	Workspace:SetAttribute("ServerEvent", "")
	Workspace:SetAttribute("ServerEventEnds", 0)
	if isStudio and (Config.StudioForceNext ~= "" or Config.StudioIntervalSeconds > 0) then
		print(string.format("[ServerEventService] Studio test flags on: StudioForceNext=%q, StudioIntervalSeconds=%d.",
			Config.StudioForceNext, Config.StudioIntervalSeconds))
	end
	task.spawn(function()
		while true do
			local ok, problem = pcall(ServerEventService.Step, os.time())
			if not ok then warn("[ServerEventService] " .. tostring(problem)) end
			task.wait(1)
		end
	end)
end

return ServerEventService
