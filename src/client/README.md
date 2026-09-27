# Client Source

Place client-side input, interface, camera, animation, and presentation code here. Client code may request gameplay actions but must not authoritatively change player progress or rewards.

`DunkController.client.luau` sends an empty F-key dunk request, shows the possession hint, and displays server-confirmed success. It never grants rewards or decides dunk results.

`DunkAnimationController` caches optional real R15 tracks per character and retains procedural fallback when IDs are absent. `HUDController` renders server-owned stats and a server-sent court training-cap notice. Neither controller changes gameplay state.

`PresentationController.client.luau` drives client-only movement presentation for every character: `BallPresentation` (local visual ball and dribble arm IK), `BodyPresentation` (dribble stance, air pose, landing crouch), `WorkoutPresentation` (leg-day workout while training) and `LocomotionFeel` (local fall gravity, landing camera dip, dust). It reads replicated state only.

`CrowdPresentation.client.luau` animates the builder-made spectators (breathing, head tracking, cheering on slams). See `docs/VISUAL_STYLE.md`.

`TransitPresentation.client.luau` plays the bus departure for riders (server-set `TransitRide`) and the local rider's camera and fade. Travel itself stays server-side in `CourtTravel`. See `docs/MOVEMENT_PRESENTATION.md`.

`LightingController.client.luau` applies the per-court lighting and post-processing look from `LightingConfig` on this client only. See `docs/VISUAL_STYLE.md`.
