# Rebirth v0.1

Rebirth lets a strong player start over from the Neighborhood in exchange for permanent Cash and training multipliers. It gives the College Arena an end goal and makes each new run faster than the last.

## Rules (starting values in `src/shared/Config/RebirthConfig.luau`)

| Setting | Value |
| --- | --- |
| Requirement | 300 Vertical (Skyline Rooftop only) **and** Cash of `200,000 x 1.6^n` (n = rebirths already done). Was 200 Vertical / $100,000 until Court #4; see `SKYLINE_ROOFTOP.md`. |
| Cash bonus | dunk and air-trick Cash x(1 + 0.5 n) |
| Training bonus | Vertical training x(1 + 0.25 n) |
| Max rebirths | 99 |
| Request cooldown | 1.5 s (reads: 0.5 s) |

Cost ladder: 1st $200,000, 2nd $320,000, 3rd $512,000, 4th $819,200, 5th $1,310,720.

Rebirth multipliers stack with court bonuses and timing. Example after 1 rebirth: a College PERFECT Windmill at 250 Vertical pays $100 x1.6 court x1.5 **rebirth** x1.5 timing x3.2 Vertical = $1,152.

In practice the requirement is only reachable at College: the High School training cap is 150 Vertical, and College's is 250.

**Reset:** Cash, Vertical (back to 30), Training Level, fractional training carry, court unlocks, and current court (back to the Neighborhood). The equipped dunk style falls back to the best style the new Vertical allows.

**Kept:** the rebirth count and its bonuses, challenge progress and claims, daily streaks, lifetime stats, and Locker shoes and ball skins. Claimed challenges stay claimed; they do not pay twice.

## Player flow

1. The gold **REBIRTH** button sits beside CHALLENGES on the HUD. After the first rebirth it reads `REBIRTH n`.
2. The panel shows the current and next multipliers, the Vertical and Cash requirement with progress, and what resets.
3. Clicking **REBIRTH** changes the button to **CONFIRM REBIRTH?**. A second click sends the request.
4. On success the player is sent to the Neighborhood spawn, stats reset, a celebration toast and sound play, and the profile saves right away.

## Server authority and security

The client can only send `RebirthRequest("Read")` or `RebirthRequest("Rebirth")`. Any extra arguments, unknown actions, repeats during processing, and requests inside the cooldown are ignored. The server never trusts a client number.

`RebirthService` order:

1. Takes the rebirth snapshot from `PlayerService` and rejects the request unless the player's data is loaded and ready and the player is idle (not dunking, training, or in transit).
2. Re-checks the requirement.
3. Sends the player to the Neighborhood through the normal `CourtTravel.Move`. This ends training, closes upgrades, and drops the ball.
4. `PlayerService.ApplyRebirth` re-validates everything: ready, idle, now at the Neighborhood, under the max, and meets both Vertical and Cash. It then applies the whole reset in one step with no yields.
5. Requests a priority save and replies on `RebirthState` with (snapshot, message, rebirthed).

Errors are caught with pcall. The player gets "Rebirth unavailable. Please try again." and their progress is untouched.

## Persistence (schema v6)

- `Rebirths` is a new saved integer, clamped to 0..MaxRebirths, with a default of 0.
- Migration v5 → v6 sets `Rebirths = 0` and keeps every other field. Existing DEV and production profiles upgrade automatically on their next join.
- The save writer (`PlayerDataStore`) copies `Rebirths` explicitly, and `SameProgress` compares it, so a rebirth is never skipped as "no change".
- Store names and keys are unchanged.

## Files

- New:
  - `src/shared/Config/RebirthConfig.luau`
  - `src/server/services/RebirthService.luau`
  - `src/client/RebirthController.luau`
  - `src/client/ui/RebirthView.luau`
- Changed:
  - `PlayerService` (multipliers, `GetRebirthSnapshot`, `ApplyRebirth`, the `Rebirths` attribute)
  - `PlayerDataSchema` (v6)
  - `PlayerDataStore`
  - `DataConfig` (`SchemaVersion = 6`)
  - `ServerMain` (Init)
  - `HUDController` and `HUDView` (button)
  - `FeedbackConfig` (Rebirth sound)
  - `default.project.json` (`RebirthRequest` and `RebirthState` remotes)

## Acceptance tests (passed in Studio against a separate QA store)

1. A saved v5 profile loads as schema 6 with `Rebirths = 0` and no other changes.
2. With 200 Vertical and $200,000 at College, a confirmed rebirth resets to $0, 30 Vertical, LVL 1 and the Neighborhood. The saved record then has `SchemaVersion 6, Rebirths 1`.
3. After the rebirth, High School and College show as locked again, and the button reads `REBIRTH 1`.
4. Dunk, air-trick and training gains include the rebirth multiplier.
5. Below the requirement, the panel shows what is missing, and the server rejects any request that is forced through anyway.

Still worth checking before release:

- Rebirth spam from a modified client (cooldown and the processing lock).
- Leaving the game during a rebirth.
- Two players rebirthing at the same time.
