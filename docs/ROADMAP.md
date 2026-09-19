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

Status: continuous hold-to-train and its jump curve are playtested. Upgrade v0.1 selects +1 through +10 Vertical per existing 0.5-second tick from private TrainingLevel, and removes training Cash. Level 1/2 gains and no-training-Cash behavior are confirmed by playtesting. Sessions still end on release or invalid conditions; see `VERTICAL_PROTOTYPE.md` and `TRAINING_UPGRADES.md`.

## 5. Economy and Shop

Introduce validated cash rewards, upgrade pricing, and a simple server-authoritative shop flow.

Status: Training Level v0.1 is implemented and its core flow is playtested: station/UI, $100 Level 2 purchase, Cash deduction, improved training gains, insufficient-Cash rejection, and exactly +$25 per completed dunk. Levels 1-10 retain configured prices, authoritative atomic deductions, validated sessions, and replay/spam protection; persistence now saves the existing level and Cash. Broader security/max-level testing and economy balancing remain. No generic shop, inventory, or other upgrade categories are implemented. See `TRAINING_UPGRADES.md`.

## 6. Multiple Courts

Current prerequisite: Court #1, The Neighborhood, its entrance cleanup, Workspace.Gameplay migration, and UpgradeStation integration are working and playtested. The builder optionally dresses the separate Studio-owned UpgradeStation. Normal Workspace Rojo ownership and the logical Rim remain unchanged; see `NEIGHBORHOOD_V01.md`. No second court or unlock system is implemented.

Add unlockable courts with distinct requirements, reward structures, and difficulty.

## 7. Player Data Persistence

Implement versioned player profiles, DataStore save/load behavior, migration strategy, and recovery handling.

Status: Data Persistence v0.1 implementation and local validation complete: native server-only schema-v1 Cash/Vertical/TrainingLevel, canonical defaults, readiness gating, safe load failure, serialized retryable saves, autosave/leave/shutdown lifecycle, isolated DEV store, and guarded Studio reset. Rojo packaging, Luau compilation, and isolated mocked lifecycle/failure checks pass. **Live Roblox DataStore acceptance tests A-H remain required; this is not yet marked fully playtested.** Revision conflict detection is not full session locking; see `DATA_PERSISTENCE.md` for limits and follow-up work.

## 8. Competitive Events

Develop server-scored dunk contests and event rules, then add rankings and reward distribution.

## 9. UI and UX

Polish onboarding, progression visibility, menus, feedback, accessibility, and player-facing information.

Status: Custom HUD v0.1 is playtested with replicated Cash/Vertical/Training Level, Basic Dunk progress, reusable gain feedback, contextual dunk hint, and matching dunk/upgrade presentation. PlayerList is hidden locally without removing leaderstats. The current high-Vertical dunk validation/execution improvements are preserved, not retuned. Persistence adds only a lightweight loading/status label and late-data binding; its integration needs the new acceptance tests. See `CUSTOM_HUD.md`. Mobile controls and a full menu framework remain deferred.

## 10. Audio, VFX, and Polish

Add impactful animation, sound, VFX, court presentation, and performance-focused polish.

## 11. Monetization

Introduce balanced, platform-compliant cosmetics and optional convenience products after core retention is validated.

## 12. Analytics

Add privacy-conscious instrumentation for onboarding, gameplay balance, retention signals, and economy health.

## 13. Testing and Launch

Complete playtesting, exploit/security review, performance testing, release checklists, and launch preparation.
