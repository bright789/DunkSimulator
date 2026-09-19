# Training Level v0.1

## Prototype Balance and State

Players start at Vertical 30, Cash 0, TrainingLevel 1. TrainingLevel is private server state, not a leaderstats column or a client-authoritative attribute. It survives character resets but resets when leaving the server; there is no DataStore.

| Training Level | Vertical per valid tick | Cost to buy this level |
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
| 10 | +10 | $50,000 |

These are prototype prices, not final economy balance. `src/shared/Config/UpgradeConfig.luau` owns the starting level, full price/gain table, interaction range (8), purchase/open throttles (0.5 seconds), session check interval (0.2 seconds), and feedback duration (2 seconds). Maximum level is the table length. Existing tick time (0.5 seconds) and jump curve remain in ProgressionConfig, unchanged.

**Training now gives no Cash.** TrainingService's existing hold sessions/timing remain untouched; every valid tick calls PlayerService.AwardTraining, which selects VerticalGain from the authoritative player's TrainingLevel. It updates actual jump height using the existing curve. Buying a level only deducts Cash and changes TrainingLevel; it grants no Vertical and does not recalculate jump height until training increases Vertical.

Successful completed dunks still award exactly **$25**. Four dunks fund Level 2; normal training cannot fund purchases. The loop is TRAIN -> DUNK -> CASH -> UPGRADE -> TRAIN FASTER (larger gains, not shorter tick intervals).

## One-Time Studio Setup

1. Stop Play and save a backup. Sync the **normal** `default.project.json` through Rojo. Verify ReplicatedStorage.Remotes contains TrainingUpgradeRequest and TrainingUpgradeState, and Shared.Config contains UpgradeConfig.
2. Remove only the old imported `ServerStorage.NeighborhoodBuilder` tool folder. Import the updated `tools/NeighborhoodBuilder.rbxmx` into ServerStorage. It now contains five ModuleScripts, including SetupUpgradeStation. Reimporting avoids the ModuleScript require cache retaining old code.
3. In Studio's edit-mode Command Bar run:

   ```luau
   require(game:GetService("ServerStorage").NeighborhoodBuilder.SetupUpgradeStation).Run()
   require(game:GetService("ServerStorage").NeighborhoodBuilder.Build).Run()
   ```

4. Save the place and restart Play. Approach the new UPGRADES stand and press E. This opens the panel and does **not** purchase. Click UPGRADE to request the next level. Use X to close.

The setup action explicitly creates one anchored, non-colliding 4 x 2 x 3 Part with a direct E ProximityPrompt under **Workspace.Gameplay.UpgradeStation**. The default placement is 24 studs behind the existing trainer in its local facing frame, preserving the trainer's bottom height. With the generated layout this is approximately X=-43, Z=-42 relative to the court, versus trainer X=-43, Z=-18. Their 8/10-stud interaction radii do not overlap. Inspect placement if you have moved/rotated the trainer manually.

Setup is idempotent: an existing valid station is returned unchanged; an invalid existing station is reported rather than overwritten. This is a Studio-owned gameplay object with **no builder ownership tag**. Build.Run never creates, moves, replaces, or deletes it. Build only reads its CFrame to make an optional non-colliding pad/equipment rack/sign in `Props.NeighborhoodV01.UpgradeArea`. Missing station skips only this dressing; the rest of the map still builds. The server separately warns and disables upgrades if the station/prompt is missing or unanchored. Restart Play after repairing it.

No Map or Gameplay deletion is needed. Normal Workspace Rojo ownership remains unchanged. The builder rerun replaces its marked output folders as before, so back up manual edits inside them first. You may omit Build.Run to test the functional station without decoration, and may delete the imported tool folder afterward. Never delete the gameplay station to remove its decoration.

To regenerate the packaged tool after source edits:

```powershell
rojo build tools/neighborhood.project.json --output tools/NeighborhoodBuilder.rbxmx
```

Use the existing direct Rojo executable fallback in README if the Rokit shim fails. A freshly built artifact is supplied for this update.

## Server Flow and Purchase Security

1. UpgradeService binds the direct station prompt once at startup. Triggered is treated as input intent: the server verifies initialized player state, living original character/root, current anchored station identity, enabled direct prompt, server-observed distance, optional line of sight, and that a dunk is not Executing.
2. Opening creates at most one per-player session with an original character and a server-generated single-use OfferId. Server snapshots contain current level/gain/Cash, next level/gain/price, affordability, and cooldown readiness. No money moves on opening.
3. A buy request contains only `"Buy", OfferId`. The identifier prevents replay of the same UI offer; it is not a trusted price/level or proof of eligibility. The server rejects extra payloads, wrong/stale tokens, invalid actions, missing sessions, or invalid current context. Independent per-player 0.5-second purchase throttles survive closing/reopening the UI.
4. The server marks processing, rotates the token before processing, and calls PlayerService.BuyNextTrainingLevel. The private state owner validates its current level, cap, configured next price, and affordability; subtracts Cash and increments exactly one level without yielding. No client values are copied into player state. Other players have separate locks/tokens/cooldowns/state.
5. Only after the transaction does the server send success and a fresh snapshot. Errors produce a generic message, not internal server details. Insufficient Cash and max level leave both level and Cash unchanged. Replays cannot buy an additional level. A new deliberate, eligible request with a fresh token after cooldown can buy the next level.
6. Open sessions revalidate about every 0.2 seconds; moving away, death, changed/removed character, missing/disabled station or prompt, or dunk execution closes them. Purchase validation repeats synchronously, so the periodic check is not an eligibility grace period. Close button releases the server session; leaving clears all per-player tables. No transaction yields, so leaving cannot interrupt a half-applied purchase. A purchase validly completed before death/exit is not refunded.

Snapshot updates send only when Cash, level, or cooldown readiness changes. The UI does not calculate authoritative prices/progression locally. Its disabled button and pending-click guard are UX conveniences; server checks still apply. Max level hides the purchase action. TrainingLevel is shown here rather than cluttering leaderstats; Cash and Vertical remain on the existing leaderboard. The UI closes on server invalidation/character removal and does not reopen on late Result/Update packets.

This follows Roblox's guidance to validate distance/context and rate-limit both prompts and remotes, rather than trusting prompt visibility or client values. See [securing the client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary). Existing character network ownership still means this is not a full movement/teleport anti-cheat system.

## Manual Acceptance and Regression Tests

- Fresh Play: Vertical 30, Cash 0. At station, panel shows Level 1 / +1, next Level 2 / +2, $100; button says NOT ENOUGH CASH. Opening/closing changes neither level, Vertical, nor Cash.
- Hold trainer for ten ticks: Vertical becomes 40 and Cash stays 0. Release, walk away, die, and respawn: existing hold cancellation/jump behavior is preserved. At roughly Vertical 35 the original basic dunk threshold remains.
- Perform three completed dunks: Cash $75, still cannot buy Level 2. A fourth gives exactly $100. Each still returns the ball and restores control.
- With exactly $100, buy Level 2: Cash becomes $0, Vertical stays unchanged, UI shows Level 2/+2, next cost $300, and confirmed level-up feedback. Subsequent training ticks add +2 at the same 0.5-second interval and give no Cash.
- Earn another $300 and buy Level 3; verify +3 per tick. Check every table entry through Level 10; at max, UI shows MAX LEVEL/+10 and no buy action. Further server requests do not spend Cash.
- Rapidly click/tap Upgrade: one click/offer must produce at most one purchase. Replay the same OfferId immediately and after cooldown: never another reward/purchase. Close/reopen immediately after purchase: cooldown remains enforced. Test with enough Cash to afford multiple levels so accidental duplicates would be visible.
- Walk farther than eight studs after opening, then request a purchase: UI closes and no purchase occurs. Trigger prompt from far away in a local test: no session opens. Place an obstruction between player and station with RequiresLineOfSight enabled: no open/purchase.
- While open, reset/die; remove the character, station or prompt; disable prompt; unanchor station. Purchases stop and UI closes. Restore edit-mode assets by stopping Play, then restart. Leave during interaction: no stuck state or errors for other players.
- Studio local server with two clients: open/buy simultaneously; only the requesting player's Cash and TrainingLevel change. One player's close/death/spam must not throttle or affect the other player.
- Send no token, a table token, stale/another player's token, invented level/price/Cash, or extra arguments in a disposable local test: no state change; eligible open sessions receive Invalid request where not rate-limited. Requests without a session and flood requests are silently dropped.
- Check X close, live Cash refresh, max-level display, return after respawn, and readable panel on smaller windows. Rejoin the server: session-only level resets to 1 and Cash to 0.
- Rebuild the map twice: one station (same instance), one decorated stand, unchanged logical Rim. Existing entrance, trainer, pickup, ball motion, +$25 dunk feedback, and ball return remain functional.

### Faster Late-Level Testing (Studio Only)

Do not edit display-only leaderstats: purchases never read them. For disposable local tests of high levels and exact balances, use the existing server module in the **server** Command Bar after Play begins:

```luau
local players = game:GetService("Players")
local service = require(game:GetService("ServerScriptService").services.PlayerService)
local player = assert(players:GetPlayers()[1])
assert(service.IsReady(player) and service.GetDunkState(player) == "Idle")
service.SetDunkState(player, "Completed")
for count = 1, 4000 do
    assert(service.RegisterDunk(player))
end
service.SetDunkState(player, "Idle")
```

This intentionally simulates $100,000 of server rewards for test setup (and also increments the debug dunk count). It does not validate dunk execution; use real dunks for that regression check. Use 4 iterations for exactly $100 on a fresh player, 3 for $75, or 13 for $325 to check duplicate-offer behavior. Select the intended test player explicitly when using multiple clients. Stop Play to discard test balances. No test grant remote, persistent cheat, or new gameplay currency source is added.
