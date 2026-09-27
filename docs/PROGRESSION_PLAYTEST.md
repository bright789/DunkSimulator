# Fresh-Player Progression Playtest

Use a **separate published private Studio test experience** with API access enabled and the existing isolated `DunkSimulator_PlayerData_DEV_v1` store. Do not run this reset against production or while Play is running. `docs/DATA_PERSISTENCE.md` has the full reset safety explanation.

1. Stop Play and sync the current Rojo source. If the High School physical gate sign still says 80, refresh only the imported `HighSchoolBuilder` and run its edit-mode command in `COURT_TRAINING_CAPS.md`; save the place.
2. In the **Edit-mode Server Command Bar**, run exactly:

   ```lua
   local userId = game:GetService("StudioService"):GetUserId(); require(game:GetService("ServerScriptService").data.PlayerDataStore).ResetStudioData(userId, "RESET " .. tostring(userId))
   ```

3. Start a new solo Play session and start one cumulative timer after `DataStatus` becomes Ready. Confirm Cash 0, Vertical 30, TrainingLevel 1, fractional remainder 0, Neighborhood only, default Basic selection, and zero claimed dunk challenges. The reach-Vertical challenges should evaluate from 30 normally. Do **not** grant stats, Cash, unlocks, or challenge progress during this run.
4. Play normally. At each milestone below, record cumulative time, Cash, TrainingLevel, equipped style, current court, and any ReadyToClaim challenges. Release the trainer before reading values. Record the High School cash-ready and purchased times separately if they differ.

| Milestone | Cumulative time | Cash | TrainingLevel | Notes / challenges ready |
| --- | --- | --- | --- | --- |
| Basic unlock (35) | | | | |
| Two-Hand unlock (50) | | | | |
| Rising Athlete (60) | | | | |
| Tomahawk / Neighborhood cap (75) | | | | |
| $6,000 Cash ready | | | | |
| High School purchased | | | | |
| 100 Vertical | | | | |
| Windmill unlock (110) | | | | |
| Above the Rim (120) | | | | |
| High School cap (150) | | | | |
| All seven challenges completed | | | | |
| All seven rewards claimed | | | | |

5. Record the TrainingLevel at High School purchase, Cash at 35/50/60/75/100/110/120/150, time to finish challenges, and which activities feel repetitive or boring. Check that dribbling and all unlocked dunks still work at the caps. Verify training stops at the right court without suppressing jumping or dunks.
6. Stop Play, rejoin without resetting, and verify Cash, Vertical, TrainingLevel, court unlock/selection, equipped style, challenge claims, and fractional remainder persist. Report the table plus any Output errors or failed transitions.

These are measurements, **not validated pacing claims**. No energy system, artificial waiting, or stat reduction is used. Existing saved profiles should be tested separately without resetting them.
