# Launch Kit: Codes + 2X CASH WEEKEND

Two tools for the first sponsored-ad push: **redeem codes** (something to post in the group, video descriptions and updates) and a **timed server-wide Cash event** (a reason to play *this weekend*). Two new ad thumbnails go with them.

## For players

**CODES button** (gold, full width, under the HUD buttons) opens a small panel:
- type a code, press **REDEEM** (or Enter),
- the answer shows under the box: green for success ("RELEASE REDEEMED! +$16,460 and 2x Cash for 15 min"), orange for problems.
- Codes are not case sensitive and spaces are ignored (`release`, `Release` and `RE LEASE` all work).
- Each code pays once per player, forever, across every server.

**Event pill:** while an event is running, a pill in the HUD column shows its name and a countdown, e.g. `2X CASH WEEKEND  2d 14h`. All dunk and air-trick Cash is multiplied while it runs, stacking with boosts, passes, friend and group bonuses.

## Launch codes (`src/server/Config/CodesConfig.luau`)

| Code | Reward | Notes |
| --- | --- | --- |
| `RELEASE` | Cash worth 20 dunks + 15 min 2x Cash Boost | Launch code for ads and the group. |
| `DUNKSIM` | Cash worth 10 dunks | Evergreen code for video descriptions. |
| `GROUPDUNK` | Cash worth 30 dunks + 15 min 2x Cash Boost | Only for members of Dunk Simulator Official (292818851). |

"Cash worth N dunks" is `N × DailyConfig.DunkValue(Vertical)`, the same scale as daily rewards, so the reward stays useful at every stage instead of being huge early or tiny late.

### Adding or retiring a code

Codes live in a **server-only** module, so exploiters can't read the list from the client. Add a line to `Codes`, then publish:

```lua
HALLOWEEN = { Dunks = 25, BoostMinutes = 10, Expires = 1793491200 },
```

- The key is the code (upper case, no spaces).
- `Dunks`: Cash worth this many dunks (optional).
- `BoostMinutes`: minutes of 2x Cash Boost (optional; stacks onto an active boost).
- `GroupOnly = true`: only group members can redeem it.
- `Expires`: Unix time (UTC) after which it says "That code has expired." Leave it out for a code that never expires. Get a timestamp from https://www.epochconverter.com.

To retire a code, give it an `Expires` in the past (players get a clear "expired" message) or delete the line ("doesn't exist"). Never reuse an old code name for a new reward: players who redeemed the old one can't redeem it again.

### How it works (`CodesService`, server only)

1. The client fires `CodeRequest("Redeem", text)`. The server rejects anything that isn't a string of 1–30 characters, and rate-limits each player (one request every 2 seconds, one at a time, only after their data has loaded).
2. The text is upper-cased and stripped of spaces, then looked up. Missing, expired and group-only-for-non-members are rejected with a message.
3. The code is **claimed first** with `UpdateAsync` in `DunkSimulator_Codes_v1` (Studio: `DunkSimulator_Codes_DEV_v1`; key = UserId, value = list of redeemed codes). If it's already in the list the player gets "You already used that code."
4. Then Cash (`GrantCash`, logged as `Code_<CODE>` in analytics) and the boost are paid. If paying fails, the claim is removed again so the player can retry. A save is requested and a `CodeRedeemed_<CODE>` custom analytics event is logged.

The codes store is separate from player data, so no schema change.

## Timed events (`src/shared/Config/EventConfig.luau`)

```lua
{ Name = "2X CASH WEEKEND", Starts = 1790899200, Ends = 1791158400, CashMultiplier = 2 },
```

**The launch weekend is scheduled:** Friday 2 Oct 2026 00:00 UTC → Monday 5 Oct 2026 00:00 UTC. That is **Thursday 1 Oct 7 PM → Sunday 4 Oct 7 PM** US Central (CDT). It turns on and off by itself; no republish needed.

- `PlayerService` multiplies dunk and trick Cash by `EventConfig.CashMultiplier(os.time())`. The server is the only one that pays; the client only reads the same config to draw the countdown pill (using `Workspace:GetServerTimeNow()` so a wrong phone clock doesn't matter).
- To schedule another event, add an entry with a new `Name`, `Starts`, `Ends` (Unix seconds, UTC) and `CashMultiplier`. Old entries can stay. If two overlap, the first one in the list wins.
- Keep event names short (about 16 characters) so the pill fits on phones.
- **Studio testing:** set `StudioForceEvent = 1` to pretend event #1 is running now. It's ignored on live servers, but **set it back to `0`** before publishing anyway.

## Thumbnails (`assets/thumbnails/`)

| File | Hook |
| --- | --- |
| `thumbnail-4-weekend.jpg` | "2X CASH WEEKEND!" + "LIMITED TIME" over the College Windmill dunk, gold burst behind the title. For ads and the store page **during** the event. |
| `thumbnail-5-rooftop.jpg` | "NEW COURT! SKYLINE ROOFTOP" + "DUNK ABOVE THE CITY", night shot of Court #4 with a glowing Power Dunk cutout. |

Suggested use:
- **Ad campaign (Fri–Sun):** run the weekend thumbnail as the ad creative; add the rooftop one as a second creative if Ads Manager lets you, and keep the one with the better click-through.
- **Store page:** put `thumbnail-4-weekend.jpg` first on Thursday evening, and move it off (or delete it) after the event ends on Sunday night, so the page never advertises an event that's over. `thumbnail-5-rooftop.jpg` can stay as a permanent #2 or #3.

Both are real in-engine footage (Rooftop captured with a Scriptable camera at night, f.lux off), composited with the same `thumbs.ps1` pipeline as the first three.

## Tested in Studio (QA stores)

- `RELEASE` → **+$16,460** and a 15-min boost (20 dunks × $823 at that Vertical).
- `RELEASE` again → "You already used that code."
- `NOTACODE` → "That code doesn't exist."
- `groupdunk` (lower case, as a group member) → **+$24,690** (30 × $823).
- With `StudioForceEvent = 1`, a dunk paid **$8,408** = $1,911 base × 1.1 group × 2 boost × 2 event.
- Afterwards: `StudioForceEvent = 0` and `StudioStoreName = "DunkSimulator_PlayerData_DEV_v1"`, confirmed in Studio.
