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
