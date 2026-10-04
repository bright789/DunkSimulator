# Early-Game Progression Rebalance v0.1

This is a **prototype balance change**, not a new progression system. No training cadence, jump curve, dunk assist/execution, court bonus, map geometry, purchase security or challenge claim behavior changes. All requirements/rewards below come from shared config. Balance targets require real playtesting.

**Current-state update:** Court Training Caps were added after this rebalance. Neighborhood training now stops at 75, High School at 150, and the High School gate was subsequently lowered from 80 to **75 Vertical**, retaining the $6,000 cost. For the current fresh-player run, use `PROGRESSION_PLAYTEST.md` rather than the historical steps below.

## Training

Each valid server-timed tick generates the authoritative TrainingLevel's `VerticalPerRep` (0.1 per level, 0.15 at Level 1; see `TRAINING_UPGRADES.md`) × the validated current court's TrainingMultiplier. The existing millionth-unit `VerticalTrainingRemainder` carries fractional progress and persists; only whole points increase Vertical, trigger unlocks or appear in HUD gain feedback. Training grants no Cash. Neighborhood remains 1.00x, High School remains 1.15x. Tick interval remains 0.5 seconds.

| Level | Old Vertical/tick | New efficiency | Old cost | New cost |
| ---: | ---: | ---: | ---: | ---: |
| 1 | +1 | 1.00x | Starting | Starting |
| 2 | +2 | 1.10x | $100 | $250 |
| 3 | +3 | 1.20x | $300 | $600 |
| 4 | +4 | 1.30x | $750 | $1,200 |
| 5 | +5 | 1.40x | $1,500 | $2,000 |
| 6 | +6 | 1.50x | $3,000 | $3,500 |
| 7 | +7 | 1.60x | $6,000 | $5,500 |
| 8 | +8 | 1.70x | $12,000 | $8,000 |
| 9 | +9 | 1.80x | $25,000 | $12,000 |
| 10 | +10 | 2.00x | $50,000 | $18,000 |

Level 5 at High School generates `1.00 × 1.40 × 1.15 = 1.61` progress per tick, not a fixed 1.61 visible Vertical. Existing saved TrainingLevel integers are unchanged; their new efficiency is read from config at runtime.

## Unlocks, Cash, and Court

| Style | Old Vertical | New Vertical | Old base reward | New base reward |
| --- | ---: | ---: | ---: | ---: |
| Basic One-Hand | 35 | 35 | $25 | $20 |
| Two-Hand Power | 45 | 50 | $40 | $35 |
| Tomahawk | 55 | 75 | $65 | $60 |
| Windmill | 70 | 110 | $100 | $100 |

Neighborhood pays these base rewards. High School still rounds `base reward × 1.25` to the nearest whole Cash: **$25 / $44 / $75 / $125**. Rewards remain server-authoritative and arrive only after completed dunks. This rebalance originally changed High School's one-time gate from **60 Vertical + $2,500** to **80 Vertical + $6,000**; the later Court Training Caps milestone lowered its Vertical requirement to **75**. Vertical is not deducted and an already purchased unlock stays permanent. Its 1.15x training bonus and 1.25x Cash bonus do not change.

## One-Time Challenges

| Challenge | Old target / reward | New target / reward |
| --- | --- | --- |
| Getting Started | 5 Basic dunks / $150 | 10 Basic dunks / $150 |
| Power Finisher | 5 Two-Hand dunks / $300 | 15 Two-Hand dunks / $350 |
| Tomahawk Specialist | 3 Tomahawks / $350 | 15 Tomahawks / $600 |
| Windmill Specialist | 3 Windmills / $500 | 20 Windmills / $1,000 |
| Rising Athlete | 50 Vertical / $300 | 60 Vertical / $300 |
| Above the Rim | 75 Vertical / $750 | 120 Vertical / $800 |
| High School Highlights | 10 High School dunks / $1,000 | 25 High School dunks / $1,500 |

The new total claimable Cash is **$4,700**, earned through longer objectives. Claims still require an explicit server-validated action.

## Existing Profiles

No schema bump or DataStore rename is needed: saved fields and challenge record shape are unchanged. Stable challenge IDs, including historical names such as `vertical_50`, `vertical_75` and `highschool_dunks_10`, are intentionally retained as persistence keys despite the new displayed targets. A previously **claimed** challenge remains claimed, normalizes to the new displayed target on load, and never pays twice. An old ready-but-unclaimed dunk count becomes partial progress (for example Tomahawk 3/3 becomes 3/15); saved Vertical is reevaluated against the new Vertical targets on data-ready. Cash, Vertical, TrainingLevel, remainder, court unlocks and selected court are preserved. A previously equipped style that no longer meets its new Vertical requirement uses the existing deterministic unlocked-style fallback. Previously unlocked High School remains unlocked even below the new gate.

## Studio Rollout and Fresh-Player Test

1. Stop Play, sync Rojo source, and restart Play to apply the new configuration/UI. The existing Studio-built High School **portal sign is builder-generated scenery**: after syncing, stop Play, back up the place, replace only the imported `ServerStorage.HighSchoolBuilder` tool folder with the latest `tools/HighSchoolBuilder.rbxmx`, run `require(game:GetService("ServerStorage").HighSchoolBuilder.Build).Run()` in the **edit-mode** Command Bar, and save/publish. This refreshes the sign's current 75 Vertical / $6,000 copy without deleting gameplay objects. The runtime portal/menu requirements update from CourtConfig without rebuilding, but the authored sign does not.
2. Use a **published private Studio test experience** with Studio API access enabled and the separate `DunkSimulator_PlayerData_DEV_v1` store. Finish Play and wait for the final save; close all other test sessions. Verify `print(game:GetService("StudioService"):GetUserId())` matches the positive solo-test UserId from Output.
3. While **stopped in edit mode**, run the guarded reset from `DATA_PERSISTENCE.md`:

   ```lua
   local userId = game:GetService("StudioService"):GetUserId(); require(game:GetService("ServerScriptService").data.PlayerDataStore).ResetStudioData(userId, "RESET " .. tostring(userId))
   ```

4. Start a new solo Play session. Wait for DataStatus Ready. Verify Cash 0, Vertical 30, TrainingLevel 1, remainder 0, Neighborhood only and no claimed challenges. The two reach-Vertical challenges normally display **30/60** and **30/120** after data-ready; dunk counts remain zero. Do not grant yourself Cash, Vertical, levels, court access or challenge progress.
5. Start one cumulative timer. Play normally, recording time, Cash, TrainingLevel, current court and ReadyToClaim challenges at **35 Basic**, **50 Two-Hand**, **60 Rising Athlete**, **75 Tomahawk/Neighborhood cap**, **$6,000 available and High School purchased**, **100 Vertical**, **110 Windmill**, **120 Above the Rim**, **150 High School cap**, and **all seven claims**. Record the 75-Vertical and purchase moments separately if Cash arrives later. Note whether 100 occurs before Windmill as expected. Record TrainingLevel at High School purchase. Release the trainer before reading values and count only completed dunks.
6. Verify DUNKS base rewards/thresholds, COURTS and physical portal requirement, upgrade multipliers/prices, challenge descriptions/targets/rewards, server-confirmed payout, unchanged fractional carry across travel/save, and no duplicate rewards or claims. Test an existing saved profile **without resetting it** separately for migration behavior.

### Pacing Caveat

Desired **cumulative** ranges for an experienced fresh player: Basic 1–2 minutes; Two-Hand 4–6; Tomahawk 8–12; High School 15–20; Windmill 20–30; 100 Vertical approximately 25–40; 120 Vertical approximately 35–50; all seven challenges approximately 30–45+ minutes. These are measurement targets, not gates or guaranteed outcomes.

The requested pacing targets are **not validated** by config math. At Level 1 with uninterrupted 0.5-second Neighborhood ticks, 30→35 takes five ticks (~2.5 seconds), 30→50 twenty ticks (~10 seconds), 30→100 seventy ticks (~35 seconds), and 30→110 eighty ticks (~40 seconds) of active training. Travel/dunks/menus add real time but no server timer forces the requested minute ranges. The exact specified values were implemented without inventing cooldowns or altering tick speed. Record an actual fresh-player run before deciding whether further balance changes are needed. **Balance targets require real playtesting.**
