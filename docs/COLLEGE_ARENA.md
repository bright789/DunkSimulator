# Court #3: College Arena

College Arena is the third court and the last stop before a [Rebirth](REBIRTH.md). It uses the same court architecture as the High School: one `CourtConfig` entry, an explicit gameplay folder, a Studio-owned map built by an edit-mode tool, and bus travel through the existing `CourtService`/`CourtTravel` path. No new gameplay services were needed.

## Numbers (starting values — tune from a real playtest)

| Setting | Value | Where |
| --- | --- | --- |
| Unlock | 150 Vertical + one-time $40,000 | `CourtConfig.College.Requirements` |
| Dunk Cash bonus | x1.6 | `CourtConfig.College.Bonuses.DunkCashMultiplier` |
| Training bonus | x1.3 | `CourtConfig.College.Bonuses.TrainingMultiplier` |
| Training cap | 250 Vertical | `CourtConfig.College.TrainingVerticalCap` |
| New challenges | College Highlights (25 College dunks, $6,000), Sky Walker (250 Vertical, $12,000) | `ChallengeConfig` |

The 150 Vertical gate matches the High School training cap, so a player reaches College by maxing out the High School. The 250 cap is above the Rebirth requirement (200 Vertical), so College is where players finish a run. Example College dunk at 250 Vertical with a PERFECT slam: Windmill $100 x1.6 court x1.5 timing x3.2 Vertical = **$768**, plus air-trick Cash (also x1.6).

The optional challenge pool is now $22,700 (was $4,700).

## Map

Built 4,800 studs from the Neighborhood (the High School is at 2,400), with the same floor-to-rim height as the other courts.

- **Size:** 204 x 190 studs and **300 studs tall**. A max College jump (250 Vertical, feet about 265 studs up) stays indoors with room for the head and camera. `Build.Run` refuses to build if `CeilingHeight` is lower than the cap jump + `JumpHeadroom` (25).
- **Arena floor:** hardwood with full-court lines, purple paint and a "DUNK U" center logo; branded entrance.
- **Seating:** six-row lower bowl, a suite level (lit suite windows and an LED-style "DUNK U / SLAM CITY" ribbon board), and a ten-row upper deck up to the side walls. **56 seated fans:** 40 in the lower bowl and 16 on the upper deck, with a fixed random seed so rebuilds match. Fans use the existing `Spectator` tag, so `CrowdPresentation` animates and cheers them with no new client code.
- **Upper arena:** championship and retired-number banners, tall glowing clerestory windows, purple and gold neon rings, big roof trusses with a purple glow and a gold ring at the roof center.
- **Vertical meter:** gold lines across the back wall at the height your feet reach with 100, 150, 200 and 250 Vertical (computed from `ProgressionConfig.GetJumpHeight` when the builder runs), with a giant "DUNK U" crest between them.
- **Jumbotron and lights:** center-hung scoreboard with neon edge frames, on cables from the roof; four court light trusses at 54 studs (16 SpotLights, the middle two frame the jumbotron) plus a light truss over each upper deck (10 SpotLights).
- **Leaderboards:** the 3-panel stand behind the hoop, left of it (see `LEADERBOARDS.md`).
- **Street face:** glass curtain wall between purple fins, a gold crown, a big "DUNK UNIVERSITY ARENA" sign over the canopy and a "DUNK U" crest up top. Grass grounds surround the building.
- **Stations:** Leg Day trainer, Hoop Shop pickup and the purple Upgrade Lab just inside the entrance, using the same shared props as the other courts.
- **Hoop:** the shared regulation hoop (`Props.Hoop`), matching the Neighborhood and High School.
- **Ceiling rule:** the roof is above the cap jump, and it and all overhead dressing are still non-collidable and non-queryable, so jumps and the camera are never blocked.
- **Lighting preset:** `LightingConfig.College` — warm top light, purple bottom shift, soft bloom. The High School gym ambience loop also plays at College.

## Bus routes

- **High School → College:** a second bus stop on the High School sidewalk (`Gameplay.Courts.HighSchool.CollegePortal`). Its sign shows the requirement read from CourtConfig at build time (`COLLEGE ARENA / 150 VERTICAL / $40000`); rerun the builder after changing it. Locked players see UNLOCK in the COURTS menu, exactly like the High School gate.
- **College → High School:** the stop outside the College entrance (`Gameplay.Courts.College.HighSchoolPortal`).

## Gameplay hierarchy (created once by the builder, never moved on rebuild)

```text
Workspace.Gameplay.Courts.College
    DunkHoop/Rim            -- invisible logical rim used by dunk validation
    Spawn                   -- neutral SpawnLocation inside the entrance
    VerticalTrainer         -- ProximityPrompt stations (E)
    BasketballPickup
    UpgradeStation
    HighSchoolPortal        -- bus stop back to the High School
Workspace.Gameplay.Courts.HighSchool.CollegePortal
Workspace.Map.College.Environment.CollegeV01          -- builder-owned scenery
Workspace.Map.HighSchool.Environment.CollegeGateV01   -- builder-owned College stop at the High School
```

## Building it in Studio

The College has already been built into the current place. Use this only for a fresh place or after changing `tools/college/*`.

1. Stop Play, save a backup, and sync the main Rojo project (CourtConfig must contain `College`).
2. The High School must already be built (see `COURT_PROGRESSION.md`).
3. Rebuild the tool package if you changed its source:

   ```powershell
   rojo build tools/college.project.json --output tools/CollegeBuilder.rbxmx
   ```

4. In Explorer remove any old `ServerStorage.CollegeBuilder`, then right-click **ServerStorage > Insert from File** and pick `tools/CollegeBuilder.rbxmx` (Build, Config, Scenery, Geometry, Props, Crowd).
5. In the edit-mode Command Bar run:

   ```lua
   require(game:GetService("ServerStorage").CollegeBuilder.Build).Run()
   ```

6. Expect `[CollegeBuilder] Built 1869 decorative Parts...` with no errors (budget: 3,600 Parts). Save the place and restart Play.

Reruns replace only the two roots stamped `BuilderOwner = "DunkSimulator.College.v1"`; they refuse to replace a root that contains hand-added content. Existing gameplay objects are reused, not moved. Any error rolls the whole build back. The tool never runs from `ServerMain`.

## Files

- `src/shared/Config/CourtConfig.luau` — College definition; High School gains `Portals.College`.
- `src/shared/Config/ChallengeConfig.luau` — `college_dunks_25`, `vertical_250`.
- `src/shared/Config/LightingConfig.luau` — College preset.
- `src/client/CrowdPresentation.client.luau` — ambience at HighSchool and College.
- `src/client/ui/CourtsView.luau` — taller panel for three courts.
- `src/client/ui/HUDView.luau` — training-cap toast names the next court, or points to Rebirth at the last court.
- `tools/college/Build.luau`, `Config.luau`, `Scenery.luau`; `tools/college.project.json`; `tools/CollegeBuilder.rbxmx`.
- `tools/neighborhood/Props.luau` — shared `TransitStop` (moved from the High School scenery) used by both builders.

## Acceptance tests (passed in Studio play-test)

1. A saved High School profile with 150+ Vertical sees UNLOCK on the College stop; unlocking charges $40,000 and the bus ride lands at the College spawn.
2. A player below 150 Vertical or $40,000 cannot unlock or travel (server rejects; menu shows the requirement).
3. Training at College stops at 250 Vertical; the cap toast points to Rebirth.
4. A College dunk pays the x1.6 court bonus on dunk and air-trick Cash (tested: +$648 dunk, +$29 Spin720).
5. College fans idle and cheer on slams; a PERFECT slam triggers the bigger cheer.
6. The College → High School bus returns to the High School spawn.
7. A 250-Vertical jump stays indoors: measured rise 265.5 studs, head about 271 studs vs the 300-stud roof, and the camera stays below the trusses.

Still worth checking before release: two players on different courts at once, reset/rejoin while at College, and bringing a basketball on the bus.
