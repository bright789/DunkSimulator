# Dunk Challenges v0.1

## One-Time Objectives

| Order | Stable ID | Name | Server requirement | Claim Cash |
| --- | --- | --- | --- | ---: |
| 1 | `basic_dunker_1` | Getting Started | 10 completed Basic One-Hand dunks | $150 |
| 2 | `two_hand_dunker_1` | Power Finisher | 15 completed Two-Hand Power dunks | $350 |
| 3 | `tomahawk_dunker_1` | Tomahawk Specialist | 15 completed Tomahawk dunks | $600 |
| 4 | `windmill_dunker_1` | Windmill Specialist | 20 completed Windmill dunks | $1,000 |
| 5 | `vertical_50` | Rising Athlete | Reach 60 whole Vertical | $300 |
| 6 | `vertical_75` | Above the Rim | Reach 120 whole Vertical | $800 |
| 7 | `highschool_dunks_10` | High School Highlights | 25 completed dunks at High School Gym | $1,500 |

Total possible one-time bonus Cash: **$4,700**. These rewards are additional to style/court dunk payouts. `src/shared/Config/ChallengeConfig.luau` owns IDs, order, targets and rewards. Styles and court lock previews use the current DunkStyles/CourtConfig requirements. Historical IDs such as `vertical_50` and `highschool_dunks_10` are stable persistence keys, **not** current target values; they remain unchanged to preserve saved claims.

## Runtime and Persistence

`ChallengeService` is notified only after `PlayerService.RegisterDunk` confirms and pays a completed dunk, or after a valid training tick changes private Vertical. Its three handlers (`DunkStyleCount`, `VerticalReached`, `CourtDunkCount`) update private PlayerService challenge state, bounded by each target. A successful High School dunk may advance both its style and court goals. Failed/started dunks and client claims of success do not advance progress. Finished or capped objectives stop changing.

Each persistent record is `{ Progress = number, Completed = boolean }`. In Progress means below target; Ready to Claim means at target but not Completed; Completed means Cash was already paid. CLAIM sends only the stable ID. The server validates data readiness, ID, target/actual Vertical for Vertical goals, completion, positive configured reward, Cash bound and per-player request guard; one synchronous state mutation sets Completed and adds Cash exactly once. It then requests the existing serialized priority save. Other progress uses normal autosave/leave/shutdown; there is no per-dunk DataStore write. The CHALLENGES menu and badge are presentation only, and the claim toast uses the actual server-confirmed Cash amount. Blank `ChallengeReady`/`ChallengeClaim` audio IDs in FeedbackConfig are optional hooks, not fabricated assets.

Schema v5 migrates existing v4 saves by adding seven zero-progress, unclaimed entries. Previous Cash, Vertical, TrainingLevel, fractional remainder, equipped style, unlocked courts and selected court are preserved; DataStore names/keys do not change. On data-ready, saved Vertical fills the two reach-Vertical goals retroactively, without paying/celebrating claims. Prior style/High School dunks cannot be reconstructed and start at zero. Unknown or malformed nested entries are sanitized independently. The existing native persistence implementation does not provide full cross-server session locking; an unconfirmed crash/close save can still lose recent progress.

The early-game rebalance does **not** change schema or erase existing challenge records. A claimed `Completed = true` entry stays claimed and cannot pay again; on load its displayed Progress normalizes to the new target. An old unclaimed 3/3 Tomahawk record becomes 3/15, not claimed/paid; an unclaimed 5/5 Basic record becomes 5/10. Saved whole Vertical reevaluates Rising Athlete at 60 and Above the Rim at 120. Already-earned Cash and court unlocks are preserved. Test this on an existing DEV profile without resetting it; reset only the separate timed fresh-player profile.

## Studio Setup

1. Stop Play. Keep the already published **private test experience** with Studio API access enabled under Experience Settings > Security; use the separate DEV DataStore. Do not reset DEV data for migration testing.
2. Sync Rojo, ensuring `ChallengeRequest` and `ChallengeState` appear under `ReplicatedStorage.Remotes`. Restart Play. No Workspace/map object or builder action is required.
3. Use a known saved profile, or a separate new test account for the new-player path. Inspect Output for DataStore/load errors. Do not test persistence in an unpublished place.

## Manual Acceptance Matrix

1. **Basic:** At 35+ Vertical, equip Basic, complete nine Basic dunks: `9/10`. The tenth shows `10/10`, CLAIM, a completion toast, and **no $150 yet**. CLAIM pays exactly $150 and shows COMPLETED.
2. **Claim spam:** Repeatedly click CLAIM or send repeated `ChallengeRequest` with the same ID; Cash increases once.
3. **Wrong style:** Complete Tomahawk; only Tomahawk's style count advances, not Basic/Two-Hand/Windmill.
4. **Failed dunk:** Press F for an invalid or interrupted dunk; no challenge count changes.
5. **High School overlap:** Complete a Tomahawk in High School; Tomahawk and High School goals each gain one, and the normal High School dunk payout remains $75.
6. **Neighborhood isolation:** Complete a Tomahawk in Neighborhood; its style goal gains one, High School goal does not.
7. **Vertical 60:** Train to 60 whole Vertical; Rising Athlete shows CLAIM and no $300 until claimed.
8. **Existing high Vertical:** Join with a saved Vertical of 120+; both reach-Vertical goals are ready without replaying historical toasts or paying automatically.
9. **Partial persistence:** Reach Tomahawk `2/15`, leave, rejoin, and confirm `2/15`.
10. **Claim persistence:** Claim Getting Started, leave/rejoin; it remains COMPLETED and cannot pay again.
11. **v4 migration:** Join with a prior save; verify Cash/Vertical/TrainingLevel/remainder/equipped style/courts unchanged, dunk goals `0`, and reach-Vertical goals filled from saved Vertical.
12. **Locked Windmill:** Below 110 Vertical, Windmill Specialist is visible at `0/20`, previews the style threshold, and cannot progress from another style.
13. **Locked High School:** Before court unlock, High School Highlights previews the gym requirement and Neighborhood dunks cannot advance it.
14. **Invalid ID:** From the test client, call `game.ReplicatedStorage.Remotes.ChallengeRequest:FireServer("not_a_challenge")`; no Cash or progress changes and no error cascade.
15. **Early claim:** Send a valid ID below its target; the server rejects without Cash.
16. **Repeat claim:** Send an already-Completed ID; the server rejects without Cash.
17. **Badge:** Make two goals ready, verify `CHALLENGES (2)`; claim one and then the other, verifying `CHALLENGES (1)` and finally no badge.
18. **Two-stage feedback:** Reaching a goal shows `Reward ready: $...`; only a confirmed claim shows `+$...` and pulses the Cash HUD.
19. **Extended session:** Continue training/dunking after goals cap or complete; progress never exceeds targets, no repeat toasts, UI objects do not accumulate, and Output remains quiet.

Also verify that possession, styles, dunk assist, High School travel, training efficiency, upgrade UI and court payouts still work. The early-game rebalance intentionally changes targets/rewards and requires a separate fresh-player pacing test; see `EARLY_GAME_REBALANCE.md`.
