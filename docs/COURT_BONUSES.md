# Court Bonuses v0.1

## Balance and Ownership

| Court | Dunk Cash | Vertical training | Access |
| --- | --- | --- | --- |
| Neighborhood | 1.00x | 1.00x | Always unlocked |
| High School Gym | 1.25x | 1.15x | 75 Vertical and a one-time $6,000 purchase |

`src/shared/Config/CourtConfig.luau` is the sole source of court multipliers. `src/shared/Config/DunkStyles.luau` keeps the style **base** rewards at $20/$35/$60/$100; `UpgradeConfig` supplies Level 1–10 efficiency multipliers from 1.00x to 2.00x on 1.00 base training progress. The training interval, jump curve, dunk assist/execution and map geometry remain unchanged. These values are prototype balance; see `EARLY_GAME_REBALANCE.md`.

The COURTS menu displays standard bonuses for Neighborhood and +25% Dunk Cash / +15% Vertical Training for High School. The DUNKS menu and equipped HUD explicitly label the **base** reward. The dunk success event carries the actual credited Cash, so its toast shows the court-adjusted result rather than a client estimate. The Vertical HUD changes only for whole points actually earned.

## Server Calculation

PlayerService uses its private `CurrentCourt` and `UnlockedCourts` with `CourtConfig.GetBonuses`. Unknown, locked or malformed court state gets Neighborhood's multipliers. Replicated attributes, leaderstats, menu text and remote payloads do not authorize bonuses. Court travel and access are still validated by CourtService/CourtTravel.

Only after DunkService confirms a completed execution, `RegisterDunk` rechecks the private equipped style and its Vertical requirement, then credits `math.floor(baseReward * DunkCashMultiplier + 0.5)`. This is round-to-nearest whole Cash for the nonnegative prototype rewards. Consuming the Completed state prevents a second award. The existing `DunkResult` payload returns the amount actually credited.

| Style | Base / Neighborhood | High School calculation | High School payout |
| --- | --- | --- | --- |
| Basic One-Hand | $20 | 20 x 1.25 = 25 | $25 |
| Two-Hand Power | $35 | 35 x 1.25 = 43.75 | $44 |
| Tomahawk | $60 | 60 x 1.25 = 75 | $75 |
| Windmill | $100 | 100 x 1.25 = 125 | $125 |

For each legitimate server-timed training tick, `PlayerService.AwardTraining` calculates `1.00 base progress × TrainingLevel efficiency × court TrainingMultiplier`. It adds this to private `VerticalTrainingRemainder`, awards only the whole part to Vertical, and carries the fraction. Progress is quantized to millionths and accumulated as integer units so repeated ticks do not drift across a whole-point boundary. The saved remainder stays in `[0, 1)` and belongs to the player, **not** the court. Travel never clears it. Neighborhood Level 1 with zero carry behaves exactly as before; a carried fraction remains available even while training there. Only authoritative **whole Vertical** affects jumping and style unlocks.

At High School from zero remainder, Level 1 yields +23 whole Vertical over 20 ticks (1.15 each), Level 2 yields +12 over 10 ticks (1.265 each, with 0.65 carry), and Level 5 yields +32 over 20 ticks (1.61 each, with 0.20 carry). Individual ticks can give different whole gains. Training still awards no Cash and never saves per tick.

## Persistence and Safety

The current schema is **v5**. The existing v3 -> v4 migration originally added `VerticalTrainingRemainder = 0`; v4 -> v5 added challenges. This rebalance changes neither schema nor DataStore namespace, and preserves Cash, Vertical, TrainingLevel, EquippedDunkStyle, UnlockedCourts, CurrentCourt, remainder, challenges and revision. New profiles start at zero carry. Load validation accepts only finite values in `[0, 1)` and normalizes them to millionths; invalid carry becomes zero without resetting valid fields. The strict runtime snapshot and serialized UpdateAsync write include the remainder. This does not add full multi-server session locking; see `DATA_PERSISTENCE.md`.

## Studio Setup

Stop Play, sync Rojo source and start a fresh Play session. Court bonus math needs no map rebuild, but the later early-game rebalance changed the High School **gateway sign**: rerun the edit-only HighSchoolBuilder once after syncing as described in `COURT_PROGRESSION.md`. No new prompt, remote, lighting change or Workspace ownership change is needed. For persistence tests, use a **published private test experience** with Studio API access enabled, the same signed-in UserId, and the existing isolated DEV store. Wait for `[DataService] Saved player ...` before rejoining. Use the guarded reset in `DATA_PERSISTENCE.md` only for disposable test profiles, never the migration profile. Do not edit leaderstats or player attributes to seed authoritative Cash, Vertical or CurrentCourt.

## Manual Acceptance Matrix

Use successful dunks only, note Cash before/after each, and verify the ball returns. Where an exact training tick count matters, start from a saved zero-remainder profile, release E after the counted ticks, and compare whole Vertical. The interval remains about 0.5 seconds.

1. **Neighborhood Basic:** Equip Basic, complete one dunk; Cash rises exactly $20 and the toast says `+$20`.
2. **Neighborhood Windmill:** Equip Windmill at Vertical >=110; one completion adds exactly $100.
3. **High School Basic:** Travel to unlocked High School; one Basic completion adds exactly $25 and the toast says `+$25`.
4. **High School Two-Hand:** One Two-Hand Power completion adds exactly $44.
5. **High School Tomahawk:** One Tomahawk completion adds exactly $75.
6. **High School Windmill:** One Windmill completion adds exactly $125.
7. **Duplicate reward:** Spam F during a High School Windmill; a single completed lifecycle adds exactly $125 once. Failed/aborted attempts add nothing.
8. **Neighborhood training:** At Level 1 with zero carry, count ten valid ticks; Vertical rises exactly 10, Cash does not change. Training timing remains unchanged.
9. **High School Level 1 training:** Starting with zero carry, count 20 valid ticks; Vertical rises exactly 23, not 20 and not 24. Individual ticks may show +1 or +2.
10. **High School Level 2 training:** Starting with zero carry, count ten valid ticks; Vertical rises exactly 12 with 0.65 carry, Cash unchanged.
11. **Travel with carry:** From zero carry at Level 1, train five High School ticks (+5 whole, 0.75 carry), travel to Neighborhood and train one tick (+1), then return to High School for two ticks (+3 whole). The carried 0.75 was not lost.
12. **Remainder persistence:** From zero carry at Level 1, train five High School ticks (+5 whole, 0.75 carry), leave after save confirmation, rejoin, then train two High School ticks (+3 whole). Cash, selected court, unlocks and style still restore.
13. **Existing profile migration:** Load a known saved schema-v3 DEV profile without resetting it. Confirm Cash, whole Vertical, TrainingLevel, equipped style, unlocked courts and CurrentCourt are unchanged. Carry starts at zero. After saving, the profile is schema v5 in the same DEV store; challenge defaults/migration follow `DUNK_CHALLENGES.md`.
14. **Spoof protection:** In client Play Command Bar set the local `CurrentCourt` attribute to `HighSchool` while server-selected Neighborhood. It must not increase actual Neighborhood dunk/training awards. Do not alter real production profiles or server-private state to test this.
15. **Invalid/locked court fallback:** In the isolated module tests, feed `GetBonuses` an unknown, locked or malformed court ID/unlock map; it must return Neighborhood 1.00x values. Normal server APIs reject selecting a locked or invalid court, so do not intentionally corrupt a live DataStore record for this test.

Also inspect COURTS at 1920x1080, 1366x768 and a smaller window: both bonus descriptions should remain readable and not overlap unlock progress or TRAVEL. Check DUNKS/equipped HUD say **base** reward, and success toasts say **actual** credited reward. Test leaving/respawning during training and a dunk; no extra Cash or fractional loss beyond the normal last-confirmed-save limitation.
