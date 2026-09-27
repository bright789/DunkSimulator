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

Status: core dunk, forgiving assist and high-Vertical normalization are playtested. Dunk Styles v0.1 implementation/local validation is complete: Basic One-Hand (35), Two-Hand Power (50), Tomahawk (75) and Windmill (110), persistent selection, derived unlocks and distinct procedural paths/temporary R15 IK. Rojo build, 31 Luau compilations and 88 isolated mocked checks pass. The new Studio matrix remains; visual/physics acceptance is not claimed from local checks. See `DUNK_STYLES.md`. Uploaded animation polish, further styles and physical rim/net interactions remain deferred.

## 4. Training and Progression

Add a small training loop and server-owned attribute progression that improves dunk capability.

Status: continuous hold-to-train and its jump curve are playtested. Upgrade v0.1 applies 1.00 base progress times private TrainingLevel efficiency (1.00x–2.00x) and removes training Cash. Court Bonuses v0.1 now multiplies that base gain by the validated court bonus, carrying/persisting fractions. The older hold/no-training-Cash behavior is playtested; the new Level 2 efficiency and overall pacing require a fresh-player test. Sessions still end on release or invalid conditions; see `VERTICAL_PROTOTYPE.md`, `TRAINING_UPGRADES.md` and `COURT_BONUSES.md`.

## 5. Economy and Shop

Introduce validated cash rewards, upgrade pricing, and a simple server-authoritative shop flow.

Status: Training Level v0.1 is implemented with a previously playtested functional purchase/training flow; the new $250 Level 2 price, 1.10x efficiency and $20 Neighborhood Basic payout require fresh balance playtesting. The style base rewards are Two-Hand $35, Tomahawk $60 and Windmill $100; Court Bonuses v0.1 now multiplies completed rewards at High School while keeping these base values unchanged. Levels 1-10 retain configured prices, authoritative atomic deductions, validated sessions, and replay/spam protection; persistence saves the level and Cash. Broader security/max-level testing and economy balancing remain. No generic shop, inventory, or other upgrade categories are implemented. See `TRAINING_UPGRADES.md` and `COURT_BONUSES.md`.

Early-Game Progression Rebalance v0.1 updates the config-driven efficiency, prices, style thresholds/rewards, High School gate and seven challenge targets/rewards after a fresh-player run cleared current content in about three minutes. The new tables build locally, but **pacing is not verified**. A fresh DEV reset and an unassisted, timed Studio playtest are required before accepting any 1–50 minute target; see `PROGRESSION_PLAYTEST.md`. That rebalance added no timers or tick-speed changes; court-specific training limits were added later as a separate milestone.

## 6. Multiple Courts

Status: Court Progression v0.1 and High School Gym are playtested. High School now requires 75 Vertical and a permanent one-time $6,000 purchase, aligning its gate with the Neighborhood training cap. Court Bonuses v0.1 adds configured 1.25x dunk Cash and 1.15x fractional Vertical training there; Neighborhood remains 1.00x. The COURTS menu presents both bonuses. Explicit per-court resolution still shares gameplay services and the editor-only builder leaves Workspace outside Rojo ownership. Court Training Caps v0.1 limits gains to 75/150 in the two courts without lowering existing stats; live Studio acceptance and a fresh timed progression run remain. See `COURT_TRAINING_CAPS.md` and `PROGRESSION_PLAYTEST.md`. College Arena (Court #3, 250 cap) is now built; see `COLLEGE_ARENA.md`. Courts beyond College remain deferred.

Environment rule for future indoor courts (College, Pro Arena and beyond): visual roofs and overhead dressing must not cap superhuman Vertical. High School (150-stud roof) and College (300-stud roof) are now tall enough that each court's cap jump stays indoors, verified in Studio, and their overhead geometry stays non-collidable. Do not change jump progression to compensate for map collision.

## 7. Player Data Persistence

Implement versioned player profiles, DataStore save/load behavior, migration strategy, and recovery handling.

Status: core persistence, Dunk Styles and Court Progression are playtested. Court Bonuses introduced schema v4's fractional training remainder; Dunk Challenges v0.1 extends it to v5 with seven bounded one-time progress/claim entries. v4 profiles migrate without resetting existing progression. Vertical objectives evaluate loaded Vertical; historical dunk counts start at zero. Court unlocks and challenge claims request throttled priority saves through the existing worker; ordinary progress uses autosave/leave/shutdown. Store namespaces and conflict handling remain unchanged, without full session locks. Studio challenge persistence/claim-spam tests are still required before release. See `DATA_PERSISTENCE.md`, `COURT_BONUSES.md`, and `DUNK_CHALLENGES.md`.

## 8. Competitive Events

Develop server-scored dunk contests and event rules, then add rankings and reward distribution.

## 9. UI and UX

Polish onboarding, progression visibility, menus, feedback, accessibility, and player-facing information.

Status: Custom HUD v0.1 is playtested with replicated Cash/Vertical/Training Level, Basic Dunk progress, reusable gain feedback, contextual dunk hint, and matching dunk/upgrade presentation. PlayerList is hidden locally without removing leaderstats. The current high-Vertical dunk validation/execution improvements are preserved, not retuned. Persistence adds only a lightweight loading/status label and late-data binding; its integration needs the new acceptance tests. See `CUSTOM_HUD.md`. Mobile controls and a full menu framework remain deferred.

Dunk Challenges v0.1 implementation adds a compact CHALLENGES panel, claimable badge, locked-style/court previews, and separate completion/claimed-reward presentations. Local build/syntax validation is complete; seven-objective playtests, saved-state migration, and claim-spam testing remain in Studio. Daily/repeatable challenges and a general quest framework remain deferred. See `DUNK_CHALLENGES.md`.

## 10. Audio, VFX, and Polish

Add impactful animation, sound, VFX, court presentation, and performance-focused polish.

Status: Game Feel & Juice v0.1 code adds server-confirmed, style-weighted dunk impact; brief client camera/FOV response; restrained local rim burst; reusable stat, unlock, arrival, and interaction feedback. Audio categories/volumes are configured but silent until real, licensed IDs are supplied. Local Luau/Rojo validation passes; Studio visual/comfort/performance testing and actual audio authoring remain. See `GAME_FEEL.md`. Uploaded animation assets, music, and advanced VFX remain deferred.

Game Feel & Juice v0.2 implementation adds style-specific post-validation gather/slam/recovery timing, larger Tomahawk/Windmill ball paths, transient R15 torso/arm IK, gentle root lift/dip, per-style local camera anticipation, and a restrained rim burst. The server retains the old eligibility/reward path. Local build/mocked regression checks pass; the 20-dunk Vertical-100 HUD-hidden Studio comparison, multiplayer IK visibility, and live reset/physics checks are required before calling the visual pass playtested. See `GAME_FEEL.md`.

**Current — Dunk Animation System v1:** Optional real R15 tracks for all four styles have empty legitimate-ID slots, per-character client caches, server-created Animators, marker/presentation hooks, and protected procedural IK fallback. Server ball/root execution and reward authority remain unchanged. Generated editable clips exist, but publication requires the experience owner's Studio account; sync/timing, high-Vertical, and multiplayer acceptance remain. See `DUNK_ANIMATIONS.md`.

**Studio authoring tool — R15 Dunk Animation Builder v1:** Generates four editable, differentiated R15 KeyframeSequences with Gather/Slam/Release/Recover markers in edit mode only. Clips are not published or configured; Clip Editor preview, polishing, legitimate asset publication, and in-game acceptance remain manual. The empty-ID procedural fallback remains in place. See `DUNK_ANIMATIONS.md`.

**Implemented in code — Dribbling v0.1:** One existing server-owned ball bounces through idle/walk/run cadences, gathers on jump or dunk attempt, and resumes after recovery. Temporary R15 IK is removed before dunk posing. Live Studio feel, replication, and interruption tests remain. See `DRIBBLING.md`.

**Implemented in code — Court Vertical Training Caps:** Server-owned 75/150 training limits, a 75-Vertical High School gate, and contextual cap feedback. Existing Vertical is never reduced. Live Studio checks remain. See `COURT_TRAINING_CAPS.md`.

**Next — Progression Playtest:** Reset the isolated DEV profile, time a fresh-player run, and re-evaluate economy/content pacing using `PROGRESSION_PLAYTEST.md`. Targets are not yet verified.

**Implemented and play-tested — College Arena + Rebirth:** Court #3 (150 Vertical + $40,000, x1.6 Cash, x1.3 training, 250 cap) with a 40-fan arena, and Rebirth (200 Vertical + $100,000 x1.6^n; permanent x(1+0.5n) Cash and x(1+0.25n) training; schema v6). All numbers are starting values for the timed pacing run. See `COLLEGE_ARENA.md` and `REBIRTH.md`.

**Implemented and play-tested — Daily rewards, streaks and daily challenges:** 7-day login ladder priced in "dunks" so it scales with progress, three eligible daily challenges from a pool of eight, and a stacking 2x Cash Boost (Day 3, Day 7, and the all-three sweep bonus). Schema v7. See `DAILY_REWARDS.md`.

**Implemented and play-tested — Global leaderboards:** Top Vertical (best ever), Most Dunks (lifetime) and Biggest Dunk (single payout) on a 3-panel stand beside the hoop in all three gyms. OrderedDataStores with throttled writes, 60 s top-10 reads and live in-server merging. Schema v8 adds lifetime Stats. See `LEADERBOARDS.md`.

**Implemented and play-tested — Dunk Contest:** server-wide 90 s rounds every 8 minutes; five judges score style, trick count/variety and slam timing (50 max); best dunk counts; tiered prizes priced in dunks plus placement bonuses; scorecard, banner and results UI; the crowd erupts for 45+. Schema v9 adds contest stats. See `DUNK_CONTEST.md`.

**Implemented and play-tested — Locker (shoes and ball skins):** six sneakers built on players' feet (+5% to +25% air-trick Cash) and six cosmetic ball skins (color, seams, trail), bought with Cash from the LOCKER menu; permanent through Rebirth. Schema v10. See `LOCKER.md`. The original feature list is now complete. A 2-player Studio test verified contest placements and cross-player Locker visuals.

**Implemented — Robux passes and products (off sale until ids are set):** 2x Cash, VIP (Diamond Kicks, Diamond ball, VIP tag) and 2x Daily Rewards passes, plus a repeatable 15-minute Cash Boost product with an idempotent ProcessReceipt. Effects were verified in Studio with `StudioOwnedPasses`. See `MONETIZATION.md`.

## 11. Monetization

Introduce balanced, platform-compliant cosmetics and optional convenience products after core retention is validated.

## 12. Analytics

Add privacy-conscious instrumentation for onboarding, gameplay balance, retention signals, and economy health.

## 13. Testing and Launch

Complete playtesting, exploit/security review, performance testing, release checklists, and launch preparation.
