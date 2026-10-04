# Skyline Rooftop (Court #4) and New Dunk Styles

Court #4 is an open-air court on top of a skyscraper at night. Three new dunk styles come with it, and Rebirth now needs this court, so every run climbs all four courts.

## The court

| | Value |
| --- | --- |
| Unlock | **250 Vertical + $120,000**, from the new bus stop outside the College Arena (left of the High School stop) |
| Bonuses | **×2.0 dunk and air-trick Cash**, **×1.45 training** |
| Training cap | **350 Vertical** |
| Travel back | The **Elevator** on the roof (prompt: "Elevator to College Arena"). The COURTS menu also travels for free once unlocked. |

**What's up there:**
- A teal sport court with magenta paint and the SKYLINE logo.
- A parapet with neon trim and a glass rail, and invisible walls taller than a max jump so nobody falls off.
- Four flood lights and short bleachers with a night crowd.
- A water tower, AC units, and the leaderboards.
- A **SKYLINE ROOFTOP** sign behind the hoop.
- Two antenna masts holding neon **height gates** at 250, 300 and 350 Vertical. They sit where your feet reach at the top of the jump.
- The tower continues below the roof, surrounded by a ring of 46 lit city towers.
- There's no roof, so 350-Vertical jumps (about 470 studs high) have open sky. The builder refuses to build if the invisible walls are ever shorter than a max jump.

**Lighting:** its own night preset in `LightingConfig.Courts.Rooftop`:
- Cool ambient light, light haze so the skyline shows, and neon bloom.
- The flood lights are at brightness 1.4. Higher values washed out the teal floor.

## New dunk styles

| Style | Vertical | Base reward | Opening air trick | Motion |
| --- | --- | --- | --- | --- |
| **Between the Legs** | 150 | $130 | Backflip | The ball dips, passes under the legs to the other hand, and rises overhead for a two-hand slam |
| **Rock the Cradle** | 200 | $165 | Cartwheel | The ball is cradled on the forearm, swung down past the hip and back, then way up and over |
| **Elbow Hang** | 280 | $210 | 720 | The arm goes through the rim to the elbow, then a long 1.1 s hang. The success heading reads "HONEY DIP!" |

- **Animation:** no published animation clips yet. They use the game's procedural system: a server-driven ball path plus body pose, the same as the original four when no clip ID is set. Add clips later through `DUNK_ANIMATIONS.md`.
- **Contest judges:** they rate them above the Windmill (style base 7.3, 7.6 and 8, against the Windmill's 7).
- **DUNKS panel:** it now scrolls, so all seven styles fit.

## Rebirth change (affects live players)

Rebirth now needs **300 Vertical** (only trainable at the Skyline Rooftop) and **$200,000 × 1.6ⁿ** Cash. Before, it was 200 Vertical and $100,000 × 1.6ⁿ.

- **Why:** without this change, players would skip Court #4 entirely, because the old requirement was met at College.
- **Pacing model:** training 0.25, no daily rewards, contests or Perfect bonuses. The first Rebirth moves from about 35 to about 48 minutes, and each later run gets the new court.
- **Existing players:** those saving up for a Rebirth under the old numbers now need the Rooftop first. Their Rebirth count and bonuses are unchanged.

## Pacing change: training speed

`ProgressionConfig.Training.BaseProgressPerTick` changed from **1.0 to 0.25**. Training used to take under 2 minutes for a whole run, which made Training Upgrades almost pointless. It now takes about 1–2.5 minutes per court. (Later replaced by per-level rates of about +0.1 Vertical per rep per Training Level; Level 1 is +0.15. See `TRAINING_UPGRADES.md`.)

## Other updates

- **Analytics progression funnel:**
  - Now: FirstDunk → Vertical75 → HighSchool → Vertical150 → College → Vertical200 → **Vertical250 → Rooftop → Vertical300** → FirstRebirth.
  - Existing players simply log their highest step again. Roblox counts a later step as also reaching the earlier ones.
- **New badge "Skyline"** (unlock the Rooftop, `Id = 0` until created). There are now **5 badges left to create**: Sky Walker, Roof Raiser, Born Again, Dunk Champion and Skyline. Its image is `assets/badge-icons/skyline.png`.
- **Court prompts:** they can now name their own ride word (`PortalVerb`). The Rooftop uses "Elevator to".

## Fix: invisible wall across the court (2026-09-27)

**Symptom.** On the live game, players couldn't walk from the elevator/spawn end onto the rest of the court. An invisible wall stopped them around the near free-throw line.

**Cause.** `Edge.BarrierSouth`, the invisible wall that keeps players from falling off the south edge of the roof, had been dragged in Studio from z = 105.25 to z = 53.75, straight across the court.
- It sits right in front of Studio's default edit camera, so a click-and-drag in the 3D view grabs it.
- This was almost certainly an accidental drag while resizing a Studio panel.

**Fix.**
- The wall was moved back to (7200, 261, 105.25), matching its parapet and the other three walls.
- All 9 invisible solid parts in `Workspace.Map` are now **Locked**: the 4 rooftop edge walls and the 5 Neighborhood fence `Collision` walls. They can't be selected or dragged from the 3D view any more.
- The Neighborhood and Rooftop builders now set `Locked = true` on these walls too (`tools/*Builder.rbxmx` repackaged).

**Checked.**
- A scan of every court for invisible solid parts at body height found none on any court, only the Neighborhood fence walls at the lot edge.
- A test player walked from the rooftop spawn to the far key with `Humanoid:MoveTo`.

**Needs a Studio publish:** the fix lives in the place, not in the Rojo-synced scripts.

## Building it in Studio (already done in the current place)

1. Add a temporary `ServerStorage → RooftopBuilder` mapping to `default.project.json` pointing at `tools/rooftop.project.json`. Restart `rojo serve` and connect.
2. In the edit-mode Command Bar:
   ```lua
   local c = game.ServerStorage.RooftopBuilder:Clone() c.Parent = game.ServerStorage
   print(pcall(function() return require(c.Build).Run() end)) c:Destroy()
   ```
3. Remove the mapping, restart Rojo, and delete `ServerStorage.RooftopBuilder`. Then save and publish.

**Rebuild behavior:**
- Rebuilding replaces only builder-owned scenery; gameplay objects are created once and never moved.
- It needs the College built first, and it also adds the Rooftop bus stop to the College's `Environment`.
- Result in this place: **1,071 decorative parts** (budget 2,000), rim height 12 studs like every court.
- `tools/RooftopBuilder.rbxmx` is the packaged builder.

## Tested in Studio (QA store)

- **Arrival:** a profile set to 300 Vertical at the Rooftop spawned on the roof. The Courts panel listed all four courts, and the Rebirth panel showed "300 / 300 MET" and $320,000 (2nd Rebirth).
- **Dunks:**
  - **Elbow Hang:** completed for $4,662 plus a $161 air trick.
  - **Between the Legs:** pressed on the way down from a 300-Vertical jump; completed with a 5-trick combo (Corkscrew shown), paying $2,886 plus $503 in tricks.
  - Analytics logged the batched Dunk and AirTrick Cash.
- **Travel:** the elevator (real E key) rode to the College, and the new College bus stop rode back up.
- **DUNKS panel:** scrolls and shows all seven styles; equipping Between the Legs worked.
- **Not checked:** the new dunk motions frame by frame, and a real phone. Both are worth a look.

## Files

- **New:**
  - `tools/rooftop/` (Config, Build, Scenery)
  - `tools/rooftop.project.json`
  - `tools/RooftopBuilder.rbxmx`
  - `docs/SKYLINE_ROOFTOP.md`
- **Changed:**
  - `CourtConfig`: Rooftop court, College portal, `PortalVerb`
  - `CourtService`: prompt verb
  - `DunkStyles`: three styles
  - `ContestConfig`: style bases
  - `RebirthConfig`: 300 Vertical / $200,000
  - `LightingConfig`: Rooftop preset
  - `MilestoneConfig`: funnel steps, Skyline badge
  - `ProgressionConfig`: training 0.25
  - `DunkStylesView`: scrolling list
