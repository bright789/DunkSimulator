# Weekly Dunk Contest Champion

Every Dunk Contest round also counts toward a **weekly board** that resets every **Monday 00:00 UTC**.

## For players

**Between rounds**, the contest banner shows:
- the reigning **👑 WEEKLY CHAMP** and their score,
- your own best this week,
- when the week resets,
- and when the next contest starts.

**The current #1** wears a gold **👑 WEEKLY CHAMP** tag over their head, visible to everyone in the server.

**Last week's #1** gets a one-time prize the next time they join:
- Cash worth **100 dunks** at their current Vertical,
- plus a **60-minute 2x Cash Boost**,
- announced with a "YOU WON LAST WEEK!" pop-up.

## How it works (`WeeklyChampionService`, server only)

**Recording scores:**
- After each round, every entrant's best score is written to that week's OrderedDataStore (`DunkSimulator_WeeklyContest_v1_W<week>`; Studio uses `..._DEV_v1_W<week>`). It's only written if it beats the player's weekly best.
- The stored value packs `score × 1,000,000 + (999,999 − seconds into the week)`. Higher scores rank first, and ties go to whoever set the score earlier.
- The week number is `ContestConfig.WeekNumber(os.time())`. Weeks start Monday; the Unix epoch was a Thursday, so it shifts by 4 days.

**Publishing:**
- Every 60 seconds (and 3 seconds after each round), the top 5 are read and published on `ReplicatedStorage.Contest` as `WeeklyTop` (JSON with display names) and `WeekEndsAt`.
- The #1 gets the crown BillboardGui, re-added on respawn.
- Each player's `WeeklyBest` attribute is set on join and whenever they improve.

**The champion prize:**
- Last week's #1 is written once to `DunkSimulator_WeeklyChampions_v1` (key `W<week>`, first writer wins).
- On join, that player's prize is claimed (`Claimed = true`) before paying. If paying fails, the claim is released, so it's paid exactly once.
- Only the previous week's prize is checked: a champion who doesn't play at all the following week misses it.

Numbers are in `ContestConfig.Weekly`: `TopCount`, `RefreshSeconds`, `PrizeDunks`, `PrizeBoostMinutes` and `CrownText`.

## Tested in Studio (QA store, DEV weekly stores)

- **Prize:** a planted "last week's champion" record paid on join: +$82,300, which is 100 dunks at 322 Vertical, plus a 60-minute boost. The record was then `Claimed = true`.
- **Scoring:** a 39-point contest dunk updated the weekly board. The banner read "👑 WEEKLY CHAMP: Bryte213 39 pts" with "Resets in 1h 55m".
- **Crown:** it appeared over the head, above the VIP tag.
- **Also confirmed:** the new community group bonus through the real membership check. **GROUP BONUS +10%** showed for the group's owner.

**Note:** the first live week ends Monday 00:00 UTC. Live and Studio use separate weekly stores, so Studio testing never touches the live board.
