# Dunk v0.3: Presentation and Approach

Sync Rojo and restart Play. No animation upload, new remote, or Studio object is required to test the code changes. The verified v0.2 entry checks, input buffer, jump curve, rewards, possession, phase durations, state machine, and cleanup remain the baseline. Only BasicOneHand is defined.

## Approach and Ball Motion

After server validation, the existing bounded AlignPosition assist still moves at most three horizontal studs with no upward lift. The new AlignOrientation constraint turns the root smoothly toward the rim from the player's actual approach side. Torque and angular speed are limited; neither position nor rotation is directly snapped. At effectively zero horizontal separation, it retains the current horizontal facing to avoid an undefined direction. This does not add a front-only restriction or make distant/grounded requests eligible.

During the first 35% of the 0.30-second gather, the detached ball follows the current hand placement. It then smoothly blends from that moving hand toward the above-rim endpoint. This lets an authored reaching arm influence presentation without controlling completion. The existing 0.25-second downward pass and 0.20-second return stay intact. The optional animation fades out during return, allowing the hand to settle before the weld is restored. All position/rotation constraints and the optional animation track are cleaned up on success or cancellation.

New `DunkConfig.Execution` settings:

| Setting | Default | Purpose |
| --- | --- | --- |
| AnimationName | BasicOneHand | Selects the sole animation definition |
| FacingMaxTorque | 40000 | Rotation torque limit |
| FacingMaxAngularVelocity | 8 rad/s | Rotation speed limit |
| FacingResponsiveness | 20 | Smooth turn response |
| FacingDirectionEpsilon | 0.1 studs | Near-center direction fallback |
| HandFollowFraction | 0.35 | Portion of gather spent following the hand; keep 0 <= value < 1 |

## Animation Architecture and Markers

`DunkAnimations.luau` holds the BasicOneHand definition: real asset ID (currently empty), R15 rig type, Action priority, speed 1, 0.05-second fade-in, 0.12-second fade-out, and marker names. The server's `DunkAnimationController.Start(humanoid, name, optionalOnCue)` handles Animator loading/playback, marker connections, fade-out, and destruction. DunkService contains no animation-specific behavior.

An empty ID or a different rig type uses the scripted fallback. Invalid ID format or a synchronous load error warns and falls back. An inaccessible or still-loading Roblox asset may also generate an engine warning; execution never waits for its length or a marker, so the scripted sequence continues. Keep the ID empty until you own a usable published animation. No fake ID is included.

Supported presentation cues are `Takeoff`, `BallAboveRim`, `BallRelease`, and `DunkComplete`. `GetMarkerReachedSignal` routes authored markers to the same optional callback as fallback server-timeline cues. Each named cue dispatches at most once per session; duplicate or late markers cannot retrigger it. Callback errors are isolated. Enable `Execution.DebugLogging` to see the source of each cue.

In v0.3, markers are presentation hooks, NOT the ball simulation clock or a scoring API. The fixed server phase timing still drives the ball and confirms completion, even if markers are missing, mistimed, or fired early. Author the clip to the timeline below. Later animation variants can use the same named interface; none are added now. `DunkComplete` describes the visual rim pass at 0.55 seconds; the +25 Cash and success UI still wait until the full return and cleanup around 0.75 seconds. A marker alone cannot produce a reward. `Takeoff` labels the committed pose, not a new jump impulse.

## Create BasicOneHand in Studio

1. Stop Play. Use a separate animation-authoring place or a spare rig away from gameplay. Insert an R15 rig through Studio's Rig Builder/rig tool, matching your game's avatar proportions. Name it `BasicOneHandRig`.
2. Open Animation Editor from the Avatar tools, select that rig, and create an animation named `BasicOneHand`. Disable looping and choose Action priority in the editor's options. Use a 0.75-second timeline. Do not translate/rotate HumanoidRootPart as root motion; execution already moves and turns the character. See the [Animation Editor guide](https://create.roblox.com/docs/animation/editor).
3. Animate the right shoulder, elbow, wrist, torso, and a modest leg tuck. Keep the right hand facing forward and reaching above the head. Use these prototype pose targets; the exact joint angles depend on the rig:

| Time | Pose | Marker |
| --- | --- | --- |
| 0.00 | Airborne starting pose, right hand near normal ball grip | Takeoff |
| 0.10 | Lift right arm, bend elbow; slight torso extension | None |
| 0.27 | Extend right arm overhead toward hoop | BallAboveRim |
| 0.30 | Wrist over rim, begin downward follow-through | BallRelease |
| 0.55 | Right hand follows down, body relaxed | DunkComplete |
| 0.75 | Return arm/torso toward ordinary airborne pose | None |

4. Scrub and play the clip repeatedly. Aim for smooth curves with no full-body spin. For preview only, place a two-stud orange sphere at the hand's grip location to check scale; do not export geometry or add a second gameplay ball. This first animation is a prototype reach, not an IK solution that guarantees exact contact at every avatar size/rim offset.
5. In the timeline settings enable **Show Animation Events**. At each time above, position the scrubber, choose **Edit Animation Events**, click **+ Add Event**, enter the exact case-sensitive marker name, and save. Parameters can remain empty. These must be event markers, not renamed keyframes. See [Roblox animation events](https://create.roblox.com/docs/animation/events).
6. Save the authoring work using the editor's Save/Save As option. Saving an editable sequence is separate from publishing a playable asset.

## Publish and Configure the Asset

1. In Animation Editor open the **...** menu and choose **Publish to Roblox**. Use the name `BasicOneHand` and a useful description.
2. Set Creator to the experience owner. For a group-owned experience, select that group, not your personal account. Submit/publish and wait for success. See [animation export and ownership](https://create.roblox.com/docs/animation/editor#export-an-animation).
3. Copy the animation ID from the confirmation dialog. If needed, find the animation in Creator Dashboard's Development Items > Animations, open its options, and use **Copy Asset ID**. See [publishing and locating IDs](https://create.roblox.com/docs/tutorials/curriculums/animator/play-your-animation).
4. Open `src/shared/Config/DunkAnimations.luau`. Replace BasicOneHand's empty `AnimationId` string with `rbxassetid://` followed immediately by your actual copied numeric ID. Leave Speed at 1 for the authored timeline and RigType as R15. Do not replace default jump/run IDs.
5. Save, sync Rojo, and restart Play. Test on an R15 avatar. R6 continues with the fallback; it needs a separately authored compatible asset before changing RigType. If access/moderation/loading errors appear in Output, verify creator permissions and publication; clear AnimationId to return to asset-free testing.

## Improve DunkHoop in Studio

Do this only in edit mode. Preserve the existing `Workspace.DunkHoop.Rim` instance and its exact Position: it is the playtested gameplay reference, not necessarily the visible ring. Never lower it to make the new decoration fit.

```text
Workspace
  DunkHoop (Model)
    Rim (existing simple gameplay-reference Part)
    Backboard (Part)
    Pole (Part)
    Support (Part)
    VisualRim (Model containing eight bars)
    TargetBox (optional Model containing four strips)
```

1. Record the existing Rim Position as `(X, Y, Z)` and court floor-top height as `F`. The following layout assumes players approach from negative Z, with the board behind the rim toward positive Z. If your court faces another direction, rotate/position ONLY the new decorative pieces around the reference; do not move the reference or entire existing hoop.
2. Set the logical Rim to Anchored true, CanCollide false, CanTouch false, CanQuery false, and Transparency 1. Leave its Position and existing Size unchanged. DunkService uses its center and name, not its mesh, transparency, or bounding geometry.
3. All new decorative Parts below should be Anchored true, CanCollide false, CanTouch false, and CanQuery false for now. This prevents new scenery from blocking the verified dunk assistance or training raycasts. Give the backboard white SmoothPlastic, the rim orange SmoothPlastic, and pole/support dark-gray Metal. No unions, mesh assets, scripts, or welds are needed.
4. Add `Backboard` directly under DunkHoop. Set Size `16, 9.33, 0.4`, Position `(X, Y + 3.335, Z + 3.6)`, Orientation `0, 0, 0`. It is a vertical board with its lower edge roughly 1.33 studs below rim height.
5. Add `Pole`. Set Size `(1.2, Y - F + 7, 1.2)` and Position `(X, (F + Y + 7) / 2, Z + 6)`. Replace the formulas with numbers using your recorded values. Example: Y = 15, F = 0 gives height 22 and center Y = 11. This is scenery only, behind the board.
6. Add `Support`: Size `1.2, 1.2, 2.4`, Position `(X, Y + 4, Z + 4.8)`.
7. Add a Model named `VisualRim`. Create eight thin Parts with Size `1.95, 0.25, 0.25`, orange color, and these offsets from the existing Rim center. The offsets form a simple octagonal ring with a clear opening rather than a solid slab. Set each Position by adding its offset to `(X, Y, Z)`:

| Bar | Position offset X,Y,Z | Orientation X,Y,Z |
| --- | --- | --- |
| Front | 0,0,-2.2 | 0,0,0 |
| Back | 0,0,2.2 | 0,0,0 |
| Left | -2.2,0,0 | 0,90,0 |
| Right | 2.2,0,0 | 0,90,0 |
| FrontRight | 1.56,0,-1.56 | 0,-45,0 |
| BackLeft | -1.56,0,1.56 | 0,-45,0 |
| FrontLeft | -1.56,0,-1.56 | 0,45,0 |
| BackRight | 1.56,0,1.56 | 0,45,0 |

8. Optional TargetBox: add two black horizontal strips of Size `5.33, 0.12, 0.05` at `(X,Y,Z+3.37)` and `(X,Y+4,Z+3.37)`, and two vertical strips of Size `0.12,4,0.05` at `(X-2.665,Y+2,Z+3.37)` and `(X+2.665,Y+2,Z+3.37)`. Set Orientation to zero. Keep their physics flags disabled like the other decoration.
9. Save the Studio place and test. The ball should pass through the open visible ring centered on the invisible reference. Rojo never manages these map objects. Later replace VisualRim/Backboard decoration with meshes while retaining the direct child Rim reference.

These are approximate regulation-shaped proportions: a board roughly four rim diameters wide and 2.33 diameters tall, based on a 6-foot by 3.5-foot board and 18-inch ring. They are scaled to this game's existing ball/avatar, not a conversion requiring you to reset hoop height. Regulation rim height is 10 feet; this game's already tuned reference height stays authoritative for progression. [NBA equipment dimensions](https://official.nba.com/rule-no-1-court-dimensions-equipment/).

## Manual Test Checklist

- [ ] With AnimationId empty, repeated v0.2 dunks still work: pickup, entry/buffer, alignment, downward ball pass, +25 only after return/cleanup, retained possession, normal movement/jump afterward.
- [ ] Test approaching from front, left, right, and an oblique angle. The character turns smoothly toward the rim along its approach side, without translation/rotation snaps. Test directly beneath the rim for stable facing.
- [ ] Recheck Vertical 30/35/40/50 on the SAME logical rim and avatar. Progression threshold, jump heights, six-stud entry range, and cooldown are unchanged. No assistance starts for invalid attempts.
- [ ] Hold movement/jump and spam F: one execution/reward. Training cannot run while Executing and works again afterward. Test two clients and verify replicated facing/ball presentation.
- [ ] Reset, disconnect, remove the ball, or remove/move the hoop during execution. Verify Idle, no reward, no stuck controls, and no leftover DunkFacing/DunkAlignment/attachments or animation tracks.
- [ ] Configure the real R15 asset: the arm raises during gather, ball stays near the moving hand initially, transitions above the ring, releases downward, then smoothly rejoins the hand. Test the asset on the actual avatar proportions.
- [ ] Missing/misspelled/duplicate or early DunkComplete markers cannot prevent normal fallback timing, grant early Cash, or duplicate rewards. Enable debug logging to inspect cues; disable it afterward.
- [ ] Empty ID, invalid ID format, wrong rig, or inaccessible asset: scripted execution still works. Check Output for asset errors; engine permission/moderation issues cannot be confirmed by a local build.
- [ ] New visual hoop does not change the logical Rim Position, progression threshold, collision behavior, or training. Test before and after adding decoration.

Rojo build verifies packaging, not engine physics or uploaded assets. Studio Script Analysis and playtests remain necessary; no standalone Luau analyzer is available in this environment.
