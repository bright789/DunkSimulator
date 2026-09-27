# Dunk Styles v0.1

## Scope and Configuration

Four usable procedural styles share the current server-authoritative entry validation, height normalization, horizontal assist, possession, and completion lifecycle. The later reward adjustment adds style-based earnings without changing jump or execution balance. Definitions and stable IDs live in `src/shared/Config/DunkStyles.luau`.

| ID | Display name | Required Vertical | Cash | Order | Gather / finish / return seconds |
| --- | --- | --- | --- | --- | --- |
| BasicOneHand | Basic One-Hand | 35 | $20 | 1 | 0.26 / 0.18 / 0.14 |
| TwoHandPower | Two-Hand Power | 50 | $35 | 2 | 0.39 / 0.17 / 0.20 |
| Tomahawk | Tomahawk | 75 | $60 | 3 | 0.56 / 0.16 / 0.18 |
| Windmill | Windmill | 110 | $100 | 4 | 0.73 / 0.20 / 0.19 |

Basic's requirement still references DunkConfig; style motion timings live in DunkStyles. All four **base** Reward values live directly in DunkStyles: Basic $20, Two-Hand $35, Tomahawk $60 and Windmill $100. CourtConfig provides a separate multiplier for the final completed-dunk payout. Unlocks are calculated from whole Vertical, never stored as booleans. Unlocking a style does not auto-equip it. Default BasicOneHand is an intended selection at Vertical 30, **not permission to dunk** before 35. The current thresholds/rewards are part of `EARLY_GAME_REBALANCE.md`.

## Equip and Attempt Flow

The DUNKS button opens a compact panel using the existing HUD theme. All four rows show the Vertical requirement, labeled **base** Cash reward and LOCKED/EQUIP/EQUIPPED state, including before unlocking. Locked takes precedence over equipped below Basic's requirement. The panel is available without a station; upgrades remain a separate interface.

One new bidirectional RemoteEvent, `EquipDunkStyle`, accepts exactly one stable ID string (maximum 32 bytes). DunkStyleService limits admitted requests to one per player per 0.35 seconds, including invalid payloads. Throttled excess requests are dropped. The non-yielding PlayerService mutation checks private data readiness, known ID, Idle dunk state, and authoritative Vertical. It updates only EquippedDunkStyle and its display attribute. No Cash, Vertical or reward is granted. Same-style equips are harmless. A request cannot select another player or switch during Attempting/Executing. The server responds with `(accepted, message, equippedId)`; the panel observes the server-written attribute, with a bounded three-second pending timeout. There is no per-frame polling or per-equip DataStore call.

F continues to send **no arguments** on RequestDunk. DunkService captures the equipped ID once, rechecks it throughout buffering, and passes it to execution. The requirement comes from that definition. All existing world/possession/airborne/approach checks remain. A completed sequence changes state to Completed, then RegisterDunk resolves the private equipped style, validates that it matches this completed attempt and is eligible, multiplies its configured base Reward by the validated court bonus, credits the rounded Cash amount once, increments the count and consumes Completed by returning to Idle. It returns the actual awarded amount. DunkService sends DunkResult(cashReward, nil, styleId) using that result and the completed style ID. Rejections retain (nil, reason). The client displays the confirmed amount and style heading rather than guessing from its current selection. Pressing F, equipping, markers and animation start never grant rewards.

## Existing Assist Preserved

Movement assistance, normalization/alignment and physical eligibility tolerances are unchanged by the early-game rebalance; the **Vertical style thresholds and base rewards** above changed through DunkStyles configuration. In particular:

- Horizontal activation: 8 studs; maximum horizontal correction: 5 studs, 2-stud rim standoff.
- Below-rim window: 8 studs. Above-rim window: min(60, 8 + jump height above the Vertical-35 reference).
- Input buffer: 0.5 seconds, only within the existing extra 3-stud vertical allowance.
- Facing allowance: 110 degrees or inward motion; reject outward velocity greater than 3 studs/second.
- Airborne: FloorMaterial Air and Jumping/Freefall. Grounded, missing ball, invalid player/rim, spoofed payloads and cooldown requests still fail.
- Cooldown: 1 second. Vertical-only normalization targets Rim.Y - 3 before the existing capped horizontal correction.

All styles use the same Vertical-35 reference for the expanding engagement ceiling, **not their own unlock threshold**. Selecting a higher style does not shrink the physical engagement window. Longer flourishes only extend their ball-phase watchdog to the larger of the existing timeout and their motion duration plus 0.45 seconds. They do not change movement assistance, cooldown or input buffering.

## Execution and Animation

`DunkExecution` retains the tested ownership handoff, ball-detachment ownership reassertion, velocity cancellation, AlignPosition/AlignOrientation, displacement bounds and protected restoration. After alignment, it uses a fixed root-centered facing frame for procedural paths. Negative local Z is toward the hoop, positive Z is behind the player; offsets are studs relative to the normalized root, not absolute jump height.

- **Basic:** keeps the direct hand-follow/above-rim/down/return path; a short right-arm extension and small torso pitch now reinforce its quick rhythm.
- **Two-Hand Power:** draws the ball to front-center `(0, 1.2, -1.5)`, loads to `(0, 2.5, -1.4)`, briefly holds, then accelerates through the rim. Both R15 arms and a small torso compression participate.
- **Tomahawk:** rises to `(1.3, 3.3, 0.6)`, cocks dramatically behind/above at `(1.6, 4.1, 3)`, holds, then whips forward/down. Right arm and torso open during the wind-up and close into the slam.
- **Windmill:** blends from hand into a 300-degree vertical elliptical sweep around `(2.1, 1.2, -0.2)` with 3.15-stud vertical/2.25-stud depth radii and an overhead hang, then exits above the rim. R15 torso lean/roll follows the arc; this is not a player 360 dunk.

`DunkStyleMotion` samples smooth waypoint segments or the actual circular path. No teleport to the first waypoint: each starts from the ball's captured held CFrame and finishes at the same above-rim endpoint. All styles use the original downward rim pass and smooth return to the current hand. The server checks possession, original character/rim, time and displacement throughout, and rewards only after successful ball return and cleanup.

`DunkPose` temporarily adds R15 arm and torso IKControls with root attachments as targets; it never writes Motor6D C0/C1/Transform, changes existing IK, or disables Animate. Weight blends in during gather and out during recovery. They and their attachments are destroyed through protected cleanup on success or cancellation. Non-R15/missing-arm rigs keep distinct ball/root motion without procedural IK. This follows Roblox's [IKControl setup](https://create.roblox.com/docs/reference/engine/classes/IKControl); visual quality still needs avatar-scale/client replication playtesting. See `GAME_FEEL.md` for the v0.2 timing comparison and acceptance test.

`DunkAnimations` has empty, independent asset slots for all four IDs. No fake IDs or uploads are required. The existing animation controller and marker hooks remain optional; markers cannot authorize completion. Future authored tracks should match the configured server timeline; disable/adjust that style's procedural Pose.Hands if it conflicts with an authored arm track.

### Interruption Safety

Execution checks readiness, original style/session, character/life/root, possession, fixed rim identity/position and existing movement bounds each Heartbeat. An error/death/reset/leave/ball loss cancels without reward. Cleanup independently attempts animation/IK/attachment/constraint destruction, movement/jump settings, ball restoration if still possessed, and original network ownership. No new persistent joint offsets, physics objects, background loops, or per-style character controllers remain. Existing default respawn behavior applies.

## Persistence: v1 to v2 Style Migration

The historical style migration to schema v2 added only `EquippedDunkStyle`; Court Progression later added v3 court fields. Court Bonuses introduced v4 fractional training carry and Dunk Challenges introduced current schema v5. The rebalance changes neither schema nor stored reward fields: Cash and equipped selection persist, while payouts derive from configuration. **Keep both DataStore names ending in `_v1` and the Player_UserId keys unchanged**: names identify the existing storage namespace, not the current record schema. Renaming them would hide existing saves.

```lua
{
    SchemaVersion = 2,
    Cash = 425,
    Vertical = 80,
    TrainingLevel = 4,
    EquippedDunkStyle = "Tomahawk",
    Revision = 2,
    WriteId = "server-generated-write-guid",
}
```

Legacy version 0 first migrates to 1. Version 1 then gains BasicOneHand and version 2 while preserving Cash, Vertical, TrainingLevel, Revision and unknown stored fields. Current v2 selections survive if known and unlocked; otherwise choose the highest unlocked style by configured order, or BasicOneHand if none are unlocked. Only the invalid selection is repaired, not the whole profile. Runtime snapshots require a valid selection and include it in equality/coalescing checks, so a style-only change while saving is not lost.

The next normal autosave/leave/shutdown writes v2 to the same key with existing revision/WriteId protections. DataService retry, load-failure blocking, DEV isolation, deadlines and native concurrency limitations are unchanged. Do not run old schema-v1 servers alongside rollout if avoidable: they fail closed when encountering v2, not downgrade it. Back up important test data and do not reset profiles to migrate them.

## Studio Setup

1. Stop Play. Keep the existing Studio place/map; no NeighborhoodBuilder rerun or Workspace edits.
2. Start/connect Rojo and sync `default.project.json`. Expect `ReplicatedStorage.Remotes.EquipDunkStyle` and v0.2's `DunkPresentation` alongside mapped code. Workspace remains outside Rojo ownership.
3. Restart Play in the published test experience with API access already enabled. Let the existing DEV profile load. Do not change DataStore names or delete saved data.
4. Use DUNKS on the HUD; use the existing ball pickup, jump and F input. No manual UI, animations, attachments or new gameplay station are needed.

## Manual Test Matrix

Use the isolated DEV store and the same account. Existing gameplay can reach the thresholds. For exact threshold tests, keep TrainingLevel 1 in a disposable DEV profile. Use the guarded reset from DATA_PERSISTENCE.md only when you intentionally want to erase that test profile, **not for migration**. Do not assign display attributes/leaderstats expecting authority.

1. **Vertical 30-34:** all four rows locked, NEXT DUNK Basic One-Hand / 35; possessing a ball and airborne F cannot award Cash. Intended default selection does not bypass this.
2. **35:** one Basic unlock toast when crossing 35, Basic equipped/usable. Jump near rim and F: original motion, one +$20 only after completion, ball return. No unlock toast on the next tick or rejoin.
3. **50:** one Two-Hand unlock toast. Equip it (no Cash/Vertical change). Both R15 arms and centered overhead ball path differ from Basic; finish +$35. Re-equip Basic and repeat for +$20.
4. **75:** one Tomahawk toast. Equip and verify clear up/back/forward motion, +$60 completion reward and return.
5. **110:** one Windmill toast. Equip and verify the full right-side ball circle, not just an overhead Basic path, with +$100 only after completion. HUD shows actual selection and all four unlocked. No future style claims.
6. **Switching:** at 110+, perform Basic -> Two-Hand -> Tomahawk -> Windmill. Every motion must be distinguishable from side and normal third-person views. Switching during Attempting/Executing must fail. Unlocking does not auto-equip a different style.
7. **High Vertical:** repeat Basic at 35/50/75/100/150, Two-Hand at 50/75/100/150, Tomahawk at 75/100/150 and Windmill at 110/150/200. Try rising, apex and falling entries, modest left/right offsets and slightly early F. No high-jump narrow-window regression. Also test grounded, far away, running away and no-ball rejection.
8. **Locked/spoofed equip:** at 35, in the Play **client** Command Bar run `game.ReplicatedStorage.Remotes.EquipDunkStyle:FireServer("Windmill")`. It must reject with a requirement message, retaining Basic. Test unknown string, table, extra argument and local EquippedDunkStyle/Vertical display tampering: server eligibility and saves must not change.
9. **Persistence:** at 75+ equip Tomahawk, record all four fields, leave/save and rejoin. All values and Tomahawk selection restore; no historical unlock toast. Repeat with an equip shortly before leaving/while autosave is active. Loaded style performs its actual motion.
10. **Migration:** use an existing v1 DEV profile without resetting it. Record Cash/Vertical/TrainingLevel before sync; after v2 join they match exactly and intended Basic initializes. Leave/save/rejoin and confirm selection persistence. Do not deliberately corrupt live records; malformed/locked-ID fallback is also covered by isolated validation.
11. **Interruption:** reset/die during each style, leave mid-motion, and in a disposable Play session delete the held ball or temporarily remove Rim. Expect no cancelled reward, no stale constraints/IK/attachments, restored walking/jumping, Idle state and normal respawn/pickup. Restore deleted Studio objects by stopping Play, not by replacing authored map assets.
12. **Spam/isolation:** spam F and equip clicks. At most one active dunk and one configured style reward per completion; style never changes mid-dunk. Multiple players can equip/dunk independently. Check no accumulating IK instances after 20 cycles.
13. **UI/regression:** 1920x1080, 1366x768, 960x540 and 800x600; resize during Play. DUNKS, all rows, requirements and close fit. Selection closes on reset/Escape. Hold training through multiple thresholds (including several in one gain): finite one-time queued unlocks, no repeated toasts or UI growth. Existing HUD stats/hint/success, upgrade opening/purchasing, no training Cash, prices, jump height and map all remain correct.

## Validation Boundary

### Reward Adjustment Playtest

Stop Play, sync Rojo and restart; no new remote or save reset is needed. Use a private DEV profile at Neighborhood, release training and record Cash before each attempt. For each eligible equipped style, verify exactly one completion delta: Basic $20, Two-Hand $35, Tomahawk $60, Windmill $100. At High School instead verify $25/$44/$75/$125. Confirm the success heading and **actual** amount match the Cash delta, the ball returns, and Vertical is unchanged. The locked/unlocked menu rows and equipped HUD must label the **base** amounts, not imply they are High School payouts. See `COURT_BONUSES.md` for the complete bonus matrix.

For **each style**, spam F during execution (one award only), try grounded/far/no-ball attempts (zero), and reset during motion before completion (zero). Switch styles between completed dunks and repeat; switching while busy must fail. At Vertical 35, request Windmill through EquipDunkStyle and spoof the local equipped attribute: no unlocked Windmill and no $100 reward. Request an unknown ID, a table or extra reward argument: reject. RequestDunk must still accept no payload: `game.ReplicatedStorage.Remotes.RequestDunk:FireServer("Windmill", 100)` from the client cannot award anything. Plain F afterward still uses the authoritative equipped style. Rejoin after saving: Cash and equipped selection restore without a new saved reward field.

Check success text and the two-line equipped progress footer at 1920x1080, 1366x768 and a smaller window. High School now requires 75 Vertical / $6,000; training timing remains unchanged while efficiency/prices are rebalanced. Its Studio-built sign needs the edit-only builder refresh described in `COURT_PROGRESSION.md`.

Reward-adjustment validation: main Rojo and both builder projects build; all 44 source/tool Luau files compile. 132 isolated checks execute current modules with mocked Roblox services: 51 persistence/court/UI/reward checks and 81 motion/validation/cleanup checks. Coverage includes exact per-style awards, one-shot completion, forged/locked IDs, all-style F spam, interruption, high-Vertical samples at both courts, displayed headings/amounts, menu rewards and equipped earnings. Protected progression, upgrade/court configuration, DunkExecution and persistence source remain unchanged in this adjustment. No real DataStore was modified; harness/tooling stays outside the repository.

Rojo packaging and Luau compilation plus isolated mocked tests are local checks, not live physics/rendering/DataStore acceptance. In particular arm reach varies with avatar proportions, and the procedural ball is not a physically simulated basketball. R6 retains ball-only style presentation. Full uploaded animation artistry, R6 arm posing, full profile session locking, and competitive movement anti-cheat are outside this milestone. Run the Studio matrix before calling the new styles playtested.
