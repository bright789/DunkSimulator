-- Experience notifications (see docs/NOTIFICATIONS.md).
--   Client (NotificationController): asks the player once per session to turn notifications on,
--     at a good moment (after the tutorial, after the first gift claim, or when Dunk Night starts).
--   Server (NotificationService): records who played each UTC day, and once a day exactly one
--     server sends one notification to recent players who aren't in this server, through
--     Roblox's Open Cloud package (ServerScriptService.OpenCloud, inserted by the owner).
-- Roblox only delivers to opted-in players aged 13+, at most one per player per day.
local Events = require(script.Parent.EventConfig)

local NotificationConfig = {
	-- Notification string ids from the Creator Hub (Engagement > Notifications). "" = that
	-- notification is off.
	Templates = {
		-- "Your free daily reward and gifts are ready. Come throw down some dunks!"
		Daily = "665e0a10-7d5c-8f4f-93d4-3b4f1710918f",
		-- "DUNK NIGHT starts soon: 2x Cash, 2x training and Golden Ball rain! Jump in!"
		DunkNight = "39821594-1689-5d49-bdc7-b0855bf43395",
	},
	-- The daily send: this UTC hour, or later (up to CatchUpHours) if no server was running then.
	SendHourUtc = 21,
	CatchUpHours = 6,
	-- On the Dunk Night day the send moves to this many minutes before Dunk Night starts, so it
	-- can use the DunkNight message (0 = always send at SendHourUtc).
	DunkNightLeadMinutes = 90,
	-- The DunkNight message is used when Dunk Night starts within this many hours of the send.
	DunkNightMessageHours = 2,
	-- Who gets it: players seen in the last RecentDays UTC days, at most MaxPerRun per day,
	-- SendGapSeconds apart.
	RecentDays = 7,
	MaxPerRun = 2000,
	SendGapSeconds = 0.1,
	-- Stop the run after this many script errors in a row from the package (it isn't set up
	-- right). Refusals from Roblox (e.g. a player who didn't opt in) don't stop it.
	MaxErrorsInARow = 10,
	-- Recent-players registry: each server batches joins and writes them this often, into
	-- Shards keys per day ("Recent_<yyyymmdd>_<shard>"), at most MaxPerDay players per day.
	RegistryFlushSeconds = 60,
	Shards = 4,
	MaxPerDay = 5000,
	-- How often each server checks whether the daily send is due.
	CheckSeconds = 60,
	-- How long one server holds the "I'm sending today" claim (MemoryStore).
	ClaimSeconds = 1800,

	-- Opt-in prompt (client). Never in the first MinSessionSeconds of a session or over another
	-- pop-up; at most once per session. After a trigger, waits up to WaitSeconds for a clear moment.
	OptIn = {
		MinSessionSeconds = 120,
		WaitSeconds = 180,
		NudgeText = "Turn on notifications to hear when Dunk Night starts!",
	},

	-- Studio never sends: it only prints what would be sent. Studio-only test flag (ignored on
	-- live servers): run that dry run about 15 s after the server starts, whatever the time. Keep false.
	StudioRunNow = false,
}

local DAY = 86400

-- "20261003" for the UTC day containing `unixTime`.
function NotificationConfig.DayKey(unixTime: number): string
	local date = os.date("!*t", math.floor(unixTime))
	return string.format("%04d%02d%02d", date.year, date.month, date.day)
end

-- When the daily notification goes out on the UTC day starting at `dayStart` (00:00 UTC).
function NotificationConfig.SendTime(dayStart: number): number
	local nightStart = Events.DunkNightStart(dayStart)
	if NotificationConfig.DunkNightLeadMinutes > 0 and nightStart >= dayStart and nightStart < dayStart + DAY then
		return math.max(dayStart, nightStart - NotificationConfig.DunkNightLeadMinutes * 60)
	end
	return dayStart + NotificationConfig.SendHourUtc * 3600
end

-- The send that is due at `now`: its day key and send time, or nil when none is due (before
-- the send time, or more than CatchUpHours after it). Yesterday's late catch-up counts too.
function NotificationConfig.DueSend(now: number): (string?, number?)
	local today = math.floor(now / DAY) * DAY
	for _, dayStart in { today, today - DAY } do
		local sendAt = NotificationConfig.SendTime(dayStart)
		if now >= sendAt and now < sendAt + NotificationConfig.CatchUpHours * 3600 then
			return NotificationConfig.DayKey(dayStart), sendAt
		end
	end
	return nil, nil
end

-- Which message to send at `now`: "DunkNight" when Dunk Night starts within
-- DunkNightMessageHours, otherwise "Daily".
function NotificationConfig.MessageFor(now: number): string
	local untilNight = Events.DunkNightStart(now) - now
	if untilNight > 0 and untilNight <= NotificationConfig.DunkNightMessageHours * 3600 then return "DunkNight" end
	return "Daily"
end

return NotificationConfig
