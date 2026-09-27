# Basic Dunk: Progression-Safe Engagement

Sync the normal Rojo project and restart Play. No map rebuild, Studio object/property changes, remotes, client edits, or animation upload are needed.

## Root Cause

The previous assist required instantaneous root height between Rim.Y - 4 and Rim.Y + 8. Its 0.5-second buffer waited only within three extra studs; above Rim.Y + 11 it immediately rejected. The unchanged jump curve, `7.2 * (Vertical / 30)^1.7`, produces about 9.36 studs at Vertical 35 but 55.75 at 100. Stronger jumps quickly leave that fixed band and spend most of their airtime above it.

The horizontal distance and approach velocity calculations already excluded Y, and there was no vertical-speed rejection. Execution already cleared initial velocity after acquiring server network ownership. However, it held the accepted entry height instead of normalizing to the rim. Its spherical 6.5-stud displacement guard would also reject a substantial vertical correction. Merely increasing the upper entry tolerance would not fix execution presentation.

Read-only inspection of the saved Studio place confirmed anchored Workspace.Gameplay.DunkHoop.Rim at (0, 13, -15), Size (4, 0.4, 4), and CourtSurface top at Y=1. No map assets were changed. This does not inspect unsaved live Studio state.

### Execution Handoff Regression

Live Studio traces subsequently exposed two execution bugs at Vertical 35. An accepted entry Y of 8.19 became Y=13.17 during takeover, but the old start-to-target corridor stopped at Y=11.50. Valid jumping motion was classified as leaving the execution path before normalization could act. Other attempts reached the gather-end assertion with Y=12.58 against target Y=10: the code advanced on one height sample and used the 0.30-second ball gather as an implicit horizontal settling deadline.

The correction keeps the original eligibility rules. During a bounded 0.10-second server handoff it suppresses residual momentum, then samples the controlled pose for alignment targets. Safety checks retain the original horizontal displacement bound and use the validated progression-specific vertical engagement envelope plus the existing 1.5-stud slack, rather than a stale entry-to-target sliver. Server ownership, life, ball and hoop remain checked. There is no unbounded grace period or position teleport.

Height normalization and horizontal alignment now each require position error <= 1.5 studs and speed <= 3 studs/second continuously for 0.08 seconds before advancing. Horizontal alignment has its own 0.75-second deadline before the animation/ball timeline starts. A transient threshold crossing or residual velocity cannot count as ready; real obstructions still time out without reward. The final pre-release alignment check remains. Cancellation diagnostics report phase, elapsed time, entry/target/current Y automatically in Studio; no Command Bar debug toggle is needed for failures.

Follow-up live traces confirmed stable alignment at Y=10.51, then exposed server ownership loss exactly when the held ball detached. Changing the weld/anchoring splits the assembly; the original ownership assignment cannot be assumed to survive. Execution now explicitly reapplies server ownership immediately after BeginDunkMotion and once on the next Heartbeat after the split, clearing residual momentum at that boundary. This is a one-shot expected-transition repair, not a blanket per-frame ownership override. Unexpected later ownership loss still cancels; cleanup retains the original pre-dunk ownership policy.

## Configuration Changes

All settings remain in DunkConfig.

| Setting / behavior | Before | Now |
| --- | --- | --- |
| DunkMinimumVertical | No explicit stat gate | 35, from private server state |
| DunkMaxBelowRim | 4 studs | 8 studs; permits early airborne engagement |
| DunkMaxAboveRim | Fixed 8 | Base 8 plus excess configured jump height over Vertical 35 |
| DunkMaxEngagementAboveRim | Absent | 60-stud absolute safety ceiling |
| GetMaxAboveRim(vertical) | Absent | min(60, 8 + max(0, jumpHeight(vertical) - jumpHeight(35))) |
| Execution.RootBelowRim | Hold entry height | Target root at Rim.Y - 3 |
| Execution.NormalizeMaxVelocity | Absent | 100 studs/second, vertical-only correction phase |
| Execution.NormalizeTimeoutSeconds | Absent | 1.25 seconds maximum |
| Execution displacement guard | 6.5-stud sphere, then entry-to-target Y corridor | Same horizontal bound, plus progression-specific engagement Y envelope with 1.5-stud slack |
| Execution.OwnershipSettleSeconds | Absent | 0.10 seconds before capturing the controlled pose |
| Execution.AlignmentTimeoutSeconds | Implicit 0.30-second gather deadline | 0.75-second horizontal preparation deadline |
| Execution.AlignmentSettleSeconds | Single position sample | 0.08 seconds continuously stable |
| Execution.AlignmentSettleSpeed | No readiness speed check | <= 3 studs/second during settling, not jump eligibility |
| Execution.TimeoutSeconds | 1.2 seconds total | Same 1.2 seconds after preparation; overall budget 3.30 seconds |

Unchanged: horizontal range 8, buffer 0.5 seconds, extra buffer-only height allowance 3, facing 110 degrees or inward movement, retreat limit 3 studs/second, cooldown 1 second, horizontal correction 5 studs, stand-off 2, horizontal speed 20, force 60000, responsiveness 40, position tolerance 1.5, rim movement tolerance 0.25, and orientation settings. Original gather/pass/return baseline is 0.30/0.25/0.20 seconds; current style timings live in DunkStyles. The early-game rebalance changes Neighborhood Basic to **+$20 after completion and cleanup**, without changing assist.

## Server Rules

Require ready player state, Idle, cooldown expiry, original living character/root, private possession, original anchored rim, horizontal proximity, and actual airborne state (FloorMaterial Air plus Jumping/Freefall). Extra RequestDunk arguments remain rejected. Existing approach checks remain: facing toward the basket or inward movement, never clear outward retreat.

PlayerService.GetVertical exposes a read-only scalar from private server state. Vertical below 35 is explicitly rejected with VERTICAL_TOO_LOW, including attempts from raised platforms. Leaderstats and client attributes cannot unlock dunks. This deliberately replaces the former purely physical approximate threshold with the requested explicit unlock; it does not change jump progression.

The lower engagement edge is now Rim.Y - 8. The upper edge grows with excess jump capability, instead of penalizing stronger jumps with a fixed rim-height ceiling. Only height misses within three extra studs may wait for the original fixed 0.5-second deadline. All gates revalidate every Heartbeat. Grounded/distant input does not queue a future dunk, and spam cannot refresh a request or create overlapping sessions.

For a given world state, increasing Vertical never removes eligibility. Across the requested 35-100 range, the extra allowance covers ordinary high-jump apex and descent on the current court. This is not unlimited altitude assistance: the 60-stud safety ceiling and minimum airborne height still reject absurd positions. Progression beyond the requested range must revisit this explicit ceiling/normalization budget before promising equal reliability there. Normal client-owned movement is still not comprehensive competitive teleport anti-cheat.

Only BasicOneHand exists. Its unlock, bounds and execution target are configurable without introducing a generic multi-style framework.

## Execution and Restoration

After validation, execution acquires server network ownership, saves movement/jump settings and Jumping-enabled state, disables movement/jumping, switches to Freefall, and clears residual momentum throughout the bounded handoff. It captures the controlled pose and rechecks horizontal engagement range. AlignPosition first corrects Y toward Rim.Y - 3 while holding captured X/Z; the ball remains welded to the hand. AlignOrientation smoothly faces the hoop. No character CFrame teleport is used.

After stable height alignment, residual normalization velocity is cleared. AlignPosition returns to the original horizontal speed/correction limits and waits for full 3D position/speed stability. Only then does the optional animation start, followed by the existing gather, downward rim pass, hand return, cleanup, and one configured reward (+$20 for Neighborhood Basic). High entry adds bounded correction time rather than demanding an exact input frame.

Every frame checks character/life/possession/hoop, server ownership, displacement bounds, and deadlines. Obstruction, reset/death, lost ball, moved/replaced hoop, excessive motion or timeout cancels without reward. Cleanup restores humanoid properties, Jumping-enabled state, ball presentation, network ownership and movement. It does not replay the original upward launch velocity. Subsequent ordinary jumps retain full Vertical power.

API references: [Humanoid state controls](https://create.roblox.com/docs/reference/engine/classes/Humanoid#SetStateEnabled), [AlignPosition](https://create.roblox.com/docs/reference/engine/classes/AlignPosition).

## Exact Studio Test Matrix

1. Sync and restart Play with the same avatar, gravity, floor and logical Rim. No Neighborhood rebuild.
2. Optionally enable DebugDunkValidation and Execution.DebugLogging before syncing/restarting. Restore both to false after testing. Validation logs are Studio-only/throttled; VERTICAL_TOO_LOW, TOO_LOW, TOO_HIGH, TOO_FAR, NOT_AIRBORNE, NO_BALL, BAD_APPROACH and EXECUTION_CANCELLED identify failures.
3. Start a **fresh Play session for each target: 30, 35, 40, 50, 75, 100**. Keep TrainingLevel 1 and acquire the ball. Either train normally, or run this disposable **server Command Bar** setup, changing targetVertical each time:

```luau
local targetVertical = 35
local player = assert(game:GetService("Players"):GetPlayers()[1])
local service = require(game:GetService("ServerScriptService").services.PlayerService)
assert(service.IsReady(player) and service.GetDunkState(player) == "Idle")
assert(service.GetTrainingUpgradeSnapshot(player).TrainingLevel == 1, "Use a fresh Level-1 session")
local current = assert(service.GetVertical(player))
assert(current <= targetVertical, "Restart Play to test a lower target")
for tickIndex = current + 1, targetVertical do
    assert(service.AwardTraining(player))
end
assert(service.GetVertical(player) == targetVertical)
print("Vertical", service.GetVertical(player), "JumpHeight", player.Character.Humanoid.JumpHeight)
```

This uses existing authoritative training, gives no Cash, adds no production setter/remote, and resets when Play stops. Do not edit display-only leaderstats. Select the intended player explicitly in multiplayer tests.

| Vertical | Configured jump height | Upper allowance above rim | Expected |
| --- | --- | --- | --- |
| 30 | 7.20 | Locked | VERTICAL_TOO_LOW with otherwise valid character/ball; no reward |
| 35 | 9.36 | 8.00 | Unlocked; early, apex and descent requests work |
| 40 | 11.74 | 10.38 | At least as eligible as 35 |
| 50 | 17.16 | 15.80 | Apex no longer constrained to the old +8 band |
| 75 | 34.18 | 32.83 | Excess height normalized; strong free jump preserved |
| 100 | 55.75 | 54.39 | Same rules; no fixed-window overshoot penalty |

4. At each level first jump without F: 50/75/100 must remain dramatically stronger. Then approach inside eight horizontal studs and try F just after takeoff, mid-ascent, apex and descent, five times each. Stop horizontal input for apex tests so leaving range/retreating does not masquerade as height failure. Record successes and rejection codes.
5. Test diagonal/off-center approaches and slightly early airborne F. Verify ball remains held during normalization, then travels through the rim and returns. Exactly +$20 Neighborhood Basic Cash only after cleanup; Vertical unchanged; next ordinary jump retains original strength.
6. At each level test grounded F, no ball, farther than eight studs, obvious retreat, fake client stats/possession, and extra remote arguments: no reward. Very low, beyond the scaled upper bound/buffer, or absurdly high positions remain invalid.
7. Spam during buffer/normalization/ball phases/cooldown: no overlap, extended deadline or duplicate Cash. Reset/die, lose the ball, or move/remove/replace the rim during normalization and return: no delayed reward or stuck controls. Check two players independently.
8. Regress training timing/gains, zero training Cash, upgrades/prices, pickup, Neighborhood and UpgradeStation.

Rojo and numerical checks do not execute Roblox physics or replace Luau Script Analysis. The matrix still requires live Studio playtesting; no Studio controller is available in this session.
