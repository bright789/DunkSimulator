# Court Progression v0.1

Court Progression v0.1 and the High School Gym have since been playtested. The original local checks below cover the first release; Court Bonuses v0.1 has its own validation and Studio matrix in `COURT_BONUSES.md`.

## Courts and Balance

The authoritative definitions live in `src/shared/Config/CourtConfig.luau`:

| Stable ID | Display name | Order | Starting court | Vertical requirement | One-time Cash cost |
| --- | --- | --- | --- | --- | --- |
| `Neighborhood` | Neighborhood Court | 1 | Yes | 0 | $0 |
| `HighSchool` | High School Gym | 2 | No | 75 | $6,000 |

Vertical is an eligibility requirement, **not a currency**. Vertical 81 / Cash 6,100 becomes Vertical 81 / Cash 100 after purchase. Unlocks are permanent saved entitlements, not derived from current Cash or Vertical. An unlocked court never charges again, even if Vertical later falls below its original requirement.

Other court configuration: purchase/travel admission interval 1 second per player, read interval 0.5 seconds, portal range 10 studs, spawn readiness deadline 10 seconds, arrival clearance 0.5 studs above the spawn/standing body height, arrival obstruction-check width 4 studs. These values do not replace or retune dunk/training settings.

Neighborhood remains the starting court. Training timing, TrainingLevel efficiency/prices, style requirements and jump curves use the same configuration at both courts. The four style **base** rewards are Basic $20, Two-Hand $35, Tomahawk $60 and Windmill $100. Court Bonuses v0.1 applies 1.25x dunk Cash and 1.15x training progress at High School, versus 1.00x at Neighborhood; see `COURT_BONUSES.md`. High School requires 75 Vertical and costs $6,000 once. Neighborhood/High School training ends at 75/150 Vertical respectively; these are not player stat caps. There are no extra styles or separate Places.

## Ownership and Complete Gameplay Hierarchy

Normal Rojo sync still has **no Workspace mapping**. It owns server/client/shared code and seven named RemoteEvents, not any court, station, spawn, terrain or scenery. Both builders are separate importable editor tools and are never required by server startup. Save the Studio place separately from source code.

```text
Workspace
├── Map
│   ├── Neighborhood                         (existing, unchanged)
│   │   ├── Court/CourtSurface
│   │   ├── Environment/ParkGround
│   │   ├── Props
│   │   │   └── HighSchoolGateV01             (new builder-owned dressing)
│   │   └── Boundaries
│   └── HighSchool
│       └── Environment
│           └── HighSchoolV01                 (replaceable generated scenery)
│               ├── Court
│               ├── Building
│               ├── Bleachers
│               ├── SchoolDetails
│               ├── Lights
│               └── Stations
├── Gameplay
│   ├── VerticalTrainer                      (existing)
│   ├── BasketballPickup                     (existing)
│   ├── UpgradeStation                       (existing)
│   ├── DunkHoop/Rim                         (existing logical reference)
│   ├── HighSchoolPortal                     (new permanent gameplay Part)
│   │   └── ProximityPrompt
│   └── Courts
│       └── HighSchool
│           ├── Spawn                        (SpawnLocation)
│           ├── VerticalTrainer/ProximityPrompt
│           ├── BasketballPickup/ProximityPrompt
│           ├── UpgradeStation/ProximityPrompt
│           ├── NeighborhoodPortal/ProximityPrompt
│           └── DunkHoop
│               ├── Rim                      (logical gameplay reference)
│               └── HighSchoolV01            (replaceable visual hoop)
└── SpawnLocation                            (existing Neighborhood spawn)
```

Nothing from the working Neighborhood must be deleted or moved. Existing Neighborhood rim position/size, spawn, stations, prompts, scenery and builder source/package are untouched.

`HighSchoolBuilder` creates missing gameplay objects **once in edit mode**; these have no scenery ownership marker. Reruns preserve their identity, authored placement and properties. Only the three named generated scenery roots above may be replaced. Each root and every descendant must have `BuilderOwner = "DunkSimulator.HighSchool.v1"`; unmarked collisions or manually added descendants abort rather than being deleted. Duplicate names/wrong types fail preflight. Construction is staged with rollback of newly created assets on failure.

Put custom additions outside those generated roots. If you intentionally edit generated Parts, rerunning replaces those edits; copy them to an unowned sibling first. Do not remove gameplay objects to refresh art.

## One-time Studio Setup / Rebuild

1. **Stop Play. Save a backup of the working Studio place.** Keep the existing Map, Gameplay and SpawnLocation.
2. Start Rojo from the inner repository (`rojo serve default.project.json`) and connect/sync in Studio. The only new project-declared instances are `CourtRequest` and `CourtState` under Remotes, plus mapped code/config modules. Reject any unexpected Workspace deletion in a sync preview.
3. In Explorer, right-click **ServerStorage > Insert from File** and select this repository's **`tools/HighSchoolBuilder.rbxmx`**. It should insert a Folder named `HighSchoolBuilder` with five ModuleScripts: Build, Config, Scenery, Geometry, Props. This package includes the shared geometry helper and the shared prop library (Hoop Shop, Leg Day gym, bus stop, school bus); no dependency download is required.
4. In **edit mode**, open View > Command Bar and run:

   ```lua
   require(game:GetService("ServerStorage").HighSchoolBuilder.Build).Run()
   ```

5. Expect `[HighSchoolBuilder] Built 201 decorative Parts...` and no errors. The tool creates the gym, its gameplay stations/spawn, both portals and gateway dressing. It does not touch global Lighting or run again when Play starts.
6. Inspect the High School spawn/hoop in Explorer and the Neighborhood gateway near the entrance. The new gateway starts 26 studs to the side of the existing spawn. If your customized park has something there, move only `Workspace.Gameplay.HighSchoolPortal` in edit mode, then rerun the builder to refit its dressing. Keep it on walkable ground and separate from the existing prompts.
7. **Bus stops (once, or after moving a stop):** in edit mode run `require(game:GetService("ServerStorage").HighSchoolBuilder.Build).PlaceTransitStops()` and then `Build.Run()` again. This moves `Workspace.Gameplay.HighSchoolPortal` onto the Neighborhood sidewalk by the street (`Config.Transit.NeighborhoodStop`, relative to the Neighborhood SpawnLocation) and the High School `NeighborhoodPortal` onto the new sidewalk outside the gym entrance (`Config.Transit.SchoolStop`), both facing the road. `Build.Run()` then builds a bus stop around each travel station and parks a school bus at the curb with its door beside the stop.
8. **Save/publish the Studio place**, then start a fresh Play session. Services bind station prompts once at startup, so do not build during Play. Both environments must be saved/published, not just source-synced.

To rebuild later, stop Play and run the same command. If tool source changed, rebuild with `rojo build tools/highschool.project.json --output tools/HighSchoolBuilder.rbxmx`, remove **only the old ServerStorage.HighSchoolBuilder tool folder**, import the new package, and run it. Replacing the tool also avoids edit-mode ModuleScript require caching. Do not delete Map, Gameplay, either Rim or either spawn. The packaged builder is built for the non-colliding ceiling revision; normal Rojo sync alone does not update Studio-owned scenery.

After syncing the current CourtConfig, rerun this edit-mode builder once so its Studio-owned High School gateway sign reads 75 Vertical / $6,000. The live portal/menu checks already use CourtConfig and cannot be changed by the sign. Only marked scenery is replaced; gameplay objects stay intact. See `PROGRESSION_PLAYTEST.md` for the guarded fresh-profile test.

## Gym Layout

The initial gym is centered 2,400 studs along world +X from the Neighborhood court, at the same floor elevation. Its logical Rim copies the **tested floor-to-rim height and size**, not a new dunk threshold. Existing High School Rim placement is retained on reruns and scenery follows that reference.

The room is approximately 110 x 140 studs, with a 60 x 104 hardwood court, one functional hoop at the far end, three-point/free-throw/center markings, blue paint, simple bleachers, fictional DUNK HIGH banners and a static scoreboard. An 82-stud-high visual roof preserves the indoor silhouette without limiting jump height; this is stylized prototype scale, not regulation architecture. Four modest downward lights illuminate the interior without changing Neighborhood Lighting. The spawn looks toward the hoop, with pickup/training near the entry and upgrades off the opposite sideline. The return portal is beside the arrival area.

Generated art uses 201 anchored Parts, plus a handful of separately preserved gameplay Parts. The floor, side/front/back walls, entrance landing and bleachers retain collision. The `Ceiling` and overhead `DoorHeader` are visual-only (`CanCollide`, `CanTouch` and `CanQuery` are false); roof beams, lights, banners and scoreboard pieces were already non-collidable. Markings, station dressing and hoop visuals also do not collide. There are no interiors to furnish, NPCs, ambient scripts, real-school logos, moving scoreboards or physics nets.

### Vertical Clearance Rule

Indoor courts must not impose an accidental hard cap on superhuman Vertical progression. Keep overhead scenery above the playable court non-collidable and non-queryable, including roofs, beams, hanging lights, banners and scoreboards; retain collision only for intentional walkable floors, seating and perimeter walls. Apply this rule to future College, Pro Arena and other indoor courts. Players may pass through the High School's visual roof at very high Vertical; the opaque roof remains for the indoor view from below. Check camera visibility above the roof in Studio before adding any local fade treatment.

## Runtime Architecture

- **CourtConfig** defines IDs, requirements, ordering, direct gameplay/spawn paths and portal edges. Adding a future court requires its definition, authored map/gameplay/spawn and desired portal connections, not another set of gameplay services.
- **GameplayObjects** resolves explicit paths, not recursive first matches. Neighborhood retains `Workspace.Gameplay` and its temporary direct-Workspace legacy fallback; High School has no fallback into Neighborhood. Duplicate names, wrong containers and invalid/unanchored logical rims are rejected.
- **TrainingService, BasketballService and UpgradeService** bind each configured court's local prompt. Every interaction rechecks private CurrentCourt and station identity. Training/upgrade sessions retain their originating station, so changing courts invalidates them. Timing, base gains/costs, possession validation and upgrade offer tokens are retained; PlayerService now applies the court's training bonus at award time.
- **DunkService/DunkExecution** resolve/revalidate the Rim for private CurrentCourt. Assist, input buffer, normalization, style paths and cooldowns are untouched. PlayerService now applies the court's Cash bonus only after completed execution.
- **PlayerService** remains the sole live progression authority. It owns UnlockedCourts, CurrentCourt and a transient CourtTransition flag, publishes safe snapshots and a display-only CurrentCourt attribute, and makes the non-yielding purchase deduction/unlock atomic.
- **CourtService** handles physical portal interaction and narrow remote intent. **CourtTravel** handles spawn resolution, arrival validation, transient cleanup and positioning.
- **CourtsController/CourtsView** add the small HUD court label, COURTS button/menu, per-player portal requirement display and one reusable unlock toast. They never deduct money or select a CFrame. Existing stats/upgrade/dunk UI contracts remain unchanged.

### Purchase Security

E at the physical HighSchoolPortal is the only purchase path. The server checks membership, loaded/placed data, living character/root, Idle dunk state, source court, exact configured portal identity, anchoring, prompt ancestry/enabled state, proximity and optional line of sight. It also verifies that the target arrival exists and is clear before charging. It determines the requirement and price from CourtConfig, then checks private Vertical/Cash, deducts Cash and marks the unlock without yielding. Per-player processing and a one-second shared purchase/travel throttle prevent overlapping requests.

First successful purchase stays at the portal and says to press E again to travel. Once unlocked, the prompt becomes TRAVEL for that player, and the COURTS menu enables free travel. Duplicate purchase interaction may travel after cooldown but never deducts again. Opening/reading a menu cannot buy anything.

`CourtRequest` accepts only `("Read")` or `("Travel", courtId)`, with exact payload shape. Unknown/locked IDs, extra CFrames/arguments and a forged `Buy` action are rejected. No client-supplied price, cash, unlock claim, destination or CurrentCourt is used. `CourtState` returns only that player's authoritative snapshot, optional message/unlock ID and portal-context flag. UI affordability/progress is advisory.

### Bus Ride

The physical travel stations are bus stops. For an owned court, E boards the bus: `CourtTravel.BeginRide` runs the same readiness/dunk/ownership checks, cancels training and the upgrade offer, sets the court transition gate, anchors the rider at the stop and sets the presentation-only `TransitRide` attribute. After `CourtConfig.RideSeconds` (3.4 s) `CourtTravel.FinishRide` unanchors and performs the normal validated `CourtTravel.Move`, then clears `TransitRide`. Leaving or resetting mid-ride cancels the ride. Locked courts still use the stop as the purchase point, and the COURTS menu still travels instantly.

Clients (`TransitPresentation.client`) play the departure for every rider: the nearest `TransitBus` opens and closes its doors, the rider fades out, and the bus pulls away, disappears and later returns to its stop. The rider's own camera watches from across the road (or the curb side if blocked), then the screen fades to black with "Riding the bus to ..." until arrival. Timings live in `PresentationConfig.Transit`.

### Travel, Spawn and Respawn

Travel requires a living, ready player and an unlocked target; an Attempting/Executing/Completed dunk must finish first. The server resolves the anchored, enabled, neutral SpawnLocation and checks a standing-character arrival box for collidable obstructions. Blocked/missing arrivals reject before clearing possession. Destination is above the spawn, facing its authored direction; no client position is accepted.

On acceptance it gates gameplay, ends training, closes the upgrade offer, despawns the held basketball, moves the current character with PivotTo, clears assembly velocities, sets RespawnLocation/CurrentCourt and releases the gate. Players pick up the destination ball normally. No character movement/jump settings are retuned. Ordinary menu/portal travel has no wait/yield inside its state change, so leaving/resetting cannot interleave half of a purchase with another action.

CourtTravel installs the starting RespawnLocation before profile loading. After data is Ready, and on later CharacterAdded, it waits up to ten seconds for that same living character/root to reach Workspace, then places it at saved CurrentCourt. Progression remains gated until placement finishes. Obsolete characters cannot relocate a replacement. Death waits for the next spawn; unrecoverable live spawn failure kicks safely rather than leaving writable progression at the wrong court. A missing/blocked saved High School spawn falls back to Neighborhood, retains the permanent unlock, and logs a warning. If Neighborhood is unavailable too, placement fails safely. Actual jump restoration still uses PlayerService's existing loaded-Vertical path.

## Persistence / Migration

Schema **3** adds:

```lua
{
    SchemaVersion = 3,
    Cash = 100,
    Vertical = 61,
    TrainingLevel = 4,
    EquippedDunkStyle = "Tomahawk",
    UnlockedCourts = { Neighborhood = true, HighSchool = true },
    CurrentCourt = "HighSchool",
}
```

Revision/WriteId bookkeeping remains. Version 2 -> 3 added Neighborhood-only unlocks and selected Neighborhood, preserving Cash, Vertical, TrainingLevel and EquippedDunkStyle. Version 3 -> 4 added `VerticalTrainingRemainder = 0`; version 4 -> 5 added challenges. The rebalance and later court training caps do not alter schema. Unknown unrelated stored fields remain preserved by UpdateAsync. Only known court IDs with exact `true` are retained; Neighborhood is always restored; invalid/locked CurrentCourt falls back to Neighborhood without discarding other fields. Previously purchased High School access remains permanent even below the current 75/$6,000 gate. Runtime snapshots deep-copy the unlock map, validate it, and include both court fields and remainder in snapshot equality and writes. See `COURT_BONUSES.md`.

**Do not rename either store**: production remains `DunkSimulator_PlayerData_v1`; Studio remains `DunkSimulator_PlayerData_DEV_v1`. Schema version is separate from store namespace. Existing failed-load protection, revision conflict detection, retry/write-ID handling and leave/shutdown/autosave behavior are retained.

A successful unlock calls `DataService.RequestSave`, which queues a fresh snapshot through the existing single save worker (priority requests throttled to ten seconds), never a separate CourtService DataStore call. It does not block the interaction or claim immediate durability. Autosave/leave/shutdown persist subsequent CurrentCourt changes. An outstanding save completes before a newer queued snapshot writes. Existing outage/crash loss and optimistic-concurrency limitations remain; this is not full session locking or a cross-server transaction system.

## Manual Test Matrix

Use a private published test experience, Studio API access enabled, and the same real solo-test UserId. See `DATA_PERSISTENCE.md` for the guarded DEV reset. Do not edit display attributes/leaderstats to seed authoritative values. Use gameplay progression and record server-confirmed values. Stop/rejoin only after Output confirms the previous session saved.

1. **Existing profile migration:** Record Cash, Vertical, TrainingLevel and equipped style before upgrading source. Rejoin an existing saved profile after sync/build. Verify all four unchanged and any already-unlocked High School entitlement retained. Leave/rejoin once to verify current schema-v5 saving. Do not reset this profile to test migration.
2. **Vertical below 75:** With sufficient Cash but Vertical <75, approach HighSchoolPortal and press E. Require a Vertical rejection, no travel and identical Cash. Portal display must show the missing Vertical.
3. **Insufficient Cash:** At Vertical >=75 but Cash <6,000, press E. Require an insufficient-Cash message and unchanged Vertical/Cash/unlocks. The portal/menu must show current Cash versus cost.
4. **Purchase:** Reach >=75 and >=6,000, note exact numbers, press E once near the portal. Expect precisely -6,000 Cash, no Vertical change, High School UNLOCKED feedback and no forced travel. Test exactly 6,000 as well: balance must become zero.
5. **No repeat cost:** After cooldown press E again, return and interact repeatedly. High School stays unlocked and Cash never drops a second time.
6. **Travel both ways:** Use both physical portals and COURTS menu to travel Neighborhood -> High School -> Neighborhood. Check correct court label, facing, clear spawn placement and readable entry view. Locked menu entries must not offer a purchase action.
7. **High School gameplay:** Pick up its ball; try Basic, Two-Hand, Tomahawk and Windmill when unlocked. Each completed style adds its court-adjusted reward (Basic $25, Two-Hand $44, Tomahawk $75, Windmill $125) and returns the ball. Hold/release the trainer: same 0.5-second cadence and no training Cash; its gain is 1.00 base progress × TrainingLevel efficiency × 1.15 with persistent fractional carry. Open upgrades, purchase an affordable next level, confirm configured cost/efficiency and no direct Vertical reward.
8. **Wrong hoop/station protection:** Dunk near each court's Rim while selected there; the other hoop must never be used. In Server Explorer confirm only the selected court's explicit Rim is returned by GameplayObjects.FindRim(PlayerService.GetCurrentCourt(player)). A forged distant prompt from the other court must not train, give a ball, open upgrades or unlock a court.
9. **Basketball cleanup:** Carry the Neighborhood ball, travel to High School, inspect character: old HeldBasketball gone and F hint hidden. Acquire High School ball, dunk, then return; the second ball must also be cleared. No duplicate ball/weld remains.
10. **Respawn:** At High School reset character. Return at High School with the same progression/equipped style and restored actual jump. No ball until pickup. Repeat Neighborhood. Reset while a menu/training session is open; old interaction must not survive.
11. **Persistence:** Select High School after unlocking, record all progression, stop/save/rejoin. Spawn at High School, retain unlock and selected style, pay nothing. Travel to Neighborhood, save/rejoin: spawn Neighborhood while High School stays unlocked. Repeat near autosave time and immediately before leaving.
12. **Locked travel exploit:** With a not-yet-unlocked profile, in the Play **client** Command Bar run `game.ReplicatedStorage.Remotes.CourtRequest:FireServer("Travel", "HighSchool")`. Expect rejection, no movement, charge or unlock.
13. **Invalid payload:** From the client request `("Travel", "NotACourt")`, then `("Buy", "HighSchool")`, then `("Travel", "Neighborhood", CFrame.new(999, 999, 999))`, waiting a second between. All must fail without state corruption. Real clients never submit destination CFrames.
14. **Spam/isolation:** Spam E on the unlock portal and travel requests; one unlock/one deduction only. Try two Studio clients independently; one player's purchase/travel must not change the other's state. During a dunk, send a menu travel request: reject until Idle, with exactly the original dunk reward/cleanup.
15. **High Vertical:** At High School test Basic/Two-Hand/Tomahawk at Vertical 100 and all four styles at Vertical 110+, 150 and 200+. Also test each style at its own threshold (Basic 35, Two-Hand 50, Tomahawk 75, Windmill 110), using Neighborhood before the High School gate where appropriate. At Vertical 75, 100, 150 and 200+ jump beneath center court, near the hoop and by the trainer; at 150+ verify the character passes through the visual roof without collision. At each value, perform unlocked dunks and observe camera tracking/visibility above and below the roof. No extra precision or overshoot cancellations should result from selecting a different court.

Additional safety/visual checks: reset during each style; remove a gym spawn in a disposable edit-mode test copy and verify safe fallback/no charge; block arrival and verify rejection; repeat failed-load test from the persistence guide; inspect UI at 1920x1080, 1366x768 and a smaller window; compare Neighborhood before/after; rebuild twice with no duplicate owned roots. Check floor visibility, interior lights, scoreboard/banners, station spacing, non-colliding lines/hoop and jump clearance. If StreamingEnabled is used, test destination loading on a slower client; no streaming settings are changed automatically.

## Validation and Limits

Local validation: all 44 source/tool Luau files compile; main Rojo build and both builder projects build; all three project JSON files parse. The gym package contains four ModuleScripts and no automatic Script/LocalScript. Neighborhood's rebuilt package is byte-identical to the existing package. Isolated temporary harnesses execute current modules: 44 persistence/style/UI/court checks plus 73 dunk motion/validation/cleanup checks (117 total). They cover migration, one-time costs, malformed data, serial saves, per-court resolution/services, portal/menu security, arrival gating/cleanup, builder reruns/ownership, and high-Vertical styles translated to High School. No live DataStore calls or test dependencies were added.

Roblox services, physics, rendering, networking and IK are mocked in those historical court tests. The gym is first-pass art with one hoop and a static scoreboard. Court Bonuses v0.1 is implemented separately and needs its own Studio acceptance matrix in `COURT_BONUSES.md`. There is still no streaming prefetch/cinematic travel system, cross-Place teleporting or full profile session lock. The visual roof no longer blocks high jumps, but above-roof camera visibility still needs live Studio review. Future indoor courts must follow the Vertical clearance rule rather than altering jump balance.

## Files in This Milestone

Created:

- `src/shared/Config/CourtConfig.luau`
- `src/server/services/CourtService.luau`
- `src/server/services/CourtTravel.luau`
- `src/client/CourtsController.luau`
- `src/client/ui/CourtsView.luau`
- `tools/highschool.project.json`
- `tools/highschool/Build.luau`
- `tools/highschool/Config.luau`
- `tools/highschool/Scenery.luau`
- `tools/HighSchoolBuilder.rbxmx`
- `docs/COURT_PROGRESSION.md`

Changed:

- `default.project.json`
- `src/server/ServerMain.server.luau`
- `src/server/Config/DataConfig.luau`
- `src/server/data/PlayerDataSchema.luau`
- `src/server/data/PlayerDataStore.luau`
- `src/server/services/DataService.luau`
- `src/server/services/PlayerService.luau`
- `src/server/services/GameplayObjects.luau`
- `src/server/services/TrainingService.luau`
- `src/server/services/BasketballService.luau`
- `src/server/services/UpgradeService.luau`
- `src/server/services/DunkService.luau` (current-court Rim lookups only in this milestone)
- `src/server/services/DunkExecution.luau` (current-court Rim identity lookup only in this milestone)
- `src/client/HUDController.client.luau`
- `src/client/ui/HUDView.luau`
- `src/shared/Config/HUDConfig.luau`
- `README.md`
- `docs/GAME_DESIGN.md`
- `docs/ARCHITECTURE.md`
- `docs/ROADMAP.md`
- `docs/DATA_PERSISTENCE.md`

Older uncommitted Dunk Styles/HUD changes were already present and are retained, not claimed as new court work. No commits or pushes are part of this task.
