# Tutorial, Badges and Analytics

Three launch features that share one idea: **milestones worked out from progress the game already saves** (best Vertical, lifetime dunks, Training Level, unlocked courts, Rebirths, contest wins). Nothing new is saved, and there is no schema change. The milestone definitions live in `src/shared/Config/MilestoneConfig.luau`.

## New-player tutorial

A step card at the top of the screen, a gold guide line from the player to the target, and a bobbing marker above it:

| Step | Card | Guide points at | Done when |
| --- | --- | --- | --- |
| 1 | TRAIN YOUR VERTICAL: hold E at the Leg Day Gym until you reach 35 Vertical (progress bar `30 / 35`) | Leg Day Gym (`VerticalTrainer`) | best Vertical ≥ 35, the dunk minimum |
| 2 | GRAB A BASKETBALL at the Hoop Shop | `BasketballPickup` | holding a ball (or has dunked) |
| 3 | DUNK IT!: jump at the rim, then press DUNK in the air | the hoop's `Rim` | first dunk |
| 4 | UPGRADE YOUR TRAINING: earn $250, then buy Level 2 at Training Upgrades (progress bar `$120 / $250`) | `UpgradeStation` | Training Level ≥ 2 |

- **Who sees it:** only players who haven't finished the steps and have never Rebirthed. Existing players never see it, and neither do players starting over after a Rebirth.
- **Controls:**
  - **SKIP** hides it for the rest of the session.
  - When the last step is done, the card shows "TUTORIAL COMPLETE!" for 5 seconds.
- **How it works:**
  - The client (`TutorialController.client.luau`) reads what the server already replicates: leaderstats, plus the `BestVertical`, `TotalDunks`, `TrainingLevel`, `Rebirths` and `HasBasketball` attributes.
  - It is display only. Every reward and check stays on the server.
- **Guide:**
  - It always points at the nearest matching part, so it also works at other courts.
  - The line hides when you're within 9 studs; the marker stays.
- **Layering:** the card sits just under the Dunk Contest banner, and reward pop-ups draw over it.

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
| **Economy** (currency `Cash`) | **Sources:** `Dunk` and `AirTrick` (batched), `Challenge_<id>` (Gameplay), `DailyLogin` / `DailyChallenge` (TimedReward), `ContestPrize` (Gameplay). **Sinks:** `Court_<id>`, `TrainingLevel_<n>`, `Shoes_<id>` / `Balls_<id>` (Shop), and `Rebirth` (Gameplay; all Cash the player gives up). |
| **Onboarding funnel** | 1 `Joined` → 2 `Train` → 3 `Ball` → 4 `Dunk` → 5 `Upgrade` (the tutorial steps). Logged only for players the tutorial applies to. |
| **Progression funnel** (`Progression`) | 1 `FirstDunk` → 2 `Vertical75` → 3 `HighSchool` → 4 `Vertical150` → 5 `College` → 6 `Vertical200` → 7 `Vertical250` → 8 `Rooftop` → 9 `Vertical300` → 10 `FirstRebirth` |
| **Custom** | `TutorialComplete`, `Rebirth` (value = Rebirth count), `ContestPlace` (value = rank), `ContestScore` (value = best score) |

- **Batching:** dunk and air-trick Cash would be an event every few seconds per player. Instead it's added up per player and sent once a minute and when they leave (`AnalyticsConfig.BatchFlushSeconds`).
- **Funnel logging:**
  - On join, each funnel logs the player's highest step already reached. Roblox counts a later step as also reaching the earlier ones, and ignores repeats.
  - Existing players therefore show up in the progression funnel too.
- **Studio:** AnalyticsService only records events in published games, so in Studio every event is printed to Output as `[Analytics] ...`. Set `AnalyticsConfig.StudioPrint = false` to silence it.
- **Robux:** purchases are tracked by Roblox automatically and aren't logged here.
- **Safety:** every call is wrapped in `pcall`, and nothing personal is sent beyond what the API itself attaches.

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

## Tested in Studio (throwaway test stores; DEV restored afterwards)

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
