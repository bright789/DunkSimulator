# Game Design

## Game Overview

Dunk Simulator is a hybrid Roblox basketball simulator and competitive progression game. Players develop an athlete through training, use improved abilities to execute satisfying dunks, earn cash, unlock more demanding courts, and eventually enter competitive events.

## Target Gameplay Experience

The game should feel responsive, readable, and grounded in basketball fundamentals while allowing exaggerated, rewarding athletic growth. Early play should make basic dunks accessible; long-term play should make higher verticals, advanced dunk styles, prestige courts, and competition meaningful goals.

## Core Gameplay Loop

1. Train to improve athletic attributes.
2. Use those attributes to perform dunks.
3. Earn cash from successful performance and activities.
4. Spend cash on upgrades and unlocks.
5. Access new courts and more difficult opportunities.
6. Compete for recognition, rankings, and higher-value rewards.

## Player Progression

Players build a basketball athlete over time. Initial progression focuses on understandable foundational attributes such as vertical, strength, stamina, and dunk ability. Upgrades should produce visible gameplay improvements while retaining enough challenge for skillful play to matter.

## Vertical Progression

Vertical is a marquee stat. It increases a player's reachable height and broadens which dunk opportunities are available. Growth should be measurable and exciting, but later upgrades should require more commitment so court and event progression stays meaningful.

## Cash and Economy Concept

The prototype starts genuinely new players at Vertical 30, Cash 0, and TrainingLevel 1. Holding the trainer interaction grants Vertical based on TrainingLevel every approximately 0.5 seconds after an initial full interval. Releasing stops training. Training no longer gives Cash. Completed basic dunks give exactly $25, which can buy the next Training Level. Purchases do not directly grant Vertical or change tick timing. Cash, Vertical, and TrainingLevel now persist across sessions; gameplay waits for safe loading. The jump curve remains `7.2 * (Vertical / 30)^1.7` studs; Basic Dunk now explicitly unlocks at server Vertical 35 and uses a progression-scaled airborne engagement window plus height normalization. Higher jumps in the 35-100 prototype range no longer have to pass through a fixed tiny rim-height band; ordinary jump progression remains unchanged. See `BASIC_DUNK_ASSIST.md`.

Cash is the primary progression currency. Currently only server-validated completed dunks award Cash. The first spend is Training Level: TRAIN -> DUNK -> CASH -> UPGRADE -> TRAIN FASTER. Future court access, events, and cosmetic spending are deferred.

### Training Level v0.1 (Prototype Balance)

| Level | Vertical per tick | Cost to reach level |
| --- | --- | --- |
| 1 | +1 | Starting level |
| 2 | +2 | $100 |
| 3 | +3 | $300 |
| 4 | +4 | $750 |
| 5 | +5 | $1,500 |
| 6 | +6 | $3,000 |
| 7 | +7 | $6,000 |
| 8 | +8 | $12,000 |
| 9 | +9 | $25,000 |
| 10 | +10 | $50,000 (maximum) |

All prices/gains and the starting level live in UpgradeConfig. Server state owns TrainingLevel and Cash; the station panel displays confirmed current/next values and purchase feedback. TrainingLevel does not add another leaderboard column. See `TRAINING_UPGRADES.md` for setup and tests. These values require playtesting and are not final economy balance.

## Courts

Court #1, **The Neighborhood**, is a compact Studio-built outdoor half-court with one existing hoop, entrance spawn, nearby basketball pickup, sideline VerticalTrainer, and non-interactive neighborhood scenery. Its playtested 60 x 55 stud playing surface and 130 x 120 park retain the tested floor-to-rim height: Vertical 30 remains below normal dunk capability, around 35 is the first basic dunk milestone, and 40+ is increasingly comfortable. The v0.1 editor builder creates permanent court markings, visual hoop, stations, fencing and a lightweight neighborhood backdrop; see `NEIGHBORHOOD_V01.md`. Reserve space for future stations and Court #2 without implementing either. This environment changes presentation and organization, not progression, rewards, or dunk rules.

Courts provide distinct progression spaces with different hoop heights, access requirements, rewards, presentation, and challenge. The first court will support the MVP. Additional courts should create aspirational goals rather than duplicate the same activity with only different visuals.

## Dunk System

The dunk system should combine player movement, jump timing, proximity to the basket, and eligible dunk styles. It should feel physical and satisfying, while the server validates every attempt and determines success, rewards, and competition scoring. The first prototype will deliberately keep this system narrow.

Dunk v0.2 preserves the playtested airborne entry zone and input buffer. Players acquire one visible basketball from BasketballPickup, jump near DunkHoop.Rim, and press F. A valid entry starts a roughly 0.75-second server-owned sequence: subtle horizontal alignment, scripted ball motion above and down through the rim, then restoration to the hand. Only completed execution awards +25 Cash and confirms success to the UI. Vertical is unchanged; actual jumping determines entry capability. Possession remains after success but is lost on death. Training is suspended during execution. Dribbling, shooting, physical rim/net simulation, uploaded dunk animations, and competition scoring remain deferred.

Dunk v0.3 adds presentation to this same basic dunk: smooth server-side facing toward the basket from the player's approach side, hand-follow gather motion, and an optional BasicOneHand animation definition. No asset is supplied; the scripted execution remains the fallback. Markers support presentation hooks but do not determine success or rewards. Entry requirements and the playtested Vertical progression remain unchanged.

## Competitive Events

Future dunk contests and competitive events will let players enter structured rounds, perform within rules and time limits, and earn server-calculated results. Events may include public contests, scheduled activities, and limited-time challenges.

## Leaderboards

Leaderboards will surface durable achievements such as event wins, seasonal performance, and major progression milestones. They should reward healthy competition without becoming a source of client-trusted or manipulable game state.

## Custom HUD v0.1

The Neighborhood HUD presents Cash, Vertical, and Training Level in compact left-side cards with charcoal panels, white numbers, muted labels, and restrained blue/green accents. The default Roblox PlayerList is hidden locally; its server-owned leaderstats are retained as display mirrors. Training Level has a separate replicated display attribute, not a new leaderboard column.

The compact Basic Dunk progress bar uses the existing configured unlock threshold (currently 35). Below it, the HUD shows NEXT GOAL and current/required Vertical; at or above it, the HUD shows UNLOCKED. This describes progression eligibility, not a guaranteed successful attempt: possession, airborne approach, and all current server validation still apply. NEXT STYLE / Coming Soon explicitly distinguishes future content; no additional usable dunk styles are claimed or implemented.

Stat gains briefly rise/fade in their own cards, and confirmed Training Level increases show LEVEL UP! A contextual F keycap/DUNK hint appears only with possession and is hidden during execution. DUNK! / +$25 appears only after the existing server-confirmed completion event. The upgrade panel shares the HUD styling without changing purchases. No gameplay, high-Vertical dunk assist, economy, or map behavior changes. See `CUSTOM_HUD.md` for sync and resolution/regression tests.

## Data Persistence v0.1

Only Cash, Vertical, and TrainingLevel persist. The server loads, migrates/validates, then initializes the existing private player state; the HUD, actual jump height, upgrade affordability, and training gain use those restored values. Character respawn retains loaded progression. Ball possession, current dunk state, and the session dunk counter are not persisted.

Native DataStoreService uses schema version 1, separate Studio/production stores, periodic autosaves, and leave/shutdown saves. A failed load never grants a writable fallback profile. Revision-checked saves reduce stale-write risk but are not a full session lock; crashes/outages or concurrent sessions can still lose unsaved progress. See `DATA_PERSISTENCE.md` for safety boundaries and tests. No new progression fields, prices, rewards, or dunk rules are introduced.

## Cosmetics

Cosmetics will let players customize their athlete, clothing, accessories, effects, and dunk presentation. Cosmetics should not provide unbounded competitive advantages and must remain separate from core progression rules.

## Future Monetization

Potential monetization includes cosmetic items, optional convenience products, game passes, and event-related offerings. Any future purchase flow must use Roblox platform validation and server-side entitlement checks. Monetization design is deferred until the core loop is enjoyable and balanced.

## MVP Scope

The MVP focuses on one court, basic movement and jumping, one reliable dunk interaction, a small training and progression loop, server-owned cash, a simple upgrade path, and readable UI. Persistence v0.1 now covers the three core progression fields; live persistence acceptance testing remains. Events, advanced cosmetics, and monetization remain later milestones.

## Explicitly Deferred

- Multiple courts and court-specific rule sets.
- Full dunk contest formats and seasonal events.
- Additional persistent progression categories and cross-server leaderboard systems.
- Cosmetic inventory, trading, and extensive avatar customization.
- Game passes, developer products, and other monetization.
- Advanced social systems, clans, matchmaking, and spectating.
- Rich audio, VFX, replay, and cinematic presentation.
