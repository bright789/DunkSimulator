# Training Level v0.1

## Prototype Balance and State

New players start at Vertical 30, Cash 0, TrainingLevel 1. TrainingLevel is private server state, not a leaderstats column or a client-authoritative attribute. Cash, Vertical, and TrainingLevel now survive rejoining through [Data Persistence v0.1](DATA_PERSISTENCE.md); gameplay waits for successful loading. Use the isolated DEV store for these tests.

| Training Level | Vertical per rep | Cost to buy this level |
| --- | --- | --- |
| 1 | +0.1 | Starting level |
| 2 | +0.2 | $250 |
| 3 | +0.3 | $600 |
| 4 | +0.4 | $1,200 |
| 5 | +0.5 | $2,000 |
| 6 | +0.6 | $3,500 |
| 7 | +0.7 | $5,500 |
| 8 | +0.8 | $8,000 |
| 9 | +0.9 | $12,000 |
| 10 | +1.0 | $18,000 |

**2026-09-27 change:** training used to be 0.25 × an efficiency multiplier (1.00x–2.00x). Now each level adds a flat +0.1 Vertical per rep, from 0.1 at Level 1 to 1.0 at Level 10, so upgrades are the main way training gets faster (10× from Level 1 to Level 10, instead of 2×). The court training bonus (High School ×1.15, College ×1.3, Rooftop ×1.45) and the Rebirth training bonus still multiply it. Auto Train uses the same rate. The pacing model put the first Rebirth at about the same time as before (around 61 minutes with upgrade buying), with a slower Level 1 start and much faster late levels.

These are prototype prices, not final economy balance. `src/shared/Config/UpgradeConfig.luau` owns the starting level, full price/efficiency table, interaction range (8), purchase/open throttles (0.5 seconds), and session check interval (0.2 seconds). The unchanged 2-second UI confirmation lives in `src/shared/Config/FeedbackConfig.luau`. Maximum level is the table length. Vertical per rep comes straight from the level's `VerticalPerRep`; the tick time (0.5 seconds) and jump curve are unchanged.

**Training gives no Cash.** TrainingService's existing hold sessions/timing remain untouched; every valid tick calls PlayerService.AwardTraining, which computes the TrainingLevel's `VerticalPerRep` × validated court training bonus × Rebirth training bonus and accumulates the existing persisted fractional remainder. Only whole points update Vertical, jump height and HUD feedback. Buying a level only deducts Cash and changes TrainingLevel; it grants no Vertical and does not recalculate jump height until training increases Vertical.

Completed Neighborhood Basic One-Hand dunks award **$20**; Two-Hand Power awards **$35**, Tomahawk **$60**, and Windmill **$100**, from DunkStyles configuration. Thirteen Basic dunks can fund the $250 Level 2 purchase from zero Cash, before any challenge claims; normal training cannot fund purchases. Court multipliers still adjust final payouts. The loop is TRAIN -> DUNK -> CASH -> UPGRADE -> TRAIN MORE EFFICIENTLY, without shorter tick intervals.

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

## Troubleshooting a Missing Station During Play

A read-only inspection of the saved Studio place during the disappearance investigation found the existing anchored, opaque UpgradeStation at approximately **(-5951, 3492.63, -5910)**. The trainer was near **(43, 1.04, 24.5)** and spawn near **(0, 1, 54.5)**. The UpgradeArea decoration was also thousands of studs away. Setup previously reported an existing valid instance and preserved this authored position; the decoration builder placed its stand around that position. A startup "ready" log confirms discovery, not proximity to the playable park.

This establishes a placement defect in that saved place, not proof that the live server deleted anything. The saved place has StreamingEnabled enabled: distant parts can be absent on clients, but streaming does not explain removal on the server. Repository inspection found no runtime station deletion/reparenting/movement/hiding, no Gameplay clearing, and no automatic builder invocation. The saved Workspace contained no scripts. If the live server still loses the instance after placement repair, capture the diagnostics below rather than assuming streaming is responsible.

### One-Time Placement Repair (No Neighborhood Rebuild)

1. Stop Play and save a backup. Sync the normal gameplay Rojo project.
2. Replace only the imported **ServerStorage.NeighborhoodBuilder** tool folder with the updated `tools/NeighborhoodBuilder.rbxmx`. Reimport even if the folder already exists, to avoid cached ModuleScripts. Leave Workspace and its objects intact.
3. Run in the **edit-mode Command Bar**:

   ```luau
   require(game:GetService("ServerStorage").NeighborhoodBuilder.SetupUpgradeStation).PlaceExistingNearTrainer()
   workspace:SetAttribute("DiagnoseUpgradeStation", true)
   ```

4. Inspect the new placement and save the place. The action moves the **existing** station 24 studs behind the trainer in the trainer's local frame, matching their bottom heights. Its Size, Parent, prompt, visibility and physics properties are preserved. Only Parts inside `Map.Neighborhood.Props.NeighborhoodV01.UpgradeArea`, under the expected BuilderOwner marker, receive the same rigid transform. It does not recreate anything, move the trainer/hoop/spawn, or rebuild the map. Repeating the action at the same trainer position leaves the result unchanged. Missing/invalid station or unowned dressing is rejected before movement.
5. Press Play. In **server Output**, compare the startup and after-3-seconds `[UpgradeStation diagnostic]` records. Expect: Destroyed=false, In Workspace=true, Same resolved station=true, Same Gameplay=true, Parent is original Gameplay=true, Same CFrame=true, Transparency=0, Anchored=true, Same prompt=true, and Prompt enabled=true. Both records describe the same captured Instance. The temporary destruction listener disconnects after three seconds; no polling loop or runtime repair runs.
6. Approach within eight studs with a living character and an unobstructed view; press E. The Training Upgrades panel should open without spending Cash. Walk away and verify it closes. Confirm trainer, pickup, configured style reward and ball return still work.
7. Stop Play and disable diagnostics in edit mode with `workspace:SetAttribute("DiagnoseUpgradeStation", nil)`, then save. Diagnostics are opt-in and Studio-only; they never run in published servers.

The agent cannot run the live Studio session: Edit-to-Play survival and E/UI interaction require these tests. If removal persists, include both diagnostic records and inspect the **server** Explorer explicitly. Do not rerun Build.Run or clone stations as a workaround.

## Server Flow and Purchase Security

1. UpgradeService binds the direct station prompt once at startup. Triggered is treated as input intent: the server verifies initialized player state, living original character/root, current anchored station identity, enabled direct prompt, server-observed distance, optional line of sight, and that a dunk is not Executing.
2. Opening creates at most one per-player session with an original character and a server-generated single-use OfferId. Server snapshots contain current level/efficiency/Cash, next level/efficiency/price, affordability, and cooldown readiness. No money moves on opening.
3. A buy request contains only `"Buy", OfferId`. The identifier prevents replay of the same UI offer; it is not a trusted price/level or proof of eligibility. The server rejects extra payloads, wrong/stale tokens, invalid actions, missing sessions, or invalid current context. Independent per-player 0.5-second purchase throttles survive closing/reopening the UI.
4. The server marks processing, rotates the token before processing, and calls PlayerService.BuyNextTrainingLevel. The private state owner validates its current level, cap, configured next price, and affordability; subtracts Cash and increments exactly one level without yielding. No client values are copied into player state. Other players have separate locks/tokens/cooldowns/state.
5. Only after the transaction does the server send success and a fresh snapshot. Errors produce a generic message, not internal server details. Insufficient Cash and max level leave both level and Cash unchanged. Replays cannot buy an additional level. A new deliberate, eligible request with a fresh token after cooldown can buy the next level.
6. Open sessions revalidate about every 0.2 seconds; moving away, death, changed/removed character, missing/disabled station or prompt, or dunk execution closes them. Purchase validation repeats synchronously, so the periodic check is not an eligibility grace period. Close button releases the server session; leaving clears all per-player tables. No transaction yields, so leaving cannot interrupt a half-applied purchase. A purchase validly completed before death/exit is not refunded.

Snapshot updates send only when Cash, level, or cooldown readiness changes. The UI does not calculate authoritative prices/progression locally. Its disabled button and pending-click guard are UX conveniences; server checks still apply. Max level hides the purchase action. TrainingLevel is shown here rather than cluttering leaderstats; Cash and Vertical remain on the existing leaderboard. The UI closes on server invalidation/character removal and does not reopen on late Result/Update packets.

This follows Roblox's guidance to validate distance/context and rate-limit both prompts and remotes, rather than trusting prompt visibility or client values. See [securing the client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary). Existing character network ownership still means this is not a full movement/teleport anti-cheat system.

## Manual Acceptance and Regression Tests

- Fresh Play: Vertical 30, Cash 0. At station, panel shows Level 1 / 1.00x, next Level 2 / 1.10x, $250; button says NOT ENOUGH CASH. Opening/closing changes neither level, Vertical, nor Cash.
- Hold trainer for ten ticks: Vertical becomes 40 and Cash stays 0. Release, walk away, die, and respawn: existing hold cancellation/jump behavior is preserved. At roughly Vertical 35 the original basic dunk threshold remains.
- Perform 12 completed Neighborhood Basic dunks: Cash $240, still cannot buy Level 2 without claiming a challenge. A thirteenth gives $260. Each still returns the ball and restores control.
- With at least $250, buy Level 2: Cash falls by exactly $250, Vertical stays unchanged, UI shows Level 2 / 1.10x, next cost $600, and confirmed level-up feedback. Subsequent ticks keep the 0.5-second interval, generate 1.10 progress each at Neighborhood and give no Cash; whole-Vertical gains vary with fractional carry.
- Earn enough for Level 3 ($600) and verify 1.20x efficiency. Check every table entry through Level 10; at max, UI shows MAX LEVEL / 2.00x and no buy action. Further server requests do not spend Cash.
- Rapidly click/tap Upgrade: one click/offer must produce at most one purchase. Replay the same OfferId immediately and after cooldown: never another reward/purchase. Close/reopen immediately after purchase: cooldown remains enforced. Test with enough Cash to afford multiple levels so accidental duplicates would be visible.
- Walk farther than eight studs after opening, then request a purchase: UI closes and no purchase occurs. Trigger prompt from far away in a local test: no session opens. Place an obstruction between player and station with RequiresLineOfSight enabled: no open/purchase.
- While open, reset/die; remove the character, station or prompt; disable prompt; unanchor station. Purchases stop and UI closes. Restore edit-mode assets by stopping Play, then restart. Leave during interaction: no stuck state or errors for other players.
- Studio local server with two clients: open/buy simultaneously; only the requesting player's Cash and TrainingLevel change. One player's close/death/spam must not throttle or affect the other player.
- Send no token, a table token, stale/another player's token, invented level/price/Cash, or extra arguments in a disposable local test: no state change; eligible open sessions receive Invalid request where not rate-limited. Requests without a session and flood requests are silently dropped.
- Check X close, live Cash refresh, max-level display, return after respawn, and readable panel on smaller windows. Leave after a confirmed save and rejoin: level, Cash, and Vertical should restore, not reset.
- Rebuild the map twice: one station (same instance), one decorated stand, unchanged logical Rim. Existing entrance, trainer, pickup, ball motion, matching style-reward feedback, and ball return remain functional.

### Faster Late-Level Testing (Studio Only)

Do not edit display-only leaderstats: purchases never read them. For disposable local tests of high levels and exact balances, use the existing server module in the **server** Command Bar after Play begins:

```luau
assert(game:GetService("RunService"):IsStudio(), "Test grants are Studio-only")
local players = game:GetService("Players")
local service = require(game:GetService("ServerScriptService").services.PlayerService)
local player = assert(players:GetPlayers()[1])
assert(service.IsReady(player) and service.GetDunkState(player) == "Idle")
assert(service.EquipDunkStyle(player, "BasicOneHand"), "Reach 35 Vertical first")
for count = 1, 4000 do
    service.SetDunkState(player, "Completed")
    assert(service.RegisterDunk(player, "BasicOneHand"))
end
service.SetDunkState(player, "Idle")
```

This explicitly equips eligible Basic One-Hand and simulates $80,000 at its current $20 Neighborhood reward for isolated late-level test setup (also incrementing challenge dunk counts). It does not validate dunk execution; use real dunks for that check. Starting from known Cash, 12 iterations add $240 and 13 add $260. Reach 35 Vertical first. Select the intended test player explicitly with multiple clients. **These balances persist: stopping Play does not discard them. Never use this grant during the timed fresh-player balance playtest.** Use only the private DEV test experience and its guarded reset from `DATA_PERSISTENCE.md`. Never grant test rewards in production. This is a privileged server Command Bar workflow, not a gameplay button or remote.
