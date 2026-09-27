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

The prototype starts genuinely new players at Vertical 30, Cash 0, and TrainingLevel 1. Each valid training tick (approximately every 0.5 seconds after an initial full interval) generates 1.00 base Vertical progress multiplied by Training Level efficiency and the current court bonus. Fractional progress carries; only whole points update Vertical and jump height. Releasing stops training. Training gives no Cash. At Neighborhood, completed Basic One-Hand dunks pay $20; High School Basic pays $25. Purchases do not directly grant Vertical or change tick timing. Cash, Vertical, TrainingLevel and fractional progress persist across sessions; gameplay waits for safe loading. The unchanged jump curve is `7.2 * (Vertical / 30)^1.7` studs. Basic Dunk unlocks at server Vertical 35 and retains its forgiving airborne engagement/height normalization. See `BASIC_DUNK_ASSIST.md`.

Cash is the primary progression currency. Currently only server-validated completed dunks award Cash. Training Level accelerates training; High School access is the first permanent court purchase. Events and cosmetic spending remain deferred.

### Training Level (Early-Game Rebalance v0.1)

| Level | Training efficiency | Cost to reach level |
| --- | --- | --- |
| 1 | 1.00x | Starting level |
| 2 | 1.10x | $250 |
| 3 | 1.20x | $600 |
| 4 | 1.30x | $1,200 |
| 5 | 1.40x | $2,000 |
| 6 | 1.50x | $3,500 |
| 7 | 1.60x | $5,500 |
| 8 | 1.70x | $8,000 |
| 9 | 1.80x | $12,000 |
| 10 | 2.00x | $18,000 (maximum) |

All prices/multipliers and the starting level live in UpgradeConfig; ProgressionConfig owns the 1.00 base progress. Server state owns TrainingLevel and Cash; the station panel displays confirmed current/next efficiency and price. TrainingLevel does not add another leaderboard column. See `TRAINING_UPGRADES.md` for setup and tests. These prototype values require a fresh-player pacing playtest.

## Courts

Court #1, **The Neighborhood**, remains the starting outdoor half-court. Its playtested 60 x 55 stud surface, 130 x 120 park, logical Rim and existing gameplay objects remain unchanged. See `NEIGHBORHOOD_V01.md` for the existing environment builder.

Court #2, **High School Gym**, requires at least 75 Vertical and costs $6,000 once. Vertical is not deducted. Purchased access persists permanently. The DUNK HIGH gym has hardwood, markings, bleachers, banners, scoreboard, lights and local versions of the same gameplay stations. Its logical floor-to-rim height matches Neighborhood; the jump curve and gameplay objects are unchanged. High School grants 1.25x Cash from completed dunks and 1.15x Vertical training progress. Neighborhood remains 1.00x for both. Neighborhood training ends at 75 Vertical and High School training ends at 150; these limits never reduce an existing player's stat. These prototype values live in CourtConfig.

**Vertical clearance rule:** Superhuman jump progression must not be capped by indoor court scenery. Indoor courts are built tall enough that a jump at the court's training cap stays indoors (High School 150-stud roof, College 300-stud roof), and their roofs, doorway headers, beams, lights and signs stay non-collidable anyway. Future College, Pro Arena and other indoor courts should keep presentation-only overhead geometry non-collidable/non-queryable above gameplay, without changing the Vertical jump curve.

Physical portals are the primary unlock/discovery flow. After purchasing, E or the COURTS menu travels freely to unlocked courts. Travel clears basketball possession and incompatible station sessions, and waits for any dunk to finish. The selected court persists and determines rejoin/respawn placement, with safe Neighborhood fallback. Both environments share one Place but are separated by 2,400 studs. See `COURT_PROGRESSION.md` for setup and `COURT_BONUSES.md` for bonus math/tests. Further courts remain deferred.

## Dunk System

The dunk system should combine player movement, jump timing, proximity to the basket, and eligible dunk styles. It should feel physical and satisfying, while the server validates every attempt and determines success, rewards, and competition scoring. The first prototype will deliberately keep this system narrow.

Dunk v0.2 preserves the playtested airborne entry zone and input buffer. Players acquire one visible basketball from BasketballPickup, jump near DunkHoop.Rim, and press F. Automatic dribbling moves that ball between hand and floor while grounded; jumping gathers it into the hand before dunk execution takes control. A valid entry starts server-owned alignment and a style-specific ball-through-rim sequence, then restores the ball to the hand. Only completed execution awards Cash and confirms success to the UI; Basic pays $20 at Neighborhood or $25 at High School. Vertical is unchanged; actual jumping determines entry capability. Possession remains after success but is lost on death. Training is suspended during execution. Shooting, physical rim/net simulation, and competition scoring remain deferred.

Dunk v0.3 adds presentation to this same basic dunk: smooth server-side facing toward the basket from the player's approach side, hand-follow gather motion, and an optional BasicOneHand animation definition. No asset is supplied; the scripted execution remains the fallback. Markers support presentation hooks but do not determine success or rewards. Entry requirements and the playtested Vertical progression remain unchanged.

### Dunk Styles v0.1

The current playable content includes Basic One-Hand at 35 Vertical, Two-Hand Power at 50, Tomahawk at 75, and Windmill at 110. Unlocks derive from whole Vertical; players select any unlocked style through DUNKS. Base rewards are $20/$35/$60/$100 respectively. On confirmed completion the server multiplies the base by the validated current court's Dunk Cash bonus and rounds to whole Cash. The menu and equipped HUD label **base** rewards; completion feedback displays the actual court-adjusted payout. Rewards are read from centralized DunkStyles/CourtConfig, never saved as a redundant field. Selection is saved as a stable EquippedDunkStyle ID. Basic is the initial intended selection, but remains locked at the new player's Vertical 30. New unlocks do not automatically change the equipped style.

All styles retain the same forgiving entry/assist and high-Vertical normalization. Their differences are procedural ball paths and temporary R15 arm posing, not tighter input windows: direct one-hand, centered two-hand power, up/back tomahawk, and a full windmill ball circle. No uploaded animations are needed. See `DUNK_STYLES.md` for tuning, migration and tests.

Game Feel v0.2 separates the styles through post-validation rhythm and physical presentation: Basic is quick/direct, Two-Hand has a centered load and forceful pass, Tomahawk has a pronounced behind-the-body wind-up, and Windmill has a larger circular sweep/brief hang. Temporary R15 torso and arm IK follows the server-driven ball; the same entry validation and high-Vertical normalization still apply. Local anticipation/impact cues are secondary to observable motion and never determine success.

### Dunk Animation System v1

All four styles now have optional R15 AnimationTrack slots. None has a published asset ID bundled with the repository; the v0.2 procedural pose/ball presentation remains the default. When a legitimate accessible R15 clip is configured, it controls avatar pose only while the server still drives root alignment, style-specific ball path, Rim contact, success, rewards, and challenges. Client-readiness reports and Gather/Slam/Release/Recover markers are presentation signals, never eligibility or Cash authority. The server-observed ball crossing is the impact hook; completed `DunkResult` is the reward/celebration hook. Tracks are cached per character and stopped on interruption, while fallback IK is disabled during a real track to avoid competing poses. `DUNK_ANIMATIONS.md` documents authoring and mixed-mode tests. BasketballService now owns hand possession, grounded dribble, jump gather, dunk handoff, and recovery transitions; see `DRIBBLING.md`.

### Game Feel & Juice v0.1

Completed dunks now use a short style-weighted impact: Basic One-Hand 0.7, Two-Hand Power 0.9, Tomahawk 1.1, and Windmill 1.3 relative presentation intensity. The camera pulse, rim-local flash, style name, and Cash popup occur only after the server confirms completion; the popup uses the actual court-adjusted payout, not the style's base reward. The HUD gives small, reusable gain/pulse feedback from replicated whole-number stats. Training feedback remains light enough for a half-second tick and shows only actual whole Vertical gained. Confirmed upgrades, threshold crossings, court purchases/travel, possession, and button interactions have brief feedback rather than large cinematics. Audio categories are prepared but silent until approved assets are supplied. These effects do not change eligibility, physics, rewards, or progression; see `GAME_FEEL.md` for tuning and comfort limits.

## Competitive Events

Future dunk contests and competitive events will let players enter structured rounds, perform within rules and time limits, and earn server-calculated results. Events may include public contests, scheduled activities, and limited-time challenges.

## Leaderboards

Leaderboards will surface durable achievements such as event wins, seasonal performance, and major progression milestones. They should reward healthy competition without becoming a source of client-trusted or manipulable game state.

## Custom HUD v0.1

The Neighborhood HUD presents Cash, Vertical, and Training Level in compact left-side cards with charcoal panels, white numbers, muted labels, and restrained blue/green accents. The default Roblox PlayerList is hidden locally; its server-owned leaderstats are retained as display mirrors. Training Level has a separate replicated display attribute, not a new leaderboard column.

The compact dunk progress area shows the actual equipped style and next locked milestone from the four-style configuration. Below 35 it shows NEXT DUNK / Basic One-Hand; after all four unlock it says ALL CURRENT DUNKS UNLOCKED. Bars remain bounded. These are progression gates, not guaranteed success: possession, airborne approach and server validation still apply. DUNKS opens selection, and a one-time toast announces thresholds crossed in-session, never historical unlocks on load.

Stat gains briefly rise/fade in their own cards, and confirmed Training Level increases show LEVEL UP! A contextual F keycap/DUNK hint appears only with possession and is hidden during execution. Completion feedback uses the **actual** server-confirmed payout: Neighborhood Basic/Two-Hand/Tomahawk/Windmill show +$20/+$35/+$60/+$100; High School shows +$25/+$44/+$75/+$125. Training feedback uses the actual whole Vertical gained per tick. COURTS displays each court's bonuses. The upgrade panel shows current/next efficiency multipliers from server snapshots. No high-Vertical dunk assist or map behavior changes. See `CUSTOM_HUD.md` for UI history and `COURT_BONUSES.md` for current bonus rules.

## Data Persistence v0.1

Cash, Vertical, TrainingLevel, EquippedDunkStyle, UnlockedCourts, CurrentCourt and VerticalTrainingRemainder persist. The server loads, migrates/validates, then initializes the existing private player state; the HUD, actual jump height, equipped style, upgrade affordability, training gain and court spawn use those restored values. The remainder is private, bounded fractional training progress that stays with the player across court travel and rejoin; only whole Vertical unlocks styles. Character respawn retains loaded progression. Ball possession, current dunk state, court-transition state and the session dunk counter are not persisted.

Native DataStoreService uses schema version 10 in the same separate Studio/production stores. Existing migrations are retained; v3 -> v4 initializes VerticalTrainingRemainder, v4 -> v5 initializes challenge progress v5 -> v6 adds the Rebirths count v6 -> v7 adds the Daily rewards record v7 -> v8 adds lifetime leaderboard Stats v8 -> v9 adds Dunk Contest stats and v9 -> v10 adds the Locker, without resetting any existing progression. Invalid court selections fall back safely; significant court purchases and challenge claims request a serialized priority save alongside periodic/leave/shutdown saves. Failed loads never grant writable fallback profiles. Revision checks are not full session locks; outages/crashes or concurrent sessions can still lose unsaved progress. See `DATA_PERSISTENCE.md`, `COURT_BONUSES.md`, and `DUNK_CHALLENGES.md`.

## Dunk Challenges v0.1

Seven configured, one-time objectives add goals without new currencies: 10 completed Basic One-Hand dunks ($150), 15 Two-Hand Power ($350), 15 Tomahawk ($600), 20 Windmill ($1,000), 60 Vertical ($300), 120 Vertical ($800), and 25 completed High School dunks of any style ($1,500). The total optional one-time claim pool is **$4,700**. Requirements and rewards are prototype balance values, not confirmed pacing results.

The server records progress only from a completed rewarded dunk or authoritative Vertical. One High School dunk can advance its style objective and the High School objective together. Progress caps at the configured target. Reaching a target makes the reward **Ready to Claim**, not paid; an explicit validated CLAIM pays Cash once and marks it **Completed**. Existing saved Vertical can satisfy Vertical goals on join, but historical dunk counts do not exist and start at zero after migration. The CHALLENGES menu previews locked styles/courts, displays progress/rewards, and highlights claimable objectives. Completion and claim use distinct client-only feedback. See `DUNK_CHALLENGES.md` for the state flow and acceptance matrix.

## Cosmetics

Cosmetics will let players customize their athlete, clothing, accessories, effects, and dunk presentation. Cosmetics should not provide unbounded competitive advantages and must remain separate from core progression rules.

## Future Monetization

Potential monetization includes cosmetic items, optional convenience products, game passes, and event-related offerings. Any future purchase flow must use Roblox platform validation and server-side entitlement checks. Monetization design is deferred until the core loop is enjoyable and balanced.

## MVP Scope

The playable foundation includes two courts, four dunk progression styles, training, server-owned Cash, Training Level upgrades, custom HUD and persistence. Court Bonuses v0.1 adds High School earning/training advantages and schema-v4 fractional carry. Automatic dribbling and court-specific 75/150 Vertical training limits are implemented in code; their Studio acceptance and fresh-player pacing run remain. College Arena (Court #3), Rebirth, Daily rewards/streaks/challenges, global leaderboards, the timed Dunk Contest and the Locker (shoes and ball skins) are implemented and play-tested with starting values; see `COLLEGE_ARENA.md`, `REBIRTH.md`, `DAILY_REWARDS.md`, `LEADERBOARDS.md`, `DUNK_CONTEST.md` and `LOCKER.md`. Events, advanced cosmetics, courts beyond College and monetization remain later milestones.

## Explicitly Deferred

- Courts beyond College Arena and court-specific rules beyond the current bonuses and training limits.
- Bracketed/seasonal dunk contest formats beyond the timed server-wide rounds, and seasonal events.
- Additional persistent progression categories and cross-server leaderboard systems.
- Cosmetic inventory, trading, and extensive avatar customization.
- Game passes, developer products, and other monetization.
- Advanced social systems, clans, matchmaking, and spectating.
- Uploaded audio assets, advanced VFX, replay, and cinematic presentation beyond the restrained v0.1 feedback.
