# Engagement: always something happening

Inspired by fast "no dead time" Roblox games. The game should never leave you standing still with nothing new on screen. Five systems were added on 2026-09-27, in this order.

## 1. Active training (rhythm reps)

Training at the Leg Day Gym is still "hold E", but every rep is now a **beat** (every 0.5 s).

- A ring closes on the **PUMP** button each beat. Press on the beat for a bigger rep:
  - **PC:** left-click anywhere.
  - **Phone:** tap PUMP.
  - **Gamepad:** RB.

| Press | Rep |
| --- | --- |
| within ±0.07 s of the beat | **PERFECT: x3** Vertical |
| within ±0.14 s | **GOOD: x1.5** |
| no press / off-beat / mashing (2+ presses in one beat) | normal x1 rep |

- **Combo:** consecutive PERFECT/GOOD beats build a combo, shown with a rising ding.
- **Popups:** every paid rep pops a "+0.3" above the ring.
- **How the server judges:** like the slam meter. The `TrainingPulse` remote carries no data, and the server stamps each press with its own clock minus the player's latency (capped at 0.25 s). Each beat is paid once no late press for it can still arrive (GoodSeconds + 0.25 s + 0.02 s after the beat), so reps land ~0.4 s after their beat.
- **Anti-cheat:** only one press per beat counts, and presses closer than 0.2 s are ignored.
- **Auto Train** reps stay normal (x1).
- **Numbers:** `ProgressionConfig.Training.Rhythm`. **Code:** `TrainingService`, `TrainingRhythmController`, `ui/TrainingRhythmView`.

## 2. Dunk streak ("HEAT")

Each dunk that lands within **15 s** of your last one raises HEAT (max 5). Dunk Cash is multiplied by:

| HEAT | 1 | 2 | 3 | 4 | 5 |
| --- | --- | --- | --- | --- | --- |
| Name | WARMING UP | HEATING UP | HOT | BLAZING | ON FIRE! |
| Cash | x1.0 | x1.1 | x1.2 | x1.3 | x1.4 |

- **Display:** a HEAT pill with a draining timer shows under the goal bar. Reaching 5 announces "ON FIRE!" and sets your court's rim on fire (on your screen).
- **Reset:** stop for 15 s and it resets.
- **Stacking:** HEAT stacks with every other bonus. `DunkService` multiplies it with Fireball into `RegisterDunk`'s bonus multiplier (capped at x3).
- **Numbers:** `HeatConfig`. **Code:** `HeatService` (attributes `Heat`, `HeatUntil`).

## 3. Things to grab

**Cash bills.** Every completed dunk spills **3 bills**, each worth **5%** of that dunk's Cash (+15% if you grab them all).
- They burst out of the rim, land 6–14 studs out on the court side, and fly to you inside 10 studs. Otherwise they vanish after 15 s.
- **Server checks:** the server keeps each drop (id, spot, value, expiry) and only pays a `PickupEvent("Collect", id)` if the drop exists, hasn't expired and your character is within 16 studs of it.

**Golden Ball.** About every **75 s (±15)**, a glowing Golden Ball appears on each court that has players.
- Everyone there gets "GOLDEN BALL ON THE COURT!" and a gold beam pointing to it.
- The first player within 5 studs wins **8 dunks' worth of Cash** at their Vertical, and everyone on the court is told who grabbed it.
- It disappears after 30 s.
- It's a real server part in `Workspace.GoldenBalls`, and the server checks the distance.

**Numbers:** `PickupConfig`. **Code:** `PickupService`, `PickupController`.

## 4. Always-on NEXT goal bar + action feed

**Goal bar** (top centre, under the contest banner). Always shows the next target, in this order:
1. The next dunk style you can reach on this court: "NEXT DUNK: TOMAHAWK 62 / 75 VERT".
2. "MAXED HERE! TRAIN AT HIGH SCHOOL GYM", when you're capped and own a higher court.
3. The next court to unlock: its Vertical, then its Cash ("UNLOCK HIGH SCHOOL GYM $1,222 / $4,000").
4. The next Rebirth.

It hides during a dunk and while the new-player tutorial panel is up (the tutorial shows its own goal). The server now publishes `UnlockedCourts` (display only) for it. **Code:** `StatusBarController`, `ui/StatusBarView`.

**Action feed** (bottom centre, above the meter):
- A stacking log of what just happened, e.g. "+2 VERTICAL", "+$1,240", "HEAT 3! HOT x1.2 CASH", "+$12 CASH BILLS (x3)", "-$800".
- Lines merge while on screen.
- Big one-offs ("ON FIRE!", "GOLDEN BALL! +$400", "SLOW-MO SLAM UNLOCKED!") pop in the middle of the screen.
- Ability messages now use the feed too (the abilities toast was removed).

**Code:** `ActionFeed`. The trick popup moved from 0.16 to 0.2 of the screen height to clear the status stack.

## 5. Cheaper early steps

| | Before | Now |
| --- | --- | --- |
| Training Level 2 / 3 / 4 / 5 / 6 | $250 / $600 / $1,200 / $2,000 / $3,500 | **$120 / $350 / $800 / $1,500 / $3,000** |
| High School Gym unlock | 75 Vertical + $6,000 | 75 Vertical + **$4,000** |

**2026-10-03:** Training Level 2 is now **$60** and Level 1 trains at +0.15 per rep; new players start at 35 Vertical and dunk before they train. Playtime gifts and a goal card were added for the first minutes. See `TUTORIAL_BADGES_ANALYTICS.md` and `GIFTS_AND_GOALS.md`.

Together with rhythm reps (up to x3 training), HEAT, bills and Golden Balls, a new player has something to buy or unlock about every minute in the first ten.

The **High School route board** at the Neighborhood bus stop is builder-made scenery. Its two labels were edited in the place to read "$4000", so save the place. `tools/highschool` reads the price from CourtConfig, so a rebuild matches too.

## Tested in Studio (fresh QA profiles, 2026-09-27)

| Test | Result |
| --- | --- |
| Rhythm judging | 4 presses on the beat gave PERFECT **0.30** each (vs 0.10). 4 presses 0.1 s late gave GOOD **0.15**. No press and mashing both gave normal 0.10, and the combo reset. |
| Real clicks | 5 real mouse clicks at random timing while training: 17 reps, 1 PERFECT + 1 GOOD. The PUMP ring, caption, combo and "+0.15" popups all showed. |
| HEAT | 5 dunks in a row paid $64 / $70 / $77 / $83 / $89 (x1.0 → x1.4). The pill read "HEAT 5 ON FIRE! x1.4 CASH" and the rim burned. |
| Bills | 3 per dunk at 5% ($3 each at ~$60 dunks), collected by walking near. Far ones stayed on the floor to grab. Feed: "+$12 CASH BILLS (x3)". |
| Golden Ball | Spawned; walking into it paid **$400** (8 × dunk value at 73 Vertical), removed the ball and sent the grab message. |
| Goal bar | "NEXT DUNK: TWO-HAND POWER", then at the 75 cap "UNLOCK HIGH SCHOOL GYM $1,222 / $4,000". Hidden under the tutorial. |
| Tutorial | Step 4 now asks for the $120 Level 2 upgrade. |

**Not tested yet:**
- What other players see (the Golden Ball race, "X grabbed the Golden Ball").
- Phone layout of the ring, status stack and feed.

## 6. Pack A (2026-10-03): Dunk Night, server events, AFK Practice, notifications

Research on 2025-26 Roblox hits (Steal An Egg, Grow a Garden, Steal a Brainrot, Volleyball Legends, Basketball: Zero, Blue Lock: Rivals) showed the ones that last all have a fixed weekly "admin abuse" event, random server events, an AFK area that pays every few minutes, and notifications. Dunk's new players averaged 1.4 minutes and almost none came back the next day.

### Dunk Night (weekly)

**Every Saturday 19:00-19:45 UTC.** `EventConfig.DunkNight` holds the day (0 = Sunday ... 6 = Saturday), start hour/minute and length; the start is worked out with plain UTC arithmetic, so daylight saving never moves it.

| While it runs | Normal |
| --- | --- |
| Dunk and air-trick Cash **x2** | x1 |
| Training reps **x2** (station, rhythm and Auto Train; `PlayerService.AwardTraining`) | x1 |
| A Golden Ball about every **15 s** on each court with players | ~75 s |
| A random server event about every **5 minutes** (270-330 s) | 15-20 minutes |

- **HUD:** the event pill shows `DUNK NIGHT  32:10` while it runs, and `DUNK NIGHT IN 3:42:10` during the 24 hours before it. The pill now has one line per running event and grows taller.
- **Start:** a big centre banner "DUNK NIGHT! 2x CASH  2x TRAINING", a feed line with the details and the Rebirth fanfare. Players who join during it see the same.
- **End:** a banner "Dunk Night is over — see you next Saturday!".
- **Stacking (decision):** all event multipliers **multiply**, capped at **x4** in total from events (`EventConfig.MaxEventMultiplier`). So Dunk Night + OVERTIME = x4 Cash, and the launch 2X CASH WEEKEND overlapping both is still x4. Passes, boosts, court, Rebirth, HEAT and crew still stack on top as before.
- Hype Crew pack luck is **not** boosted (that would need live odds changes on the PACKS page).
- **Studio flag:** `EventConfig.StudioForceDunkNight` (default **false**) makes it Dunk Night all the time in Studio.

### Random server events

`ServerEventService` + `EventConfig.ServerEvents`. While at least one player is in a court, one event starts for the whole server **15-20 minutes** (random) after the previous one ended (the first one 15-20 minutes after someone joins). Never two at once, and not while a Dunk Contest round has 20 s or less left (it waits until the round is over). The tutorial isn't blocked: banners are plain text in the middle of the screen.

| Event | Weight | Length | Effect |
| --- | --- | --- | --- |
| **OVERTIME** | 30 | 3:00 | Dunk and air-trick Cash x2 |
| **TRAINING FRENZY** | 30 | 3:00 | Training reps x2 |
| **GOLDEN BALL STORM** | 20 | 1:30 | A Golden Ball about every 10 s on each court with players |
| **CASH RAIN** | 20 | 1:00 | Every player on a court gets 2 bills a second falling around them (4-16 studs away), each worth 0.25 of a plain dunk at their Vertical (`PickupConfig.Rain`). They are ordinary Cash bills: same server checks, they fly to you within 10 studs and vanish after 15 s. |

- The running event is published as Workspace attributes `ServerEvent` (its Id, `""` when none) and `ServerEventEnds` (Unix seconds). `PlayerService` (Cash, training) and `PickupService` (Golden Ball timer) read them through `EventConfig`, the same way as the scheduled events, so multipliers stack with passes and boosts exactly like those.
- **Clients:** a banner such as "OVERTIME! 2x Cash for 3:00", a line in the event pill (`OVERTIME  2:41`), and a feed line and sound when it starts ("OVERTIME STARTED!") and ends ("OVERTIME IS OVER").
- **Analytics:** custom event `ServerEvent_Overtime` / `_TrainingFrenzy` / `_GoldenBallStorm` / `_CashRain` for each player in a court when it starts. Cash Rain Cash shows as `PickupBills`.
- **Studio flags** (default off): `ServerEvents.StudioForceNext` (an event Id to start 10 s after the first player is ready) and `ServerEvents.StudioIntervalSeconds` (seconds between events instead of 15-20 minutes).

### AFK Practice Court

`AfkService` + `AfkConfig`. When the server starts it puts **one glowing pad per court** near the court's spawn: a cyan disc and ring with a light and the label "AFK PRACTICE / earn while you chill".

- **Placement:** starting at the court's SpawnLocation it tries spots in front of the spawn (toward the court) and to its sides, never behind it (that's the entrance), at 14, 18, 22, 26 and 30 studs. A spot is used when the floor there is flat (raycasts at the centre and around the edge), within 3 studs of the spawn's height, nothing solid is in a 7-stud-tall box above it, and it is far enough from the rim (30 studs), the Leg Day trainer, Hoop Shop and Upgrade station (14), their props (Hoop Shop, gym, Upgrade Lab: 10), bus stops, return gates and the elevator (12), court portals (14), leaderboard stands (8) and spawns (8). Output prints where each pad went, e.g. "Neighborhood AFK pad at (12.1, 0.2, -40.5), 22 studs from the spawn". If a court has no good spot it warns; then set `AfkConfig.Offsets.<Court>` (studs from the spawn: X to its right, Z forward) to place it by hand.
- **Earning:** every second the server checks who is standing on the pad of the court they're on (HumanoidRootPart within 5 studs, not riding the bus). That second counts toward two timers:
  - every **3 minutes** on the pad: Cash worth **4 dunks** (`AfkDunks`) at your Vertical (`DailyConfig.DunkValue`);
  - every **15 minutes** on the pad: a **free prize**: 5 minutes of 2x Cash Boost (40%), 10 dunks of Cash (40%) or 50 Dunk Pass XP (20%; the Cash prize instead when no season is running). It's free, so it isn't a paid random item.
  - **VIP** doubles all AFK Cash.
  - Leaving the pad **pauses** both timers for the session (they don't reset); rejoining starts them over.
- **Client:** while you're on a pad a strip reads "AFK PRACTICE  •  next reward 1:42  •  prize in 12:10" (above the action feed; lower middle on phones). Payouts show as "AFK PRACTICE  +$420" in the feed and prizes as a big "AFK PRIZE!" message.
- AFK time counts toward the playtime gifts by itself (they use the session clock).
- **Analytics:** custom events `AfkReward` and `AfkPrize`; Cash sources `AfkReward` / `AfkPrize` (TimedReward).
- **Note:** Roblox disconnects players who give no input for about **20 minutes**, so "AFK" players still need to touch a key now and then.
- **Studio flag:** `AfkConfig.StudioFastAfk` (default **false**): rewards every 10 s and prizes every 30 s in Studio.

| Remote | Direction | Payload |
| --- | --- | --- |
| `AfkPractice` | server -> client | `("Reward", cash)` and `("Prize", kind, amount, text)` with kind `"Boost"`, `"Cash"` or `"PassXp"`. Clients send nothing. The timers are the player attributes `AfkOnPad`, `AfkRewardIn` and `AfkPrizeIn` (seconds of pad time left). |

### Notifications

A daily Roblox notification to last week's players, and a once-per-session opt-in prompt at a good moment. See `NOTIFICATIONS.md`.

### Pack A Studio checklist

1. **Dunk Night:** set `StudioForceDunkNight = true`, Play: banner and fanfare, pill `DUNK NIGHT  mm:ss`, a dunk pays twice its usual Cash, a rep adds twice its usual Vertical, Golden Balls every ~15 s. Set it back.
2. **Countdown:** on a Friday/Saturday before 19:00 UTC the pill reads `DUNK NIGHT IN h:mm:ss`.
3. **Server events:** set `StudioForceNext = "CashRain"` (then the other three): 10 s after spawning the banner shows, bills fall around you and pay when collected, the pill shows the event's line and it ends with "CASH RAIN IS OVER". `StudioIntervalSeconds = 30` shows several in a row. Set both back.
4. **AFK:** check Output for each court's pad position, then look at each pad in Play: it must not block a doorway, the rim, the Hoop Shop, gym, Upgrade station, bus stop/portal or the leaderboard. With `StudioFastAfk = true`: stand on it, the strip counts down, +4 dunks every 10 s, a prize every 30 s; step off and the timers pause. Set it back.
5. **Hype Crew:** with Lucky Packs owned (the creator owns every pass) the PACKS page shows **LUCKY ODDS** with the boosted numbers.

## Pack A Studio test (2026-10-03)

Run on the QA profile at the Rooftop (350 Vertical). The test flags were reverted afterwards.

- **Dunk Night (forced on):**
  - The event pill showed `2X CASH WEEKEND / DUNK NIGHT 41:11 / TRAINING FRENZY 2:58`.
  - Golden Balls kept spawning.
- **Random events (25 s Studio interval):**
  - TRAINING FRENZY started with its banner ("2x training reps for 2:59"), a feed line and `ServerEvent_TrainingFrenzy`.
  - OVERTIME started exactly 25 s after Training Frenzy ended, with no overlap.
  - Forced CASH RAIN: bills fell around the player, the feed read "+$2,873 CASH BILLS (x13)" and the pill showed `CASH RAIN 0:31`.
- **AFK pads:**
  - Placed on all 4 courts, 14 to 18 studs from each spawn and clear of the court.
  - Standing on the Rooftop pad showed "AFK PRACTICE • next reward 0:06 • prize in 0:16".
  - Fast mode paid +$7,056 every cycle (4 dunks x $882 x 2 VIP) and a prize of +$17,640 (10 dunks x 2 VIP).
- **Hype Crew:** "LUCKY ODDS" showed the boosted chances (Campus 27.6 / 29.9 / 34.6 / 7.9%), and packs stayed openable for a player who isn't restricted.
