# Data Persistence v0.1

## What Is Saved

Cash, Vertical, TrainingLevel, EquippedDunkStyle, UnlockedCourts, CurrentCourt, VerticalTrainingRemainder, one-time Challenges, the Rebirths count (see `REBIRTH.md`), the Daily record (see `DAILY_REWARDS.md`) lifetime Stats for the leaderboards and Dunk Contest (see `LEADERBOARDS.md` and `DUNK_CONTEST.md`) and the Locker's owned/equipped shoes and ball skins (schema v10, see `LOCKER.md`) persist. Existing private PlayerService state remains authoritative; leaderstats, display attributes and HUD are mirrors only. Ball possession, dunk execution/state, court-transition state, session dunk count and map objects are not saved. Court Bonuses and Dunk Challenges extend the existing lifecycle without bypassing its safety rules; see `COURT_BONUSES.md` and `DUNK_CHALLENGES.md`.

New-player defaults come from ProgressionConfig, UpgradeConfig, DunkStyles, CourtConfig and ChallengeConfig: Cash 0, Vertical 30, TrainingLevel 1, intended BasicOneHand selection, Neighborhood unlocked/selected, fractional training remainder 0, and seven unclaimed challenge entries. Basic remains locked until 35. A successful read returning no record creates a new profile; a failed read never does.

Example record after its first successful save (field order is irrelevant):

```lua
{
    SchemaVersion = 10,
    Cash = 425,
    Vertical = 63,
    TrainingLevel = 4,
    EquippedDunkStyle = "Tomahawk",
    UnlockedCourts = { Neighborhood = true },
    CurrentCourt = "Neighborhood",
    VerticalTrainingRemainder = 0.45,
    Rebirths = 0,
    Daily = { Streak = 0, LastClaimDay = -1, BoostUntil = 0, ChallengeDay = -1, Challenges = {} },
    Stats = { BestVertical = 63, TotalDunks = 0, BestDunkCash = 0, BestContestScore = 0, ContestWins = 0 },
    Locker = { Shoes = { Owned = { classic = true }, Equipped = "classic" }, Balls = { Owned = { classic = true }, Equipped = "classic" } },
    Challenges = {
        basic_dunker_1 = { Progress = 3, Completed = false },
        -- The other six configured challenge IDs are also present.
    },
    Revision = 1,
    WriteId = "server-generated-write-guid",
}
```

Revision/WriteId are persistence bookkeeping. Rebirths is an integer clamped to 0..RebirthConfig.MaxRebirths. There are no speculative inventory fields or redundant style-unlock booleans. Court unlocks are different: they persist a purchase entitlement, not a Vertical-derived style. Existing unknown unrelated fields, key metadata and UserIds are retained on update.

## Configuration and Names

All persistence settings are in `src/server/Config/DataConfig.luau`, which is not replicated to clients.

| Setting | v0.1 value |
| --- | --- |
| ProductionStoreName | `DunkSimulator_PlayerData_v1` |
| StudioStoreName | `DunkSimulator_PlayerData_DEV_v1` |
| KeyPrefix | `Player_` followed by immutable UserId |
| SchemaVersion | 10 (same existing store names/keys) |
| PrioritySaveCooldownSeconds | 10 (court unlock/claim requests share the existing worker) |
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
3. PlayerDataSchema inspects root/schema/revision. Legacy records migrate through v1 -> v2 (intended BasicOneHand selection) -> v3 (Neighborhood-only unlocks/selection) -> v4 (fractional training remainder 0) -> v5 (default challenge records) -> v6 (Rebirths 0) -> v7 (empty Daily record) -> v8 (Stats: BestVertical = current Vertical, counters 0) -> v9 (contest stats 0) -> v10 (free Classic shoes and ball). Cash/Vertical/TrainingLevel, style selection and court state are preserved. Invalid styles recover to highest unlocked style or Basic if none; Basic remains unusable below 35. Court sanitation retains known IDs with exact true values, always restores Neighborhood and falls back there for invalid/locked CurrentCourt. Unsupported future schemas, non-table roots and corrupt revisions still fail closed.
4. Missing/non-finite/non-numeric individual progression fields use canonical defaults. Finite numbers are floored and clamped: Cash to 0..MaxCash; Vertical to StartingVertical..MaxVertical; TrainingLevel to StartingLevel..the configured upgrade table length. Fractional carry must be finite and in `[0, 1)`; it is normalized to millionths, with malformed values repaired to zero. Challenge progress is integer and capped at each configured target; claim flags require exact `true`. Other valid fields are preserved. A single concise repair warning is emitted.
5. PlayerService initializes private state and display mirrors. DataService marks Ready and defers the court-placement callback. Its private status, not the attribute, controls data readiness; progression also waits for CourtTransition to finish.
6. Existing/later characters receive the unchanged loaded-Vertical jump calculation. CourtTravel places each living character at saved CurrentCourt after readiness checks, and restores that court on respawn. Training reads private TrainingLevel; affordability reads private Cash.

Training, purchases, dunk rewards and pickup call PlayerService.IsReady. Loading/failed/closing sessions and court transitions cannot mutate progression. HUD placeholders wait for replicated values; court UI reads a server snapshot, never DataStore. Persistence itself exposes no client save/load/reset remote.

If loading fails or exceeds its deadline, progression remains unavailable and the player receives a friendly kick. No fallback/default save is enqueued. A late response after departure, timeout, or shutdown is ignored. Loading existing players uses separate tasks, so a slow request does not block other service initialization.

These are storage integrity bounds, not changes to the jump curve or training balance. Snapshots from runtime must already be valid: they are rejected rather than silently clamped before saving. If legitimate progression ever approaches these generous bounds, revise the storage policy deliberately before launch. Do not raise them just to conceal malformed data.

## Saving and Shutdown

DataService asks PlayerService for a non-yielding copy of private persistent progression, including a fresh unlock map, fractional training remainder and challenge records. DataStore is not the live database. Training/dunks/TrainingLevel purchases/equips update memory and replication without per-action DataStore traffic. A significant court purchase requests a priority snapshot through DataService.RequestSave (ten-second admission interval) and the same serialized worker; there is no direct CourtService DataStore access or second racing writer. Feedback confirms the runtime purchase, not guaranteed immediate durability.

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
4. Stop Play, connect/sync Rojo and complete the one-time HighSchoolBuilder setup in `COURT_PROGRESSION.md`, then start a fresh **solo Play** session. Persistence itself does not create maps or modify Studio settings.
5. In server Output, verify `Loading player <UserId> (DunkSimulator_PlayerData_DEV_v1)` followed by `data ready`. If API access is unavailable, expect retries and a safe kick rather than playable defaults.
6. Use the same signed-in Roblox account and the same experience/store for each persistence test. Solo Play normally uses your account's positive UserId. Record the actual ID from server Output. Studio multi-client dummy IDs are not reliable substitutes for real-account rejoin tests.

Studio API access can reach the same backing stores as live servers if code selects the same name. The separate DEV name is an additional guard, not permission to enable access carelessly in your live experience. Roblox recommends using a separate test version. See [official Studio DataStore access instructions](https://create.roblox.com/docs/cloud-services/data-stores#enable-studio-access).

## Fresh Player Playtest / Safe DEV Reset

This deliberately destructive helper resets **only the signed-in Studio user's positive solo-test UserId in the configured DEV store**. It is not a gameplay button or RemoteEvent and cannot run in production or during Play. No reset occurs automatically. Studio uses `DunkSimulator_PlayerData_DEV_v1`; published servers use `DunkSimulator_PlayerData_v1`.

1. Publish a separate private test experience and enable Studio API access as described above. During solo Play, record your positive UserId from the `[DataService] Loading player ...` log. Finish the previous session and check for its final `Saved player ...` message.
2. **Stop Play** and close all other Studio test sessions/windows using this DEV profile. Wait for the previous session to stop before resetting. Do not run the command in Play, a client Command Bar, or a published game.
3. In Studio **edit mode**, open View > Command Bar and run `print(game:GetService("StudioService"):GetUserId())`. Confirm that this positive ID matches the solo-test ID you recorded. Then run this exact reset command; it targets only that signed-in account:

```lua
local userId = game:GetService("StudioService"):GetUserId(); require(game:GetService("ServerScriptService").data.PlayerDataStore).ResetStudioData(userId, "RESET " .. tostring(userId))
```

4. Require a `[DataService] Reset DEV data for player ... to new-player defaults` confirmation with no error and the matching ID. **Start a new solo Play session**. Wait for `DataStatus = Ready` before interacting.
5. Before training or dunking, verify the HUD shows Cash 0, Vertical 30 and Training Level 1. COURTS shows Neighborhood selected/unlocked and High School locked; DUNKS shows Basic One-Hand as the intended default selection but still locked until 35 Vertical. CHALLENGES shows zero dunk-count progress and no claims; Rising Athlete and Above the Rim show 30/60 and 30/120 progress from starting Vertical. All other fields come from the current `PlayerDataSchema.Defaults()`.

For a full saved-profile check immediately after joining, switch the Command Bar to **Server** and run:

```lua
local player = game:GetService("Players"):GetPlayers()[1]; local server = game:GetService("ServerScriptService"); local schema = require(server.data.PlayerDataSchema); local profile, _, problem = require(server.data.PlayerDataStore).Load(player.UserId, function() return true end); assert(profile, problem); print("Fresh profile:", schema.SameProgress(profile, schema.Defaults()), "Cash", profile.Cash, "Vertical", profile.Vertical, "TrainingLevel", profile.TrainingLevel, "Remainder", profile.VerticalTrainingRemainder, "Court", profile.CurrentCourt, "Style", profile.EquippedDunkStyle)
```

`Fresh profile: true` immediately after joining confirms the reset **stored record** matches canonical new-player defaults: Cash, Vertical, TrainingLevel, zero fractional remainder, default style, Neighborhood-only unlock/selection and zero/unclaimed challenge records. Once the player is Ready, ChallengeService evaluates Vertical 30 into 30/60 and 30/120 runtime progress; neither challenge is completed or claimed. That derived progress may appear in later saves, so the stored-record equality check is intended for the first moments before gameplay/autosave. Play normally afterward and rejoin to confirm saving has resumed.

The helper checks `IsStudio`, edit mode, no active players, exact confirmation, distinct DEV/production names, and that the target matches `StudioService:GetUserId`. That API needs the elevated editor Command Bar context; do not invoke this helper from a runtime Script. The helper uses `UpdateAsync` to replace the DEV record with `PlayerDataSchema.Defaults()` and advance its revision. A stale pre-reset session using the prior revision cannot overwrite the fresh record through normal saves, including autosave, PlayerRemoving or BindToClose. An invalid/unsupported profile revision or unconfirmed write fails instead of claiming success. Other Studio windows cannot be stopped by this helper, so close them first. Never remove these guards or put this behind a client remote. [StudioService API](https://create.roblox.com/docs/reference/engine/classes/StudioService#GetUserId).

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

Train to dunk capability, earn at least $250 through completed dunks or claimed challenges, and buy Level 2. Train again and complete another dunk so all three fields differ from defaults. Release training, wait for execution to finish, and record exact values. Stop Play/leave, verify a `Saved player <UserId>` confirmation with no final-save warning, then rejoin using the same account. Compare all three fields exactly; do not train/dunk before recording the restored values. Repeat after waiting 100 seconds to exercise autosave as well as leave saving.

### C — Jump Restoration

Reach a noticeably higher Vertical (for example 70), leave/save, and rejoin. Confirm the HUD value and actual jump capability. On the server compare `player.Character.Humanoid.JumpHeight` with `require(game.ReplicatedStorage.Shared.Config.ProgressionConfig).GetJumpHeight(player.leaderstats.Vertical.Value)`; they should match and UseJumpPower should be false. Try a normal Basic Dunk at the restored high Vertical; existing assist/execution must still work.

### D — TrainingLevel Restoration

Leave with Level 2 or higher, save, and rejoin. Record Vertical and `VerticalTrainingRemainder`, then count multiple valid ticks. Expected total progress is `1.00 × UpgradeConfig.Levels[TrainingLevel].TrainingMultiplier × current court TrainingMultiplier × tick count`, plus the starting remainder. Visible Vertical increases by the whole part; the new remainder carries the fraction. For Level 2 at Neighborhood with zero starting carry, ten ticks add 11 whole Vertical. Cash must remain unchanged.

### E — Cash Restoration

Earn enough Cash for your next configured upgrade (at Level 2, the next costs $600). Record Cash/level, leave/save, and rejoin. Approach UpgradeStation and open its UI: the restored balance must be recognized. Buy once; Cash falls by the configured price, level increases once, Vertical does not change from the purchase, and HUD updates normally. Leave/rejoin again to confirm the post-purchase values persisted. Insufficient Cash still rejects purchases.

### F — Respawn

Load an existing profile, record the three fields and JumpHeight, then reset your character. All three values remain; JumpHeight/UseJumpPower restore correctly. Possession is still lost on death as before. Pick up another ball, train, open upgrades, and dunk to check the original loop remains functional.

### G — Rapid Leave and Overlap

Immediately after a training tick, completed dunk, or confirmed purchase, stop Play/leave. Wait for save confirmation, then rejoin and compare final values. Repeat near 90-100 seconds after joining to overlap autosave and leaving. Also stop a two-player Studio server while an autosave is active: check no duplicate workers/errors and no cross-player data mixing. Use real-account solo rejoin for durable-value assertions; dummy client IDs can differ across test modes.

### H — Load Failure Protection

First save a known DEV profile. Stop Play, temporarily disable **Enable Studio Access to API Services** in the test experience's Studio settings, save settings, and start a fresh solo Play. Expect a loading message, retry warnings, blocked training/purchase/rewards, no initialized leaderstats profile, and a friendly kick. There must be no default-profile save. Re-enable access, restart Play, and verify the original saved values still load. If Studio still permits requests, use a separate unpublished test copy to exercise failure, without renaming the production store. The isolated mock tests also inject read failures without touching real data.

Additional release checks: delayed loading before/after character spawn; leaving during loading; malformed single fields retaining good fields; rejected future schema; forced save failures; two-server stale revisions; large HUD values; and the Studio reset's rejection of Play mode/wrong UserId. Do not intentionally corrupt real profiles to test these cases.

## Validation and Remaining Work

Local validation passes: Rojo build/project JSON and source packaging, compilation of all 25 source Luau files, diff checks, and 18 isolated Luau checks executing the actual persistence/PlayerService modules with mocked Roblox services. They cover new/default/load gating, restored jump/gains/purchases, exact reload, failed/late loads, schema sanitation, final snapshot serialization, ambiguous/transient write retry, stale revision rejection, bounded shutdown, respawn/late character creation, extra-field preservation, display-mirror tampering, concurrent player isolation, and reset guards. The temporary official Luau CLI/harness live outside the repository; no game dependency or test framework was added.

The original persistence, Dunk Styles and Court Progression milestones are user-playtested. Court Bonuses introduced v4 for fractional carry; Dunk Challenges adds v5 for one-time progress and claims. The current isolated challenge regression checks cover v4 migration, capped progress, overlap, duplicate claims and rejoin; see `DUNK_CHALLENGES.md` for Studio acceptance. Local checks are not live DataStore/rendering tests. Remaining limitations: no full session lock, no guarantee during outages/crashes, possible loss since the last confirmed save and no recovery dashboard. Migration is now legacy -> v1 -> v2 -> v3 -> v4 -> v5; store names must not change or existing records would appear missing.

**Schema v11 (2026-09-27):** adds `Settings = { Music = boolean }` (default true). v10 profiles migrate with music on. See `INVITES_MUSIC_PASSES.md`.

**Schema v12 (2026-09-27):** adds `Abilities = { SlowMo, Fireball, HangTime }`: the level of each ability, 0 = locked, up to 5. v11 profiles migrate with all three locked; the ones a player has already earned by Vertical unlock for free when they next join. Cooldowns and ARMED flags are not saved. Rebirth keeps ability levels. See `ABILITIES.md`.

**Schema v13 (2026-09-27):** adds `LastOnline` (Unix time of the last save, for welcome-back earnings) and `Crew = { Owned = { memberId = stars }, Equipped = { memberId... } }` (Hype Crew). v12 profiles migrate with `LastOnline = 0` and an empty crew. Rebirth keeps the crew. See `HYPE_CREW.md`.

**Schema v14 (2026-09-27):** adds `Season = { Id, Xp, Free = { tiers }, Premium = { tiers } }` (Dunk Pass). v13 profiles migrate with an empty record, and a new season resets it. See `DUNK_PASS.md`.
