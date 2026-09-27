# Global Leaderboards

Three global leaderboards, shown on a board stand next to the hoop in every gym:

| Board | Ranks by | Saved stat |
| --- | --- | --- |
| **TOP VERTICAL** | Best Vertical ever reached (survives Rebirth) | `Stats.BestVertical` |
| **MOST DUNKS** | Lifetime dunks landed | `Stats.TotalDunks` |
| **BIGGEST DUNK** | Most Cash from a single dunk (slam + air tricks, with every bonus) | `Stats.BestDunkCash` |

Each panel shows the top 10 (the top three ranks in gold, silver and bronze) and a `YOU:` line with your own value, plus your rank if you're in the top 10. Your name is highlighted green when you're on a list.

## How it works

- **Stats** (`PlayerService`, server only):
  - `TotalDunks` goes up and `BestDunkCash` updates in `RegisterDunk`. It now receives the air-trick Cash DunkExecution already paid, so "biggest dunk" means the whole payout.
  - `BestVertical` updates in `AwardTraining` and on join (never below the current Vertical).
  - They are mirrored to player attributes of the same names for the boards.
- **LeaderboardService** (server):
  - **Writes:** one OrderedDataStore per board, keyed by UserId. A player's stats are written at most every 120 s (only values that changed), and again when they leave or the server shuts down.
  - **Reads:** every 60 s the server reads the top 10 of each board (3 requests).
  - **Live merge:** every 5 s it merges in the live stats of players in this server, so a new record shows up within seconds even before the stores catch up.
  - **Publishing:** it sorts the merged lists, resolves display names (cached; `UserService` batch lookup with a `GetNameFromUserIdAsync` fallback), and publishes each list as a JSON attribute on `ReplicatedStorage.Leaderboards`.
- **LeaderboardPresentation** (client): draws a SurfaceGui on every part tagged `LeaderboardPanel` (attribute `Board` = `Vertical`, `Dunks` or `BestDunk`). It follows streaming via CollectionService and redraws when the lists or your stats change.
- **Security:** clients send nothing. All values come from server-owned stats.

Store names (in `src/server/Config/DataConfig.luau`):
- **Studio:** `DunkSimulator_Leaderboard_DEV_v1_<Board>`
- **Live servers:** `DunkSimulator_Leaderboard_v1_<Board>`

Tuning (in `src/shared/Config/LeaderboardConfig.luau`): `Size` 10, `RefreshSeconds` 60, `WriteSeconds` 120, board titles and colors.

## Persistence (schema v8)

New saved field `Stats = { BestVertical = 200, TotalDunks = 57, BestDunkCash = 1450 }`. Migration v7 → v8 starts `TotalDunks` and `BestDunkCash` at 0 (there's no history to count) and sets `BestVertical` to the current Vertical. `LeaderboardConfig.SanitizeStats` floors and clamps the values. The save writer copies `Stats` explicitly, and `SameProgress` compares it.

## The board stands (map builders)

`Props.Leaderboards` (in `tools/neighborhood/Props.luau`) builds a freestanding stand: posts, a dark backing, neon trim, a LEADERBOARDS header and one tagged panel per board, in `LeaderboardConfig.Boards` order from left to right as seen by viewers. Placement is set in each builder's `Config.Leaderboard`:

| Map | Spot (builder frame) | Facing |
| --- | --- | --- |
| Neighborhood | `(25, 0, 45)` ground frame: on the grass behind the hoop, left of it | the court |
| High School | `(52, 0, -61)`: right side behind the baseline | the court (-X) |
| College | `(-50, 0, -86)`: behind the hoop, left of it, below the banners | the court (+Z) |

The stands were added by rerunning all three builders in Studio edit mode: Neighborhood 455 parts, High School 952, College 1,869. To rebuild after changing a spot, rebuild that tool package with `rojo build tools/<map>.project.json --output tools/<Map>Builder.rbxmx`, reimport it into ServerStorage and run its `Build.Run()` (see the court docs).

## Files

- **New:**
  - `src/shared/Config/LeaderboardConfig.luau`
  - `src/server/services/LeaderboardService.luau`
  - `src/client/LeaderboardPresentation.client.luau`
- **Changed:**
  - `PlayerService`: `Stats`, attributes, `GetStats`, and `RegisterDunk(..., trickCash)`
  - `DunkService`: passes `trickCash`
  - `PlayerDataSchema`, `PlayerDataStore`, and `DataConfig` (`SchemaVersion = 8`, store prefixes)
  - `ServerMain`
  - `default.project.json`: `ReplicatedStorage.Leaderboards` folder
  - `tools/neighborhood/Props.luau`: `Props.Leaderboards`
  - Builders: each map's `Scenery` and `Config`

## Acceptance tests (passed in Studio against the QA store)

1. A schema-7 profile migrates to schema 8 with `Stats` (BestVertical = current Vertical 200).
2. The College board shows TOP VERTICAL with the player at #1 (live merge), "Be the first!" on empty lists, and `YOU:` lines.
3. One dunk updated MOST DUNKS to 1 and BIGGEST DUNK to $831 (648 slam + tricks) within seconds.
4. The OrderedDataStores held Vertical 200, Dunks 1, BestDunk 831 for the player after leaving. The saved profile had `Stats` 200 / 1 / 831.
5. Panels read TOP VERTICAL, MOST DUNKS, BIGGEST DUNK from left to right on all three maps.
6. No client or server errors.

Still worth checking on a published server: several players across servers, display names for offline players, and DataStore budget under a full server.
