# Dunk v0.3: Presentation and Approach

This is the historical v0.3 approach/hoop guide. For the current four-style R15 animation architecture, markers, asset workflow, and new `DunkAnimationStatus` remote, use [Dunk Animation System v1](DUNK_ANIMATIONS.md). No animation upload or Studio object is required to keep the procedural fallback working. [Basic Dunk Assist](BASIC_DUNK_ASSIST.md) documents entry and normalization.

## Approach and Ball Motion

After server validation, AlignPosition first normalizes height toward Rim.Y - 3 while holding entry X/Z and keeping the ball in hand. It then applies the existing at-most-five-stud horizontal assist. The optional animation and original ball timeline start after normalization. AlignOrientation turns the root smoothly toward the rim. Neither position nor rotation is teleported; effectively zero horizontal separation retains current facing. Entry rejects clear retreating/backward approaches, without a front-of-hoop-only restriction. See Basic Dunk Assist for the Vertical-35 unlock, scaled height limits, and normalization deadlines.

During the first 35% of Basic's gather, the detached ball follows the current hand placement, then blends toward the above-rim endpoint. Current style-specific gather/finish/return durations live in `DunkStyles`. A configured local track fades during return; the per-character cache is destroyed on character removal. All position/rotation constraints and temporary fallback IK are cleaned up on success or cancellation.

New `DunkConfig.Execution` settings:

| Setting | Default | Purpose |
| --- | --- | --- |
| FacingMaxTorque | 40000 | Rotation torque limit |
| FacingMaxAngularVelocity | 8 rad/s | Rotation speed limit |
| FacingResponsiveness | 20 | Smooth turn response |
| FacingDirectionEpsilon | 0.1 studs | Near-center direction fallback |
| HandFollowFraction | 0.35 | Portion of gather spent following the hand; keep 0 <= value < 1 |

## Animation Architecture and Markers

`DunkAnimations.luau` now has four empty legitimate-ID slots. Server-created Animators, client per-character track caching, `GetMarkerReachedSignal` for Gather/Slam/Release/Recover, server-clock start, and protected procedural fallback are documented in [Dunk Animation System v1](DUNK_ANIMATIONS.md). The server still drives the ball and result; markers never score. Follow that guide rather than the superseded v0.3 marker timings.

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

- [ ] With AnimationId empty, repeated Basic dunks still work: pickup, entry/buffer, alignment, downward ball pass, +$20 Neighborhood Cash only after return/cleanup, retained possession, normal movement/jump afterward.
- [ ] Test approaching from front, left, right, and an oblique angle. The character turns smoothly toward the rim along its approach side, without translation/rotation snaps. Test directly beneath the rim for stable facing.
- [ ] Recheck Vertical 30/35/40/50/75/100 on the SAME logical rim and avatar. The explicit Vertical-35 unlock and scaled height envelope replace physical-only eligibility. Jump heights, eight-stud horizontal range and cooldown are unchanged. No assistance starts for invalid attempts.
- [ ] Hold movement/jump and spam F: one execution/reward. Training cannot run while Executing and works again afterward. Test two clients and verify replicated facing/ball presentation.
- [ ] Reset, disconnect, remove the ball, or remove/move the hoop during execution. Verify Idle, no reward, no stuck controls, and no leftover DunkFacing/DunkAlignment/IK. A configured track may remain cached while that character exists, but must stop playing on interruption and be destroyed on character removal.
- [ ] Configure the real R15 asset: the arm raises during gather, ball stays near the moving hand initially, transitions above the ring, releases downward, then smoothly rejoins the hand. Test the asset on the actual avatar proportions.
- [ ] Missing/misspelled/duplicate or early Gather/Slam/Release/Recover markers cannot grant early Cash or duplicate rewards. Server Contact/`DunkResult` remain authoritative; use `DUNK_ANIMATIONS.md` for current marker tests.
- [ ] Empty ID, invalid ID format, wrong rig, or inaccessible asset: scripted execution still works. Check Output for asset errors; engine permission/moderation issues cannot be confirmed by a local build.
- [ ] New visual hoop does not change the logical Rim Position, progression threshold, collision behavior, or training. Test before and after adding decoration.

Rojo build verifies packaging, not engine physics or uploaded assets. Studio Script Analysis and playtests remain necessary; the standalone Luau analyzer does not include Roblox engine types in this environment.
