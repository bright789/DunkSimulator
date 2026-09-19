# Neighborhood Court v0.1: Automated Studio Build

## What Is Implemented

The builder creates a permanent first-pass environment: blue-gray half-court, contrasting paint, boundaries, key, free-throw circle, 28-segment three-point arc, a 20-segment orange rim with backboard/support, training signage/pad, basketball stand, entrance sign, perimeter fencing, sidewalk/curb/street, three simple houses, four trees, two bushes, two benches, two trash cans, and two court lights. No external assets, meshes, unions, uploaded images, dependencies, or interactive prop scripts are needed.

This is a Studio **edit-mode tool**, not a live-server map generator. It uses the existing CourtSurface/ParkGround and existing gameplay instances. The logical Rim is the fixed anchor: its identity, CFrame, Size, and tested floor-to-rim height stay unchanged. No gameplay source/configuration is modified.

## One-Time Setup: Import and Run

1. **Stop Play and save a separate backup of your working place.** Leave Map, Gameplay, and SpawnLocation in place. Do not delete anything before syncing/importing.
2. In Explorer, right-click **ServerStorage**, choose **Insert > Import Roblox Model** (older Studio versions call this **Insert from File**), and select the repository file `tools/NeighborhoodBuilder.rbxmx`. Confirm that `ServerStorage.NeighborhoodBuilder` contains the four ModuleScripts Build, Config, Geometry, and Scenery. Import into the working place, not a new place. Roblox documents this [model-import workflow](https://create.roblox.com/docs/parts/model-generation).
3. Open Studio's **Command Bar** (Window > Script > Command Bar, or View > Command Bar on older layouts). Run this single command **while Play is stopped**:

   ```luau
   require(game:GetService("ServerStorage").NeighborhoodBuilder.Build).Run()
   ```

4. Output should report the number of anchored Parts and preserved rim height. Inspect the scene, save the place, then press Play. The tool rejects Play/Run mode. Nothing is generated automatically when a server starts. The Command Bar is described in [Studio's debugging documentation](https://create.roblox.com/docs/studio/debugging).
5. After building, you may delete **only `ServerStorage.NeighborhoodBuilder`**; the generated Parts remain. Keeping the folder is also inert, but removing it avoids shipping unused editor tooling. Do not delete Gameplay or the generated map.

There is no live Studio connection available to the coding agent in this session; importing/running is the remaining manual action. The generated tool model is already built for you. No changes to the Rojo plugin connection are necessary.

## Required Existing Objects

```text
Workspace
  Map (Folder)
    Neighborhood (Folder)
      Court (Folder)
        CourtSurface (anchored, collidable BasePart; approximately 60 x 0.5 x 55)
      Environment (Folder)
        ParkGround (anchored, collidable BasePart; approximately 130 x 1 x 120)
      Props (Folder; created if absent)
      Boundaries (Folder; created if absent)
  Gameplay (Folder)
    VerticalTrainer (anchored BasePart with direct ProximityPrompt)
    BasketballPickup (anchored BasePart with direct ProximityPrompt)
    DunkHoop (Model)
      Rim (existing anchored BasePart)
  SpawnLocation (existing anchored SpawnLocation)
```

Names must be unique. Surface yaw is supported, but floors must be horizontal. ParkGround's top must be at or up to one stud below CourtSurface's top. The builder checks these prerequisites before changing the place. It does not silently invent missing gameplay objects or reset their configuration. An error tells you which existing object needs attention; do not fix a floor-height error by moving the Rim.

## Exact Ownership Boundary

**Normal Rojo project:** unchanged. `default.project.json` still has **no Workspace entry**. Rojo cannot sync/delete these map objects through this configuration. It continues to manage gameplay code, Shared, and Remotes only.

**Tool source control:** `tools/neighborhood.project.json` packages only a Folder of editor modules. Use `rojo build`, not `rojo serve`, for this separate project. The generated `tools/NeighborhoodBuilder.rbxmx` is an import convenience artifact; edit the `.luau` sources and rebuild it rather than editing its XML.

**Studio:** owns Map, Gameplay, SpawnLocation, generated environment Parts, Lighting, and unrelated Workspace content. Save the finished place separately; a gameplay Rojo build still does not contain the map. Source control retains the deterministic construction recipe, not all subsequent manual map edits.

The builder creates the following **explicitly replaceable output folders**. It marks each with `BuilderOwner = DunkSimulator.Neighborhood.v1`. An explicit rerun replaces only these marked folders, not their parent containers:

```text
Workspace.Map.Neighborhood
  Court
    CourtSurface                         existing, reused
    NeighborhoodV01
      Paint
      Lines                              named boundary/key/arc segments
  Environment
    ParkGround                           existing, reused
    NeighborhoodV01
      Sidewalk / Curb / Street / RoadDash...
      Houses
  Props
    NeighborhoodV01
      TrainingArea / BallStand
      Benches / Trees / Lights
      Bush... / TrashCan...
      Entrance
        EntranceSign / EntrancePost-1 / EntrancePost1
  Boundaries
    NeighborhoodV01
      Fences
        Left / Right / Back / FrontLeft / FrontRight
Workspace.Gameplay.DunkHoop
  Rim                                    existing logical reference
  NeighborhoodV01                        generated visual-only hoop
    VisibleRim / Backboard / Pole / Base / Support / RimBracket / Target...
```

The hoop's generated visual folder serves the proposed `Visuals` role; its unique name avoids taking over a manually created `Visuals` folder. An unmarked folder with the same output name causes a refusal rather than deletion. Put manual additions **outside NeighborhoodV01** if you want them preserved across explicit rebuilds. Normal Rojo sync never rebuilds these folders.

## Changes to Existing Instances

- **Rim:** only Transparency becomes 1. Position, orientation, size, parent, anchoring, and collision settings are untouched. Visible hoop geometry is non-colliding and non-queryable.
- **CourtSurface and ParkGround:** instances, dimensions, thickness, collision properties, and top Y levels are retained. Their X/Z centers are aligned around the fixed Rim so it sits six studs inside the baseline. Court heading follows the existing surface's yaw, choosing its hoop-facing end. Ground adopts this yaw. This can shift the existing surfaces horizontally; it does not lower the dunk threshold.
- **Trainer/pickup:** the original Parts and prompts are retained with all gameplay/prompt settings. Only CFrame is changed to present them beside the entrance approach. No source logic or reward setting changes. Trainer center is approximately X=-43, Z=-18 and pickup X=-18, Z=-35 relative to the new court center, with their bottoms just above park ground.
- **SpawnLocation:** retains the existing instance, size, collision, Enabled, Neutral/team settings, and normal spawn behavior. It sits 12 studs inside the entrance, facing the hoop. The pad and its Decal/Texture children now have Transparency=1 and the pad has CastShadow=false, removing the dominant white square without shrinking its functional spawn area. These presentation changes participate in rollback; no children are deleted.
- **Previous hoop decoration:** direct children named Backboard, Pole, Support, VisualRim, TargetBox, or Visuals are retained, but their BaseParts are made invisible/non-colliding/non-queryable to avoid duplicate hoops. Unrecognized custom decorations are left alone. Restore from the backup if you want the original presentation back.
- **Lighting:** ClockTime=15.5, Brightness=2, OutdoorAmbient=(140,140,140). No Atmosphere, post-processing stack, rendering technology, or existing Lighting instance is replaced. Two small downward court lights have shadows disabled. Existing extreme Lighting effects may still require manual adjustment.
- **Everything else:** left alone, including other Map children, terrain, baseplates, and unrelated Workspace content. If old hand-made markings or props overlap the generated scene, inspect and relocate those specific objects manually after making a backup. Do not blanket-delete Map.

New scenery is staged off-Workspace first. The builder checks its Part budget and ownership before applying changes. Errors during application restore changed properties and previous generated folders. This protection is not a replacement for a saved backup or verification in your actual place.

## Layout and Visual Budget

The actual existing surface sizes are used, accepting up to two studs of variation from 60 x 55 and 130 x 120. No size changes are made. Relative to the court center, the hoop is on positive Z and the entrance is on negative Z. Flow: entrance/spawn -> pickup/trainer -> court -> hoop.

- Key: 16 x 19. Three-point radius: 24, 28 segments. Free-throw circle: radius 6, 20 segments. Thin paint/lines sit 0.025/0.055 studs above the floor and are non-colliding.
- Visible rim radius: 2.2, 20 segments. Backboard: 14 x 8. All hoop geometry is decorative, so it cannot obstruct assisted execution.
- Fence: nine studs high, **20-stud clear entrance opening between the inner post faces**, sparse crossed-wire panels with simple transparent collision barriers. FrontLeft and FrontRight are generated independently and stop outside the gateway posts; no front rails, wires or collision barrier span the opening. Other perimeter fence generation is unchanged. It suggests chain-link without dense wire geometry or textures. It is not an anti-cheat wall; advanced jumping can clear it.
- Gateway: one-stud-square posts at local X=+/-10.5, height 11.5. Sign width 22, height 2.5, center Y=10.25 above park ground: its bottom is nine studs high. The sign is centered over the opening and readable on both sides. Front fence endpoints are X=+/-11.1, leaving 0.1 studs to the posts' outer faces. Duplicate small terminal posts are omitted at those endpoints; the gateway posts serve as terminals. All positions use the park's frame, so rotated layouts retain the same clearances. Config exposes EntranceWidth, EntrancePostWidth, EntrancePostHeight, and EntranceFenceGap.
- Hard budget: 400 generated BaseParts, checked before installation. Output prints the actual count. All generated Parts are anchored; only sidewalk, curb, street, five fence barriers, and the two gateway posts collide. The posts sit entirely outside the opening; the overhead sign is non-colliding. Decorative Parts cannot create new jump platforms near the rim. Only two lights; no generated scripts, physics constraints, effects, or asset requests.
- Benches/trees/props are intentionally non-colliding first-pass scenery. Net simulation and final-art detail are deferred.

Geometry and layout live in `Scenery.luau`, reusable primitive construction in `Geometry.luau`, and major palette/segment/budget values in `Config.luau`. These settings are **editor art settings**, separate from gameplay configuration. Do not retune DunkConfig or ProgressionConfig to compensate for map mistakes.

## Rebuilding After Tool Changes

From the repository root:

```powershell
rojo build tools/neighborhood.project.json --output tools/NeighborhoodBuilder.rbxmx
```

If the Rokit shim fails, use:

```powershell
& "$env:USERPROFILE\.rokit\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe" build tools/neighborhood.project.json --output tools/NeighborhoodBuilder.rbxmx
```

Stop Play, save, remove only the old imported `ServerStorage.NeighborhoodBuilder` folder, import the rebuilt file, and run again. Reimporting avoids Roblox's ModuleScript require cache keeping the previous tool code. Generated output folders will be replaced; user-edited contents inside them are not preserved. Keep a backup if retaining those edits matters.

For the entrance update, the supplied artifact is already rebuilt. Run the same Build.Run command after reimporting. No map-folder deletion or gameplay migration is needed. Existing builder ownership names/attributes are unchanged: replacement of the marked Props and Boundaries output removes the old entrance sign/posts/front fence, rather than appending a second set. The normal Run still regenerates all its owned output using the same layout elsewhere; it does not selectively preserve manual edits inside those output folders. Unmarked/manual objects outside them are not cleared.

## Gameplay Regression Checklist

- Spawn near the open gate facing the court; walk to both stations without collision traps.
- Hold E at VerticalTrainer: continuous +1 Vertical/+5 Cash per existing interval; release/move away/death stops training normally.
- Pickup works from the front of the stand; exactly one held ball and F hint appear. Decorative signs must not obstruct prompt sightlines.
- On the flat court, test Vertical 30 (normally cannot dunk), about 35 (first dunk), 40 and 50 (more comfortable). Check floor/Rim height and any leftover baseplate if results differ; do not retune progression.
- Jump/F near the rim: existing buffer, alignment and ball-through-rim execution remain responsive. Grounded/distant attempts and F spam produce no extra rewards.
- Each completed dunk awards exactly +25 Cash, changes no Vertical, restores the ball to the hand, and restores movement.
- Death/respawn and cancelled execution still clean up correctly. No errors in Output.
- Save/reopen the place, sync the normal Rojo project, and verify the environment survives without running the builder again.

## Visual and Builder Checklist

- Court lines are visible from the normal camera with no flickering; arcs are curved, not rectangular.
- Only one visible hoop; the orange ring centers on the unchanged logical Rim. Check old unnamed decoration manually if duplicated.
- Trainer sign and ball rack read clearly; entrance opening and spawn path remain unobstructed.
- Fence blocks ordinary walking through closed sections, but the gate stays open.
- Approach from the street and walk through the center and both sides of the 20-stud gate. No invisible front barrier should block the path. Check the sign from outside and inside: posts line up with opening edges, and rails/wires stop outside the supports.
- Spawn faces into the park without a white pad/logo or pad shadow drawing attention. Confirm respawn/team behavior is unchanged. If a separate manually built white platform remains, inspect it in Explorer; the builder deliberately does not delete arbitrary Parts.
- Houses, trees, benches, road and lights establish a neighborhood without obscuring the hoop or prompts.
- Lighting stays bright enough to see the ball/character. Check the actual game's existing post-processing settings.
- Rerun in a saved test copy: no duplicate generated folders/props; Rim CFrame/Size/top-floor relationship remain identical.
- Remove a prerequisite in a disposable copy and run: fail clearly without constructing a partial map. An unmarked output-name collision must also fail safely.
- Do not treat a successful Rojo build as proof of in-engine visuals or gameplay. Those checks require Studio.
