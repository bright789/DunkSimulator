# Tutorial, Badges and Analytics

Three launch features that share one idea: **milestones worked out from progress the game already saves** (best Vertical, lifetime dunks, Training Level, unlocked courts, Rebirths, contest wins). Nothing new is saved, and there is no schema change. The milestone definitions live in `src/shared/Config/MilestoneConfig.luau`.

## New-player tutorial

A step card at the top of the screen, a gold guide line from the player to the target, and a bobbing marker above it.

**Dunk first, train second (2026-10-03).** New players now start at **35 Vertical**, the dunk minimum (`ProgressionConfig.StartingVertical` = `DunkConfig.DunkMinimumVertical`), so they can dunk within seconds instead of holding E for ~25 s first. Training comes after the first dunk, with a faster Level 1 (+0.15 per rep) and a $60 Level 2 (see `TRAINING_UPGRADES.md`).

| Step | Card | Guide points at | Done when |
| --- | --- | --- | --- |
| 1 | GRAB A BASKETBALL: walk up to the Hoop Shop and press E | `BasketballPickup` | holding a ball (or has dunked) |
| 2 | DUNK IT!: jump at the rim, then press DUNK in the air | the hoop's `Rim` | first dunk |
| 3 | TRAIN YOUR VERTICAL TO 40: hold E at the Leg Day Gym (click on the beat for 3x!). Higher jumps = bigger dunk Cash! (progress bar `35 / 40`; touch text: "Hold the Leg Day Gym button (tap PUMP on the beat!)") | Leg Day Gym (`VerticalTrainer`) | best Vertical ≥ 40 (`Milestones.TutorialTrainVertical`), or already owns Training Level 2 |
| 4 | UPGRADE YOUR TRAINING: earn $60 from dunks, then buy Level 2 at Training Upgrades (progress bar `$21 / $60`) | `UpgradeStation` | Training Level ≥ 2 |

- **Who sees it:** only players who haven't finished the steps and have never Rebirthed. Existing players never see it, and neither do players starting over after a Rebirth.
- **Players from the old order (train to 35 first):**
  - Saved profiles below 35 Vertical are raised to 35 on load (Vertical and best Vertical), because `PlayerDataSchema` clamps both to `StartingVertical`. The usual one-line "Repaired missing/invalid fields" warning is printed once for each such profile.
  - Anyone who hasn't dunked yet lands on step 1 (grab a ball). Someone who dunked but hasn't upgraded lands on step 3 (train to 40), then step 4.
  - Anyone who already bought Level 2 (finished the old tutorial) counts as done, even below 40 Vertical: step 3 also accepts Training Level 2. A new player who buys Level 2 before reaching 40 also finishes the tutorial there.
- **Controls:**
  - **SKIP** hides it for the rest of the session.
  - When the last step is done, the card shows "TUTORIAL COMPLETE!" for 5 seconds.
- **How it works:**
  - The client (`TutorialController.client.luau`) reads what the server already replicates: leaderstats, plus the `BestVertical`, `TotalDunks`, `TrainingLevel`, `Rebirths` and `HasBasketball` attributes.
  - It is display only. Every reward and check stays on the server.
  - The step shown comes only from the order of `MilestoneConfig.Tutorial` and `TutorialStepsDone`; nothing else depends on a step's position.
- **Guide:**
  - It always points at the nearest matching part, so it also works at other courts.
  - The line hides when you're within 9 studs; the marker stays.
- **Layering:** the card sits just under the Dunk Contest banner, and reward pop-ups draw over it. The NEXT goal bar and the goal card (`GIFTS_AND_GOALS.md`) stay hidden while the tutorial runs.

## Badges

| Key | Badge | How to earn | Image (`assets/badge-icons/`) |
| --- | --- | --- | --- |
| `Welcome` | Welcome (id 2421074952642248) | Join the game | `welcome.png` |
| `FirstDunk` | First Slam (id 414673442946406) | Land your first dunk | `first-slam.png` |
| `Vertical100` | Vertical 100 (id 1200946718501511) | Reach 100 Vertical | `hops-100.png` |
| `HighSchool` | Varsity (id 128763592521392) | Unlock the High School Gym | `varsity.png` |
| `College` | Big Stage (id 2582750542412877) | Unlock the College Arena | `big-stage.png` |
| `Vertical200` | Sky Walker | Reach 200 Vertical | `sky-walker-200.png` |
| `Vertical250` | Roof Raiser | Reach 250 Vertical | `roof-raiser-250.png` |
| `Rooftop` | Skyline | Unlock the Skyline Rooftop | `skyline.png` |
| `FirstRebirth` | Born Again | Rebirth for the first time | `born-again.png` |
| `ContestWin` | Dunk Champion | Win a Dunk Contest (2+ players) | `dunk-champion.png` |

**Status:** the first five are created and wired in (ids above). Sky Walker, Roof Raiser, Skyline, Born Again and Dunk Champion are still `Id = 0`.

**To turn them on:**
1. Creator Hub → Dunk Simulator → **Engagement → Badges → Create Badge**. Use the name, description and image above. Roblox crops badge images to a circle, and these were drawn for that.
2. Roblox gives **5 free badges per 24 hours (GMT)** per game; more cost 100 Robux each. Suggested split:
   - Day one: Welcome, First Slam, Hops, Varsity, Big Stage.
   - The next day: Sky Walker, Roof Raiser, Born Again, Dunk Champion.
3. Paste each badge's id into `Milestones.Badges[...].Id` in `MilestoneConfig.luau`, sync, and publish. Badges whose id is still 0 are skipped; in Studio, Output shows `[Badges] <player> earned "<badge>" (no badge id set yet)`.

**How awarding works** (`MilestoneService`, server only):
- **On join:** every badge the player already qualifies for but doesn't own is awarded. One `CheckUserBadgesAsync` call per join, then `AwardBadgeAsync` for the missing ones, so existing players get their badges the first time they play after launch.
- **During play:** badges are awarded as milestones happen. Relevant attribute changes trigger an immediate check, plus a 5-second sweep that catches court unlocks.
- **Failures:** calls are retried up to 3 times. Failures only print a warning; they never affect gameplay.
- **Regenerate the images:** `powershell -ExecutionPolicy Bypass -File tools/badge-icons.ps1`

## Analytics

`AnalyticsReporter` sends server-side events through `AnalyticsService`. See them in the Creator Hub under the game's **Analytics** section (Economy, Funnels, Custom events).

| Kind | Events |
| --- | --- |
| **Economy** (currency `Cash`) | **Sources:** `Dunk` and `AirTrick` (batched), `Challenge_<id>` (Gameplay), `DailyLogin` / `DailyChallenge` (TimedReward), `ContestPrize` (Gameplay), `Gift_<n>` (TimedReward), `Goal_<id>` / `Goal_Repeat` (Gameplay). **Sinks:** `Court_<id>`, `TrainingLevel_<n>`, `Shoes_<id>` / `Balls_<id>` (Shop), and `Rebirth` (Gameplay; all Cash the player gives up). |
| **Onboarding funnel** | 1 `Joined` → 2 `Moved` → 3 `Ball` → 4 `DunkTry` → 5 `Dunk` → 6 `FirstRep` → 7 `Train` → 8 `Upgrade` (since 2026-10-03; see below). Logged only for players the tutorial applies to. |
| **Progression funnel** (`Progression`) | 1 `FirstDunk` → 2 `Vertical75` → 3 `HighSchool` → 4 `Vertical150` → 5 `College` → 6 `Vertical200` → 7 `Vertical250` → 8 `Rooftop` → 9 `Vertical300` → 10 `FirstRebirth` |
| **Custom** | `TutorialComplete`, `Rebirth` (value = Rebirth count), `ContestPlace` (value = rank), `ContestScore` (value = best score), `GiftClaimed` (value = gift number), `GoalComplete` (value = goal number; 11 = the repeating goal) |

- **Batching:** dunk and air-trick Cash would be an event every few seconds per player. Instead it's added up per player and sent once a minute and when they leave (`AnalyticsConfig.BatchFlushSeconds`).
- **Funnel logging:**
  - On join, the progression funnel logs the player's highest step already reached. Roblox counts a later step as also reaching the earlier ones, and ignores repeats. Existing players therefore show up in the progression funnel too.
  - The onboarding funnel logs every step it reaches, in order, missing earlier ones first (see below).
- **Studio:** AnalyticsService only records events in published games, so in Studio every event is printed to Output as `[Analytics] ...`. Set `AnalyticsConfig.StudioPrint = false` to silence it.
- **Robux:** purchases are tracked by Roblox automatically and aren't logged here.
- **Safety:** every call is wrapped in `pcall`, and nothing personal is sent beyond what the API itself attaches.

### Onboarding funnel (2026-10-03)

Finer steps, so the dashboard can tell "couldn't find it" from "found it but quit". Defined in `Milestones.Onboarding`; logged by `MilestoneService` through `AnalyticsReporter.OnboardingStep` (`LogOnboardingFunnelStepEvent`).

| # | Step | Reached when | Logged from |
| --- | --- | --- | --- |
| 1 | `Joined` | data loaded and the tutorial applies | `MilestoneService.OnPlayerReady` |
| 2 | `Moved` | the character walked 10+ studs (flat, `Milestones.MoveStuds`) from where the server first saw it once the player was ready | `MilestoneService` 1-second check of server positions |
| 3 | `Ball` | tutorial step 1 done (holding a ball) | attribute watch (`HasBasketball`) |
| 4 | `DunkTry` | a `RequestDunk` reached the server while the player held a ball | `DunkService` → `MilestoneService.OnDunkRequest` |
| 5 | `Dunk` | tutorial step 2 done (first dunk) | attribute watch (`TotalDunks`) |
| 6 | `FirstRep` | a training rep counted (station or Auto Train) | `TrainingService` → `MilestoneService.OnTrainingRep` |
| 7 | `Train` | tutorial step 3 done (40 Vertical, or owns Level 2) | attribute watch (`BestVertical`, `TrainingLevel`) |
| 8 | `Upgrade` | tutorial step 4 done (first upgrade = tutorial complete; also sends `TutorialComplete`) | attribute watch (`TrainingLevel`) |

- **Once per session, always in order.** A done tutorial step implies every step before it, so missing earlier steps are logged first (a player who grabs a ball without walking 10 studs logs `Moved`, then `Ball`). A step the server saw happen early waits for the step before it: a training rep before the first dunk is logged as `FirstRep` right after `Dunk`.
- **Returning players** (tutorial not finished) log `Joined` and the steps their saved progress implies, then continue live. Finished and Rebirthed players log nothing.
- **Reading the dashboard:** the step meanings changed on 2026-10-03 (the old funnel was 1 `Joined` → 2 `Train` → 3 `Ball` → 4 `Dunk` → 5 `Upgrade`). Roblox keeps each player's first log of a step number, so compare only players who joined after the update went live.

**Before baseline (live, last 28 days, recorded 2026-10-03, 699 new players):** Joined 699 → Train (reach 35 Vertical) 410 (**41% lost**) → Ball 400 → Dunk 362 → Upgrade 228 (**37% lost** after the first dunk). Only **24.8%** of new players were still playing after 5 minutes, and the average new-user session was **1.4 minutes**. New players spawned at 30 Vertical and needed about 25 s of holding E (0.1 Vertical per rep, 2 reps/s) before they could dunk at all; after the first dunk (~$21) the first upgrade cost $120 (~6 dunks).

## Files

- **New:**
  - `src/shared/Config/MilestoneConfig.luau`
  - `src/server/Config/AnalyticsConfig.luau`
  - `src/server/services/AnalyticsReporter.luau`
  - `src/server/services/MilestoneService.luau`
  - `src/client/TutorialController.client.luau`
  - `src/client/ui/TutorialView.luau`
  - `tools/badge-icons.ps1`
  - `assets/badge-icons/*.png`
- **Changed:**
  - `PlayerService`: economy events, `GetMilestoneSnapshot`, an optional `sku`/type on `GrantCash` and `SpendCash`
  - `DailyService`, `ContestService`, `LockerService`: label their Cash
  - `ServerMain`: starts both services and calls `MilestoneService.OnPlayerReady`
- **Changed on 2026-10-03 (dunk first, finer funnel):** `ProgressionConfig` (StartingVertical 35), `UpgradeConfig` (Level 1 0.15/rep, Level 2 $60), `MilestoneConfig` (new order, `TutorialTrainVertical`, `Onboarding`), `MilestoneService` (funnel), `DunkService` / `TrainingService` (DunkTry / FirstRep hooks), `PlayerService` (`BestContestScore` in the milestone snapshot), `UpgradeController` (shows 0.15 per rep). Not yet play-tested in Studio.

## Tested in Studio (throwaway test stores; DEV restored afterwards)

This test was run on the original order (train to 35 first) and the old $120 upgrade.

- **Brand-new player (fresh store):**
  - Step 1 showed `30 / 35` with the guide line to TRAIN HERE.
  - Holding E at the Leg Day Gym advanced it to step 2. Grabbing a ball advanced it to step 3.
  - The first dunk advanced it to step 4, which showed `$41 / $250`.
  - Dunking to $273 and buying Level 2 in the real Training Upgrades panel showed "TUTORIAL COMPLETE!".
  - Output logged:
    - Onboarding steps 1–5 in order.
    - Progression step 1 (`FirstDunk`).
    - The Welcome and First Slam badges.
    - A batched `Dunk` source.
    - The `TrainingLevel_2` sink and `TutorialComplete`.
    - Contest prize and placement events from a round that ended mid-test.
  - The Daily Rewards panel no longer pops over the tutorial for players with 0 dunks, and SKIP hides the card and the guide.
- **Existing player (Rebirthed, in College):**
  - No tutorial and no onboarding events.
  - Badges awarded retroactively: Welcome, First Slam, Hops, Varsity, Big Stage, Sky Walker and Born Again.
  - Not awarded, correctly: Roof Raiser (best 200) and Dunk Champion (no 2+ player win).
  - One progression event: step 7 `FirstRebirth`.
- No warnings or errors in Output.
- Real badge awarding and AnalyticsService delivery can only be verified in the published game once badge ids are set.
