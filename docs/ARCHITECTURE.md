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

`Remotes` contains `RequestDunk`, `DunkResult`, `TrainingUpgradeRequest`, and `TrainingUpgradeState`, declared in the project file. The vertical trainer continues to use server-side ProximityPrompt events without custom training remotes.

Workspace is deliberately absent from the project tree. Courts, hoops, spawn locations, terrain, and other map assets remain Studio-owned and must be saved in the Studio place separately. A Rojo build contains only the declared project content, not the complete playable map.

The DataModel root, ServerScriptService, StarterPlayer, StarterPlayerScripts, and ReplicatedStorage explicitly set `$ignoreUnknownInstances` to `true` to preserve children not represented by Rojo. This does not protect objects whose names and paths match source-controlled objects: those are managed by Rojo. Nested source folders have their own ownership rules; the flag is not a blanket guarantee for every descendant.

`Shared` and `Remotes` explicitly set `$ignoreUnknownInstances` to `false` because their contents belong to source control. Do not store manual Studio assets inside them; unknown children may be removed during synchronization. Source-defined objects can also be removed when deleted from the repository.

`globIgnorePaths` excludes `**/README.md`, retaining the existing source directory documentation without creating Roblox instances. See Rojo's [project format](https://rojo.space/docs/v7/project-format/) for these settings and [sync details](https://rojo.space/docs/v7/sync-details/) for file mappings.

## Studio Gameplay Object Discovery

`src/server/services/GameplayObjects.luau` centralizes map lookup for TrainingService, BasketballService, DunkService, and DunkExecution. The canonical locations are `Workspace.Gameplay.VerticalTrainer`, `Workspace.Gameplay.BasketballPickup`, and `Workspace.Gameplay.DunkHoop.Rim`. Gameplay must be a Folder; DunkHoop must be a Model and Rim a direct anchored BasePart. Station type, anchoring, prompt, distance, and player validations remain in their services.

The resolver prefers a direct child of Gameplay, falling back to the same name directly under Workspace only when that child is absent. An invalid preferred object is rejected, not replaced by a legacy fallback. A wrongly typed Gameplay container disables discovery. No recursive search finds decorative objects, and no code creates or reparents map assets. Keep names unique. Trainer/pickup still bind at startup; restart Play after edit-mode migration. Rim identity is checked throughout buffered attempts and execution, retaining cancellation on removal/replacement.

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

Each significant domain should use a focused server service instead of a single master script. The prototypes implement `PlayerService`, `DataService`, `TrainingService`, `BasketballService`, `DunkService`, and `UpgradeService`. Future services may include `EconomyService`, `CourtService`, `CompetitionService`, and `LeaderboardService`; create them only when their features require them.

## Current Vertical Prototype

- `src/server/ServerMain.server.luau` initializes PlayerService before training, basketball, dunk, and upgrade services.
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

`src/shared/Config/DunkAnimations.luau` defines only BasicOneHand, with an empty asset ID by default, R15 rig compatibility, priority, speed, fades, and marker names. `DunkAnimationController` isolates server Animator playback and marker subscriptions from DunkService. Its session provides Cue, FadeOut, and Destroy plus an optional presentation callback. Empty/incompatible IDs use the scripted fallback, and the execution never waits for asset loading or markers.

The ball follows the current right-hand placement for the first 35% of gather, then blends toward the above-rim endpoint. The existing downward/return phases remain. The optional track fades out during return and is destroyed before possession restoration. Takeoff/BallAboveRim/BallRelease/DunkComplete cues are emitted at most once from markers or the fallback timeline. They cannot advance the server completion state or award Cash. The authored clip must match the fixed server timeline; marker-driven scoring/movement is deliberately not implemented.

Studio decoration lives separately from the direct-child logical `DunkHoop.Rim` reference. Keep that reference and its tuned Position, make it invisible/non-colliding, and construct Backboard/Pole/VisualRim around it. The server remains independent of visible mesh geometry. See `DUNK_PRESENTATION.md` for exact setup, asset publication, and tests.

## Training Level Upgrades

PlayerService initializes private TrainingLevel from the validated loaded profile (canonical default 1 for a new player). TrainingService's hold validation and timer are unchanged: AwardTraining reads the player's configured level gain, adds only Vertical, and reapplies the existing jump curve. Normal training never updates Cash. BuyNextTrainingLevel uses private state, validates the next configured price/cap/affordability, and deducts Cash/increments the level without yielding. It grants no direct Vertical. RegisterDunk still awards exactly the existing configured $25.

UpgradeService resolves UpgradeStation through GameplayObjects and binds its direct prompt. Opening creates one validated per-player session (original character and single-use OfferId) but cannot purchase. Requests revalidate player membership, life, station identity/anchoring, enabled prompt, distance, optional sightline, and non-executing dunk state. Per-player processing guards, token rotation, and a 0.5-second purchase throttle prevent duplicate/replayed offers; the cooldown survives close/reopen. The server alone chooses the next level/price. Session monitoring every 0.2 seconds closes invalid contexts; purchase checks do not wait for that monitor. PlayerRemoving clears sessions and throttles.

| Remote | Direction | Contract |
| --- | --- | --- |
| TrainingUpgradeRequest | Client -> server | `"Buy", OfferId` or `"Close"`. Buy accepts no level, price, Cash, reward, target player, or extra arguments. OfferId is a replay identifier, not authority to bypass eligibility. |
| TrainingUpgradeState | Server -> requesting client | `"Open"`, `"Update"`, or `"Result"` plus snapshot; Result additionally includes safe feedback and purchase boolean. `"Close"` dismisses the panel. No server purchase listener exists on this event. |

Snapshots are copies of authoritative current level/gain/Cash and next level/gain/price/affordability, plus session token and readiness. The client never optimistically grants a level or Cash. Server-confirmed updates refresh the panel; leaderstats Cash updates at purchase. TrainingLevel remains off the leaderboard. The separate persistence service handles saving, not UpgradeService. No generic shop framework is added. See `TRAINING_UPGRADES.md` for prototype prices, setup, edge cases, and the Studio-owned UpgradeStation/builder-dressing boundary.

## Custom HUD v0.1

- `HUDController.client.luau` subscribes to the existing local player's replicated leaderstats Cash/Vertical values and the new TrainingLevel display attribute. It reads their current values after subscribing, including late arrival during startup. Unavailable values display `--`, not invented client defaults. Initial hydration does not show gain feedback.
- PlayerService mirrors private TrainingLevel into a player attribute on initialization and after a completed purchase. This is the only server addition for the HUD. Private state remains authoritative; no server code reads this attribute or leaderstats to calculate gains, purchases, or eligibility. There are no new remotes or polling requests. Individual replicated fields can arrive separately; the purchase panel still uses the existing confirmed server snapshots.
- `ui/HUDView` constructs three stat cards and the Basic Dunk progress display once, then updates properties. `ui/StatFeedback` reuses one label and at most one retained tween per card, cancelling/destroying the old tween before a replacement. There are no per-tick GUI instances, render-step loops, or progress-bar tweens. View/controller teardown disconnects owned connections, cancels startup tasks/tweens, and destroys the screen.
- `ui/UIComponents` supplies small shared native Roblox UI helpers; `HUDConfig` holds presentation colors, fonts, layout, gain timing, and progression copy. Its BasicVertical references the current DunkConfig threshold read-only; nothing in the HUD config changes eligibility or the server's configuration. Progress clamps to [0, 1] with an explicit zero-target guard.
- `DunkController` retains the same F input gate, local cooldown, zero-argument RequestDunk, and DunkResult contract. `ui/DunkView` only styles the existing possession hint, confirmed reward, and rejection messages. Death/reset hides transient feedback. UpgradeController shares the palette/helpers but retains its offer-token, pending, affordability, snapshot, close, and result behavior.
- ScreenGuis survive respawn and respect the core UI safe area. HUD cards use UIListLayout, UIPadding, and a resize-driven UIScale; panels/text use size constraints and bounded text scaling. Upgrade UI stays above HUD feedback via DisplayOrder. Only PlayerList is disabled, using a bounded startup retry; chat, menus, health, and default controls are not disabled. Leaderstats instances remain intact.

See `CUSTOM_HUD.md` for the complete file map, validation limits, and multi-resolution Studio checklist.

## Configuration

Balancing values, court definitions, reward tables, upgrade costs, and feature tuning should live in named configuration modules under `src/shared/` when safe to expose, or server-only configuration when sensitive. Gameplay services consume configuration rather than hard-code scattered values.

## Player Data

Schema version 1 persists only Cash, Vertical, and TrainingLevel. PlayerService's existing private table remains the live gameplay authority. Leaderstats/attributes remain display mirrors; clients never choose saved values or readiness. Dunks, DunkState, and possession remain transient. See `DATA_PERSISTENCE.md` for exact bounds, schema, configuration, and Studio instructions.

### Persistence Modules and Lifecycle

- `src/server/Config/DataConfig.luau`: store names/key prefix, version, validation bounds, autosave cadence, retry/deadline settings, and safe failure messages. All persistence modules stay in ServerScriptService; no new remotes or Rojo ownership changes.
- `src/server/data/PlayerDataSchema.luau`: canonical defaults imported from ProgressionConfig/UpgradeConfig, explicit unversioned/version-0 to version-1 migration, field-by-field sanitation, and strict runtime snapshot validation. Unsupported versions, invalid root structures, or corrupt revision metadata fail closed. Unknown fields survive subsequent writes.
- `src/server/data/PlayerDataStore.luau`: native uncached GetAsync and revision-checked UpdateAsync, protected calls and bounded exponential backoff/jitter, retry-idempotent write IDs, and an explicitly invoked Studio-only DEV reset helper. No per-tick reads/writes.
- `src/server/services/DataService.luau`: owns Loading/Ready/Closing/Failed lifecycle state, one save worker per UserId, a coalesced latest snapshot, and any unconfirmed in-flight snapshot/write ID. It stores persistence bookkeeping, not a second live gameplay profile.
- PlayerService.Init supplies three non-yielding adapter callbacks: Initialize creates its existing state/displays from the validated profile; Snapshot copies only its three private persistent fields; Cleanup disconnects the character connection and drops runtime state. DataService owns PlayerAdded/PlayerRemoving, autosave, and BindToClose. Existing players load in separate tasks so server startup does not block other services.

On join, DataStatus is Loading and no default runtime profile or leaderstats are published. A successful load of a missing key is the only new-profile path. Validation/initialization precede Ready. PlayerService.IsReady checks the private DataService session, so existing training, dunk reward, purchase, and pickup gates automatically reject loading/closing/failed players without retuning their services. The replicated DataStatus attribute drives only a small HUD loading message. Loaded Vertical reaches the existing applyJump path for an already spawned character or its next CharacterAdded; subsequent respawns retain the loaded state and jump curve.

Autosave requests a snapshot every 90 seconds plus up to ten seconds of jitter. PlayerRemoving/BindToClose first disable readiness, then capture a final snapshot before cleanup. If an autosave is already running, the final snapshot waits behind it on the same worker; identical snapshots coalesce. Failed calls retain the same snapshot/write ID for a later retry, since a failed response can conceal a successful backend write. A changed newer snapshot is saved only after the old outcome resolves. No transaction or UI update waits for a DataStore call.

The loader tries up to four calls with backoff and a 30-second acceptance deadline. Failure kicks safely without saving defaults. Late results cannot initialize a departed/expired session. Writes have a 20-second attempt budget, and leave/shutdown waiting is bounded to 25 seconds. Roblox requests already in flight cannot be forcibly rolled back; unconfirmed final saves warn and may lose unsaved progress. Shutdown closes profiles in parallel across players while preserving serialization within each profile.

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
