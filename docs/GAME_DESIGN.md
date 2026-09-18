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

The first playable prototype starts players at Vertical 30 and Cash 0. Holding the trainer interaction grants +1 Vertical and +5 Cash approximately every 0.5 seconds per player after an initial 0.5-second wait. Releasing stops training. Cash is visible but cannot be spent yet; all progress is session-only. The initial jump curve is `7.2 * (Vertical / 30)^1.7` studs, giving progressively exaggerated jumps without changing the default movement controls. These values require playtesting and are not final balance.

Cash is the primary progression currency. It is earned through validated gameplay performance, training activities, and future events. It funds attribute upgrades, court access, and selected cosmetic or convenience offerings. Economy values will live in configuration rather than gameplay scripts.

## Courts

Courts provide distinct progression spaces with different hoop heights, access requirements, rewards, presentation, and challenge. The first court will support the MVP. Additional courts should create aspirational goals rather than duplicate the same activity with only different visuals.

## Dunk System

The dunk system should combine player movement, jump timing, proximity to the basket, and eligible dunk styles. It should feel physical and satisfying, while the server validates every attempt and determines success, rewards, and competition scoring. The first prototype will deliberately keep this system narrow.

Dunk v0.1 is implemented as a forgiving airborne proximity check. Players acquire one visible basketball from BasketballPickup, jump near DunkHoop.Rim, and press F. The server checks possession and physical character position, then awards +25 Cash and confirms success to the UI. Vertical is unchanged; its existing effect on actual jumping determines reach. Possession remains after success but is lost on death. Dribbling, shooting, ball-through-rim detection, dunk animations, and competition scoring remain deferred.

## Competitive Events

Future dunk contests and competitive events will let players enter structured rounds, perform within rules and time limits, and earn server-calculated results. Events may include public contests, scheduled activities, and limited-time challenges.

## Leaderboards

Leaderboards will surface durable achievements such as event wins, seasonal performance, and major progression milestones. They should reward healthy competition without becoming a source of client-trusted or manipulable game state.

## Cosmetics

Cosmetics will let players customize their athlete, clothing, accessories, effects, and dunk presentation. Cosmetics should not provide unbounded competitive advantages and must remain separate from core progression rules.

## Future Monetization

Potential monetization includes cosmetic items, optional convenience products, game passes, and event-related offerings. Any future purchase flow must use Roblox platform validation and server-side entitlement checks. Monetization design is deferred until the core loop is enjoyable and balanced.

## MVP Scope

The MVP will focus on one court, basic movement and jumping, one reliable dunk interaction, a small training and progression loop, server-owned cash, a simple upgrade path, and a minimal UI for player feedback. Persistence, events, advanced cosmetics, and monetization are later milestones.

## Explicitly Deferred

- Multiple courts and court-specific rule sets.
- Full dunk contest formats and seasonal events.
- Persistent player data and cross-server leaderboard systems.
- Cosmetic inventory, trading, and extensive avatar customization.
- Game passes, developer products, and other monetization.
- Advanced social systems, clans, matchmaking, and spectating.
- Rich audio, VFX, replay, and cinematic presentation.
