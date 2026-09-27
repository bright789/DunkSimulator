# College Court Preparation

College is **not implemented or unlockable**. Do not add a `College` entry to `CourtConfig` until dribbling, dunk-animation playback, both court caps, and the timed fresh-player progression run have passed Studio acceptance.

The existing court architecture already resolves gameplay stations, hoop, spawn, unlocks, bonuses, and training cap from a stable court ID. A later College milestone can add one definition and a Studio-owned environment, then wire purchase/travel through the existing `CourtService` and `GameplayObjects` paths. A proposed College training cap is **250 Vertical**, subject to playtest results; its unlock Vertical, Cash cost, and multipliers are deliberately unset. Do not persist the cap or add speculative profile fields.

Before building Court #3:

1. Measure time to Neighborhood 75, High School purchase, Windmill 110, High School 150, and all seven challenges using `PROGRESSION_PLAYTEST.md`.
2. Choose the College gate and bonuses from measured pacing, not from an arbitrary multiplier.
3. Plan a new explicit gameplay path with local hoop, ball pickup, trainer, upgrade station, spawn, and return portal; do not rely on recursive name searches.
4. Keep Workspace Studio-owned. Make indoor overhead scenery non-collidable and non-queryable above play, so 250+ Vertical and the camera remain usable.
5. Add schema migration only if a genuinely new persistent field is needed. Existing `UnlockedCourts` and `CurrentCourt` can already represent another configured ID.
6. Test travel with a basketball, reset/rejoin, locked/invalid court requests, cap clamping, high-Vertical dunks, and two-player court separation before release.
