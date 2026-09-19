# Custom HUD v0.1

## Scope and Setup

This is a presentation milestone, not a gameplay rebalance. The current high-Vertical Basic Dunk assist, input buffer, execution, ball return, and exactly +$25 completion reward are unchanged. Training still gives only level-based Vertical on the existing timer. Upgrade costs, authoritative private state, and map ownership are unchanged.

1. Stop Play in Studio.
2. Run `rojo serve default.project.json` from the repository root if it is not already serving, then connect/sync the Rojo plugin.
3. Verify StarterPlayerScripts contains HUDController and the `ui` folder, and ReplicatedStorage.Shared.Config contains HUDConfig.
4. Start a fresh Play session. Scripts create the UI once under the local PlayerGui; do not create ScreenGuis manually.

No NeighborhoodBuilder rerun, Workspace edits, additional remotes, or project mapping changes are required. Do not delete existing map/gameplay objects. Stop/restart Play when syncing controller changes to avoid testing stale running LocalScripts.

## Files and Responsibilities

| File | Role |
| --- | --- |
| `src/client/HUDController.client.luau` | Stat subscriptions, initial hydration, PlayerList hiding, teardown |
| `src/client/ui/HUDView.luau` | Cards, Basic Dunk progress, resize handling |
| `src/client/ui/StatFeedback.luau` | One reusable label/tween per stat |
| `src/client/ui/UIComponents.luau` | Native UI panels, text sizing, rounding, number formatting |
| `src/client/ui/DunkView.luau` | Context hint and confirmed result/rejection presentation |
| `src/shared/Config/HUDConfig.luau` | Theme, layout, feedback timing, presentation milestone copy |
| `src/client/DunkController.client.luau` | Existing F input/results wired to the new view; input rules unchanged |
| `src/client/UpgradeController.client.luau` | Existing purchase behavior with matching styling and cleanup |
| `src/server/services/PlayerService.luau` | Two additional TrainingLevel display-attribute writes, no authority changes |

## Authoritative Data

- Cash/Vertical come from the existing server-written leaderstats IntValues; TrainingLevel comes from a server-written player attribute initialized from private state and updated after purchase.
- The HUD only observes. It never writes these values, applies gains, purchases levels, changes jump properties, or awards Cash. Local tampering with a display mirror cannot change private server state.
- No HUD remote or polling request is added. The upgrade panel retains its authoritative server snapshot/offer flow; stat fields may replicate independently rather than atomically.
- The dunk hint uses the existing HasBasketball display attribute and hides during Executing. Possession authority remains in BasketballService. DUNK! appears only when the existing DunkResult event carries a confirmed numeric reward, not on F or on a Cash value change.
- Only PlayerList is hidden. Leaderstats still exist for replication/debugging, and no TrainingLevel leaderboard column is added. The client uses Roblox's [SetCoreGuiEnabled pattern](https://create.roblox.com/docs/players/disable-ui); failures retry at most ten times, then warn once.

## Presentation and Efficiency

Three small left-side cards keep the center clear. Charcoal panels, subtle strokes, bold white values, muted captions, blue accents, and restrained green Cash feedback match the upgrade panel. The bottom-center F keycap reads DUNK. Brief confirmed dunk feedback uses the same styling; validation rejection text remains visible.

Basic Dunk is the only implemented style. The milestone references the existing DunkConfig minimum (35), with NEXT GOAL below it and UNLOCKED at/above it. The preview always says NEXT STYLE / Coming Soon. Unlock text means progression eligibility, not automatic success. Progress stays within 0-100%, including high Vertical, and safely handles a zero target. No new physics or unlock rules are introduced.

UI instances are created once per controller session and survive character respawn. Stat changes update only the relevant labels and, for Vertical, progress properties. Positive changes reuse a card's gain label; one short tween is cancelled/destroyed before replacement, with no accumulating GUI objects or tween completion subscriptions. Feedback lasts 0.45 seconds by default (0.1 hold + 0.35 fade), shorter than a normal training interval. Deductions update Cash immediately without falsely showing a positive gain. Initial hydration does not animate as a reward. Controller teardown disconnects listeners and cancels owned startup work/tweens.

Layout uses the core safe area, UIListLayout, UIPadding, UIScale, UISizeConstraint, and bounded text scaling. HUD scaling reacts to safe-area size changes, not a per-frame loop; large numbers use comma grouping and shrink within their label. The upgrade panel remains centered and takes precedence over feedback. This is desktop responsive UI, not new mobile input support.

## Manual Studio Checklist

Repeat visual checks at **1920x1080**, **1366x768**, **960x540**, and **800x600** using Studio's device/window sizing. Resize during Play as well as starting at each size.

1. Fresh join: Cash $0, Vertical 30, Training LVL 1. PlayerList is hidden; server Explorer still contains leaderstats Cash/Vertical and the TrainingLevel player attribute. There is one NeighborhoodHUD, one DunkFeedback, and one TrainingUpgrades screen in PlayerGui. No phantom gain/level-up plays on join.
2. Check cards, captions, hint, progress, close button, and upgrade costs fit. The center stays clear outside short feedback/the open upgrade panel. Check default topbar/chat usability and that opening chat/focusing a text box still prevents F requests.
3. Hold E on VerticalTrainer for at least 30 seconds: +1 per tick at Level 1, no Cash. Each +1 is brief; no UI pile-up or growing GUI descendant count. Release stops training. Jump capability remains unchanged from the working prototype.
4. At Vertical 32 the bar shows 32 / 35. At 35 it becomes UNLOCKED / Basic Dunk unlocked with a full bar. At 40, 50, 70, and high Vertical it stays bounded and does not claim Two-Hand/Tomahawk/etc. are playable.
5. Before pickup, no dunk hint. Pick up a ball: F keycap/DUNK appears. During execution it hides, then returns with possession. A failed/grounded/far-away attempt shows the server's rejection, never DUNK! or a cash gain.
6. Complete dunks at Vertical 35, 50, and a previously playtested high Vertical. The unchanged sequence completes, Cash rises by exactly $25, DUNK! / +$25 shows once, and the ball returns. No reward appears merely on F press or execution start.
7. Earn $100, approach UpgradeStation, and press E. Opening spends nothing. Buy Level 2: Cash becomes $0, Training becomes LVL 2 with LEVEL UP!, and the confirmed upgrade panel updates. Vertical does not change from purchasing; subsequent training gives +2 per tick with no Cash. Insufficient Cash still prevents the next purchase.
8. Check max-level/large-number display in a disposable Studio test session using your existing server-side test setup; do not edit private gameplay rules or expect editing leaderstats to grant real currency. MAX LEVEL has no valid purchase action. Large values do not overrun cards.
9. Open the upgrade UI, then walk away or reset: existing server session closure still works. Respawn preserves stats, loses the ball/hint, and creates no duplicate HUD. Reset again with feedback visible: no stale result or stuck panel. With Data Persistence v0.1, rejoin shows a brief loading/status message and restores saved Cash/Vertical/TrainingLevel rather than resetting them; see `DATA_PERSISTENCE.md`.
10. Use two Studio clients: each HUD shows only its own stats, purchase confirmations, and dunk results. Check Output for new UI errors.

## Validation Boundary

`rojo build default.project.json --output <temporary-path>.rbxlx` validates packaging and project JSON, not Roblox rendering or physics. Review client/server diffs and run `git diff --check`. The Studio checklist above is still required for visual layout, safe-area behavior, and live replication; do not treat a successful Rojo build as a runtime playtest.
