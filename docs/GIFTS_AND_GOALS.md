# Playtime Gifts and the Goal Tracker

Two "something every minute" features added on 2026-10-03 for the first five minutes (and beyond), ported in idea from Steal a Sneaker, where they made sessions longer. Neither adds saved data or a schema change. See `TUTORIAL_BADGES_ANALYTICS.md` for the live onboarding numbers they are meant to improve.

## Playtime gifts

Seven free gifts open as you keep playing. Tuning lives in `src/shared/Config/GiftConfig.luau`.

| Gift | Opens after | Reward | At 35 Vertical |
| --- | --- | --- | --- |
| 1 | 1 min | 3 dunks of Cash (min $60) | $63 |
| 2 | 3 min | 4 dunks of Cash (min $80) | $84 |
| 3 | 5 min | 2 dunks of Cash (min $40) + 3 min Cash Boost | $42 + 2x Cash 3 min |
| 4 | 8 min | 6 dunks of Cash (min $120) | $126 |
| 5 | 12 min | 8 dunks of Cash (min $160) | $168 |
| 6 | 20 min | 12 dunks of Cash (min $250) | $252 |
| 7 | 30 min | 20 dunks of Cash (min $400) + 10 min Cash Boost + a free Hype Crew pack (the best one: the biggest gift) | $420 + boost + pack |

- **"Dunks" of Cash:** one plain dunk of your best unlocked style at your Vertical (`DailyConfig.DunkValue`, like the daily rewards), so gifts stay worth opening at every stage. Cash Boost minutes go through `DailyService.GrantBoost` (stacks, 60 min max) and the crew pack through `CrewService.GrantPack` (the same free pack the Dunk Pass gives, with the normal reveal).
- **Per session (decision):** the clock starts when your data has loaded, and both the clock and the claims start over when you rejoin. Nothing is saved, so there is no schema change. The early gifts are small on purpose: rejoining to farm the 1- and 3-minute gifts pays far less than just dunking for that time (a new player earns about $20 per dunk). The crew pack only comes with the 30-minute gift.
- **HUD:** a full-width **GIFTS** button is the last row of the menu grid (the left column on desktop, the top-right block on touch). It reads `NEXT GIFT 0:42` while counting down, turns green with `GIFTS (2)` when gifts are waiting, and reads `GIFTS` once all seven are claimed.
- **Panel:** GIFTS opens a list of the seven gifts with CLAIM, a countdown, or CLAIMED. It never opens by itself, so it never stacks on the daily reward and welcome-back pop-ups at join.
- **When one opens:** a gold "FREE GIFT READY! OPEN GIFTS TO CLAIM IT" line in the action feed plus the challenge-ready sound. A claim shows a big "FREE GIFT! +$63" message and the claim sound.
- **Analytics:** Cash source `Gift_<n>` (TimedReward) and custom event `GiftClaimed` (value = gift number).

**Server rules** (`GiftService`): the server keeps each player's start time and claims in memory. A claim is accepted only when the player is in the game with loaded data, the gift number is a whole number from 1 to 7, it isn't claimed yet, and the server clock says it is open (2 s of grace for the client's countdown). One claim is processed at a time per player, with a 0.5 s claim and 1 s read cooldown; extra or malformed arguments are ignored. Cash is added first; if that fails (e.g. the Cash limit) nothing is claimed. A claim then requests a priority save.

| Remote | Direction | Payload |
| --- | --- | --- |
| `GiftRequest` | client → server | `"Read"`, or `"Claim", index` |
| `GiftState` | server → client | `(snapshot, result?)`. Snapshot: `{ StartedAt, Gifts = { { Minutes, UnlockAt, Claimed, Cash, BoostMinutes, CrewPack } } }` (times are `Workspace:GetServerTimeNow()` seconds). Result: `{ Kind = "Claimed", Index, Cash, BoostMinutes, CrewPack }` or `{ Kind = "Rejected", Message }`. |

**Studio test flag:** `GiftConfig.StudioFastGifts` (default **false**). When true, in Studio only, each gift "minute" lasts `StudioSecondsPerMinute` (5) seconds, so the whole ladder opens in 2.5 minutes; Output prints a reminder. Live servers always use real minutes. Turn it back off before publishing.

## Goal tracker

Always one next goal on screen, with a progress bar and its Cash reward, paid automatically with a short celebration the moment it's done. Tuning lives in `src/shared/Config/GoalConfig.luau`.

**Why a new chain instead of the challenges:** the existing CHALLENGES are permanent goals with rewards, but the first two a new player can work on are 10 Basic dunks and 60 Vertical, several minutes apart, and the rest need Two-Hand Power, the Tomahawk, Windmill or other courts. That is too slow for "something every minute" in the first session, and they need a manual claim in a panel. So the tracker has its own short chain, and CHALLENGES are unchanged (some milestones, like 60 Vertical, pay in both).

| # | Goal | Reward |
| --- | --- | --- |
| 1 | Land 5 dunks | 3 dunks |
| 2 | Train to 45 Vertical | 3 dunks |
| 3 | Reach 50 Vertical to unlock Two-Hand Power | 4 dunks |
| 4 | Land 15 dunks | 4 dunks |
| 5 | Buy Training Level 3 | 5 dunks |
| 6 | Train to 60 Vertical | 5 dunks |
| 7 | Dunk during a Dunk Contest (counted at the round's buzzer) | 6 dunks |
| 8 | Land 40 dunks | 6 dunks |
| 9 | Reach 75 Vertical to unlock the Tomahawk | 8 dunks |
| 10 | Unlock the High School Gym | 10 dunks |
| then | Land the next 25 dunks (50, 75, 100, ... lifetime), forever | 5 dunks each |

Rewards use the same "dunks" price as the gifts, worked out when the goal pays.

**No saved data, no double pay** (`GoalService`): every goal reads lifetime progress the game already saves (lifetime dunks, best Vertical, Training Level, unlocked courts, best contest score, Rebirths; the last three count as done after a Rebirth). Those only ever go up, and a goal pays only when the server sees it become done during a session:
- At join, goals the player already meets are skipped without a reward (met in an earlier session, or before goals existed).
- Players still in the new-player tutorial get no goal until it's finished, so the card never clashes with the tutorial banner. When it finishes, goals they met during the tutorial (usually "Land 5 dunks") are paid, one celebration after another.
- Goals that finish out of order are paid when they finish; the card always shows the first goal not done yet.
- The repeating goal counts from the dunks the player had when it started in this session.
- A player who SKIPs the tutorial gets goals once its steps are actually done (the server can't see SKIP).

**Card placement** (`ui/GoalView`), checked against `HUDView`, `PayoutOfferView`, `DunkView`, `ContestView`, `AbilitiesView` and `StatusBarView`:
- **Keyboard, mouse, gamepad:** the top-right corner (8 px down, 12 px in). Everything at the top centre (Dunk Contest banner, NEXT bar and HEAT pill, tutorial card, reward and unlock toasts) is at most 470 px wide, so the card shrinks (down to 60%) to stay right of it. The left stat/menu column, the contest scorecard (right side, from 30% of the height down), the ability hotbar (right edge, middle) and the payout card (bottom right) are all elsewhere.
- **Touch** (the card takes `TouchLayout` from HUDView, so it always matches the HUD's layout):
  - **Phones:** the menu, ability row and jump/DUNK buttons fill the right side, so the card sits under the stat column on the left. It has the same width and scale as the stat cards (down to 0.35) and ends above 76% of the screen height, clear of the thumbstick ring.
  - **Tablets:** the stat column is too tall for that, so the card goes under the menu and ability row on the right, above the jump/DUNK buttons.
  - If neither spot fits, it hides. The card has no buttons, so touches pass through it.
  - Changed after the Studio test: the first version sat under the ability row only. On an iPhone 7 that left no room, so the card hid. In the emulator it also covered the menu's top rows.

| Remote | Direction | Payload |
| --- | --- | --- |
| `GoalState` | server → client | `("Goal", goal or nil)` with goal `{ Text, Progress, From, Target, Reward }` (the bar fills from `From` to `Target`); `("Complete", { Text, Cash })` for each paid goal. Clients send nothing. |

**Analytics:** Cash source `Goal_<id>` / `Goal_Repeat` (Gameplay) and custom event `GoalComplete` (value = goal number; 11 = the repeating goal).

## Files

- **New:** `src/shared/Config/GiftConfig.luau`, `src/shared/Config/GoalConfig.luau`, `src/server/services/GiftService.luau`, `src/server/services/GoalService.luau`, `src/client/GiftsController.luau`, `src/client/GoalController.luau`, `src/client/ui/GiftsView.luau`, `src/client/ui/GoalView.luau`.
- **Changed:** `default.project.json` (`GiftRequest`, `GiftState`, `GoalState` remotes), `ServerMain` (starts both services and calls their `OnPlayerReady`), `HUDView` (GIFTS row), `HUDController` (starts both controllers), `PlayerService` (`BestContestScore` in the milestone snapshot).

## Studio checklist

1. Set `GiftConfig.StudioFastGifts = true`, sync, and Play with a fresh DEV profile. GIFTS counts down `NEXT GIFT 0:05`; at 0 the feed says the gift is ready and the button turns green `GIFTS (1)`. Claim it: Cash goes up by the shown amount and the row says CLAIMED. Claiming twice, or a gift that isn't open, is refused. Gift 3 starts the `2x CASH` pill; gift 7 also opens a crew pack reveal. Set the flag back to false.
2. Rejoin: the gifts start over from gift 1.
3. During the tutorial there is no goal card. Finish it: "GOAL COMPLETE! Land 5 dunks" plays if you dunked 5 times during it, then the card shows "Train to 45 Vertical  40 / 45".
4. Train to 50: two celebrations (45, then 50) and the card moves on to "Land 15 dunks".
5. Rejoin with an existing profile past several goals: no payouts at join; the card shows the first goal not done yet.
6. Check the card on desktop (1920x1080 and a small window), iPhone and iPad in the Device Emulator: it must not cover the stats/menu, the NEXT bar, the contest banner, the ability buttons, the jump/DUNK buttons or the payout card.

## Studio test (2026-10-03)

Run on a fresh profile (`QA_FRESH_ONB1`) with `StudioFastGifts` on, reverted afterwards. The creator owns Auto Train, so Vertical rose by itself during the test.

- **Spawn:** Vertical 35. The tutorial showed "1/4 GRAB A BASKETBALL", and GIFTS (1) appeared after 5 s.
- **Tutorial:**
  - The ball moved it to "2/4 DUNK IT!".
  - The first Basic One-Hand dunk worked straight away.
  - Step 3 was skipped because Auto Train had already passed 40.
  - "4/4 UPGRADE YOUR TRAINING" opened a panel showing Level 1 +0.15 → Level 2 +0.2 for $60. Buying it showed "TUTORIAL COMPLETE!".
- **Funnel:** the log showed onboarding steps 1 Joined, 2 Moved, 3 Ball, 4 DunkTry, 5 Dunk, 6 FirstRep, 7 Train, 8 Upgrade, plus `TutorialComplete`, all in order. FirstRep from Auto Train waited until after Dunk.
- **Gifts:**
  - The 3-minute gift paid exactly +$92.
  - The 30-minute gift paid +$460 plus a 10-minute 2x Cash and an "UNCOMMON! Park Coach" crew reveal.
  - Rows switched to CLAIMED, and the economy events were `TimedReward` / `Gift_n`.
- **Goals:**
  - The card appeared after the tutorial: "Land 5 dunks 1/5 +$69".
  - The 5th dunk paid `Goal_dunks5` +$69 and the card moved to "Train to 45 Vertical".
  - Vertical goals finished by Auto Train paid once each (50, 60, 75).
  - On rejoin, goals already met were skipped without paying, and the card showed "Land 15 dunks 5/15".
- **Layouts:**
  - Desktop: top-right.
  - iPhone 7 (Device Emulator): under the stat column on the left.
  - iPad: under the ability row on the right.
  - Nothing was covered in any of them.

