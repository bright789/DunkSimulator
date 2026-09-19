# Data Persistence v0.1

## What Is Saved

Only Cash, Vertical, and TrainingLevel persist. Existing private PlayerService state remains authoritative during gameplay. Leaderstats, TrainingLevel/DataStatus attributes, and the HUD are display-only mirrors. Ball possession, current dunk execution/state, session dunk count, and map objects are not saved.

New-player defaults come directly from ProgressionConfig.StartingCash/StartingVertical and UpgradeConfig.StartingLevel, currently 0 / 30 / 1. A successful read returning no record creates a new profile; a failed read never does.

Example record after its first successful save (field order is irrelevant):

```lua
{
    SchemaVersion = 1,
    Cash = 425,
    Vertical = 63,
    TrainingLevel = 4,
    Revision = 1,
    WriteId = "server-generated-write-guid",
}
```

Revision/WriteId are persistence bookkeeping, not new progression. There are no speculative inventory, court, style, or rebirth fields. Existing unknown fields, DataStore key metadata, and associated UserIds are retained when updating a record.

## Configuration and Names

All persistence settings are in `src/server/Config/DataConfig.luau`, which is not replicated to clients.

| Setting | v0.1 value |
| --- | --- |
| ProductionStoreName | `DunkSimulator_PlayerData_v1` |
| StudioStoreName | `DunkSimulator_PlayerData_DEV_v1` |
| KeyPrefix | `Player_` followed by immutable UserId |
| SchemaVersion | 1 |
| AutosaveSeconds / jitter | 90 + random 0-10 seconds per player |
| MaxAttempts | 4 per pending operation |
| Retry delays | 1, 2, 4 seconds + random 0-0.5 seconds |
| LoadTimeoutSeconds | 30 |
| SaveTimeoutSeconds | 20 per worker run |
| CloseTimeoutSeconds | 25 for leave/shutdown waiting |
| MaxCash | 9,007,199,254,740,991 (safe integer precision bound) |
| MaxVertical | 1,000,000 (stored-data integrity bound, not a new training cap) |

Studio always selects the DEV name with RunService:IsStudio(); live servers select production. Identical names are rejected. A separate published **test experience/universe** provides another layer of isolation. A published test server outside Studio uses that test experience's production-named store, not its DEV store. Renaming a store changes which profiles are visible; it does not migrate existing data.

## Loading and Validation

1. DataService registers a private Loading session and a display-only DataStatus attribute. There is no writable default runtime state or leaderstats yet.
2. PlayerDataStore requests the UserId key using uncached GetAsync, protected by pcall, bounded retries, and backoff.
3. PlayerDataSchema inspects the root/schema/revision. Unversioned or version-0 records migrate to v1. Unknown future versions, unsupported migration paths, non-table roots, and corrupt revision metadata fail closed rather than being overwritten.
4. Missing/non-finite/non-numeric individual progression fields use canonical defaults. Finite numbers are floored and clamped: Cash to 0..MaxCash; Vertical to StartingVertical..MaxVertical; TrainingLevel to StartingLevel..the configured upgrade table length. Other valid fields are preserved. A single concise repair warning is emitted.
5. PlayerService initializes its existing private state from the validated values, then publishes leaderstats and TrainingLevel. DataService marks Ready. Its private status, not the attribute, controls readiness.
6. The existing character immediately receives the unchanged jump calculation; CharacterAdded handles a later spawn and every respawn. Training reads the loaded private TrainingLevel and upgrade affordability reads loaded private Cash.

Training, purchases, dunk rewards, and pickup already call PlayerService.IsReady; that method now also checks the private persistence session. Loading/failed/closing sessions cannot mutate progression. The HUD keeps `--` placeholders until real values arrive and shows only a small loading/status label; its layout/style is unchanged. No new remotes or HUD queries are introduced.

If loading fails or exceeds its deadline, progression remains unavailable and the player receives a friendly kick. No fallback/default save is enqueued. A late response after departure, timeout, or shutdown is ignored. Loading existing players uses separate tasks, so a slow request does not block other service initialization.

These are storage integrity bounds, not changes to the jump curve or training balance. Snapshots from runtime must already be valid: they are rejected rather than silently clamped before saving. If legitimate progression ever approaches these generous bounds, revise the storage policy deliberately before launch. Do not raise them just to conceal malformed data.

## Saving and Shutdown

DataService asks PlayerService for a non-yielding copy of only its private persistent fields. DataStore is not the live database. Training/dunks/purchases update memory and replication without making any DataStore request.

- Autosave captures roughly every 90-100 seconds, staggered per player; no per-tick saves.
- PlayerRemoving changes Ready to Closing **before** taking the final snapshot. No further rewards/purchases can change it. Character resources/state are cleaned after the save worker ends or its close deadline expires.
- BindToClose disables new loads, closes all remaining sessions, and waits at most 25 seconds. Different players save concurrently; each individual player retains one worker. PlayerRemoving and shutdown share the same close operation.
- If autosave is active at departure, the final snapshot is queued behind it, not written concurrently. Only the latest queued snapshot is retained. An identical snapshot needs no second write.
- The same pending snapshot/revision/WriteId is kept across failed attempts. A response can fail even if the backend committed. A retry recognizing its own already-written ID confirms the old outcome before writing any newer snapshot. Old retries never silently roll back newer same-server writes.
- Transient autosave failure leaves the pending write for the next autosave/leave attempt. Final failure is logged; unsaved changes can be lost. An exhausted retry budget does not mean an unconfirmed write definitely failed at the backend.

No UpdateAsync callback yields or changes gameplay state. A callback preserves unknown fields and only writes validated snapshot fields plus bookkeeping. See Roblox's [DataStore retry/write guidance](https://create.roblox.com/docs/cloud-services/data-stores/best-practices) for why failed responses can have ambiguous outcomes and why retries must remain ordered.

The deadlines bound new attempts, acceptance, and shutdown waiting; they cannot abort or roll back an already-running Roblox API request. The callback also checks whether its session/deadline is still valid. A hard process crash or long service outage can still lose changes since the last confirmed save. v0.1 is not a durability guarantee.

## Cross-server Limitation

UpdateAsync compares the current stored Revision with the revision loaded/last confirmed by this session. It also accepts an exact retry of that session's own pending WriteId. A different newer revision refuses the write and disables/kicks the stale session; it never blindly replaces another writer's newer progression.

**This is optimistic conflict detection, not an exclusive session lock.** Two servers can load the same revision and play before either saves. The first writer wins; the other may lose its unsaved progress. A rapid reconnect can load the previously saved snapshot while the old server is still saving; this implementation cannot guarantee a seamless transfer of those unsaved changes. Wait for the old session's save confirmation during acceptance tests. Same-server closing sessions block a second Player instance for the same UserId while they remain active.

Full ownership leases, cross-server handoff/reconciliation, crash recovery, and operational rollback tooling remain follow-up work. Do not claim UpdateAsync alone solves profile session locking. Adding teleport-heavy flows or other cross-server features should revisit this boundary first.

Revision protection assumes all writers follow this protocol. External/manual edits that change fields without advancing Revision are not detected; do not edit records under active sessions.

## Safe Studio Setup

1. Save a backup of your place. Prefer publishing a separate private **test experience**, not testing against a public production experience.
2. Publish the test place to Roblox so it belongs to an experience.
3. Open **File > Experience Settings** (called **Game Settings** in some Studio layouts), select **Security**, turn on **Enable Studio Access to API Services**, and save. Code does not enable this setting for you.
4. Stop Play, start/connect Rojo, sync the current source, then start a fresh **solo Play** session. No map rebuild, object migration, or remote changes are required.
5. In server Output, verify `Loading player <UserId> (DunkSimulator_PlayerData_DEV_v1)` followed by `data ready`. If API access is unavailable, expect retries and a safe kick rather than playable defaults.
6. Use the same signed-in Roblox account and the same experience/store for each persistence test. Solo Play normally uses your account's positive UserId. Record the actual ID from server Output. Studio multi-client dummy IDs are not reliable substitutes for real-account rejoin tests.

Studio API access can reach the same backing stores as live servers if code selects the same name. The separate DEV name is an additional guard, not permission to enable access carelessly in your live experience. Roblox recommends using a separate test version. See [official Studio DataStore access instructions](https://create.roblox.com/docs/cloud-services/data-stores#enable-studio-access).

## Safe DEV Reset

This deliberately destructive helper resets **only the signed-in Studio user's positive solo-test UserId in the configured DEV store**. It is not a gameplay button or RemoteEvent and cannot run in production or during Play. No reset occurs automatically.

1. During solo Play, record your actual UserId from the load log and confirm it is positive. The server Command Bar can also run `print(game:GetService("Players"):GetPlayers()[1].UserId)`.
2. Stop Play and all other Studio test sessions/windows using this DEV profile. Wait for pending saves to finish. A remote session still running could write after a reset; the helper cannot discover all other Studio processes.
3. In Studio **edit mode**, open View > Command Bar. Replace the numeric example with that exact UserId and intentionally run:

```lua
local userId = 12345678
require(game:GetService("ServerScriptService").data.PlayerDataStore)
    .ResetStudioData(userId, "RESET " .. tostring(userId))
```

4. Check for the DEV reset confirmation, then start a fresh solo Play. Defaults should load.

The helper checks IsStudio, not IsRunning, exact confirmation, store separation, and that the target matches StudioService:GetUserId. That last API is restricted to an elevated Studio context such as the editor Command Bar; do not invoke this helper from a normal runtime Script. Wrong users, dummy/negative IDs, live servers, and Play mode are rejected. It uses protected RemoveAsync once; a failed reset is reported, not treated as success. Never remove its guards or put it behind a client remote. [StudioService API](https://create.roblox.com/docs/reference/engine/classes/StudioService#GetUserId).

## Manual Acceptance Tests A-H

Use the DEV store/test experience. To record values in solo Play, switch the Command Bar to **Server** and run:

```lua
local player = game:GetService("Players"):GetPlayers()[1]
print(player.UserId, player:GetAttribute("DataStatus"),
    player.leaderstats.Cash.Value, player.leaderstats.Vertical.Value,
    player:GetAttribute("TrainingLevel"))
```

Do not assign to leaderstats/attributes to seed authoritative progression; those are mirrors. Use the working gameplay loop. Tests build on each other; reset only for A.

### A — New Player

Run the guarded DEV reset, then solo Play. Wait for Ready. Expect Cash 0, Vertical 30, TrainingLevel 1; no fake gain/level-up appears from loading. Hold the trainer: +1 Vertical per tick, no Cash. Confirm default PlayerList remains hidden and no duplicate HUD appears.

### B — Save Progression

Train to dunk capability, earn at least $100 through completed dunks, and buy Level 2. Train again and complete another dunk so all three fields differ from defaults. Release training, wait for execution to finish, and record exact values. Stop Play/leave, verify a `Saved player <UserId>` confirmation with no final-save warning, then rejoin using the same account. Compare all three fields exactly; do not train/dunk before recording the restored values. Repeat after waiting 100 seconds to exercise autosave as well as leave saving.

### C — Jump Restoration

Reach a noticeably higher Vertical (for example 70), leave/save, and rejoin. Confirm the HUD value and actual jump capability. On the server compare `player.Character.Humanoid.JumpHeight` with `require(game.ReplicatedStorage.Shared.Config.ProgressionConfig).GetJumpHeight(player.leaderstats.Vertical.Value)`; they should match and UseJumpPower should be false. Try a normal Basic Dunk at the restored high Vertical; existing assist/execution must still work.

### D — TrainingLevel Restoration

Leave with Level 2 or higher, save, and rejoin. Record Vertical, hold E for one successful tick, then release. The increase must equal `UpgradeConfig.Levels[TrainingLevel].VerticalGain`, not the starting gain. Cash must remain unchanged.

### E — Cash Restoration

Earn enough Cash for your next configured upgrade (at Level 2, the next costs $300). Record Cash/level, leave/save, and rejoin. Approach UpgradeStation and open its UI: the restored balance must be recognized. Buy once; Cash falls by the configured price, level increases once, Vertical does not change from the purchase, and HUD updates normally. Leave/rejoin again to confirm the post-purchase values persisted. Insufficient Cash still rejects purchases.

### F — Respawn

Load an existing profile, record the three fields and JumpHeight, then reset your character. All three values remain; JumpHeight/UseJumpPower restore correctly. Possession is still lost on death as before. Pick up another ball, train, open upgrades, and dunk to check the original loop remains functional.

### G — Rapid Leave and Overlap

Immediately after a training tick, completed dunk, or confirmed purchase, stop Play/leave. Wait for save confirmation, then rejoin and compare final values. Repeat near 90-100 seconds after joining to overlap autosave and leaving. Also stop a two-player Studio server while an autosave is active: check no duplicate workers/errors and no cross-player data mixing. Use real-account solo rejoin for durable-value assertions; dummy client IDs can differ across test modes.

### H — Load Failure Protection

First save a known DEV profile. Stop Play, temporarily disable **Enable Studio Access to API Services** in the test experience's Studio settings, save settings, and start a fresh solo Play. Expect a loading message, retry warnings, blocked training/purchase/rewards, no initialized leaderstats profile, and a friendly kick. There must be no default-profile save. Re-enable access, restart Play, and verify the original saved values still load. If Studio still permits requests, use a separate unpublished test copy to exercise failure, without renaming the production store. The isolated mock tests also inject read failures without touching real data.

Additional release checks: delayed loading before/after character spawn; leaving during loading; malformed single fields retaining good fields; rejected future schema; forced save failures; two-server stale revisions; large HUD values; and the Studio reset's rejection of Play mode/wrong UserId. Do not intentionally corrupt real profiles to test these cases.

## Validation and Remaining Work

Local validation passes: Rojo build/project JSON and source packaging, compilation of all 25 source Luau files, diff checks, and 18 isolated Luau checks executing the actual persistence/PlayerService modules with mocked Roblox services. They cover new/default/load gating, restored jump/gains/purchases, exact reload, failed/late loads, schema sanitation, final snapshot serialization, ambiguous/transient write retry, stale revision rejection, bounded shutdown, respawn/late character creation, extra-field preservation, display-mirror tampering, concurrent player isolation, and reset guards. The temporary official Luau CLI/harness live outside the repository; no game dependency or test framework was added.

These are not live DataStore or Studio rendering tests. Complete A-H against Roblox before treating this milestone as playtested. Remaining limitations: no full session lock, no guarantee during outages/crashes, possible loss since the last confirmed save, no recovery/admin dashboard, and no migration beyond the explicit legacy-to-v1 path. No gameplay/economy tuning, dunk changes, or map rebuild are part of this milestone.
