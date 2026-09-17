# Architecture

## Overview

The project uses a Rojo-friendly split between server, client, and shared code. Gameplay authority stays on the server. The client handles player intent and presentation, while shared code contains definitions that are safe for both sides to use.

## Server Responsibilities

`src/server/` will contain focused services for authoritative gameplay decisions, including player state, training validation, dunk validation, rewards, court access, and future competition results. Server code owns mutable game state and makes final decisions.

## Client Responsibilities

`src/client/` will contain input handling, camera behavior, animation and visual requests, local responsiveness, and UI presentation. Client code may request an action but never grants itself cash, attributes, unlocks, purchases, or a competitive outcome.

## RemoteEvents and RemoteFunctions

Remotes will be created intentionally and documented as features are added. Use `RemoteEvent` for one-way requests or notifications and `RemoteFunction` only when a synchronous response is necessary. Every client-to-server request must have a narrow payload, rate limits where relevant, validation, and an authoritative server result. Do not expose a generic remote that accepts arbitrary rewards or state changes.

## Shared Modules

`src/shared/` will hold modules that can safely run on both server and client, such as types, immutable constants, identifiers, and non-sensitive configuration. Shared modules must not contain server secrets, direct client trust assumptions, or authoritative mutable state.

## Services

Each significant gameplay domain should use a focused server service instead of a single master script. Likely future services include `PlayerDataService`, `TrainingService`, `DunkService`, `EconomyService`, `CourtService`, `CompetitionService`, and `LeaderboardService`. These names are planning guidance, not systems to create yet.

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
