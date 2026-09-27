# Daily Rewards, Streaks and Daily Challenges

A reason to come back every day: a 7-day login reward ladder with a streak, three fresh daily challenges, and a timed **2x Cash Boost**. The server owns the calendar and every payout; the client only shows what the server sends.

## How it works for players

- **DAILY button** on the HUD (third row). It shows `DAILY (n)` when something is waiting to be claimed. The panel also opens by itself once per session when today's login reward hasn't been claimed.
- **Login reward:** claim once per UTC day. Claiming on consecutive days grows the streak and walks the 7-day ladder, then the ladder repeats. Missing a whole UTC day starts the streak over at Day 1; the panel says so.
- **Daily challenges:** three per day, picked from a pool of eight and only from ones you can actually finish right now. Finish one, get a "DAILY CHALLENGE COMPLETE" toast, then press CLAIM in the panel. Claiming all three gives the **sweep bonus**.
- **Cash Boost:** doubles dunk and air-trick Cash while it runs. A countdown pill (`2x CASH 12:34`) appears under the HUD buttons. It runs in real time, even while offline, and stacks up to 60 minutes.
- New challenges and the next login reward unlock at 00:00 UTC (the panel shows "New day in ...").

## Numbers (starting values in `src/shared/Config/DailyConfig.luau`)

Rewards are priced in **dunks**: one "dunk" is the Cash a plain dunk of your best unlocked style earns at your current Vertical, with no court, rebirth, timing or boost bonus (minimum $10). So the rewards stay worth claiming from 30 Vertical to 250.

| Ladder day | Cash | Extra |
| --- | --- | --- |
| 1 | 4 dunks (min $50) | |
| 2 | 6 dunks (min $75) | |
| 3 | 8 dunks (min $100) | 2x Cash Boost, 10 min |
| 4 | 10 dunks (min $125) | |
| 5 | 12 dunks (min $150) | |
| 6 | 15 dunks (min $200) | |
| 7 | 25 dunks (min $400) | 2x Cash Boost, 30 min |

Examples: at 30 Vertical, Day 1 is $80 and Day 7 is $500. At 200 Vertical (Windmill), Day 1 is $1,080 and Day 7 is $6,750.

Each daily challenge pays **6 dunks (min $75)**. The sweep bonus is a **15-minute** Cash Boost. With the **2x Daily Rewards** pass, login and challenge Cash pays ×2 and the panel shows the doubled amounts (see `MONETIZATION.md`). The Cash Boost developer product adds 15 minutes to the same boost.

| Pool id | Challenge | Can be rolled when |
| --- | --- | --- |
| `dunks` | Land 15 dunks | always |
| `perfects` | Hit 5 PERFECT slams | always |
| `cash` | Earn 20 dunks' worth of Cash from dunks (tricks and bonuses count) | always |
| `tricks` | Land 20 air tricks | 60+ Vertical |
| `combos` | Land 3 dunks with a 4+ trick combo | 130+ Vertical |
| `style` | Land 10 dunks with one of your unlocked styles | a style is unlocked |
| `court` | Land 10 dunks at an unlocked court other than the Neighborhood | High School or College unlocked |
| `training` | Finish 40 training reps | below your best court's training cap |

The three are a shuffle that's fixed per player and per day. Targets and rewards are locked in when they're rolled (the first time you're online that day), so leveling up later that day doesn't change them.

## Server authority and security

- The client can only send `DailyRequest("Read")`, `DailyRequest("Reward")` or `DailyRequest("Challenge", slot)` with a whole-number slot of 1–3. Anything else is ignored. There's a 0.5 s cooldown per player and one claim in flight at a time.
- The day is `math.floor(os.time() / 86400)` on the server, so a client clock can't change it.
- **Progress** only comes from server events:
  - `DunkService` calls `DailyService.OnDunk` after a completed, rewarded dunk, passing the style, court, slam rating, tricks landed (new 5th return from `DunkExecution.Run`) and Cash earned.
  - `TrainingService` calls `DailyService.OnTrainingRep` for each rep that earned progress.
- **Payouts** go through `PlayerService.GrantCash`, which refuses anything that isn't a whole non-negative number or would pass the Cash limit. A claim is validated and applied in one step with no yields.
- The boost multiplier is applied inside `PlayerService.RegisterDunk` and `AwardDunkTrick`, from the saved boost end time.
- Claims request a priority save (subject to the usual 10 s priority-save cooldown; autosave covers the rest).

## Persistence (schema v7)

New saved field `Daily`:

```lua
Daily = {
    Streak = 3,              -- consecutive days claimed
    LastClaimDay = 20723,    -- UTC day number of the last login-reward claim (-1 = never)
    BoostUntil = 1790000000, -- os.time() when the Cash Boost ends (0 = none)
    ChallengeDay = 20723,    -- UTC day these challenges belong to (-1 = none yet)
    Challenges = {           -- up to 3
        { Id = "style", Param = "Windmill", Target = 10, Reward = 1620, Progress = 4, Claimed = false },
    },
}
```

- Migration v6 → v7 adds an empty `Daily`; everything else is kept.
- `DailyConfig.Sanitize` repairs bad values: unknown challenge ids or invalid style/court options are dropped, and numbers are floored and clamped.
- The save writer copies `Daily` explicitly, and `SameProgress` compares it.

## Files

- **New:**
  - `src/shared/Config/DailyConfig.luau`
  - `src/server/services/DailyService.luau`
  - `src/client/DailyController.luau`
  - `src/client/ui/DailyView.luau`
- **Changed:**
  - `PlayerService`: Daily state, `GetDaily`, `GetDailyContext`, `GrantCash`, boost in payouts
  - `PlayerDataSchema`, `PlayerDataStore`, and `DataConfig` (`SchemaVersion = 7`)
  - `DunkExecution` (tricks landed), `DunkService`, `TrainingService`, `ServerMain`
  - `HUDView` (DAILY button, boost pill), `HUDConfig` (`BoostHeight`), `HUDController`
  - `default.project.json` (`DailyRequest`, `DailyState` remotes)

## Acceptance tests (passed in Studio against the separate QA store)

1. A schema-6 profile loads as schema 7. The panel opens by itself with Day 1 claimable (at 200 Vertical: $1,080) and three eligible challenges priced at 6 dunks ($1,620).
2. Claiming Day 1 pays once, marks it CLAIMED, sets streak 1, and shows "next reward in ...". A second claim the same day is refused.
3. With "claimed yesterday, streak 2" saved: Day 3 is claimable, pays $2,160 and starts a 10-minute boost; the HUD pill counts down.
4. During the boost a College dunk paid double: +$1,296 dunk (100 × 1.6 court × 1.5 rebirth × 2 boost × 2.7 Vertical) plus boosted tricks. The Money Maker challenge advanced by the full amount earned.
5. With "last claim 3 days ago": the streak-lost notice shows and the claim pays Day 1.
6. Finished challenges claim once each. Finishing the last one by dunking shows the ready toast and `DAILY (1)`, and claiming it gives the sweep bonus: +15 minutes stacked onto the running boost.
7. The boost carries across sessions (real time). The saved record matches: schema 7, claims, streak and boost end.
8. No client or server errors.

Still worth checking before release: a player online across 00:00 UTC (challenges re-roll and the reward unlocks), two players claiming at once, and the panel on a phone-sized screen.
