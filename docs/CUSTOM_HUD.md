# Custom HUD v0.1

## Scope and Setup

This was a presentation milestone; the later early-game rebalance changed balance configuration but not the HUD's authoritative data flow or high-Vertical dunk mechanics. Neighborhood Basic now pays +$20, while High School Basic pays +$25. The upgrade panel now shows training efficiency rather than fixed Vertical/tick. See `COURT_BONUSES.md` and `EARLY_GAME_REBALANCE.md`.

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
| `src/shared/Config/HUDConfig.luau` | Theme, layout, presentation milestone copy; Game Feel timings now live in `FeedbackConfig.luau` |
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

Dunk Styles v0.1 extends the progression card: DUNKS opens four usable style rows, and the card shows actual equipped selection and the next locked milestone (35/50/75/110), or all current styles unlocked. Progress stays within 0-100%, including high Vertical, and safely handles no next target. EquippedDunkStyle is a server-written display attribute; only a validated EquipDunkStyle request can mutate private selection. Historical unlocks on join are silent; new crossings queue at most four one-time toasts. See `DUNK_STYLES.md` for updated setup and acceptance tests; the older Basic-only visual checks below are superseded by that matrix.

UI instances are created once per controller session and survive character respawn. Stat changes update only the relevant labels and, for Vertical, progress properties. Positive changes reuse a card's gain label; one short tween is cancelled/destroyed before replacement, with no accumulating GUI objects or tween completion subscriptions. Feedback lasts 0.45 seconds by default (0.1 hold + 0.35 fade), shorter than a normal training interval. Deductions update Cash immediately without falsely showing a positive gain. Initial hydration does not animate as a reward. Controller teardown disconnects listeners and cancels owned startup work/tweens.

Layout uses the core safe area, UIListLayout, UIPadding, UIScale, UISizeConstraint, and bounded text scaling. HUD scaling reacts to safe-area size changes, not a per-frame loop; large numbers use comma grouping and shrink within their label. The upgrade panel remains centered and takes precedence over feedback. **Touch layout:**
- Touch-only devices move the six menu buttons (DUNKS through LOCKER) to a 2×3 block in the top-right corner. Roblox's movement thumbstick takes touches in the lower-left of the screen, and buttons there block it.
- On phones (shortest side ≤ `Layout.CompactMaxSize`, 500 px), the Training card and dunk-progress panel are also hidden, and Court / Cash / Vertical are pinned to the top-left above the thumbstick.
- `CompactStatsHeight` and `TouchMenuHeight` in `HUDConfig.Layout` set how much of the screen height each block uses.
- Desktop and keyboard devices keep the original column.
- The menu grid is now 2 columns x 6 rows plus a full-width GIFTS row (2026-10-03). The goal card sits top-right on desktop, under the stat column on phones and under the ability row on tablets; see `GIFTS_AND_GOALS.md`.
- Checked in Studio's Device Emulator: iPhone XR (896×414) and iPad 6th gen (1024×768).

## Manual Studio Checklist

Repeat visual checks at **1920x1080**, **1366x768**, **960x540**, and **800x600** using Studio's device/window sizing. Resize during Play as well as starting at each size.

1. Fresh join: Cash $0, Vertical 35, Training LVL 1. PlayerList is hidden; server Explorer still contains leaderstats Cash/Vertical and the TrainingLevel player attribute. There is one NeighborhoodHUD, one DunkFeedback, and one TrainingUpgrades screen in PlayerGui. No phantom gain/level-up plays on join.
2. Check cards, captions, hint, progress, close button, and upgrade costs fit. The center stays clear outside short feedback/the open upgrade panel. Check default topbar/chat usability and that opening chat/focusing a text box still prevents F requests.
3. Hold E on VerticalTrainer for at least 30 seconds: +1 per tick at Level 1, no Cash. Each +1 is brief; no UI pile-up or growing GUI descendant count. Release stops training. Jump capability remains unchanged from the working prototype.
4. At Vertical 32 the bar shows 32 / 35. At 35 Basic unlocks; the card then previews the next locked milestone. At 50, 75 and 110 the corresponding style unlocks. The bar stays bounded and never claims a locked style is playable.
5. Before pickup, no dunk hint. Pick up a ball: F keycap/DUNK appears. During execution it hides, then returns with possession. A failed/grounded/far-away attempt shows the server's rejection, never DUNK! or a cash gain.
6. Complete eligible dunks at the new style thresholds and a high Vertical. The sequence completes, Cash rises by the equipped style's base reward at Neighborhood ($20/$35/$60/$100) or the court-adjusted reward at High School ($25/$44/$75/$125), matching style/amount feedback shows once, and the ball returns. No reward appears merely on F press or execution start.
7. Earn $250, approach UpgradeStation, and press E. Opening spends nothing. Buy Level 2: Cash falls by exactly $250, Training becomes LVL 2 with LEVEL UP!, and the confirmed upgrade panel shows 1.10x efficiency. Vertical does not change from purchasing; subsequent training accumulates 1.10 base progress per tick at Neighborhood with no Cash. Insufficient Cash still prevents the next purchase.
8. Check max-level/large-number display in a disposable Studio test session using your existing server-side test setup; do not edit private gameplay rules or expect editing leaderstats to grant real currency. MAX LEVEL has no valid purchase action. Large values do not overrun cards.
9. Open the upgrade UI, then walk away or reset: existing server session closure still works. Respawn preserves stats, loses the ball/hint, and creates no duplicate HUD. Reset again with feedback visible: no stale result or stuck panel. With Data Persistence v0.1, rejoin shows a brief loading/status message and restores saved Cash/Vertical/TrainingLevel rather than resetting them; see `DATA_PERSISTENCE.md`.
10. Use two Studio clients: each HUD shows only its own stats, purchase confirmations, and dunk results. Check Output for new UI errors.

## Validation Boundary

`rojo build default.project.json --output <temporary-path>.rbxlx` validates packaging and project JSON, not Roblox rendering or physics. Review client/server diffs and run `git diff --check`. The Studio checklist above is still required for visual layout, safe-area behavior, and live replication; do not treat a successful Rojo build as a runtime playtest.
