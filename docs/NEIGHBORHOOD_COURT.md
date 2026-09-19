# Court #1: The Neighborhood

## Current v0.1 Build

**Use [the automated v0.1 builder](NEIGHBORHOOD_V01.md), not the manual construction steps below.** The playtested scale is now CourtSurface approximately 60 x 0.5 x 55 and ParkGround approximately 130 x 1 x 120. Workspace.Gameplay migration has been tested. The source-controlled editor tool builds permanent Parts around the existing logical Rim without changing gameplay. Import the supplied model and run one edit-mode command; normal Rojo Workspace ownership remains unchanged.

The remaining sections are the earlier design/manual reference, including its superseded 64 x 56 court dimensions and suggested object names. The v0.1 guide takes precedence for dimensions, exact hierarchy, generation, and ownership of rebuildable output folders.

## Scope and Theme

A compact, welcoming outdoor half-court between a sidewalk and neighborhood homes: worn blue asphalt, orange rim, muted green fencing, trees, benches, and warm lighting. This is the first real environment for the existing gameplay loop, not a new court-unlock system. All construction below happens in Studio edit mode. No runtime map generator or interactive prop scripts are needed.

## Ownership and Saving

- Rojo owns `src/server` -> ServerScriptService, `src/client` -> StarterPlayerScripts, `src/shared` -> ReplicatedStorage.Shared, and the declared Remotes.
- Studio owns Workspace, including Map, Gameplay, SpawnLocation, terrain, and every permanent environment Part. Studio also owns manually configured Lighting settings.
- `default.project.json` deliberately has no Workspace mapping and preserves unknown DataModel children. Leave it that way. Do not put map objects under Shared or Remotes; those folders are source-owned.
- Save the working place in Studio and keep a separate backup before map work. Git does not back up these map assets. Review Rojo sync changes before accepting deletions, and stop if Workspace assets appear in the proposed changes.
- A `rojo build` output contains code/remotes, not this map. Never replace the working Studio place with that build output. Edit map objects with Play stopped or the changes will be lost when Play ends.

## Complete Target Hierarchy

Folders unless a different class is specified. Decorative subfolders/models are organizational, not lookup targets.

```text
Workspace
├── Map
│   └── Neighborhood
│       ├── Court
│       │   ├── Surface (Part)
│       │   ├── Paint (Part)
│       │   └── Lines (Folder: boundary, key, free-throw, arc Parts)
│       ├── Environment
│       │   ├── Ground (Part)
│       │   ├── Sidewalk (Part)
│       │   ├── Street (Part)
│       │   ├── Buildings (Folder: decorative Models)
│       │   └── Trees (Folder: decorative Models)
│       ├── Props
│       │   ├── Benches
│       │   ├── TrashCans
│       │   ├── Lights
│       │   └── FutureStations (empty Folder; reserve space only)
│       └── Boundaries
│           ├── Fence (Folder: posts, rails, visual panels)
│           └── Collision (Folder: simple invisible barrier Parts)
├── Gameplay (Folder, exact name)
│   ├── VerticalTrainer (anchored Part)
│   │   └── ProximityPrompt
│   ├── BasketballPickup (anchored Part)
│   │   └── ProximityPrompt
│   └── DunkHoop (Model)
│       ├── Rim (anchored Part: logical reference, direct child)
│       ├── Backboard (Part)
│       ├── Pole (Part)
│       ├── Support (Part)
│       └── VisualRim (Model: ring segments)
└── SpawnLocation
```

Hoop decoration stays with its gameplay Model so moving the whole hoop keeps it aligned. The logical Rim can be invisible; DunkService never searches visual ring segments or mesh geometry. Do not put the three gameplay objects inside Court or another nested folder.

## Lookup and Safe Migration

`GameplayObjects` is the shared server-only resolver. For each requested name it first checks direct children of Workspace.Gameplay, then direct children of Workspace if that name is absent. No recursive search, cached positions, tags, or client-selected paths are involved. Mixed old/new layouts work temporarily.

A named object inside Gameplay takes priority even if its type is wrong; the service rejects it instead of silently choosing a legacy duplicate. If Gameplay exists but is not a Folder, discovery fails safely. Use exactly one object per name in each container, preferably only the new copy. Do not duplicate names: same-parent duplicates are ambiguous in Roblox.

1. Stop Play and save a backup of the working place. Record the current Rim Position, Size, Orientation, and the top Y of the flat floor from which successful test jumps begin. Also record trainer/pickup positions and prompt settings.
2. Sync this code revision through Rojo before reorganizing. Test once with the original root objects to confirm backward compatibility.
3. Create the Gameplay Folder directly in Workspace. Drag the existing VerticalTrainer, BasketballPickup, and entire DunkHoop Model into it in Explorer. **Move, do not duplicate.** Keep each prompt directly inside its original Part and Rim directly inside DunkHoop.
4. Reparenting should retain world positions. Compare recorded properties; do not use a move/scale tool during this step. Keep all existing sizes, heights, and prompt settings initially.
5. Restart Play and test the loop before building scenery. Trainer/pickup bind once at startup: replacing or moving them during Play is not a supported editor workflow. Rim is resolved during attempts and execution; removing/replacing it cancels execution without a reward.
6. Stop Play. Build the environment below, then reposition the original objects deliberately. Preserve the measured floor-to-rim height and leave a flat, unobstructed approach. Save again.

Older prototype guides show root Workspace paths; these remain a compatibility layout, not the target Neighborhood hierarchy. Do not rerun `SetupDunkStudio.luau` to migrate objects: that legacy helper now refuses to run when Gameplay exists, preventing accidental root duplicates.

## Scale and Coordinate Plan

All dimensions are studs, all Positions refer to Part centers, and Size is `(X, Y, Z)`. This is a gameplay-scaled half-court, not an NBA specification. The fenced park is approximately 120 x 110; reserve about 170 x 180 including sidewalk, street, and building facades. The playing rectangle is 64 wide x 56 deep, with generous sideline space.

Use a convenient court center `(0, F, 0)`, where **F is the existing tested takeoff floor's top Y**, not necessarily zero. Offset every X/Z coordinate consistently if building elsewhere. Positive Z is behind the hoop; players approach it from negative Z. Record **H = existing Rim.Position.Y - F**. Keep H unchanged; the new Rim center is `(0, F+H, 22)`. Do not substitute an assumed regulation height.

The physical relationship between flat floor and rim, not a Vertical stat gate, preserves Vertical 30 below normal dunk capability, around 35 as the first milestone, and 40+ as more comfortable. A raised court, step, bench, or spawn pad near the rim can change that relationship. Decorative paint/lines are non-colliding to avoid changing takeoff height.

## Ordered Studio Construction Guide

### 1. Establish the folders and clear work area

Open Explorer and Properties, stop Play, and follow the migration checklist first. Insert Folders and Models with the exact names above. Add Parts through Studio's Part tool, rename them, then enter Size and Position in Properties. Set every permanent Part Anchored = true.

Unless noted otherwise, floors/ground use CanCollide = true; painted lines, hoop decoration, and fine fence details use CanCollide = false, CanTouch = false, CanQuery = false. Gameplay trainer/pickup should retain their current validated settings; recommended non-colliding station Parts still keep CanQuery = true for prompt visibility. The logical Rim needs Anchored = true and CanCollide = false. No scripts belong in scenery.

### 2. Lay the ground and half-court

| Part | Size | Position | Finish |
| --- | --- | --- | --- |
| Ground | (120, 1, 110) | (0, F-0.75, 0) | Grass, muted green RGB(83,111,69) |
| Surface | (64, 0.5, 56) | (0, F-0.25, 0) | Asphalt, blue-gray RGB(57,76,89) |
| Paint | (16, 0.02, 20) | (0, F+0.015, 18) | SmoothPlastic, faded blue RGB(64,113,139) |

Ground top is F-0.25, slightly below court top F; Paint is a non-colliding visual overlay. Remove the old test baseplate only after confirming the new floor covers the play area and saving a backup. Otherwise resize/lower it so no exposed upper surface changes jumping or causes flickering. Do not delete the existing SpawnLocation or gameplay objects with it.

### 3. Add painted boundaries, key, and free-throw line

Use white SmoothPlastic Parts, CanCollide/CanTouch/CanQuery = false. Thickness Y = 0.02, center Y = F+0.035 (slightly above Paint). Width of each line is 0.3 studs.

| Marking | Size | X/Z center |
| --- | --- | --- |
| Baseline and opposite boundary (two Parts) | (64, 0.02, 0.3) | (0, 28), (0, -28) |
| Sidelines (two Parts) | (0.3, 0.02, 56) | (-32, 0), (32, 0) |
| Key sides (two Parts) | (0.3, 0.02, 20) | (-8, 18), (8, 18) |
| Free-throw line | (16, 0.02, 0.3) | (0, 8) |

This makes a 16 x 20 key from baseline Z=28 to free-throw Z=8. Court lines have no scoring behavior. A free-throw semicircle is optional decoration, not a blocker for the first build.

### 4. Make a practical three-point arc from Parts

Use a faceted painted semicircle of radius 26 centered beneath the rim at X=0, Z=22. It reaches X=+/-26 and forward to Z=-4. Add corner straight lines sized (0.3, 0.02, 6) centered at (+/-26, F+0.035, 25).

For a script-free arc, make 18 white non-colliding strips sized (0.3, 0.02, 4.55). In Properties set each strip's Position and Y Orientation using this table. Every Y position is F+0.035; X/Z Orientation are zero. These values approximate tangent segments, avoiding any plugin or runtime generation. Duplicate the first Part and enter the next row's values.

| Segment | X | Z | Y Orientation (degrees) |
| --- | ---: | ---: | ---: |
| 1 | 25.90 | 19.73 | 5 |
| 2 | 25.11 | 15.27 | 15 |
| 3 | 23.56 | 11.01 | 25 |
| 4 | 21.30 | 7.09 | 35 |
| 5 | 18.38 | 3.62 | 45 |
| 6 | 14.91 | 0.70 | 55 |
| 7 | 10.99 | -1.56 | 65 |
| 8 | 6.73 | -3.11 | 75 |
| 9 | 2.27 | -3.90 | 85 |
| 10 | -2.27 | -3.90 | 95 |
| 11 | -6.73 | -3.11 | 105 |
| 12 | -10.99 | -1.56 | 115 |
| 13 | -14.91 | 0.70 | 125 |
| 14 | -18.38 | 3.62 | 135 |
| 15 | -21.30 | 7.09 | 145 |
| 16 | -23.56 | 11.01 | 155 |
| 17 | -25.11 | 15.27 | 165 |
| 18 | -25.90 | 19.73 | 175 |

### 5. Move and dress the existing hoop

Move the entire DunkHoop horizontally until its logical Rim is `(0, F+H, 22)`. Retain the Rim's tested Size and world Y relative to F. Set Transparency = 1 after visible geometry is ready; do not replace it with a mesh or move it under VisualRim.

For new visual Parts, let R = F+H. All are anchored and non-colliding/non-queryable so they do not obstruct execution or prompt sightlines:

| Part | Size | Position | Finish |
| --- | --- | --- | --- |
| Backboard | (16, 9.33, 0.4) | (0, R+3.335, 25.6) | White SmoothPlastic |
| Pole | (1.2, H+7, 1.2) | (0, F+(H+7)/2, 28) | Dark gray Metal |
| Support | (1.2, 1.2, 2.4) | (0, R+4, 26.8) | Dark gray Metal |

Create VisualRim from eight orange bars sized (1.95, 0.25, 0.25), at Y=R. Relative to logical rim X/Z center: (0,+2.2) and (0,-2.2), Y rotation 0; (+2.2,0) and (-2.2,0), rotation 90; (+1.56,+1.56) and (-1.56,-1.56), rotation 45; (+1.56,-1.56) and (-1.56,+1.56), rotation -45. The open ring permits a clear view of the scripted ball path. Keep the logical Part invisible inside it. Do not add net/rim physics.

These roughly basketball-like proportions are scaled to the existing two-stud ball; preserving H takes precedence over real-world height. See `DUNK_PRESENTATION.md` for optional backboard target markings; animation work remains separate.

### 6. Position trainer, pickup, and spawn

- VerticalTrainer: retain its size and prompt; suggested center X=-44, Z=-6, bottom on Ground top F-0.25. For a 4 x 2 x 4 Part, center Y=F+0.75. Keep ten studs of clear approach space, including a clean line of sight to its center. Give its pad a muted yellow accent without putting it near the hoop.
- BasketballPickup: suggested size (3,2,3), center (-24,F+0.75,-34), orange SmoothPlastic. Retain its direct ProximityPrompt, Enabled=true, E key. Server configures action text, HoldDuration=0 and interaction distance. Do not add scripts.
- SpawnLocation: keep directly under Workspace. Suggested size (6,0.5,6), center (0,F,-43), Anchored=true, CanCollide=true, Neutral=true, AllowTeamChangeOnTouch=false. This sits on Ground with its top F+0.25, far away from the dunk area. Face the spawn toward positive Z (suggested Y Orientation=180), then verify facing in Play. Keep the entrance route clear.
- Trainer likewise uses a direct Enabled ProximityPrompt with E; the server retains the current continuous-hold configuration. Do not change training values or add a second trainer.
- Reserve two empty 10 x 10 spaces at (44,-12) and (44,8) in X/Z for future upgrades/training. Do not place active prompts, shops, or new stats there yet.

### 7. Add perimeter fencing and a clear entrance

Fence perimeter: X=+/-60, Z=-55 and +55. Leave a 12-stud entrance centered at X=0 on Z=-55. Use Metal posts (0.5,10,0.5), centered Y=F+4.75 (base on Ground), roughly every ten studs. Add horizontal rails at Y=F+0.75 and F+9.25, thickness 0.2.

For chain-link style without imported models, build one ten-stud visual panel with thin diagonal Metal strips, clip/shorten the ends to the panel, then duplicate along the fence. Dark gray or desaturated green reduces visual noise. Keep these fine details non-colliding; avoid hundreds of dense pieces initially. Plain posts/rails are an acceptable first pass before adding chain-link detail.

Use separate transparent CanCollide=true barrier Parts under Boundaries/Collision, height 10, thickness 0.5: side walls length 110 at X=+/-60; back wall length 120 at Z=55; front sections length 54 centered X=+/-33 at Z=-55. Center their Y at F+4.75. Do not bridge the entrance gap. These are scenery boundaries, not an anti-cheat solution: high-Vertical players can jump over them.

### 8. Add sidewalk, street, and neighborhood backdrop

- Sidewalk: (140,0.5,12), center (0,F-0.25,-61), Concrete RGB(157,157,150). It touches the front fence at Z=-55 and ends at -67. Add a short non-colliding visual path from the gate toward spawn if desired.
- Street: (160,0.5,24), center (0,F-0.35,-79), Asphalt RGB(42,43,45). Its near edge is Z=-67. White/yellow non-colliding strips can suggest road markings. No vehicles or traffic systems.
- Buildings: a few anchored Models beyond the street/back fence or beside the park, outside movement lanes. Start with 18 x 18 x 16 facade blocks centered roughly (-40,F+9,-102), (0,F+9,-102), (40,F+9,-102). Use muted brick, tan, and gray; simple roof slabs and flat non-colliding windows. Do not add interiors or scripts.
- Trees: trunks roughly (1.5,8,1.5), green ball-shaped canopies roughly (8,8,8), around X=+/-52, Z=28 or -30, away from trainer sightlines. Anchor every Part.
- Benches: seats (7,0.5,2), backs (7,2,0.4), simple legs; place beside sidelines around (44,30) and (-44,30), not behind/beneath the rim. Trash cans can be dark cylinders roughly two studs wide and three high nearby. Props have no prompts or behavior.
- Keep elevated collidable props at least 15 horizontal studs from the rim to discourage unintended launch platforms. Keep streets/backdrop modest; they are not a second playable zone.

### 9. Light and reserve expansion space

Start with clear late-afternoon daylight (Lighting ClockTime around 15), neutral shadows, and readable court colors. Adjust manually in Studio; do not add a runtime lighting controller. Two anchored light poles around X=+/-48, Z=38, height 22, can carry downward-facing SpotLights. Start with Range=60, Angle=90, Brightness=1; inspect night/day performance before adding more lights. Avoid intense bloom or effects that hide the ball.

Reserve the east side beyond X=60 near Z=-30 for an eventual path to Court #2. For now keep the fence closed and use only optional non-interactive signage. No teleport, unlock, extra court, or reward logic is added. Keep buildings off that future route.

### 10. Save, sync, and test before adding detail

Player flow: entrance/spawn -> nearby pickup -> court/jump attempt -> trainer off the left sideline -> return to hoop -> reward. Keep the hoop visible from spawn and do not cover either prompt with props. Prioritize this loop over scenery density. Save the Studio place separately after every major construction stage.

## Acceptance Checklist

- Before migration: original root layout still trains, picks up, dunks, and rewards correctly.
- After reparenting and restarting Play: both prompts work; training gives +1 Vertical/+5 Cash per 0.5 seconds and stops on release, distance, death, or departure.
- Pick up one ball; repeated pickup cannot duplicate possession. F feedback and ball restoration still work.
- Test on the flat court at Vertical 30, around 35, 40, and 50 with the same avatar: 30 should remain below normal dunk capability; around 35 first basic dunks; 40/50 increasingly comfortable. If changed, check floor/Rim heights and launch props, not configuration.
- Completed dunk gives exactly +25 Cash, no Vertical change; F spam, grounded/distant attempts, or cancellation give no extra rewards.
- During execution, remove the resolved hoop in a disposable Play test: cancellation restores controls/ball without reward. Stop Play to restore edit-mode map.
- Missing/wrong-type trainer, pickup, Gameplay Folder, or Rim yields a clear warning/rejection, not a server crash. Test only in a backup/Play session.
- New Gameplay objects win over legacy root names; do not keep duplicates in the final saved map. Decorative objects named Rim elsewhere are ignored.
- Test walking from spawn through pickup/trainer/court, clear sightlines, unobstructed dunk alignment, and no collision from paint or hoop detail.
- Sync Rojo, confirm Map and Gameplay remain intact, save, close/reopen the saved place, and repeat the loop. A source-only build passing is not proof of map/runtime behavior.
