# Roadmap

This roadmap sequences work so the core movement and dunk experience is proven before persistence, events, and monetization add complexity.

## 1. Project Foundation

Create documentation, repository structure, Rojo conventions, and shared engineering rules.

Status: implemented, including Rojo mappings that leave Workspace assets Studio-owned.

## 2. Movement and Jump Prototype

Prototype responsive player movement and a measurable jump/vertical model without persistence or economy.

Status: jump curve implemented using existing Roblox movement controls; Studio playtesting and tuning remain. This prototype brings forward the minimal trainer and visible cash counter from milestones 4 and 5 to make progression playable. It does not implement a full economy.

## 3. First Dunk Prototype

Build one server-validated dunk interaction on one court, including clear success and failure feedback.

Status: Dunk v0.1 entry detection and v0.2 execution are playtested. Dunk v0.3 adds smooth approach-facing, hand-follow gather, and optional BasicOneHand animation/marker architecture with a scripted fallback. Presentation testing and authoring/publishing the first real asset remain; see `DUNK_PRESENTATION.md`. Multiple dunk types and physical rim/net interactions remain deferred.

## 4. Training and Progression

Add a small training loop and server-owned attribute progression that improves dunk capability.

Status: continuous hold-to-train implemented and playtested (+1 Vertical and +5 Cash per server-timed 0.5-second interval). Sessions end on release or invalid player/station conditions. Its existing jump curve naturally determines physical reach for Dunk v0.1. See `VERTICAL_PROTOTYPE.md` for setup and acceptance checks.

## 5. Economy and Shop

Introduce validated cash rewards, upgrade pricing, and a simple server-authoritative shop flow.

Status: session-only training cash rewards implemented. Spending, pricing, and shops remain deferred.

## 6. Multiple Courts

Current prerequisite: Court #1, The Neighborhood. Workspace.Gameplay migration and the gameplay loop are playtested. The Neighborhood v0.1 edit-mode builder is implemented and packaged: permanent half-court markings, hoop visuals, station dressing, fence, entrance, street and simple neighborhood props, preserving the existing Rim and tested floor height. Normal Workspace Rojo ownership is unchanged. Import/run in the working Studio place and visual/gameplay acceptance testing remain pending; see `NEIGHBORHOOD_V01.md`. This takes priority over further Dunk v0.3 presentation work. No second court or unlock system is implemented.

Add unlockable courts with distinct requirements, reward structures, and difficulty.

## 7. Player Data Persistence

Implement versioned player profiles, DataStore save/load behavior, migration strategy, and recovery handling.

## 8. Competitive Events

Develop server-scored dunk contests and event rules, then add rankings and reward distribution.

## 9. UI and UX

Polish onboarding, progression visibility, menus, feedback, accessibility, and player-facing information.

## 10. Audio, VFX, and Polish

Add impactful animation, sound, VFX, court presentation, and performance-focused polish.

## 11. Monetization

Introduce balanced, platform-compliant cosmetics and optional convenience products after core retention is validated.

## 12. Analytics

Add privacy-conscious instrumentation for onboarding, gameplay balance, retention signals, and economy health.

## 13. Testing and Launch

Complete playtesting, exploit/security review, performance testing, release checklists, and launch preparation.
