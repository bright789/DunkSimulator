-- Timed server-wide events. While one is running, dunk and air-trick Cash is multiplied by
-- its CashMultiplier (stacks with boosts and passes) and the HUD shows a countdown pill.
-- Times are Unix seconds (UTC). Add a new entry to schedule another event; past ones can
-- stay in the list. The server applies the bonus; clients only display it.
local EventConfig = {
	Events = {
		-- Launch weekend: Friday 2 Oct 2026 00:00 UTC to Monday 5 Oct 2026 00:00 UTC.
		{ Name = "2X CASH WEEKEND", Starts = 1790899200, Ends = 1791158400, CashMultiplier = 2 },
	},
	-- Studio only: pretend this event index is running now (0 = off). Ignored on live servers.
	StudioForceEvent = 0,
}

-- The event running at `unixTime` (nil if none). `studio` lets Studio force one for testing.
function EventConfig.Active(unixTime: number, studio: boolean?)
	if studio and EventConfig.StudioForceEvent > 0 then
		return EventConfig.Events[EventConfig.StudioForceEvent]
	end
	for _, event in EventConfig.Events do
		if unixTime >= event.Starts and unixTime < event.Ends then return event end
	end
	return nil
end

function EventConfig.CashMultiplier(unixTime: number, studio: boolean?): number
	local event = EventConfig.Active(unixTime, studio)
	return event and event.CashMultiplier or 1
end

return EventConfig
