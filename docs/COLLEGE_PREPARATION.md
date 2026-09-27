# College Court Preparation (historical)

**College Arena is now implemented.** See [COLLEGE_ARENA.md](COLLEGE_ARENA.md) for the current numbers, map, builder steps and acceptance tests, and [REBIRTH.md](REBIRTH.md) for the Rebirth loop that College leads into.

This page recorded the pre-build plan. How each item was resolved:

1. **Pacing first.** College starting numbers (150 Vertical + $40,000 unlock, x1.6 Cash, x1.3 training, 250 cap) are starting values in `CourtConfig` and still need a timed playtest with `PROGRESSION_PLAYTEST.md`.
2. **Explicit gameplay path.** College uses `Workspace.Gameplay.Courts.College` with its own hoop Rim, pickup, trainer, upgrade station, spawn and return bus stop. There are no recursive name searches.
3. **Studio-owned Workspace.** The map comes from the edit-mode `CollegeBuilder` tool. Overhead scenery is non-collidable and non-queryable, so 250+ Vertical and the camera stay usable.
4. **No speculative schema.** College itself needed no new saved field; `UnlockedCourts`/`CurrentCourt` already handle it. Schema v6 exists only for the Rebirth count.
5. **Travel tests.** Travel, locked-court requests, the cap, high-Vertical dunks and the return bus passed in Studio. Two-player court separation and bringing a basketball on the bus are still open (listed in `COLLEGE_ARENA.md`).
