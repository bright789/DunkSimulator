# Architecture

## Overview

The project uses a Rojo-friendly split between server, client, and shared code. Gameplay authority stays on the server. The client handles player intent and presentation, while shared code contains definitions that are safe for both sides to use.

## Rojo Mapping and Ownership

`default.project.json` defines the source-controlled portion of the DataModel:

| Source | Roblox destination |
| --- | --- |
| `src/server/` | `ServerScriptService` |
| `src/client/` | `StarterPlayer/StarterPlayerScripts` |
| `src/shared/` | `ReplicatedStorage/Shared` |
| Project declaration | `ReplicatedStorage/Remotes` |

`Remotes` contains `RequestDunk`, `DunkResult`, `EquipDunkStyle`, `CourtRequest`, `CourtState`, `TrainingUpgradeRequest`, and `TrainingUpgradeState`, declared in the project file. Training and physical court purchase portals use server-side ProximityPrompt events without custom purchase/training remotes.

Workspace is deliberately absent from the project tree. Courts, hoops, spawn locations, terrain, and other map assets remain Studio-owned and must be saved in the Studio place separately. A Rojo build contains only the declared project content, not the complete playable map.

The DataModel root, ServerScriptService, StarterPlayer, StarterPlayerScripts, and ReplicatedStorage explicitly set `$ignoreUnknownInstances` to `true` to preserve children not represented by Rojo. This does not protect objects whose names and paths match source-controlled objects: those are managed by Rojo. Nested source folders have their own ownership rules; the flag is not a blanket guarantee for every descendant.

`Shared` and `Remotes` explicitly set `$ignoreUnknownInstances` to `false` because their contents belong to source control. Do not store manual Studio assets inside them; unknown children may be removed during synchronization. Source-defined objects can also be removed when deleted from the repository.

`globIgnorePaths` excludes `**/README.md`, retaining the existing source directory documentation without creating Roblox instances. See Rojo's [project format](https://rojo.space/docs/v7/project-format/) for these settings and [sync details](https://rojo.space/docs/v7/sync-details/) for file mappings.

## Studio Gameplay Object Discovery

`src/server/services/GameplayObjects.luau` centralizes explicit court lookup through CourtConfig. Neighborhood keeps its existing `Workspace.Gameplay` stations/DunkHoop.Rim and root SpawnLocation. High School uses `Workspace.Gameplay.Courts.HighSchool` for stations, DunkHoop.Rim and Spawn. Gameplay containers must be Folders, DunkHoop a Model, Rim a direct anchored BasePart. Services resolve against private PlayerService.CurrentCourt and validate station/prompt/distance/player state; no recursive first-hoop search or duplicated per-court services.

Only Neighborhood retains the temporary direct-Workspace fallback when a preferred station is absent. Invalid/duplicate preferred objects or containers fail closed; High School never falls back to Neighborhood. BindStations registers each configured court's direct prompts at startup; sessions retain their originating station and reject a mismatched current court. Restart Play after editor builds. Rim identity is checked throughout buffering/execution. Runtime discovery never creates/reparents map assets.

Permanent scenery belongs under `Workspace.Map.Neighborhood`; SpawnLocation remains directly under Workspace. Workspace stays outside Rojo. See [Neighborhood construction and migration](NEIGHBORHOOD_COURT.md) for the complete hierarchy, backup workflow, and geometry that preserves the tested jump threshold. Old root paths in prototype guides remain supported during migration.

## Neighborhood Editor Tool

`tools/neighborhood.project.json` is a separate build-only Rojo project producing `tools/NeighborhoodBuilder.rbxmx`, a Folder of five ModuleScripts. It is not included in `default.project.json` or server startup. Import it into ServerStorage and explicitly call Build.Run from the edit-mode Command Bar. SetupUpgradeStation.Run is a separate opt-in edit-mode action creating the Studio-owned gameplay station once; Build only decorates an existing station and never owns or moves it. Both reject live/Play execution. The tool does not change normal Rojo ownership, gameplay remotes, source services, or gameplay configuration.

Build handles preflight, protected installation/rollback, and explicitly owned output replacement. Config contains art-only values, Geometry makes anchored primitives, and Scenery assembles the environment. Generated folders named NeighborhoodV01 under Court, Environment, Props, Boundaries and DunkHoop are marked with a builder ownership attribute; reruns only replace matching marked folders. Unmarked conflicts fail safely. Workspace itself remains Studio-owned, including the generated Parts, and must be saved separately. This is source-controlled construction code, not bidirectional syncing of manual map edits.

Existing CourtSurface/ParkGround dimensions and top heights are retained while aligning them horizontally around the fixed Rim. Existing trainer/pickup/spawn instances are moved to the entrance layout without replacing prompts or changing gameplay properties. Rim changes only visibility; previous recognized hoop decoration is hidden rather than destroyed. The tool adjusts three Lighting properties conservatively. Complete mutation boundaries, setup, and regression tests are in `NEIGHBORHOOD_V01.md`. The runtime resolver never constructs map assets.

## Server Responsibilities

`src/server/` will contain focused services for authoritative gameplay decisions, including player state, training validation, dunk validation, rewards, court access, and future competition results. Server code owns mutable game state and makes final decisions.

## Client Responsibilities

`src/client/` will contain input handling, camera behavior, animation and visual requests, local responsiveness, and UI presentation. Client code may request an action but never grants itself cash, attributes, unlocks, purchases, or a competitive outcome.

## RemoteEvents and RemoteFunctions

Remotes will be created intentionally and documented as features are added. Use `RemoteEvent` for one-way requests or notifications and `RemoteFunction` only when a synchronous response is necessary. Every client-to-server request must have a narrow payload, rate limits where relevant, validation, and an authoritative server result. Do not expose a generic remote that accepts arbitrary rewards or state changes.

## Shared Modules

`src/shared/` will hold modules that can safely run on both server and client, such as types, immutable constants, identifiers, and non-sensitive configuration. Shared modules must not contain server secrets, direct client trust assumptions, or authoritative mutable state.

## Services

Each significant domain uses focused services rather than a master script. PlayerService/DataService own runtime/persistence; TrainingService, BasketballService, DunkService/DunkStyleService and UpgradeService own their existing gameplay. CourtService now handles progression/portal intent, with CourtTravel isolating safe arrival/spawn handling. Future economy/competition/leaderboard services should only be created when needed.

## Current Vertical Prototype

- `src/server/ServerMain.server.luau` first installs CourtService/spawn handling, then initializes PlayerService with the court-placement callback before training, basketball, dunk, and upgrade services.
- `src/server/services/PlayerService.luau` owns private session state including TrainingLevel, initializes players already present or joining, replicates display-only leaderstats, applies jump height on spawn/respawn, grants configured level-based Vertical gains (no training Cash), and cleans up departing players. Leaderstats values are never read as authority. Only server modules can call reward/purchase methods.
- `src/server/services/TrainingService.luau` resolves the anchored VerticalTrainer and its direct ProximityPrompt once at startup. It validates membership, initialized state, living character, current resolved station identity, prompt ancestry, anchored state, enabled state, server-observed distance, and optional line of sight at session start and every server Heartbeat. Missing or invalid setup warns and disables training until the next Play session.
- `src/shared/Config/ProgressionConfig.luau` holds Vertical/Cash defaults, `Training.TickIntervalSeconds` (0.5), maximum interaction distance, and the unchanged pure `GetJumpHeight(vertical)` curve. UpgradeConfig separately holds level gains/prices. Neither contains mutable player state.

Current data flow: ProximityPrompt.Triggered -> TrainingService validates and opens one session -> server Heartbeat revalidates and awards each due tick -> PlayerService updates private state, leaderstats, and Humanoid jump height. ProximityPrompt.TriggerEnded removes the session immediately when the release event reaches the server. PlayerService explicitly sets `UseJumpPower = false` and modifies `JumpHeight`, so Vertical is not used directly as JumpPower. Existing Roblox movement controls provide input; no custom client controller is needed.

Training sets `HoldDuration = 0` so pressing the input opens a session immediately. The first reward waits one full configured interval. Roblox's [TriggerEnded event](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt#TriggerEnded) reports release even for this zero-duration prompt. No hold-progress animation or custom remote is needed; the prompt text asks the player to hold.

One server Heartbeat connection manages a table with at most one session per player. Duplicate starts do nothing; stopping and restarting requires another full interval before a reward. Each tick schedules the next from the current server time, with no catch-up burst after lag. No client event directly awards a tick. Validation and award paths do not yield. Invalid conditions remove the session before any reward; its original character is retained to prevent a respawn from inheriting a held session. PlayerRemoving clears it immediately. After cancellation, a fresh press is required.

The default maximum distance is 10 studs from the character root to the trainer's center. When `RequiresLineOfSight` is enabled on the server, a root-to-center raycast rejects obstructions. This may be stricter than the prompt's camera-based visibility. Physical key state cannot be proven by the server: prompt events are input intent, not trusted evidence. A modified client can misreport holding, but cannot bypass server eligibility checks, speed up ticks, or select rewards. Normal release stops future awards once its event arrives; network latency can delay that notification.

These checks protect reward decisions but do not implement movement/teleport anti-cheat: Roblox characters still use normal client-controlled movement. Future competitive results must validate movement history and outcomes independently. Reference: [Roblox client/server boundary guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary).

## Current Dunk Prototype

- `BasketballService` owns a private possession table and a massless, non-colliding orange Part welded to the R15 RightHand or R6 Right Arm. Pickup validates server membership, living character, distance, anchored station, enabled prompt, and optional line of sight. A 0.5-second server pickup cooldown limits repeated requests; existing possession cannot create another ball. Death, character removal, and departure clear possession and related connections.
- `DunkService` resolves DunkHoop.Rim through GameplayObjects on every attempt and buffered validation. It validates the current character, life, root part, private possession, anchored rim, root-to-rim horizontal and vertical distances, and airborne state (`FloorMaterial == Air` plus Jumping or Freefall). It never reads client-supplied positions or ownership.
- The server sets a one-second attempt cooldown before detailed validation, so failed requests also consume cooldown. Private PlayerService state (`Idle -> Attempting -> Executing -> Completed -> Idle`) prevents overlapping attempts throughout the 0.5-second input buffer and execution. Rejection/error returns to Idle. Waiting for a buffer/execution Heartbeat yields. Success renews cooldown for one second, and one admitted request can award only once. There are no touch-based rewards.
- Basic Dunk now requires private server Vertical >= 35 via the read-only PlayerService.GetVertical accessor. Buffered attempts retain character/rim identities and revalidate all gates each Heartbeat. Entry spans eight studs below the rim through a progression-scaled ceiling: min(60, 8 + excess jump height over Vertical 35). Only misses within three extra vertical studs can wait, for the unchanged 0.5-second deadline. Horizontal range remains eight studs; facing/retreat, possession and airborne checks are unchanged. Grounded/invalid attempts cancel and spam cannot extend expiry. See `BASIC_DUNK_ASSIST.md` for the high-Vertical root cause, normalization, safety limits and exact test matrix. Studio-only validation logging remains opt-in and throttled.
- `DunkExecution` owns temporary movement restriction, server network ownership, bounded AlignPosition guidance, server-interpolated ball motion, and protected cleanup. It returns success only after all motion phases and restoration succeed. BasketballService exposes begin/end ball-motion methods while retaining private possession. See `DUNK_EXECUTION.md` for cancellation rules and tuning.
- `PlayerService.RegisterDunk` accepts only Completed state, then adds the configured cash reward and increments the session dunk counter. It does not change Vertical or jump height. `Dunks` and `DunkState` attributes are debugging mirrors, not authority. TrainingService cancels/refuses training while Executing, and PlayerService also blocks training rewards then. The jump curve and training cadence remain unchanged; level-based gains and removal of training Cash are described below.
- `DunkController.client.luau` detects F outside processed input/text entry, shows a contextual F keycap/DUNK hint while the server's `HasBasketball` attribute is true (except during execution), and displays a brief result only on server confirmation. `ui/DunkView` owns its presentation. Client-side request throttling improves UX; the independent server cooldown is authoritative.
- `DunkConfig` holds shared, non-sensitive tuning. The server uses its own required module values. `HasBasketball` and `Dunks` attributes are display mirrors only; server decisions never read them as authority.

### Remote Contracts

| RemoteEvent | Direction | Payload | Server behavior |
| --- | --- | --- | --- |
| `RequestDunk` | Client -> server | None | Uses the engine-supplied Player; extra arguments are rejected and consume cooldown. Validates, rate-limits, and processes one attempt. |
| `DunkResult` | Server -> requesting client | Confirmed cash reward number, or nil plus rejection message | Numeric success is sent only after cash/count updates. Rejections explain validation failures without granting rewards. There is no reward-granting server listener on this event. |

The pickup binds once at startup and warns if missing; restart Play after creating/replacing it. The rim is resolved per attempt, allowing Studio tuning/replacement without cached hoop positions. Workspace stays Studio-owned; held balls are runtime objects under characters, not map assets in Rojo.

Entry is tested using the character root; execution then scripts the ball down through the rim. Physical rim collisions are not simulated. Falling into the zone counts as airborne, and repeated attempts may succeed after execution/cooldown while still airborne. There is no per-jump scoring rule. Normal character movement remains client-simulated outside execution; these checks are not full teleport/movement anti-cheat. Competitive validation is deferred.

See `DUNK_PROTOTYPE.md` for concrete tuning, setup, and manual tests. Remote direction follows [Roblox's RemoteEvent API](https://create.roblox.com/docs/reference/engine/classes/RemoteEvent).

## Dunk Presentation v0.3

`DunkExecution` uses a torque/speed-limited AlignOrientation beside AlignPosition. Its facing target comes from the server-observed horizontal root-to-rim direction. A near-zero separation retains horizontal facing. Basic Dunk first normalizes the root toward Rim.Y - 3 using a bounded vertical-only phase while the ball stays held. It cancels launch velocity, suppresses jumping, then applies the existing capped five-stud horizontal correction and unchanged ball phases/reward. Separate horizontal/vertical displacement bounds permit legitimate height correction; all saved jump/movement settings are restored. Both alignment constraints use the existing cleanup path.

`src/shared/Config/DunkAnimations.luau` defines empty-by-default R15 asset slots for all four styles, Action priority, playback speed, fades, and Gather/Slam/Release/Recover event markers. `ServerMain` initializes the server `DunkAnimationController` before player startup so each character has a server-created Animator. The client `DunkAnimationController` preloads and caches valid tracks per character and reports only presentation readiness through `DunkAnimationStatus`; the server validates the report against its current character, rig, and configured style. This advisory signal cannot validate an attempt, change ball motion, or award Cash. The server sends `AnimationStart`/fade/stop on the existing `DunkPresentation` remote after accepted alignment. The client starts its cached track with server-clock compensation; player-character animation replication should show it to observers. Invalid/unavailable assets or R6 use procedural fallback. See `DUNK_ANIMATIONS.md`.

`tools/dunkanimations.project.json` separately packages the edit-only `DunkAnimationBuilder` (`Build`, `Config`, `Poses`) as an importable `.rbxmx` Folder. Its explicit `Build.Run()` creates R15 authoring `KeyframeSequence`s in ServerStorage with cubic poses, editor markers, and no root translation; it does not touch runtime animation slots, Workspace, or gameplay. A staged replacement updates only its marked clips. The generated clips are unpublished authoring data, not client/runtime assets. See `DUNK_ANIMATIONS.md` for the import, preview, and publication workflow.

The ball follows the current right-hand placement for the first 35% of gather, then blends toward the above-rim endpoint. The downward/return phases remain server-owned. A cached client track fades during return and stops on cleanup/reset; only character removal destroys its cache. When a track is active, `DunkExecution` does not create conflicting `DunkPose` IK; if playback fails after selection, it latches IK fallback for the remainder. Marker callbacks affect only local anticipation/recovery. Server-observed Rim Contact triggers `OnDunkImpact`; the completed `DunkResult` triggers `OnDunkCompleted` and shows the actual reward. The authored clip must match the server timeline; marker-driven scoring/movement is deliberately not implemented.

Studio decoration lives separately from the direct-child logical `DunkHoop.Rim` reference. Keep that reference and its tuned Position, make it invisible/non-colliding, and construct Backboard/Pole/VisualRim around it. The server remains independent of visible mesh geometry. See `DUNK_PRESENTATION.md` for exact setup, asset publication, and tests.

`BasketballService` now owns a private per-player possession mode: Holding, Dribbling, Gathering, Dunking, or Recovering; NoBall is absence of possession. A single server Heartbeat moves the existing non-colliding ball at a bounded 30 Hz while grounded. It disables the existing hand weld and anchors that ball during dribble, then eases it back to the hand on jump/attempt and re-enables the weld. `BeginDunkMotion` hands that same ball to DunkExecution's existing server-owned path; `EndDunkMotion` restores the weld and recovery mode. Clients hide that server ball and render the dribble, gather, held and dunk ball plus all dribble/jump/landing posing locally (`PresentationController`, see `MOVEMENT_PRESENTATION.md`); the server no longer creates dribble IK. The server-owned `BasketballAction` attribute is presentation-only; possession checks still use the private table. Death, reset, court travel and leave destroy the ball and pose. See `DRIBBLING.md`.

## Dunk Styles v0.1

`DunkStyles` centralizes four stable IDs, order, requirements, base style rewards ($20/$35/$60/$100), ball timings/paths and IK grip parameters. Basic references existing DunkConfig entry/timing values. Base reward amounts live only in DunkStyles; the obsolete generic DunkConfig.DunkCashReward was removed. All assist/normalization values stay unchanged. Unlocks are pure `Vertical >= RequiredVertical`; only EquippedDunkStyle is stored. PlayerService owns that private selection plus a display-only attribute. The default BasicOneHand selection is unusable below 35.

`DunkStyleService` handles the single new bidirectional EquipDunkStyle event: one string ID in; accepted/message/current ID out. One non-yielding handler per admitted request validates shape, rate limit (0.35 seconds), private readiness, Idle dunk state, existence and Vertical. No client reward, destination or unlock claims are accepted. Switching during attempts/execution is rejected. F remains the existing no-payload RequestDunk; DunkService captures the current ID, revalidates it through buffering, and passes it to DunkExecution. RegisterDunk verifies Completed/selection/eligibility, resolves the private equipped definition and a validated current court bonus, credits the rounded final Cash reward, then consumes Completed to prevent duplicate registration. It returns the credited amount; DunkResult carries (amount, nil, completedStyleId), so UI headings and amounts describe that completed dunk, even if selection later changes. Invalid requests never choose a reward.

`DunkStyleMotion` implements waypoint/elliptical ball paths and per-style body/height/finish curves after the unchanged movement alignment. Basic retains the hand-follow path. `DunkPose` owns temporary R15 arm and torso IK target attachments only in fallback mode, blended and destroyed on completion/cancellation; no Motor6D offsets or Animate changes. Non-R15 rigs retain distinct ball/root motion without IK. DunkExecution retains all protected restoration/ownership logic and checks readiness/style/session throughout. Completion still requires rim pass, ball return, validation and successful cleanup. `DunkAnimations` offers empty optional asset slots for each ID; no marker or client animation grants success.

`DunkStylesController` is a focused client module owned by HUDController. It observes Vertical and EquippedDunkStyle/DataStatus/DunkState, submits equip intent, and drives `DunkStylesView`. The HUD shows current equipped/next locked milestone, with a bounded progress bar. One reusable toast and a queue bounded by four one-time thresholds handle unlock feedback; initial hydration marks historical unlocks silently. Views are built once, connections/tasks are cleaned on controller teardown, and pending equip UI has a timeout. Upgrade UI contracts are unchanged.

Persistence schema v2 adds EquippedDunkStyle to PlayerService snapshots, strict schema validation, snapshot equality and UpdateAsync writes. Version 0 -> 1 -> 2 migration preserves existing three fields and adds BasicOneHand. Invalid/locked IDs deterministically recover to the highest unlocked ID or intended Basic if none. DataStore names/keys, revision/write IDs and DataService lifecycle are unchanged; no redundant unlock booleans, extra per-equip writes or default-profile bypass. See `DUNK_STYLES.md` for the complete contracts, rollout and test matrix.

## Court Progression v0.1

CourtConfig defines stable IDs, order, requirements, direct gameplay/spawn paths and portal edges. Neighborhood remains the starting court; HighSchool requires 75 Vertical and a one-time $6,000 purchase. Only Cash is deducted. Unlocks are persistent entitlements, unlike dunk styles' Vertical-derived unlocks.

PlayerService owns private UnlockedCourts, CurrentCourt and transient CourtTransition. CourtService validates physical portal identity, source court, prompt, proximity/line of sight, data readiness, living character, Idle dunk state, target availability and request rate. BuyCourt performs the configured private-state deduction/unlock without yielding. CourtRequest exposes only Read and Travel intent; there is no remote purchase-from-anywhere action. CourtState returns per-player snapshots/feedback. COURTS shows progress and travels only to already unlocked courts; HUD/portal labels never authorize an action.

CourtTravel resolves the server destination, checks arrival clearance and rejects travel during a dunk. It gates progression, ends training/upgrade sessions, clears the ball, positions the current character, clears velocity and updates CurrentCourt/RespawnLocation. After profile Ready and on CharacterAdded, bounded same-character readiness checks place the player at saved CurrentCourt. Unavailable saved destinations fall back to Neighborhood without removing unlocks; unavailable starting spawns fail safely. Jump restoration retains the existing loaded-Vertical code.

HighSchoolBuilder is a separate edit-only four-ModuleScript package. It creates missing gameplay objects once without scenery ownership, and replaces only its fully marked scenery roots. It never runs from ServerMain. High School is 2,400 studs away in the same Place; Neighborhood's hierarchy/Rim and Rojo's unmapped Workspace boundary remain intact. See `COURT_PROGRESSION.md` for the complete hierarchy, builder command, security contracts, files and acceptance tests.

HighSchoolBuilder's scenery source sets the visual `Ceiling` and `DoorHeader` non-collidable; the shared Geometry helper also makes those presentation Parts non-touchable and non-queryable. Roof beams, lights, banners and scoreboard parts already use the same decorative defaults. Gym floor, perimeter walls, landing and bleachers retain collision. Rebuild the edit-only package and rerun it in Studio to replace only owned scenery; normal Rojo sync never modifies Workspace. Future indoor court builders should apply the same Vertical clearance rule rather than limiting player jump progression. Both indoor builders also size the room to the court's training cap: `Build.Run` compares `CeilingHeight` with `ProgressionConfig.GetJumpHeight(cap) + JumpHeadroom` and refuses to build a room the cap jump would leave.

`CourtConfig.TrainingVerticalCap` now defines 75 for Neighborhood and 150 for High School, independent of saved Vertical. `PlayerService.AwardTraining` resolves the private current court and unlock map, rejects ticks at/above its cap, clamps a crossing tick to the cap, and preserves its sub-point remainder for future training at a higher court. Higher existing Vertical and its remainder are untouched on return to a lower court. `TrainingService` ends the hold session and sends a throttled server-to-client `TrainingCapNotice`; `HUDView` renders brief contextual feedback. Court caps are not saved, so schema v5 and native DataStore safety remain unchanged. See `COURT_TRAINING_CAPS.md`.

## Court Bonuses v0.1

CourtConfig is the canonical source of each court's `DunkCashMultiplier` and `TrainingMultiplier`. `Courts.GetBonuses(privateCurrentCourt, privateUnlockedCourts)` accepts only a known, unlocked court; otherwise it supplies Neighborhood's 1.00x values. High School supplies 1.25x dunk Cash and 1.15x training progress. No client CurrentCourt attribute, UI calculation, or RemoteEvent value authorizes these bonuses. Future configured courts can use the same server award paths without new training/dunk services.

After a completed, eligible dunk, PlayerService computes `math.floor(style.Reward * DunkCashMultiplier + 0.5)` for nonnegative Cash and returns the credited amount to DunkService's confirmed result event. The DUNKS menu and equipped HUD explicitly label the style's **base** reward; success feedback uses the actual awarded amount. The existing Completed-to-Idle guard still prevents duplicate rewards.

For every valid training tick, PlayerService multiplies `ProgressionConfig.Training.BaseProgressPerTick` (1.00) by the private TrainingLevel efficiency (1.00x–2.00x) and validated court `TrainingMultiplier` and private `VerticalTrainingRemainder`. Progress is quantized to millionths of a Vertical point, accumulated in integer units, and only whole points update Vertical, jump height and HUD feedback. The remainder remains in `[0, 1)` and follows the player across courts. Neighborhood with a zero remainder has its exact prior gain. Thresholds and jump physics continue to use whole Vertical. See `COURT_BONUSES.md`.

## Training Level Upgrades

PlayerService initializes private TrainingLevel from the validated loaded profile (canonical default 1 for a new player). TrainingService's hold validation and timer are unchanged: AwardTraining reads the player's configured base gain, applies the validated court multiplier/fractional carry, adds only whole Vertical, and reapplies the existing jump curve. Normal training never updates Cash. BuyNextTrainingLevel uses private state, validates the next configured price/cap/affordability, and deducts Cash/increments the level without yielding. It grants no direct Vertical. RegisterDunk awards the court-adjusted style reward only after validated completion; Neighborhood Basic pays $20.

Early-Game Rebalance v0.1 changes only configuration/award arithmetic: UpgradeConfig now supplies per-level efficiency multipliers and prices; DunkStyles supplies thresholds/base rewards; CourtConfig supplies the High School purchase requirement; ChallengeConfig supplies objective targets/rewards. PlayerService applies `base progress × level efficiency × validated court training multiplier`, retaining the existing millionth-unit fractional carry. TrainingUpgradeState now sends `TrainingMultiplier` and `NextMultiplier` instead of whole-point gains, so the purchase UI does not imply a fixed visible gain each tick. Existing private state, purchase security, hold cadence, jump curve, dunk validation/execution, and persistence flow are unchanged.

Schema v5 and the DataStore names remain unchanged: TrainingLevel is still an integer, and challenge records still use stable IDs with `{Progress, Completed}`. On load, unclaimed saved challenge progress is retained below the new target; completed/claimed entries remain claimed and normalize their displayed progress to the new target without repaying. Reached-Vertical objectives also reevaluate saved whole Vertical on data-ready. Persisted court unlocks remain permanent even though the new purchase gate is higher. A saved equipped style below its new Vertical requirement uses the existing deterministic style fallback. See `DUNK_CHALLENGES.md` and `EARLY_GAME_REBALANCE.md`.

UpgradeService resolves UpgradeStation through GameplayObjects and binds its direct prompt. Opening creates one validated per-player session (original character and single-use OfferId) but cannot purchase. Requests revalidate player membership, life, station identity/anchoring, enabled prompt, distance, optional sightline, and non-executing dunk state. Per-player processing guards, token rotation, and a 0.5-second purchase throttle prevent duplicate/replayed offers; the cooldown survives close/reopen. The server alone chooses the next level/price. Session monitoring every 0.2 seconds closes invalid contexts; purchase checks do not wait for that monitor. PlayerRemoving clears sessions and throttles.

| Remote | Direction | Contract |
| --- | --- | --- |
| TrainingUpgradeRequest | Client -> server | `"Buy", OfferId` or `"Close"`. Buy accepts no level, price, Cash, reward, target player, or extra arguments. OfferId is a replay identifier, not authority to bypass eligibility. |
| TrainingUpgradeState | Server -> requesting client | `"Open"`, `"Update"`, or `"Result"` plus snapshot; Result additionally includes safe feedback and purchase boolean. `"Close"` dismisses the panel. No server purchase listener exists on this event. |

Snapshots are copies of authoritative current level/efficiency/Cash and next level/efficiency/price/affordability, plus session token and readiness. The client never optimistically grants a level or Cash. Server-confirmed updates refresh the panel; leaderstats Cash updates at purchase. TrainingLevel remains off the leaderboard. The separate persistence service handles saving, not UpgradeService. No generic shop framework is added. See `TRAINING_UPGRADES.md` for prototype prices, setup, edge cases, and the Studio-owned UpgradeStation/builder-dressing boundary.

## College Arena and Rebirth

College is a third `CourtConfig` entry resolved through the same explicit `Gameplay.Courts.<Id>` paths, travel, unlock, bonus and cap code as the High School; no court service changed. Its map comes from the edit-only `CollegeBuilder` package (4,800 studs out), which also adds the High School's `CollegePortal` bus stop. See `COLLEGE_ARENA.md`.

`RebirthService` owns the `RebirthRequest`/`RebirthState` remotes (no client numbers, cooldowns, one request in flight). It moves the player home with `CourtTravel.Move`, then `PlayerService.ApplyRebirth` re-validates and resets atomically. `RebirthConfig` multipliers are applied inside `PlayerService` (dunk Cash, air-trick Cash, training), so no other service trusts or computes them. Schema v6 adds the `Rebirths` integer. See `REBIRTH.md`.

`DailyService` owns the `DailyRequest`/`DailyState` remotes and the server calendar (UTC days from `os.time()`). It rolls each player's three daily challenges, advances them from `DunkService`/`TrainingService` events, and pays claims through `PlayerService.GrantCash`. The live `Daily` record sits in PlayerService state (schema v7), and DailyService is its only writer. The Cash Boost multiplier is applied inside PlayerService's dunk and trick payouts. See `DAILY_REWARDS.md`.

`LeaderboardService` is write/read-only toward OrderedDataStores and has no remotes. It writes PlayerService's lifetime `Stats` (schema v8) with throttling and on leave, and reads the top 10 every minute. It merges in live stats and publishes JSON attributes on `ReplicatedStorage.Leaderboards`. `LeaderboardPresentation` draws them on builder-made panels tagged `LeaderboardPanel`. See `LEADERBOARDS.md`.

`ContestService` runs the Dunk Contest schedule and has no client-to-server remotes. It judges each completed dunk handed over by DunkService (style, server slam rating, the air tricks actually paid). It publishes the round state as attributes on `ReplicatedStorage.Contest`, and at the buzzer it pays through `PlayerService.GrantCash` and records contest stats (schema v9). See `DUNK_CONTEST.md`.

`LockerService` owns `LockerRequest`/`LockerState` (read, buy by id, equip by id). It spends Cash through `PlayerService.SpendCash` and welds equipped sneakers to the character's feet as massless, non-colliding parts. It sets the `BallSkin` attribute that the clients' `BallPresentation` renders. The shoe bonus is applied in `PlayerService.AwardDunkTrick`. Schema v10 adds the `Locker` record. See `LOCKER.md`.

`MonetizationService` checks game-pass ownership server-side (`UserOwnsGamePassAsync`, plus the `PromptGamePassPurchaseFinished` result) into PlayerService's unsaved `Passes`, then applies the effects: 2x Cash in PlayerService, 2x Daily in DailyService, VIP Locker items and tag. It handles developer products in `ProcessReceipt`, claiming each PurchaseId in a receipts DataStore before granting so retries never double-pay. See `MONETIZATION.md`.

## Custom HUD v0.1

- `HUDController.client.luau` subscribes to the existing local player's replicated leaderstats Cash/Vertical values and the new TrainingLevel display attribute. It reads their current values after subscribing, including late arrival during startup. Unavailable values display `--`, not invented client defaults. Initial hydration does not show gain feedback.
- PlayerService mirrors private TrainingLevel into a player attribute on initialization and after a completed purchase. This is the only server addition for the HUD. Private state remains authoritative; no server code reads this attribute or leaderstats to calculate gains, purchases, or eligibility. There are no new remotes or polling requests. Individual replicated fields can arrive separately; the purchase panel still uses the existing confirmed server snapshots.
- `ui/HUDView` constructs three stat cards, equipped/next dunk progress and DUNKS access once, then updates properties. `ui/StatFeedback` reuses one label and at most one retained tween per card, cancelling/destroying the old tween before a replacement. There are no per-tick GUI instances, render-step loops, or progress-bar tweens. View/controller teardown disconnects owned connections, cancels startup tasks/tweens, and destroys the screen.
- `ui/UIComponents` supplies small shared native Roblox UI helpers; `HUDConfig` holds presentation colors, fonts, layout, gain timing, and progression copy. Milestones come from DunkStyles; nothing in HUD config changes eligibility or the server's configuration. Progress clamps to [0, 1] with an explicit zero-target guard.
- `DunkController` retains the same F input gate, local cooldown, zero-argument RequestDunk, and DunkResult contract. `ui/DunkView` only styles the existing possession hint, confirmed reward, and rejection messages. Death/reset hides transient feedback. UpgradeController shares the palette/helpers but retains its offer-token, pending, affordability, snapshot, close, and result behavior.
- ScreenGuis survive respawn and respect the core UI safe area. HUD cards use UIListLayout, UIPadding, and a resize-driven UIScale; panels/text use size constraints and bounded text scaling. Upgrade UI stays above HUD feedback via DisplayOrder. Only PlayerList is disabled, using a bounded startup retry; chat, menus, health, and default controls are not disabled. Leaderstats instances remain intact.

See `CUSTOM_HUD.md` for the complete file map, validation limits, and multi-resolution Studio checklist.

## Game Feel & Juice v0.1–v0.2

The v0.1 feedback layer is client-only and additive. `src/shared/Config/FeedbackConfig.luau` is the single tuning source for relative dunk intensity, short UI/camera durations and limits, and optional audio IDs/volumes. It contains no reward or gameplay balance values. `src/client/FeedbackController.luau` routes presentation cues; `CameraFeedback.luau` applies a bounded, short local camera response; `FeedbackAudio.luau` owns one reusable local Sound per configured category and remains silent for blank IDs. A small local BillboardGui ring at the current court's Rim is presentation-only, auto-removed, and never moves the logical Rim. v0.1 used no new remote or server service.

The existing server `DunkResult` is the sole trigger for a *successful* dunk title and actual awarded Cash popup; v0.2's server-observed Contact cue may play physical impact before reward confirmation, but F input alone cannot produce either. A rejected result only shows its reason. `TrainingUpgradeState` with `purchased == true` triggers purchase feedback; `CourtState`'s confirmed unlock ID and CurrentCourt change drive court unlock/arrival titles. The server-owned `HasBasketball` attribute drives the hint/pickup cue. Replicated leaderstats Vertical/Cash and TrainingLevel attribute drive HUD stat pulses; positive Vertical deltas are the actual whole points awarded, including fractional-carry bonus ticks. In-session threshold crossings from those values drive dunk-unlock toasts, not historical values on join. These replicas control presentation only; server services never read client presentation state.

Views create screens/cards once. Stat feedback and button responses reuse a bounded tween/UIScale per control. Hint/result/toast/arrival tweens cancel when replaced or reset. Rim bursts use Debris; no permanent particle emitter or per-tick GUI creation exists. v0.2 also starts short RenderStepped camera anticipation cues after server acceptance; these disconnect after their configured duration or on interruption. Prior camera FOV/Humanoid CameraOffset are restored unless another script changed them in the meantime. Reset/character removal cancels transient effects. Training audio is throttled independently of training's server cadence. See `GAME_FEEL.md` for the exact effect configuration, empty-ID audio setup, and Studio acceptance matrix.

### v0.2 Dunk Differentiation

Style motion/timings now live in `DunkStyles`, sampled by `DunkStyleMotion` and applied only after `DunkService` accepts an unchanged valid entry. Server-driven root/ball motion and temporary R15 IK replicate to observers; R6 retains ball/root differences. `DunkExecution` sends owning-client-only `DunkPresentation(styleId, moment)` for Gather/Windup/Slam anticipation and server-observed Rim Contact. This event has no server listener, cannot grant rewards, and may be absent during a partial sync without cancelling the dunk. Contact may trigger local impact visuals/audio; `DunkResult` alone confirms completion and actual Cash after ball return. Client `FeedbackController` selects short per-style `CameraFeedback` profiles, local rim streaks and optional `FeedbackAudio` sound hooks; it never moves logical Rim geometry. Camera controls are bounded and stop on reset, repeated cues replace older ones, Debris cleans the burst, and server cleanup destroys IK/physics resources. No economy, persistence, court/map, eligibility, assist, or input-buffer changes are made. See `GAME_FEEL.md` for before/after motion values and the HUD-hidden comparison test.

## Configuration

Balancing values, court definitions, reward tables, upgrade costs, and feature tuning should live in named configuration modules under `src/shared/` when safe to expose, or server-only configuration when sensitive. Gameplay services consume configuration rather than hard-code scattered values.

## Player Data

Schema version 4 persists Cash, Vertical, TrainingLevel, EquippedDunkStyle, UnlockedCourts, CurrentCourt and VerticalTrainingRemainder. PlayerService's private table remains the live authority. Leaderstats/attributes remain display mirrors; clients never choose saved values/readiness or remainder. Dunks, DunkState, CourtTransition and possession are transient. Version 3 -> 4 initializes fractional carry to zero while retaining all earlier fields; malformed carry is repaired independently. See `DATA_PERSISTENCE.md` and `COURT_BONUSES.md`.

### Persistence Modules and Lifecycle

- `src/server/Config/DataConfig.luau`: store names/key prefix, version, validation bounds, autosave cadence, retry/deadline settings, and safe failure messages. All persistence modules stay in ServerScriptService; no new remotes or Rojo ownership changes.
- `src/server/data/PlayerDataSchema.luau`: canonical defaults imported from progression/style/court/challenge config, explicit legacy -> v1 -> v2 -> v3 -> v4 -> v5 migration, field-by-field sanitation, and strict runtime snapshot validation. Unsupported versions, invalid root structures, or corrupt revision metadata fail closed. Unknown unrelated top-level fields survive subsequent writes; challenge records retain configured IDs and bounded integer progress/claim flags. A finite carry in `[0, 1)` is rounded to configured millionths; malformed values become zero without resetting other fields.
- `src/server/data/PlayerDataStore.luau`: native uncached GetAsync and revision-checked UpdateAsync, protected calls and bounded exponential backoff/jitter, retry-idempotent write IDs, and an explicitly invoked Studio-only DEV reset helper. No per-tick reads/writes.
- `src/server/services/DataService.luau`: owns Loading/Ready/Closing/Failed lifecycle state, one save worker per UserId, a coalesced latest snapshot, and any unconfirmed in-flight snapshot/write ID. It stores persistence bookkeeping, not a second live gameplay profile.
- PlayerService.Init supplies non-yielding Initialize/Snapshot/Cleanup callbacks and deferred Ready callbacks for challenge initialization and court placement. Snapshot copies all persistent fields, including separate unlock/challenge maps and private training remainder. DataService owns PlayerAdded/PlayerRemoving, autosave and BindToClose. Existing players load in separate tasks so startup does not block other services. IsDataReady checks the private loaded session; IsReady additionally requires no active court transition.

On join, DataStatus is Loading and no default runtime profile or leaderstats are published. A successful load of a missing key is the only new-profile path. Validation/initialization precede Ready. PlayerService.IsReady checks the private DataService session, so existing training, dunk reward, purchase, and pickup gates automatically reject loading/closing/failed players without retuning their services. The replicated DataStatus attribute drives only a small HUD loading message. Loaded Vertical reaches the existing applyJump path for an already spawned character or its next CharacterAdded; subsequent respawns retain the loaded state and jump curve.

Autosave requests a snapshot every 90 seconds plus up to ten seconds of jitter. PlayerRemoving/BindToClose first disable readiness, then capture a final snapshot before cleanup. If an autosave is already running, the final snapshot waits behind it on the same worker; identical snapshots coalesce. Failed calls retain the same snapshot/write ID for a later retry, since a failed response can conceal a successful backend write. A changed newer snapshot is saved only after the old outcome resolves. No transaction or UI update waits for a DataStore call.

The loader tries up to four calls with backoff and a 30-second acceptance deadline. Failure kicks safely without saving defaults. Late results cannot initialize a departed/expired session. Writes have a 20-second attempt budget, and leave/shutdown waiting is bounded to 25 seconds. Roblox requests already in flight cannot be forcibly rolled back; unconfirmed final saves warn and may lose unsaved progress. Shutdown closes profiles in parallel across players while preserving serialization within each profile.

Successful court unlocks call DataService.RequestSave. This throttled priority request queues a validated snapshot through the same serialized worker, not a second DataStore writer. It does not guarantee immediate durability or block purchase feedback. CurrentCourt/unlock changes participate in snapshot equality; subsequent travel is persisted by the existing autosave/leave/shutdown lifecycle. Store names and concurrency safety remain unchanged.

### Dunk Challenges v0.1

`ChallengeConfig` is the shared read-only definition table (stable IDs, order, requirement type/parameters, target, Cash reward); it contains no mutable player state. PlayerService owns each loaded player's private `Challenges[id] = { Progress, Completed }` alongside Cash/Vertical and performs the non-yielding claim transition. `ReadyToClaim` is derived from `Progress >= target and not Completed`, not saved separately. `ChallengeService` applies three small handlers: `DunkStyleCount` and `CourtDunkCount` consume only a successful server dunk, while `VerticalReached` samples private Vertical after valid training and once after data loads. Progress caps and completed entries stop mutating. `DunkService` reports successful style/court after `RegisterDunk`; `TrainingService` reports after the existing award. Neither gameplay service contains challenge rewards.

`ChallengeRequest` accepts a challenge ID for CLAIM or zero arguments for a throttled state read. `ChallengeState` sends a copy of that player's progress and any newly ready IDs/confirmed claim result. IDs, readiness, per-player processing/cooldown and the configured reward are checked server-side; Cash and Completed change together without yielding before `DataService.RequestSave` queues a priority snapshot. The client never submits progress, style, court, reward, or success. Invalid/duplicate claims cannot pay again. The CHALLENGES panel is a reusable scrolling native UI; readiness and badge are display-only. A separate reusable `RewardPresentation` presents ready-versus-claimed feedback, with optional silent-until-configured audio hooks. No Workspace/map ownership changed.

Schema v5 adds sanitized challenge records to the existing store names and UpdateAsync snapshot, preserving all v4 fields. v4 migration starts dunk counts at zero because no historical counter was saved; loaded Vertical goals are evaluated retroactively without a historic unlock toast. Autosave and final saves persist progress, claims request throttled priority saves, and the existing native cross-server conflict/session-lock limitation still applies. See `DUNK_CHALLENGES.md`.

### Native Concurrency Boundary

Each record includes Revision and WriteId metadata. UpdateAsync accepts only the revision this session loaded/last confirmed, or an exact retry of its own already-committed write. Different newer revisions abort the write and disable/kick the stale session. Callback work does not yield or grant rewards. This is optimistic conflict detection, **not profile session locking**: two servers may load the same revision and play before either saves. First writer wins; the other session can lose unsaved progress. UpdateAsync alone does not provide exclusive ownership. Lease/session-lock acquisition, recovery, and teleport handoff remain follow-up work before production-scale concurrency demands it.

## Security and Server Authority

The server verifies eligibility, positions, cooldowns, attribute requirements, ownership, prices, and rewards. It ignores client-provided totals and outcome claims. A client can ask to start training or attempt a dunk; it cannot declare the training reward, dunk success, cash balance, upgrade purchase, or contest score.

## Planned Data Flow

1. The client collects input and submits a narrow action request.
2. The server validates the player, action context, cooldowns, and rules.
3. The relevant server service updates authoritative runtime or player data.
4. The server sends a sanitized result or state update to the affected client(s).
5. The client updates UI, animation, camera, and effects from that result.

## Persistence Follow-up

The native v0.1 boundary now handles core progression. Complete live Studio/private-server acceptance tests, then design full session locking, operational recovery/version rollback, and explicit migrations when new persisted fields are actually needed. Do not add speculative inventories/unlocks to the current schema or use DataStore as a live gameplay database.
