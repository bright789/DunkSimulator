# Dunk Simulator

Dunk Simulator is a Roblox basketball simulator built around athletic progression, high-impact dunks, unlockable courts, and competitive events.

The first development phase establishes a maintainable Rojo project foundation. Gameplay systems are intentionally not implemented yet.

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

Project foundation only. No gameplay, remotes, persistence, or monetization systems exist yet.
