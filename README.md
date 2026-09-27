# Dunk Simulator

Dunk Simulator is a Roblox basketball simulator built around athletic progression, high-impact dunks, unlockable courts, and competitive events.

The playable prototypes provide persistent progression and court selection, a configurable jump curve, basketball possession, and four server-validated dunk styles. Neighborhood is the starting court; High School Gym is a permanent progression unlock.

## Project Layout

- `src/server/` — authoritative gameplay services and server-only logic.
- `src/client/` — input, camera, presentation, and UI-facing logic.
- `src/shared/` — safe-to-share modules, types, constants, and configuration.
- `docs/` — game design, architecture, and delivery roadmap.

## Development Principles

- The server owns rewards, progression, purchases, and competitive outcomes.
- Client code requests actions and renders feedback; it does not decide game state.
- Modules stay small and focused so new systems are easy to test and extend.

## Documentation

- `docs/GAME_DESIGN.md` describes the intended player experience and MVP.
- `docs/ARCHITECTURE.md` defines code boundaries and planned data flow.
- `docs/ROADMAP.md` sequences development milestones.

## Current Status

[Dunk Animation System v1](docs/DUNK_ANIMATIONS.md) adds optional cached R15 AnimationTracks for all four styles. **No animation asset IDs are bundled**: procedural v0.2 posing and server ball paths remain the default. Publish your own clips, place their actual IDs in `src/shared/Config/DunkAnimations.luau`, sync Rojo, and restart Play. The new `DunkAnimationStatus` remote reports presentation readiness only; it cannot grant dunks or rewards. The guide covers marker placement, first Basic clip authoring, fallback, interruption, and multiplayer checks. No map builder or profile migration is required.

`tools/DunkAnimationBuilder.rbxmx` is an optional, explicit **Studio edit-only** authoring package. Import it into ServerStorage and run `require(game:GetService("ServerStorage").DunkAnimationBuilder.Build).Run()` in the edit-mode Command Bar to generate four editable R15 `KeyframeSequence` clips under `ServerStorage.GeneratedDunkAnimations`. Its `CopyToRig` helper stages all four onto an R15 Clip Editor rig in one command. Preview/refine/publish them through the Clip Editor; the builder does **not** publish clips or invent animation IDs. [Exact authoring steps](docs/DUNK_ANIMATIONS.md) explain the R15 rig and local-save workflow. Neither Rojo sync nor game startup runs this builder.

[Early-Game Progression Rebalance v0.1](docs/EARLY_GAME_REBALANCE.md) replaces raw per-level Vertical gains with efficiency multipliers, spreads dunk/style and challenge milestones, and raises the High School unlock gate. These are prototype values, not verified session pacing; use the guide's guarded DEV reset and timed fresh-player Studio playtest. The existing High School portal **sign** needs one editor-only builder refresh after sync.

Genuinely new players start at Vertical 30, Cash 0, and TrainingLevel 1; returning players load their saved values before progression is enabled. Hold E at VerticalTrainer to gain Vertical from the TrainingLevel efficiency multiplier (1.00x–2.00x) and current court bonus applied to 1.00 base progress, with persisted fractional carry approximately every 0.5 seconds, starting after the first interval. Training gives no Cash. Release E to stop. The server owns session validation and tick timing. Jump height updates after each whole-Vertical gain and is applied after loading and on respawn.

[Data Persistence](docs/DATA_PERSISTENCE.md) saves progression through native server-side DataStoreService on leave, shutdown, and roughly every 90-100 seconds. Schema v5 adds one-time challenge progress/claims after v4's fractional training remainder; older saves migrate without resetting progression. Keep store names unchanged: Studio uses `DunkSimulator_PlayerData_DEV_v1`, separate from `DunkSimulator_PlayerData_v1`. **Before testing, publish a separate private test experience and enable File > Experience Settings (Game Settings) > Security > Enable Studio Access to API Services.** Failed loads block progression and safely kick instead of using writable defaults. No Studio settings are changed by code. The guide covers safe DEV resets, schema/limits, cross-server concurrency limitations, and tests A-H.

[Court Progression v0.1](docs/COURT_PROGRESSION.md) adds High School Gym: reach 75 Vertical and spend $6,000 once at the Neighborhood portal. Vertical is not spent. Press E again to travel, or use COURTS for free travel to unlocked courts. CurrentCourt/unlocks persist, resets return to the selected court, and travel clears the held ball. **One-time Studio builder setup is required below; syncing source alone does not create the gym.** [Court Bonuses v0.1](docs/COURT_BONUSES.md) gives High School 1.25x dunk Cash and 1.15x Vertical training; Neighborhood stays 1.00x. The server rounds completed dunk Cash to the nearest whole dollar and carries/persists fractional training progress. [Court Training Caps](docs/COURT_TRAINING_CAPS.md) limit training at 75/150 without reducing a player's existing Vertical.

[Dunk Styles v0.1](docs/DUNK_STYLES.md) provides Basic One-Hand (35 Vertical, $20 base), Two-Hand Power (50, $35 base), Tomahawk (75, $60 base) and Windmill (110, $100 base). Each has distinct procedural ball motion; new styles add temporary R15 arm IK. DUNKS previews base rewards and opens selection; the server validates equips, saves the stable ID, and F attempts that selection. Unlocks derive from Vertical. Rewards are awarded exactly once after server-confirmed completion; success feedback shows the actual court-adjusted amount, while the selection menu and equipped HUD label the base reward. Existing assist/high-Vertical normalization is unchanged. Sync and restart for the balance changes; refresh the Studio-owned High School portal sign with its edit-only builder. No new remote is required. See the guide for limitations and reward/security tests.

[Training Level upgrades](docs/TRAINING_UPGRADES.md) spend dunk-earned Cash to improve training efficiency from 1.00x to 2.00x instead of granting +1 to +10 Vertical per tick. E at UpgradeStation opens a server-confirmed panel; only clicking UPGRADE requests a purchase. See the guide for the one-time station setup, builder refresh, full price table, and security/regression checklist.

[Custom HUD v0.1](docs/CUSTOM_HUD.md) displays replicated Cash, Vertical, Training Level, and Basic Dunk progress in compact Neighborhood-styled cards. It hides PlayerList without deleting leaderstats, styles the existing dunk/upgrade feedback, and makes no gameplay or tuning changes. Stop Play, sync Rojo, and restart Play; no map rebuild or manual UI assets are needed.

[Game Feel & Juice v0.1](docs/GAME_FEEL.md) adds short, client-only impact/camera feedback, actual-reward popups, stat pulses, unlock and court-arrival titles, a smooth ball-possession hint, and button responses. Existing server confirmations and replicated stats drive these effects; no gameplay, economy, or Workspace assets change. Audio hooks are silent until you configure real, permitted sound IDs in `src/shared/Config/FeedbackConfig.luau`. Stop Play, sync Rojo, then restart Play; no map rebuild or new Studio objects are needed.

[Game Feel & Juice v0.2](docs/GAME_FEEL.md) makes the four dunk styles physically distinct through configured gather/slam timing, ball paths, small root movement, and temporary R15 arm/torso IK. The new `DunkPresentation` remote provides server-timed anticipation and physical Rim-contact cues only; completed rewards still come exclusively from `DunkResult`. Sync Rojo and restart Play to add that remote; no map rebuild is needed. Audio remains silent until real permitted per-style IDs are configured. The guide includes a 20-dunk HUD-hidden Studio comparison that remains necessary for visual acceptance.

[Dunk Challenges v0.1](docs/DUNK_CHALLENGES.md) adds seven one-time objectives totaling $4,700 in optional claimable Cash. The server tracks completed style/court dunks and authoritative Vertical, while the CHALLENGES menu shows progress and explicit CLAIM actions. Existing saved players retain their progression; current Vertical backfills Vertical objectives, but past dunk counts cannot be reconstructed. Sync Rojo and restart Play for the two new remotes; no map rebuild is needed. Live Studio acceptance testing is still required.

Pick up a basketball at BasketballPickup, jump near DunkHoop.Rim, and press F. [Automatic dribbling v0.1](docs/DRIBBLING.md) bounces the existing server-owned ball while grounded, gathers it on jumps, and suspends it throughout an accepted dunk. Completion awards the equipped style's base Cash amount multiplied by the selected court bonus, without changing Vertical. Feedback uses the completed style and actual awarded amount (Neighborhood Basic shows `DUNK!` / `+$20`; High School Basic shows `DUNK!` / `+$25`). Controls and held possession are restored afterward; death/respawn clears possession. Shooting and uploaded dunk animation assets are not included yet.

Use [the fresh-player playtest checklist](docs/PROGRESSION_PLAYTEST.md) after syncing code and refreshing the Studio-owned High School portal sign. It records actual milestone timing, Cash, TrainingLevel, and challenge completion; target pacing remains unverified until this run.

[College Arena](docs/COLLEGE_ARENA.md) is Court #3 (150 Vertical + $40,000, x1.6 Cash, 250 cap). [Rebirth](docs/REBIRTH.md) resets a 200-Vertical player to the Neighborhood for permanent Cash/training multipliers. [Daily rewards](docs/DAILY_REWARDS.md) add a 7-day login streak, three daily challenges and a timed 2x Cash Boost. [Global leaderboards](docs/LEADERBOARDS.md) (Top Vertical, Most Dunks, Biggest Dunk) stand next to the hoop in every gym. A timed [Dunk Contest](docs/DUNK_CONTEST.md) opens every 8 minutes: five judges score every dunk and the best scores win prizes. The [Locker](docs/LOCKER.md) sells sneakers (visible, with an air-trick Cash bonus) and ball skins (schema v10). [Robux passes](docs/MONETIZATION.md) (2x Cash, VIP, 2x Daily Rewards) and a Cash Boost product are built but off sale until you paste their ids into `MonetizationConfig`.

See [prototype setup and manual tests](docs/VERTICAL_PROTOTYPE.md) before pressing Play.

See [Dunk System v0.1 setup, tuning, and tests](docs/DUNK_PROTOTYPE.md) to add the pickup and hoop in Studio.

See [Dunk System v0.2 execution and cleanup tests](docs/DUNK_EXECUTION.md) for the new sequence. Existing Studio objects and Rojo remotes need no changes.

[Dunk v0.3 presentation](docs/DUNK_PRESENTATION.md) records smooth facing, early hand-follow ball motion, and the Parts-based visual hoop guide. For the current four-style Animation Editor/publishing workflow, use [Dunk Animation System v1](docs/DUNK_ANIMATIONS.md). Animation IDs are empty by default, so scripted dunks remain usable without uploads.

## Rojo Setup

### Court #1: The Neighborhood

Use [Neighborhood v0.1 automated setup](docs/NEIGHBORHOOD_V01.md): import the supplied `tools/NeighborhoodBuilder.rbxmx` into ServerStorage, then run `require(game:GetService("ServerStorage").NeighborhoodBuilder.Build).Run()` in Studio's edit-mode Command Bar. Save a backup first. The builder reuses the existing 60 x 55 court and 130 x 120 ground, preserves the fixed logical Rim and floor-to-rim height, and creates permanent scenery. It repositions the surfaces horizontally and the original stations/spawn into an entrance layout. Do not delete existing Map objects before running it.

Workspace remains completely outside normal Rojo ownership. The separate tool project packages editor-only modules, not a live-server generator; save the finished map in Studio. See the guide for replaceable output folders, rebuilding, and regression tests. Neighborhood's Workspace.Gameplay paths remain unchanged.

### Court #2: High School Gym

Stop Play, back up your place, sync current Rojo source, then import **`tools/HighSchoolBuilder.rbxmx`** into **ServerStorage** using Insert from File. In the edit-mode Command Bar run:

```lua
require(game:GetService("ServerStorage").HighSchoolBuilder.Build).Run()
```

Save the Studio place and restart Play. Do not delete/move existing Map or Gameplay objects, and do not rebuild Neighborhood. The tool creates the gym 2,400 studs away, missing gameplay stations/spawn once, and both portals. Reruns replace only explicitly marked scenery, not gameplay objects. It never runs at server startup. See [the complete court guide](docs/COURT_PROGRESSION.md) for ownership, safe rebuilds, migration, all changed files and the 15-test acceptance matrix.

To refresh the gym art in an existing Studio place (for example the taller 150-stud gym): stop Play, back up the place, remove **only** `ServerStorage.HighSchoolBuilder`, re-import the updated `tools/HighSchoolBuilder.rbxmx`, run the edit-mode command above, then save/publish. Gameplay objects remain where they are. Rojo sync alone does not rebuild Studio-owned map art.

### Court #3: College Arena

After the High School is built, import **`tools/CollegeBuilder.rbxmx`** into **ServerStorage** and run in the edit-mode Command Bar:

```lua
require(game:GetService("ServerStorage").CollegeBuilder.Build).Run()
```

Save the place and restart Play. It builds the arena 4,800 studs away, its gameplay stations once, and the College bus stop at the High School. See [College Arena](docs/COLLEGE_ARENA.md).

### Tools

Use Roblox Studio and the Rojo CLI with a compatible Rojo Studio plugin. The existing `rokit.toml` selects Rojo 7.7.0. If you use Rokit, run `rokit install` from the repository root to install the selected tool. See the [official installation guide](https://rojo.space/docs/v7/getting-started/installation/) for CLI and plugin setup.

Run commands from the folder containing `default.project.json`, `AGENTS.md`, and `src/`. In this workspace that is the inner `DunkSimulator` folder, not its parent.

### Start the Development Server

Check the CLI, then start the server in your terminal:

```powershell
rojo --version
rojo serve default.project.json
```

Keep this terminal open. The default connection is `localhost` on port `34872`; use the address and port printed in the terminal if they differ.

If the Rokit launcher reports a missing path, check the Rokit installation and run `rokit install` from this repository. When the selected binary is already installed, you can also invoke it directly in PowerShell:

```powershell
& "$env:USERPROFILE\.rokit\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe" serve default.project.json
```

### Connect and Synchronize Roblox Studio

1. Open your Dunk Simulator place in Studio in edit mode.
2. Open the Rojo plugin from Studio's Plugins toolbar.
3. Enter `localhost` and port `34872` (or the values printed by the server), then click Connect.
4. Review and accept the initial sync if the plugin prompts you. Expect the mapped containers below; Workspace is outside this project.
5. Save future source edits in your editor. While connected, Rojo automatically sends those changes to Studio.

The mappings are:

| Source | Studio destination |
| --- | --- |
| `src/server/` | `ServerScriptService` |
| `src/client/` | `StarterPlayer/StarterPlayerScripts` |
| `src/shared/` | `ReplicatedStorage/Shared` |
| Declared in `default.project.json` | `ReplicatedStorage/Remotes` (`RequestDunk`, `DunkResult`, `DunkPresentation`, `DunkAnimationStatus`, `EquipDunkStyle`, `CourtRequest`, `CourtState`, `TrainingUpgradeRequest`, `TrainingUpgradeState`, `TrainingCapNotice`, `ChallengeRequest`, `ChallengeState`) |

The source README files remain as directory documentation and are explicitly excluded from synchronization. `ServerMain` installs court/spawn handling, then starts the player/data lifecycle, training, basketball, dunk, and upgrade services. No environment builder runs at startup.

### Stop the Server

Disconnect in the Studio Rojo plugin, then press `Ctrl+C` in the terminal running `rojo serve`. Stopping the server stops synchronization; it does not remove the objects already synchronized into Studio.

### Basic Development Workflow

1. Read the project docs and identify the server, client, and shared files needed for your task.
2. Start Rojo and connect your Studio place.
3. Edit source files in your editor and save them to synchronize. `*.server.luau` files become server Scripts, `*.client.luau` files become LocalScripts, and ordinary `*.luau` files become ModuleScripts. Rojo also supports the `.lua` equivalents.
4. Test changes with Studio's Play tools and inspect Output for errors. Stop the play session before making map edits or reconnecting.
5. Build courts, hoops, spawn locations, terrain, and other level assets in Studio. Save the place separately: those assets are not stored by this Rojo configuration.
6. Review source changes and perform relevant validation before finishing.

Treat repository files as the source of truth for mapped code; editing their synchronized copies in Studio does not update the files. Reserve `Shared` and `Remotes` for source-controlled objects. Unknown children in those two folders may be removed during sync. Unmapped children at the service boundaries are preserved, but objects matching source-controlled names may be updated or replaced.

For a build check, write a temporary place file outside the repository:

```powershell
rojo build default.project.json --output "$env:TEMP\DunkSimulator-check.rbxlx"
```

This checks the source-controlled portion only. The generated file does not include your Studio-built map and should not replace your working place. See the [official live-sync guide](https://rojo.space/docs/v7/getting-started/new-game/) for more detail.
