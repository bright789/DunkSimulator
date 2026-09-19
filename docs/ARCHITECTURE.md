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

`Remotes` contains `RequestDunk` and `DunkResult`, declared in the project file. The vertical prototype continues to use server-side ProximityPrompt events without any custom remotes.

Workspace is deliberately absent from the project tree. Courts, hoops, spawn locations, terrain, and other map assets remain Studio-owned and must be saved in the Studio place separately. A Rojo build contains only the declared project content, not the complete playable map.

The DataModel root, ServerScriptService, StarterPlayer, StarterPlayerScripts, and ReplicatedStorage explicitly set `$ignoreUnknownInstances` to `true` to preserve children not represented by Rojo. This does not protect objects whose names and paths match source-controlled objects: those are managed by Rojo. Nested source folders have their own ownership rules; the flag is not a blanket guarantee for every descendant.

`Shared` and `Remotes` explicitly set `$ignoreUnknownInstances` to `false` because their contents belong to source control. Do not store manual Studio assets inside them; unknown children may be removed during synchronization. Source-defined objects can also be removed when deleted from the repository.

`globIgnorePaths` excludes `**/README.md`, retaining the existing source directory documentation without creating Roblox instances. See Rojo's [project format](https://rojo.space/docs/v7/project-format/) for these settings and [sync details](https://rojo.space/docs/v7/sync-details/) for file mappings.

## Studio Gameplay Object Discovery

`src/server/services/GameplayObjects.luau` centralizes map lookup for TrainingService, BasketballService, DunkService, and DunkExecution. The canonical locations are `Workspace.Gameplay.VerticalTrainer`, `Workspace.Gameplay.BasketballPickup`, and `Workspace.Gameplay.DunkHoop.Rim`. Gameplay must be a Folder; DunkHoop must be a Model and Rim a direct anchored BasePart. Station type, anchoring, prompt, distance, and player validations remain in their services.

The resolver prefers a direct child of Gameplay, falling back to the same name directly under Workspace only when that child is absent. An invalid preferred object is rejected, not replaced by a legacy fallback. A wrongly typed Gameplay container disables discovery. No recursive search finds decorative objects, and no code creates or reparents map assets. Keep names unique. Trainer/pickup still bind at startup; restart Play after edit-mode migration. Rim identity is checked throughout buffered attempts and execution, retaining cancellation on removal/replacement.

Permanent scenery belongs under `Workspace.Map.Neighborhood`; SpawnLocation remains directly under Workspace. Workspace stays outside Rojo. See [Neighborhood construction and migration](NEIGHBORHOOD_COURT.md) for the complete hierarchy, backup workflow, and geometry that preserves the tested jump threshold. Old root paths in prototype guides remain supported during migration.

## Neighborhood Editor Tool

`tools/neighborhood.project.json` is a separate build-only Rojo project producing `tools/NeighborhoodBuilder.rbxmx`, a Folder of four ModuleScripts. It is not included in `default.project.json` or server startup. Import it into ServerStorage and explicitly call Build.Run from the edit-mode Command Bar. It rejects live/Play execution. Normal Rojo ownership, remotes, source services, and gameplay configuration are unchanged.

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

Each significant gameplay domain should use a focused server service instead of a single master script. The prototypes implement `PlayerService`, `TrainingService`, `BasketballService`, and `DunkService`. Future services may include `PlayerDataService`, `EconomyService`, `CourtService`, `CompetitionService`, and `LeaderboardService`; create them only when their features require them.

## Current Vertical Prototype

- `src/server/ServerMain.server.luau` initializes PlayerService before TrainingService and emits one startup message.
- `src/server/services/PlayerService.luau` owns private session state, initializes players already present or joining, replicates display-only leaderstats, applies jump height on spawn/respawn, grants fixed training rewards, and cleans up departing players. Leaderstats values are never read as authority. Only server modules can call the reward method.
- `src/server/services/TrainingService.luau` resolves the anchored VerticalTrainer and its direct ProximityPrompt once at startup. It validates membership, initialized state, living character, current resolved station identity, prompt ancestry, anchored state, enabled state, server-observed distance, and optional line of sight at session start and every server Heartbeat. Missing or invalid setup warns and disables training until the next Play session.
- `src/shared/Config/ProgressionConfig.luau` holds defaults, fixed rewards, `Training.TickIntervalSeconds` (0.5 by default), maximum interaction distance, and a pure `GetJumpHeight(vertical)` curve. It contains no player state.

Current data flow: ProximityPrompt.Triggered -> TrainingService validates and opens one session -> server Heartbeat revalidates and awards each due tick -> PlayerService updates private state, leaderstats, and Humanoid jump height. ProximityPrompt.TriggerEnded removes the session immediately when the release event reaches the server. PlayerService explicitly sets `UseJumpPower = false` and modifies `JumpHeight`, so Vertical is not used directly as JumpPower. Existing Roblox movement controls provide input; no custom client controller is needed.

Training sets `HoldDuration = 0` so pressing the input opens a session immediately. The first reward waits one full configured interval. Roblox's [TriggerEnded event](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt#TriggerEnded) reports release even for this zero-duration prompt. No hold-progress animation or custom remote is needed; the prompt text asks the player to hold.

One server Heartbeat connection manages a table with at most one session per player. Duplicate starts do nothing; stopping and restarting requires another full interval before a reward. Each tick schedules the next from the current server time, with no catch-up burst after lag. No client event directly awards a tick. Validation and award paths do not yield. Invalid conditions remove the session before any reward; its original character is retained to prevent a respawn from inheriting a held session. PlayerRemoving clears it immediately. After cancellation, a fresh press is required.

The default maximum distance is 10 studs from the character root to the trainer's center. When `RequiresLineOfSight` is enabled on the server, a root-to-center raycast rejects obstructions. This may be stricter than the prompt's camera-based visibility. Physical key state cannot be proven by the server: prompt events are input intent, not trusted evidence. A modified client can misreport holding, but cannot bypass server eligibility checks, speed up ticks, or select rewards. Normal release stops future awards once its event arrives; network latency can delay that notification.

These checks protect reward decisions but do not implement movement/teleport anti-cheat: Roblox characters still use normal client-controlled movement. Future competitive results must validate movement history and outcomes independently. Reference: [Roblox client/server boundary guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary).

## Current Dunk Prototype

- `BasketballService` owns a private possession table and a massless, non-colliding orange Part welded to the R15 RightHand or R6 Right Arm. Pickup validates server membership, living character, distance, anchored station, enabled prompt, and optional line of sight. A 0.5-second server pickup cooldown limits repeated requests; existing possession cannot create another ball. Death, character removal, and departure clear possession and related connections.
- `DunkService` resolves DunkHoop.Rim through GameplayObjects on every attempt and buffered validation. It validates the current character, life, root part, private possession, anchored rim, root-to-rim horizontal and vertical distances, and airborne state (`FloorMaterial == Air` plus Jumping or Freefall). It never reads client-supplied positions or ownership.
- The server sets a one-second attempt cooldown before detailed validation, so failed requests also consume cooldown. Private PlayerService state (`Idle -> Attempting -> Executing -> Completed -> Idle`) prevents overlapping attempts throughout the existing 0.35-second input buffer and v0.2 execution. Rejection/error returns to Idle. Waiting for a buffer/execution Heartbeat yields. Success renews cooldown for one second, and one admitted request can award only once. There are no touch-based rewards.
- Buffered attempts retain the original character and rim identities and revalidate player state, possession, distance, and airborne state each Heartbeat. Only height misses within three extra vertical studs can wait; this extra range cannot start execution. The entry floor remains four studs below the rim and the ceiling six studs above it. Horizontal radius stays six studs. Grounded or otherwise invalid attempts cancel, and expiry cannot be extended by repeated input. No Vertical stat gate is introduced; assistance starts only after entry validation passes.
- `DunkExecution` owns temporary movement restriction, server network ownership, bounded AlignPosition guidance, server-interpolated ball motion, and protected cleanup. It returns success only after all motion phases and restoration succeed. BasketballService exposes begin/end ball-motion methods while retaining private possession. See `DUNK_EXECUTION.md` for cancellation rules and tuning.
- `PlayerService.RegisterDunk` accepts only Completed state, then adds the configured cash reward and increments the session dunk counter. It does not change Vertical or jump height. `Dunks` and `DunkState` attributes are debugging mirrors, not authority. TrainingService cancels/refuses training while Executing, and PlayerService also blocks training rewards then. The jump curve and training values are unchanged.
- `DunkController.client.luau` detects F outside processed input/text entry, shows `F - Dunk` while the server's `HasBasketball` attribute is true, and displays a brief result only on server confirmation. Client-side request throttling improves UX; the independent server cooldown is authoritative.
- `DunkConfig` holds shared, non-sensitive tuning. The server uses its own required module values. `HasBasketball` and `Dunks` attributes are display mirrors only; server decisions never read them as authority.

### Remote Contracts

| RemoteEvent | Direction | Payload | Server behavior |
| --- | --- | --- | --- |
| `RequestDunk` | Client -> server | None | Uses the engine-supplied Player; extra arguments are ignored. Validates, rate-limits, and processes one attempt. |
| `DunkResult` | Server -> requesting client | Confirmed cash reward number, or nil plus rejection message | Numeric success is sent only after cash/count updates. Rejections explain validation failures without granting rewards. There is no reward-granting server listener on this event. |

The pickup binds once at startup and warns if missing; restart Play after creating/replacing it. The rim is resolved per attempt, allowing Studio tuning/replacement without cached hoop positions. Workspace stays Studio-owned; held balls are runtime objects under characters, not map assets in Rojo.

Entry is tested using the character root; execution then scripts the ball down through the rim. Physical rim collisions are not simulated. Falling into the zone counts as airborne, and repeated attempts may succeed after execution/cooldown while still airborne. There is no per-jump scoring rule. Normal character movement remains client-simulated outside execution; these checks are not full teleport/movement anti-cheat. Competitive validation is deferred.

See `DUNK_PROTOTYPE.md` for concrete tuning, setup, and manual tests. Remote direction follows [Roblox's RemoteEvent API](https://create.roblox.com/docs/reference/engine/classes/RemoteEvent).

## Dunk Presentation v0.3

`DunkExecution` adds a torque/speed-limited AlignOrientation beside the existing AlignPosition. Its facing target comes from the server-observed horizontal root-to-rim direction. A near-zero separation retains horizontal facing. Entry checks, root translation bounds, buffer, phase duration, and rewards remain unchanged. Both alignment constraints use the existing cleanup path.

`src/shared/Config/DunkAnimations.luau` defines only BasicOneHand, with an empty asset ID by default, R15 rig compatibility, priority, speed, fades, and marker names. `DunkAnimationController` isolates server Animator playback and marker subscriptions from DunkService. Its session provides Cue, FadeOut, and Destroy plus an optional presentation callback. Empty/incompatible IDs use the scripted fallback, and the execution never waits for asset loading or markers.

The ball follows the current right-hand placement for the first 35% of gather, then blends toward the above-rim endpoint. The existing downward/return phases remain. The optional track fades out during return and is destroyed before possession restoration. Takeoff/BallAboveRim/BallRelease/DunkComplete cues are emitted at most once from markers or the fallback timeline. They cannot advance the server completion state or award Cash. The authored clip must match the fixed server timeline; marker-driven scoring/movement is deliberately not implemented.

Studio decoration lives separately from the direct-child logical `DunkHoop.Rim` reference. Keep that reference and its tuned Position, make it invisible/non-colliding, and construct Backboard/Pole/VisualRim around it. The server remains independent of visible mesh geometry. See `DUNK_PRESENTATION.md` for exact setup, asset publication, and tests.

## Configuration

Balancing values, court definitions, reward tables, upgrade costs, and feature tuning should live in named configuration modules under `src/shared/` when safe to expose, or server-only configuration when sensitive. Gameplay services consume configuration rather than hard-code scattered values.

## Player Data

Player data will be represented on the server as a versioned profile with progression, currencies, unlocks, inventory, and relevant event history. The client receives only the view of that data needed for presentation. Runtime state is separate from persistent profile data.

## Security and Server Authority

The server verifies eligibility, positions, cooldowns, attribute requirements, ownership, prices, and rewards. It ignores client-provided totals and outcome claims. A client can ask to start training or attempt a dunk; it cannot declare the training reward, dunk success, cash balance, upgrade purchase, or contest score.

## Planned Data Flow

1. The client collects input and submits a narrow action request.
2. The server validates the player, action context, cooldowns, and rules.
3. The relevant server service updates authoritative runtime or player data.
4. The server sends a sanitized result or state update to the affected client(s).
5. The client updates UI, animation, camera, and effects from that result.

## Future DataStore Architecture

Persistence will be introduced after the first playable loop is stable. A dedicated server-side data layer will load, validate, migrate, save, and reconcile versioned player profiles through Roblox DataStores. Services will request controlled data operations through that layer rather than calling DataStores directly. Save behavior, failure handling, shutdown safety, and schema migration rules must be designed before persistence is enabled.
