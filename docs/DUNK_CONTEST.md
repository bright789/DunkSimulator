# Dunk Contest

A timed, server-wide event. Every few minutes a contest round opens for everyone in the server. Five judges score every dunk landed during the round, on any court, and each player's best dunk counts. At the buzzer everyone is ranked and paid.

## How it plays

1. **Countdown:** 30 s before a round, a banner at the top reads `DUNK CONTEST IN 0:25` with a tip.
2. **Round (90 s):** the banner shows the time left, your best score and the current leader. Just dunk; entry is automatic.
3. **Judging:** after each dunk a **JUDGES** scorecard on the right reveals five cards one by one (a rising ding per card), then the total out of 50 and `NEW BEST!` if it beat your round best. The crowd around you erupts for 45+, and a perfect 50 plays the Perfect sound.
4. **Results:** a panel shows the top 3, your placement, your score tier and your prize (it closes after 10 s or with X). A win plays the rebirth fanfare.

## Judging

Each judge scores `style base + bonuses`, then adds their own opinion (a random ±0.7) and rounds to a whole card from 1 to 10.

| Part | Points per judge |
| --- | --- |
| Style base | Basic One-Hand 4, Two-Hand Power 5, Tomahawk 6, Windmill 7 |
| Air tricks landed | +0.25 each (6 max, +1.5) |
| Variety: 3+ different tricks | +0.5 |
| Slam timing | Perfect +1.5, Good +0.5 |

A **perfect 50** needs a Windmill with a full, varied 6-trick combo and a Perfect slam. A Windmill with 6 varied tricks and no timing bonus scores about 45, and a plain Basic dunk about 20. Higher Vertical means more air tricks, so progression shows up in the score.

## Prizes

Priced in **dunks**, like daily rewards: one dunk is the Cash of a plain dunk with your best style at your Vertical. So prizes matter at every stage.

| Tier | Best score | Prize |
| --- | --- | --- |
| ALL-STAR | 45+ | 20 dunks |
| HIGHLIGHT | 40+ | 12 dunks |
| SOLID | 30+ | 6 dunks |
| ROOKIE | 1+ | 3 dunks |

When at least two players scored, placement adds **+10 / +5 / +3 dunks** for 1st, 2nd and 3rd, and 1st place counts as a **contest win**. Ties go to whoever set the score first. Leaving mid-round forfeits your entry. Example at 200 Vertical (Windmill, $270 per dunk): an ALL-STAR solo round pays $5,400.

## Server authority and security

- Clients send nothing. `DunkService` hands each completed, rewarded dunk to `ContestService.OnDunk` with the style, the server-judged slam rating and the air tricks DunkExecution actually paid (new 6th return value). Judge cards are rolled on the server.
- Round state is published as attributes on `ReplicatedStorage.Contest`:
  - `Phase`: Idle, Open or Results
  - `StartsAt`, `EndsAt`: server time, compared with `workspace:GetServerTimeNow()`
  - `Round`
  - `Leader` and `Results`: JSON
- Players get their own scorecards over the `ContestScore` remote and their results over `ContestResult`. A player attribute `ContestJudged` ("seq:total") lets every client's crowd react.
- Prizes go through `PlayerService.GrantCash`. Contest stats go through `PlayerService.RecordContest`, followed by a priority save request.

## Persistence (schema v9)

`Stats` gains `BestContestScore` (0–50) and `ContestWins`. Migration v8 → v9 sets both to 0. They're mirrored to player attributes of the same names; they're ready for a future leaderboard board or badge.

## Tuning (`src/shared/Config/ContestConfig.luau`)

| Setting | Value |
| --- | --- |
| Schedule | first round 90 s after server start (20 s in Studio), then every 480 s |
| Announce / Open / Results | 30 s / 90 s / 12 s |
| Judging | `StyleBase`, `TrickPoints`, `VarietyTricks`, `VarietyBonus`, `TimingBonus`, `Variance` |
| Prizes | `ScoreTiers`, `PlacementDunks`, `HypeScore` 45 |

## Files

- **New:**
  - `src/shared/Config/ContestConfig.luau`
  - `src/server/services/ContestService.luau`
  - `src/client/ContestController.luau`
  - `src/client/ui/ContestView.luau`
- **Changed:**
  - `DunkExecution`: landed trick ids
  - `DunkService`, `ServerMain`, `HUDController`
  - `CrowdPresentation`: contest hype
  - `PlayerService`: `RecordContest`, contest stat attributes
  - `LeaderboardConfig`: stat fields
  - `PlayerDataSchema`, `DataConfig` (`SchemaVersion = 9`)
  - `default.project.json`: `Contest` folder, `ContestScore` and `ContestResult` remotes

## Acceptance tests (passed in Studio against the QA store)

1. The countdown banner appeared 20 s after Play began and switched to the live timer when the round opened.
2. A College Windmill with 6 varied tricks scored 9-9-9-9-9 = 45 (`NEW BEST!`). The banner showed "Your best: 45 pts | Leader: Bryte213 45".
3. At the buzzer the results panel showed "1. Bryte213 46 pts", "YOU: #1 of 1 - 46 pts (ALL-STAR)" and "PRIZE: +$5,400", and the cash was paid (20 dunks × $270, no placement bonus when solo).
4. The saved record reached schema 9 with BestContestScore 46 and ContestWins 0 (a solo round isn't a win).
5. No client or server errors.

### 2-player test (Studio "Server & Clients", QA store)

- **Setup:** Player1 (250 Vertical, Galaxy Jets, Lava ball) and Player2 (140 Vertical, Court Kings, Ice ball) both dunked in round 2.
- **Server results:** `[Player1 46, Player2 45]`. Player1 has ContestWins 1 and BestContestScore 46; Player2 has ContestWins 0 and 45.
- **Prizes paid:**
  - Player1: ALL-STAR 20 + 1st place 10 = 30 dunks × $320 = $9,600.
  - Player2: ALL-STAR 20 + 2nd place 5 = 25 dunks × $210 = $5,250.
- **Banner:** each client's banner showed the other player as the live leader.
- **Errors:** none on the server or either client.

Still worth checking on a live server: ties, someone leaving mid-round, and a player joining during Results.
