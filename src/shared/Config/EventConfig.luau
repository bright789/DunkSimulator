-- Timed server-wide events. While one is running, dunk and air-trick Cash is multiplied by
-- its CashMultiplier and training reps by its TrainingMultiplier (both stack with boosts and
-- passes), and the HUD shows a countdown pill. There are three kinds:
--   Events        scheduled dates. Times are Unix seconds (UTC). Add a new entry to schedule
--                 another event; past ones can stay in the list.
--   DunkNight     every week on the same UTC day and time (worked out here, no dates to type).
--   ServerEvents  short random events (OVERTIME, CASH RAIN, ...) that ServerEventService
--                 starts in each server and publishes as Workspace attributes.
-- When several run at once their multipliers multiply, up to MaxEventMultiplier in total
-- (passes, boosts and the rest still stack on top). The server applies every bonus;
-- clients only display them.
local EventConfig = {
	Events = {
		-- Launch weekend: Friday 2 Oct 2026 00:00 UTC to Monday 5 Oct 2026 00:00 UTC.
		{ Name = "2X CASH WEEKEND", Starts = 1790899200, Ends = 1791158400, CashMultiplier = 2 },
	},
	-- Studio only: pretend this event index is running now (0 = off). Ignored on live servers.
	StudioForceEvent = 0,
	-- Cap on all event multipliers multiplied together (e.g. Dunk Night x2 and OVERTIME x2 = x4).
	MaxEventMultiplier = 4,

	-- "Dunk Night": the weekly admin-abuse style event.
	DunkNight = {
		Name = "DUNK NIGHT",
		-- UTC day of the week: 0 = Sunday, 1 = Monday ... 6 = Saturday.
		Weekday = 6,
		StartHourUtc = 19,
		StartMinuteUtc = 0,
		DurationMinutes = 45,
		CashMultiplier = 2,
		TrainingMultiplier = 2,
		-- A Golden Ball on each court with players about this often (normally PickupConfig's 75 s).
		GoldenBallSeconds = 15,
		-- Random server events come this often during Dunk Night (instead of ServerEvents' 15-20 min).
		ServerEventMinSeconds = 270,
		ServerEventMaxSeconds = 330,
		-- The HUD counts down to Dunk Night during this many hours before it starts.
		CountdownHours = 24,
		Color = Color3.fromRGB(255, 120, 40),
	},
	-- Studio only: pretend Dunk Night is on (back-to-back nights). Ignored on live servers. Keep false.
	StudioForceDunkNight = false,

	-- Random server events (ServerEventService). One at a time, for the whole server, while at
	-- least one player is in it. `Banner` gets the event's length, e.g. "3:00".
	ServerEvents = {
		-- Seconds between the end of one event and the start of the next (a random time in between).
		MinSeconds = 900,
		MaxSeconds = 1200,
		-- Don't start an event when a Dunk Contest round has this many seconds or fewer left.
		ContestQuietSeconds = 20,
		List = {
			{ Id = "Overtime", Name = "OVERTIME", Weight = 30, DurationSeconds = 180, CashMultiplier = 2,
				Banner = "OVERTIME! 2x Cash for %s", Color = Color3.fromRGB(255, 90, 60) },
			{ Id = "TrainingFrenzy", Name = "TRAINING FRENZY", Weight = 30, DurationSeconds = 180, TrainingMultiplier = 2,
				Banner = "TRAINING FRENZY! 2x training reps for %s", Color = Color3.fromRGB(80, 200, 255) },
			{ Id = "GoldenBallStorm", Name = "GOLDEN BALL STORM", Weight = 20, DurationSeconds = 90, GoldenBallSeconds = 10,
				Banner = "GOLDEN BALL STORM! A Golden Ball every 10 s for %s", Color = Color3.fromRGB(255, 200, 40) },
			-- Bills fall around every player on a court (PickupConfig.Rain sets how many and their value).
			{ Id = "CashRain", Name = "CASH RAIN", Weight = 20, DurationSeconds = 60, CashRain = true,
				Banner = "CASH RAIN! Grab the falling bills for %s", Color = Color3.fromRGB(80, 200, 95) },
		},
		-- Studio only (ignored on live servers), for testing. Keep them off.
		-- An event Id to start 10 s after the first player is ready ("" = off).
		StudioForceNext = "",
		-- Seconds between events in Studio instead of MinSeconds-MaxSeconds (0 = off).
		StudioIntervalSeconds = 0,
	},
}

local DAY = 86400
local WEEK = 7 * DAY

-- Scheduled events (the Events list) running at `unixTime`. `studio` lets Studio force one.
function EventConfig.Scheduled(unixTime: number, studio: boolean?): { any }
	local list = {}
	if studio and EventConfig.StudioForceEvent > 0 then
		local forced = EventConfig.Events[EventConfig.StudioForceEvent]
		if forced then table.insert(list, forced) end
		return list
	end
	for _, event in EventConfig.Events do
		if unixTime >= event.Starts and unixTime < event.Ends then table.insert(list, event) end
	end
	return list
end

-- The first event running at `unixTime` (nil if none): a scheduled one, else Dunk Night, else
-- the server event `published` (see ActiveEvents below).
function EventConfig.Active(unixTime: number, studio: boolean?, published)
	return EventConfig.ActiveEvents(unixTime, studio, published)[1]
end

-- Start time (Unix seconds) of the Dunk Night running at `unixTime`, or else the next one.
-- Pure UTC arithmetic, so daylight saving never moves it. 1 Jan 1970 was a Thursday (4).
function EventConfig.DunkNightStart(unixTime: number): number
	local night = EventConfig.DunkNight
	local day = math.floor(unixTime / DAY)
	local weekday = (day + 4) % 7
	local daysUntil = (night.Weekday - weekday) % 7
	local start = (day + daysUntil) * DAY + night.StartHourUtc * 3600 + night.StartMinuteUtc * 60
	local length = night.DurationMinutes * 60
	-- Still inside last week's night (one that runs past midnight)?
	if unixTime < start - WEEK + length then return start - WEEK end
	-- This week's night is already over: next week.
	if unixTime >= start + length then return start + WEEK end
	return start
end

-- The Dunk Night running at `unixTime` as an event ({ Name, Starts, Ends, multipliers, ... }),
-- or nil. In Studio, StudioForceDunkNight makes every moment part of a night.
function EventConfig.DunkNightAt(unixTime: number, studio: boolean?)
	local night = EventConfig.DunkNight
	local length = night.DurationMinutes * 60
	local starts = EventConfig.DunkNightStart(unixTime)
	if studio and EventConfig.StudioForceDunkNight then
		starts = math.floor(unixTime / length) * length
	end
	if unixTime < starts or unixTime >= starts + length then return nil end
	return { Name = night.Name, Starts = starts, Ends = starts + length, CashMultiplier = night.CashMultiplier,
		TrainingMultiplier = night.TrainingMultiplier, GoldenBallSeconds = night.GoldenBallSeconds,
		Color = night.Color, DunkNight = true }
end

function EventConfig.GetServerEvent(eventId)
	if type(eventId) ~= "string" then return nil end
	for _, event in EventConfig.ServerEvents.List do
		if event.Id == eventId then return event end
	end
	return nil
end

-- The random server event that ServerEventService published on `holder` (Workspace
-- attributes ServerEvent / ServerEventEnds) as { Id, Ends }, or nil when there is none.
function EventConfig.ReadServerEvent(holder: Instance)
	local eventId, ends = holder:GetAttribute("ServerEvent"), holder:GetAttribute("ServerEventEnds")
	if not EventConfig.GetServerEvent(eventId) or type(ends) ~= "number" then return nil end
	return { Id = eventId, Ends = ends }
end

-- The server event running at `unixTime` as an event ({ Id, Name, Ends, ... }), or nil.
-- `published` is what ReadServerEvent returned.
function EventConfig.ServerEventAt(unixTime: number, published)
	local event = published and EventConfig.GetServerEvent(published.Id)
	if not event or unixTime >= published.Ends then return nil end
	return { Id = event.Id, Name = event.Name, Ends = published.Ends, CashMultiplier = event.CashMultiplier,
		TrainingMultiplier = event.TrainingMultiplier, GoldenBallSeconds = event.GoldenBallSeconds,
		CashRain = event.CashRain, Color = event.Color, Server = true }
end

-- Every event running at `unixTime`: scheduled ones, Dunk Night, then the server event.
function EventConfig.ActiveEvents(unixTime: number, studio: boolean?, published): { any }
	local list = EventConfig.Scheduled(unixTime, studio)
	local night = EventConfig.DunkNightAt(unixTime, studio)
	if night then table.insert(list, night) end
	local serverEvent = EventConfig.ServerEventAt(unixTime, published)
	if serverEvent then table.insert(list, serverEvent) end
	return list
end

local function combined(unixTime: number, studio: boolean?, published, field: string): number
	local total = 1
	for _, event in EventConfig.ActiveEvents(unixTime, studio, published) do
		total *= event[field] or 1
	end
	return math.min(total, EventConfig.MaxEventMultiplier)
end

-- Dunk and air-trick Cash multiplier from every running event (1 when none).
function EventConfig.CashMultiplier(unixTime: number, studio: boolean?, published): number
	return combined(unixTime, studio, published, "CashMultiplier")
end

-- Training rep multiplier from every running event (1 when none).
function EventConfig.TrainingMultiplier(unixTime: number, studio: boolean?, published): number
	return combined(unixTime, studio, published, "TrainingMultiplier")
end

-- Seconds between Golden Balls while an event speeds them up (the shortest wins), or nil.
function EventConfig.GoldenBallSeconds(unixTime: number, studio: boolean?, published): number?
	local shortest = nil
	for _, event in EventConfig.ActiveEvents(unixTime, studio, published) do
		if event.GoldenBallSeconds and (not shortest or event.GoldenBallSeconds < shortest) then
			shortest = event.GoldenBallSeconds
		end
	end
	return shortest
end

return EventConfig
