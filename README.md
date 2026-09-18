# Dunk Simulator

Dunk Simulator is a Roblox basketball simulator built around athletic progression, high-impact dunks, unlockable courts, and competitive events.

The playable prototypes provide session-only Vertical training, a configurable jump curve, basketball possession, and server-validated dunks.

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

Players start at Vertical 30 and Cash 0. Hold E at VerticalTrainer to earn +1 Vertical and +5 Cash approximately every 0.5 seconds, starting after the first interval. Release E to stop. The server owns session validation and tick timing. Jump height updates after each reward and is reapplied on respawn. Data resets when leaving the server; no persistence is implemented.

Pick up a basketball at BasketballPickup, jump near DunkHoop.Rim, and press F. A server-confirmed dunk awards +25 Cash without changing Vertical and displays `DUNK!` / `+$25`. Possession persists after a dunk but resets on death/respawn. No dribbling, shooting, or dunk animations are implemented.

See [prototype setup and manual tests](docs/VERTICAL_PROTOTYPE.md) before pressing Play.

See [Dunk System v0.1 setup, tuning, and tests](docs/DUNK_PROTOTYPE.md) to add the pickup and hoop in Studio.

## Rojo Setup

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
| Declared in `default.project.json` | `ReplicatedStorage/Remotes` (`RequestDunk`, `DunkResult`) |

The source README files remain as directory documentation and are explicitly excluded from synchronization. `ServerMain` starts the player, training, basketball, and dunk services when the server runs.

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
