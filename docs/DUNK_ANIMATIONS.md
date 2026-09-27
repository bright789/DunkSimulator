# Dunk Animation System v1

The four dunk styles work without uploaded assets. `src/shared/Config/DunkAnimations.luau` deliberately has empty `AnimationId` slots. A configured, accessible R15 clip changes **avatar pose only**; the server still validates the attempt, aligns the character, moves the real held basketball through the logical Rim, restores possession, records challenges, and awards the configured court-adjusted Cash only after completed execution. No Studio map rebuild or profile migration is required.

## Generate editable R15 clips in Studio

> **Dunk v2 (slam + hang):** clips now cover only wind-up and slam, ending with the arm up; the rim grab and hang are procedural (`RimPresentation`). Markers per style: Slam = `GatherSeconds`, Release = Gather + Finish, Recover shortly after. See [Movement Presentation](MOVEMENT_PRESENTATION.md#dunk-finish-slam-rim-grab-hang-v2). If Studio has no *Import Roblox Model* entry, temporarily map `tools/dunkanimations` into `ServerStorage.DunkAnimationBuilder` in `default.project.json`, restart `rojo serve`, sync, then revert the project file.
>
> **Pose data fix (v1.1):** the first generated clips had torso/head pitch, feet and elbows inverted. `Poses.luau` now follows the R15 sign table in [Movement Presentation](MOVEMENT_PRESENTATION.md). Regenerate, then in Clip Editor use **Publish to Roblox > Overwrite an existing asset** for each clip so the IDs in `DunkAnimations.luau` stay the same.

The separate `tools/DunkAnimationBuilder.rbxmx` package contains `Build`, `Config`, and `Poses` ModuleScripts. It is **not** in `default.project.json` or `ServerMain`; `Build.Run()` also requires Studio edit mode (not Play). It authors four non-looping Action-priority `KeyframeSequence` assets under `ServerStorage.GeneratedDunkAnimations` without publishing or supplying asset IDs. The generated assets are source poses to inspect and refine, not gameplay animations until you publish them and configure real IDs.

1. Stop Play and save a backup of your place. In Studio Explorer, right-click **ServerStorage** and choose **Insert from File**. Select this repository's `tools/DunkAnimationBuilder.rbxmx`; confirm `ServerStorage.DunkAnimationBuilder` appears. If refreshing an older imported package, remove **only** `ServerStorage.DunkAnimationBuilder` first, then import the latest file. Leave existing `GeneratedDunkAnimations` in place.
2. In Studio's **Command Bar** (Edit mode, server context), run exactly:

   ```lua
   require(game:GetService("ServerStorage").DunkAnimationBuilder.Build).Run()
   ```

3. Expand `ServerStorage.GeneratedDunkAnimations`. It should contain `BasicOneHand`, `TwoHandPower`, `Tomahawk`, and `Windmill`, each a `KeyframeSequence` with R15 nested poses and `Gather`, `Slam`, `Release`, and `Recover` **KeyframeMarker** instances. Save the place. The command does not start Play or upload anything.

The builder stages and validates all four sequences before changing the destination. It replaces only sequences with its `BuilderOwner = DunkAnimationBuilderV1` attribute, refuses to overwrite a same-named unowned clip, and preserves unrelated ServerStorage/folder contents. **Duplicate a generated clip before hand-editing it**: rerunning the builder replaces its own four generated sequences but never touches independent Animation Editor saves. `ServerStorage` is not owned by normal Rojo sync. Do not run this package from a runtime script or move it into the production source tree.

### Preview and edit Basic One-Hand

1. In Studio's **Avatar** tab, use the rig/character builder to insert a standard **R15 Block Avatar** into Workspace. Rename it `DunkPreviewRig`. Do not use an R6 rig.
2. Open **Avatar > Clip Editor** (Animation Editor), select `DunkPreviewRig`, create a temporary blank clip named `DunkPreviewSeed`, then **Save** it locally. Close the editor. This initializes the rig's `AnimSaves` reference; in current Studio it is an `ObjectValue` pointing to a folder under `ServerStorage.RBX_ANIMSAVES`.
3. With Play still stopped, run this exact **Command Bar** command once to copy all four generated clips into that rig's editable local saves:

   ```lua
   require(game:GetService("ServerStorage").DunkAnimationBuilder.Build).CopyToRig(workspace.DunkPreviewRig)
   ```

   Confirm all four clips appear under the folder referenced by `workspace.DunkPreviewRig.AnimSaves.Value`. Repeating this command preserves existing preview saves and only copies missing clips. Keep the originals in `GeneratedDunkAnimations` as rebuildable sources.
4. Reopen **Clip Editor**, select `DunkPreviewRig`, use the editor's **⋯ > Load > BasicOneHand**, then Play/scrub the timeline. Check the right arm reaches overhead with a one-hand silhouette, the left arm counters, the knees tuck asymmetrically, and the body recovers. Adjust any pose/timing/marker directly in the editor and **Save** the edited clip. Repeat for each style. If your Studio version uses a different local-save layout, follow [Roblox's import/load workflow](https://create.roblox.com/docs/education/build-it-play-it-island-of-move/sharing-animations) using a `.rbxm` export of the generated `KeyframeSequence`; do not import a lone `Keyframe`.

### Publish Basic One-Hand and configure it

1. In Clip Editor, load the edited `BasicOneHand` save, verify **Looping off** and **Action** priority, then use **⋯ > Publish to Roblox**. Publish under the experience owner or a creator/group authorized for this experience. Roblox Studio must perform this publication; the builder cannot do it.
2. Copy the **actual published numeric animation asset ID**. In the repository, edit `src/shared/Config/DunkAnimations.luau`: replace only the empty string in `BasicOneHand.AnimationId` with `"rbxassetid://<your published numeric ID>"`. Do not change `TwoHandPower`, `Tomahawk`, or `Windmill` until those clips are published.
3. Sync the main Rojo project, restart Play, and dunk with Basic equipped. Basic should play the real R15 track; the other three should use the procedural fallback. If Basic still falls back, inspect Studio Output and check ownership/permissions, R15 rig, and clip length. Test high Vertical, ball/rim contact timing, reset, rewards, and two-player visibility before accepting it.

**Generated timing and motion** (seconds from `AnimationStart`, after server alignment):

| Clip | Duration | Gather | Slam | Release | Recover | Readable body action |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Basic One-Hand | 0.70 | 0.00 | 0.35 | 0.38 | 0.44 | Asymmetric knee tuck, right arm rises straight overhead, left arm balances, quick forward follow-through. |
| Two-Hand Power | 0.80 | 0.00 | 0.52 | 0.55 | 0.56 | Both elbows draw the ball in, torso and both knees compress, both arms extend together, heavy two-arm crunch. |
| Tomahawk | 0.95 | 0.00 | 0.69 | 0.72 | 0.73 | Shoulder opens deeply behind head, torso arches/turns, left arm balances, then right arm whips forward. |
| Windmill | 1.10 | 0.00 | 0.88 | 0.91 | 0.94 | Long two-leg tuck, rotating/leaning torso, right shoulder sweeps outside/back/up over several beats before the finish. |

Slam beats are intentionally **earlier** than the initial authoring sketch: they sit near the existing server ball's actual Rim crossing (approximately 0.35/0.52/0.69/0.88 after animation start). The server still triggers impact from its observed ball contact, not these markers, so inspect synchronization in Play after publishing. The server's return phase may fade the clip before the very last authored recovery keyframe; recovery begins at the listed Recover marker. Easing uses cubic pose interpolation; the authored `HumanoidRootPart` pose has identity rotation and zero weight, and **no pose translates the root**. The actual basketball remains server-owned and follows the existing per-style path; no prop is embedded in these clips.

## Runtime contract

1. `DunkService` accepts F using the existing server checks. `DunkExecution` completes the same high-Vertical normalization and rim alignment before starting a presentation session.
2. The server creates/uses the character's `Animator`; this is required for an animation played by that character's client to replicate to observers. On spawn the owning client preloads each configured animation once, loads one `AnimationTrack` per style for that character, verifies nonzero `Length`, and reports *presentation readiness* through `DunkAnimationStatus`. This report cannot approve a dunk or change any gameplay value.
3. At the beginning of the server ball timeline, `DunkPresentation` sends `AnimationStart` with the chosen style, character, and server clock. If that character's track was ready, the client plays its cached track at Action priority and compensates for network transit using the server clock. Otherwise the server uses the existing temporary R15 `DunkPose` IK fallback. If playback fails or ends prematurely, the client reports unavailable and the server latches procedural fallback for the rest of that dunk.
4. The unchanged server ball phases are Gather, Finish (through Rim), and Return (to the possession weld). The server sends Gather/Windup/Slam anticipation cues and sends Contact when it observes the ball cross below Rim height. Contact is the `OnDunkImpact` hook for local camera, rim burst, and audio. `DunkResult` after successful return/cleanup is the `OnDunkCompleted` hook for the actual Cash reward. Neither an animation marker nor the readiness report grants success.
5. The server sends `AnimationFadeOut` during ball return and `AnimationStop` on cleanup/cancellation. Death/reset destroys the client cache, stops the track, and restores normal `Animate` locomotion. Court travel is already rejected during an active dunk; possession is relinquished after allowed travel. There are no permanent Motor6D edits or root translation in these clips.

`DunkPose` is not started while a real track is active, so its arm/torso IK cannot fight authored limb animation. The server still drives the root constraints and per-style ball path in either mode. The client only drives its own animation, camera, FOV, audio, and UI. Roblox's character animation replication should let nearby players see the track; confirm this in a two-player Studio test. R6 retains procedural ball/root motion but cannot use the R15 clips.

## Configuration

For each of `BasicOneHand`, `TwoHandPower`, `Tomahawk`, and `Windmill`, `DunkAnimations.luau` exposes:

| Field | Initial value | Meaning |
| --- | --- | --- |
| `AnimationId` | `""` | Empty = procedural fallback; replace with a legitimately published `rbxassetid://<numeric ID>` |
| `RigType` | `Enum.HumanoidRigType.R15` | Only a matching R15 character uses the track |
| `Priority` | `Enum.AnimationPriority.Action` | Overrides normal idle/walk/jump/fall during the dunk |
| `PlaybackSpeed` | `1` | Clip playback speed; author to the server ball timeline first |
| `FadeInSeconds` / `FadeOutSeconds` | `0.05` / `0.12` | Brief blending into/out of the clip |
| `Markers` | Gather, Slam, Release, Recover | Exact case-sensitive Animation Editor event names |

Procedural fallback is always enabled rather than a toggle: a missing/bad track must never make an otherwise eligible dunk unusable.

`LoadTimeoutSeconds = 5` bounds the post-preload track-length wait. Invalid/inaccessible IDs, failed preload, missing Animator, wrong rig, or zero-length tracks warn in Studio and use procedural fallback. A first dunk before an uploaded clip finishes preparing may also use fallback; later dunks can use the cached track. Configure IDs in source, not in a Studio-synced copy. No fake IDs are supplied.

## Author each clip in Roblox Studio

1. Stop Play. In Studio's **Avatar** tab, insert an **R15 rig** (preferably with body proportions close to the game's player avatars) in a separate authoring area or place. Confirm the experience's avatar settings actually spawn R15; the Rojo project does not set the avatar type.
2. Open **Animation Editor / Clip Editor** from the Avatar tools, select the rig, and create a non-looping animation. Set its priority to **Action**. Do not animate `HumanoidRootPart` translation or write gameplay root motion: `DunkExecution` positions/turns the character.
3. Animate torso, shoulders, arms, elbows, hands, and a small leg tuck. Preview a temporary basketball prop near the hand if helpful, but do not publish an extra gameplay ball or hand weld. The actual basketball remains server-owned and follows `DunkStyles`'s path.
4. In the editor timeline settings enable **Show Animation Events**. At the desired frames, use **Edit Animation Events → Add Event**, name each marker exactly `Gather`, `Slam`, `Release`, or `Recover`, and save. These are animation **event markers**, not renamed keyframes. [Roblox animation events](https://create.roblox.com/docs/animation/events) explains the editor and `GetMarkerReachedSignal`.
5. Scrub/preview the whole clip without the HUD. Keep the dunk hand near the scripted ball path and the final slam pose close to the logical hoop. Save the editable animation, then choose **Publish to Roblox** in the editor. Publish under the same creator/group that owns the experience or grant the experience permission to use the asset. Copy the actual numeric animation asset ID. [Roblox's Animation Editor guide](https://create.roblox.com/docs/tutorials/use-case-tutorials/animation/create-an-animation) covers creation and publishing.
6. Paste the published ID into the matching `AnimationId` in `src/shared/Config/DunkAnimations.luau`, as `"rbxassetid://123..."`. Sync Rojo, restart Play, and inspect Output. If it fails to load, check owner/group/experience asset permissions, publication/moderation status, and R15 compatibility; clear the slot to return to fallback.

### Recommended poses and markers

Current server timing, measured **after alignment** from `AnimationStart`: Basic Gather/Finish/Return `0.26/0.18/0.14` seconds; Two-Hand `0.39/0.17/0.20`; Tomahawk `0.56/0.16/0.18`; Windmill `0.73/0.20/0.19`. The physical ball crosses the Rim during Finish, not at its start. Place **Slam** near that crossing, then Release just after and Recover near the end of Finish/start of Return. Exact impact frames need Studio visual tuning, especially with different avatar scales and network conditions.

| Style | Gather | Slam | Release / Recover |
| --- | --- | --- | --- |
| Basic One-Hand | Quick right-hand reach; opposite arm balances | Direct one-hand extension | Straight through-rim follow-through; quick recovery |
| Two-Hand Power | Center the ball at chest; square shoulders and tuck | Both arms extend with a strong downward beat | Heavy two-hand follow-through; slower recovery |
| Tomahawk | Open shoulder/torso and pull the ball visibly behind/above the head | Explosive forward arm swing | Aggressive downstroke; close torso and recover |
| Windmill | Tuck, lean, and carry the ball through a large circular sweep | Extend toward the Rim after the circle | Flashy follow-through; controlled aerial recovery |

The `Gather` marker can cue local gather presentation once; `Slam` can cue the existing whoosh/anticipation once. `Release` is a local presentation hook; it **does not** detach or move the authoritative ball. `Recover` begins fading the local track. The server's own Gather/Slam cues fill gaps if markers are absent, and server-observed Contact remains the impact clock regardless of marker timing. Markers never tell the server to award Cash, advance a phase, or move a ball.

## First Basic One-Hand test

Author only the Basic clip first. A starting timing sketch is Gather at `0.00`, right-hand rise by `0.15`, `Slam` around `0.34–0.38`, `Release` immediately after, and `Recover` around `0.44`. End near `0.58` seconds. These are **visual authoring targets**, not new gameplay timers; tune against the live ball/rim pass in Studio. Set only `BasicOneHand.AnimationId`. Basic should use the R15 track while Two-Hand, Tomahawk, and Windmill retain their existing procedural IK/ball paths.

## Test matrix and limits

- **No IDs:** All four styles still dunk, show distinct procedural motion, return the ball, and award only the existing server-confirmed Cash. No new warnings in Output.
- **One ID:** Basic uses its cached R15 track; the other three use IK fallback. Repeated Basic dunks reuse one track on the same character. Reset, then verify a new character receives a new cache and normal walk/jump resumes.
- **Bad/inaccessible ID:** Studio warns; the dunk still works procedurally. Test a malformed string and an asset without experience access separately.
- **All IDs:** Each plays the correct clip and keeps its distinct server ball path. Ignore the HUD while comparing motion. Tune marker frames so hand/ball/rim impact align.
- **High Vertical:** At 150+ Vertical, perform all four styles; entry reliability, server alignment, rewards, challenges, court bonuses, and ball return must remain unchanged.
- **Interruptions:** Reset/die/remove the ball during each style; confirm no stuck pose, FOV, camera, temporary IK, held-ball error, or duplicate reward. Spam F; only one dunk lifecycle succeeds.
- **Multiplayer:** Start Server with two players. Player B should see Player A's R15 animation/ball path, but never receive A's camera, FOV, audio, or reward UI.
- **Performance:** Repeatedly dunk/respawn and inspect Animator tracks and temporary instances. Tracks are cached per character and destroyed on character removal; active event connections are disconnected with the cache.

The builder supplies four **editable authoring sequences**, not published custom animation assets. Actual AnimationIds, hand-to-ball alignment, marker timing, avatar-scale quality, and multiplayer replication must be accepted in Studio after real clips are published. Automatic Dribbling v0.1 now releases the hand weld while grounded, gathers on jump/attempt, and hands the same ball to server-owned DunkExecution; it removes temporary dribble IK before either the real track or procedural fallback plays. See `DRIBBLING.md`.
