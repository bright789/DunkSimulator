# Visual Style ("pop" pass)

Goal: a bright, saturated, high-contrast look in the spirit of popular Roblox action games, with bold UI.

## Lighting and post-processing (per court)

`src/client/LightingController.client.luau` applies `src/shared/Config/LightingConfig.luau` on each client and blends to the next court's look over `BlendSeconds` when `CurrentCourt` changes. It reuses the place's own Atmosphere / Bloom / SunRays / DepthOfField (adding a ColorCorrection) and only changes them locally, so Studio edit mode keeps the saved Lighting.

| Court | Look |
| --- | --- |
| Neighborhood | Sunny 14:00, clear blue Atmosphere (no grey haze), +32% saturation, contrast, gentle bloom and sun rays |
| HighSchool | Bright indoor arena: warm ambient fill, +26% saturation, contrast, highlight bloom, no haze |

Tune any Lighting or effect property per court in `LightingConfig`; omitted properties are left alone.

## Map palette

Both scenery builders read their colors from config:

- `tools/neighborhood/Config.luau` `Colors`: blue court, orange key, lush grass and trees, red-brick houses (`Brick`), sky-blue windows (`Glass`).
- `tools/highschool/Config.luau` `Colors`: warm hardwood, royal-blue paint and wall stripes, bright white lines and walls.

Scenery is Studio-owned, so after changing a palette: rebuild the package (`rojo build tools/<name>.project.json --output tools/<Name>Builder.rbxmx`), replace only the imported builder folder in ServerStorage, run its `Build.Run()` in the edit-mode Command Bar, then save/publish. The builders only replace builder-marked scenery and keep the rim, courts and gameplay objects.

## Stations and props

Shared prop library `tools/neighborhood/Props.luau` (packaged in both builders) dresses the gameplay stations; the gameplay Parts and prompts are unchanged.

| Station | Look |
| --- | --- |
| Basketball pickup | **Hoop Shop** stall: counter, striped awning, shelves of seamed basketballs, "HOOP SHOP" sign. Prompt: "Hoop Shop / Grab a Basketball". |
| Vertical Trainer | **Leg Day** gym corner: rubber floor, squat rack with barbell and plates, bench, plyo boxes, dumbbell rack. Prompt: "Leg Day Gym / Hold to Train Vertical". While training, players loop squats, lunges, jump squats and calf raises (client-only, `WorkoutPresentation`) and their ball rests on the floor beside them. |
| Training Upgrades | **Upgrade Lab** (both maps, electric purple `Colors.Lab`): glowing platform with neon trim, dark back wall with a lit LEVEL UP screen, stacked neon chevrons, a vertical-jump tester pole with colored vanes, and two lit sneaker display cases. Built by `Props.UpgradeLab`. |
| Court travel | **Bus stop** (glass shelter, route board naming the destination, BUS STOP sign, yellow curb) and a parked **school bus** on the road. The High School now has a sidewalk, street and lawn outside its entrance for its return stop. |

Both courts use the same hoop (`Props.Hoop`): an orange ring, a net, a blue target square, and a padded pole to the floor. Backboards are tinted, 35% transparent glass (`Colors.Backboard`, `Colors.BackboardTransparency` in both builder configs) instead of glowing white. Basketballs (shop props and each player's local visual ball) are pebbled leather with dark seams; the visual ball rolls and spins with its motion (`PresentationConfig.Ball.SeamColor`, `SeamWidth`, `DribbleSpin`).

## Spectators

`tools/neighborhood/Crowd.luau` (packaged in both builders) makes real R15 avatars with `Players:CreateHumanoidModelFromDescription` in edit mode. Each one is recolored into clothes (skin, shirt, pants, shoes), given part-built headwear (cap, backwards cap, beanie, headband, short hair, puff) and sometimes a foam finger. It's posed by forward kinematics (`Stand`, `StandCrossed`, `Sit`, `SitLean`, `SitClap`) and fully anchored. The Humanoid, the Animate script and the physics constraints are removed; the joint AnimationConstraints stay. Each rig gets the CollectionService tag `Spectator` and `ModelStreamingMode = Atomic`, so it streams in whole. The client also retries any rig that arrives incomplete.

- **Neighborhood:** one fan leaning forward on the bench across from the stations, and one standing with arms crossed just outside the sideline.
- **High School:** `Config.Crowd.PerSide` (10) fans on each bleacher, on random rows and spots (fixed `Seed`, so rebuilds match). The home side (-X) wears school blue/white and the guest side (+X) orange/red. `FoamFingerChance` of them wave foam fingers.

`src/client/CrowdPresentation.client.luau` animates them locally near the camera (`PresentationConfig.Crowd`). They breathe. Attentive fans turn their heads toward whoever is dunking, otherwise toward you, and the rest glance around. When any player within `CheerRadius` hits the Slam phase, they cheer: arms up, fist pumps and bouncing. Nothing is sent to the server.

## HUD

`src/shared/Config/HUDConfig.luau` sets the palette (deep navy panels, cyan accent, green/gold values), fonts (`FredokaOne` headings, `GothamBold` body) and `Style` (panel stroke, panel shading, text outline). `UIComponents` applies these to every panel and label, stat values use their card's accent color, and the dunk result heading gets a gold gradient and a bounce (`FeedbackConfig.Dunk.PopStartScale`, `PopBounceLength`).

Stat gains show as a pill badge in the card's accent color, with dark text, at the right end of the value row: `+$375` green, `+8` cyan, `LEVEL UP!` gold. It pops in, holds for about a second, then rises and fades as one piece (`FeedbackConfig.Stats.Badge*`, `GainHoldSeconds`).

## World signs

Every builder sign (`Geometry.Sign`) matches the HUD: a deep-navy rounded panel with a rim in the sign's color (the HUD's light-blue stroke for very dark signs), white FredokaOne text with a dark outline, unaffected by scene lighting. The colors mirror `HUDConfig`; if the HUD palette changes, update `tools/neighborhood/Geometry.luau` and rebuild both maps.
