# Movement Presentation v1

Client-only polish for dribbling, jumping, landing, and the dunk ball. Nothing here changes possession, dunk eligibility, rewards, or saved data; the server stays authoritative for all of those.

## Why it moved to the client

Before v1 the server moved the anchored dribble ball at 30 Hz from its own (network-delayed) view of the character, and created the dribble IK on the server. On clients this showed as a ball that trailed a running player and a stuttering arm. The dunk ball was also CFramed by the server every Heartbeat, which replicates as visible steps.

## What runs where

| Piece | Where | Job |
| --- | --- | --- |
| `BasketballService` | Server | Unchanged possession, dribble/gather/dunk modes and the authoritative `HeldBasketball`. No longer creates IK. |
| `ProgressionConfig.Jump.Gravity` | Server (`ServerMain`) | Sets `Workspace.Gravity` to 285. `Humanoid.JumpHeight` keeps every Vertical's apex identical; only hang time is shorter. |
| `PresentationController.client` | Every client | Tracks every character and drives the three modules below. Reads replicated attributes only; sends nothing. |
| `BallPresentation` | Every client | Hides the server ball locally and draws a local visual ball: a client-simulated dribble tied to the live root, a gather blend into the hand, the hand-held position, and during dunks a hand-follow that hands over to the interpolated server path near the rim. Drives local right-arm IK while dribbling. |
| `BodyPresentation` | Every client (R15) | Additive joint layer after the Animator: athletic dribble stance, jump tuck/fall reach with a two-hand chest hold, and a feet-planted landing crouch. Disabled while dunking so the dunk track owns the pose. |
| `LocomotionFeel` | Local player (+ dust for all) | Extra fall gravity on the local character, a short camera dip on landing, and a dust puff. |
| `WorkoutPresentation` | Every client (R15) | While the server-set `Training` attribute is on (prompt held at the Vertical Trainer), loops squats, lunges, jump squats and calf raises from `PresentationConfig.Workout.Routine`, blending in/out and pausing if the player walks away. Body layers step aside meanwhile, and the visual ball rests on the floor beside the player. |
| `TransitPresentation.client` | Every client | Bus departure for any player with `TransitRide` set (doors, rider fade, bus pulls away) plus the rider's own camera and fade. See `COURT_PROGRESSION.md` "Bus Ride". |

All tuning lives in `src/shared/Config/PresentationConfig.luau`. `DunkConfig.BallDiameter` is now 1.5 studs (was 2) so the ball reads at a sensible scale on a ~5-stud avatar.

## Dunk finish: slam, rim grab, hang (v2)

The dunk is now shaped like a real slam instead of a lay-in.

| Phase (`DunkPhase` attribute) | Server (`DunkExecution`) | Clients |
| --- | --- | --- |
| `Descent` | After the ownership handoff (momentum is damped, not zeroed), one eased move from where F was accepted to the wind-up point. High entries end already at wind-up height. A high drop becomes an air-trick combo (see `DUNK_REWARDS.md`); each trick is paid as the server timeline finishes it. `DunkTricks` / `DunkDescentSeconds` attributes are set for clients. | `DescentPresentation` plays the combo in order with the ball at the chest (spins, flips, cartwheel, corkscrew around the hips; the physical root never rotates), changing body shape per trick, then opens into the clip. The dunker sees a popup per paid trick. The ball gets a short trail. |
| `Gather` | Root rises `HeightLift` above the aligned target and leans `SlamReach` toward the rim. | The visual ball rides the animated hand (wind-up in the clip). |
| `Slam` | Root drives down to the hang spot (`HangRootBelowRim` below the rim, just outside the ring measured from its `Segment` parts). The server ball still has to pass below the rim. | The ball is steered over the ring centre and released when the hand reaches the rim; court/grade impact VFX (`DUNK_VFX.md`), ring kick, and a 75 ms hit-stop on the dunker's own track (longer and harder on Good/Perfect). |
| `Hang` | Root held under the rim for `HangSeconds`; the ball is returned server-side during this time. | `RimPresentation` IK grips the front of the ring (both hands for Two-Hand), the legs swing and settle, and the ring stays bent then springs back. |
| cleared | Normal cleanup; the player drops and lands. | The loose ball bounces and is caught back after landing. |

The attribute is presentation-only and is cleared on every cleanup path. Rewards, eligibility and the rim-pass check are unchanged. Per-style timings live in `DunkStyles` (`GatherSeconds`, `FinishSeconds`, `HangSeconds`, `Motion.HeightLift`, `Motion.SlamReach`); hang geometry lives in `DunkConfig.Execution`; client tuning lives in `PresentationConfig.Ball` and `PresentationConfig.Rim`. Clips end with the arm reaching up (`Recover` marker) so the procedural rim grab takes over without a pop.

### High-Vertical entries

At high Vertical the jump apex is far above the rim. `DunkMaxEngagementAboveRim` lets a dunk start from the apex, so the whole fall becomes the trick descent (0.22 s base + 0.008 s per stud, capped at 0.7 s, stretched to fit the air-trick combo and so the move never exceeds `DescentMaxVelocity`). It is computed from the highest court training cap: the jump height at that Vertical + 20 studs (about 285 studs for College's 250 cap), so a max-Vertical press at the very top of the jump is accepted. It used to be a fixed 120, which rejected presses near the apex above about 195 Vertical. A press that is still too high keeps buffering for up to `DunkHighBufferSeconds` (1.1 s) while the player falls into range instead of being rejected. The per-Vertical height limit (`GetMaxAboveRim`) is unchanged below the cap.

## Tuning knobs

| What it changes | Where | Setting |
| --- | --- | --- |
| How high you rise over the rim before the slam | `DunkStyles` per style | `Motion.HeightLift` |
| How far you lean in toward the rim on the slam | `DunkStyles` per style | `Motion.SlamReach` |
| Wind-up / slam / hang durations | `DunkStyles` per style | `GatherSeconds`, `FinishSeconds`, `HangSeconds` |
| First (signature) trick of an air combo | `DunkStyles` per style | `DescentTrick` = `Spin360`, `Spin720`, `FrontFlip`, `BackFlip`, `Cartwheel`, `Corkscrew` |
| Trick count, unlocks, speed, Cash, combo bonus | `DunkRewards.Tricks` | see `DUNK_REWARDS.md` |
| Dunk Cash per Vertical point | `DunkRewards.Vertical` | `BonusPerPoint` |
| Descent speed | `DunkConfig.Execution` | `DescentBaseSeconds`, `DescentSecondsPerStud`, `DescentMaxSeconds` |
| How high above the rim a dunk may start | `DunkConfig` | `DunkMaxEngagementAboveRim`, `DunkHighBufferStuds`, `DunkHighBufferSeconds` |
| How low the body hangs under the rim | `DunkConfig.Execution` | `HangRootBelowRim`, `HangStandOffPadding` |
| Ring bend while hanging / impact kick | `PresentationConfig.Rim` | `HangBendDegrees`, `ImpactKickDegreesPerSecond`, `Stiffness`, `Damping` |
| Freeze-frame on the slam | `PresentationConfig.Rim` | `HitStopSeconds` |
| Sparks | `PresentationConfig.Rim` | `Sparks`, `SparkColor` |
| Trick body shapes | `PresentationConfig.Descent` | `Shapes` (Tuck/Layout/Pike/Star), `ShapeBlendRate`, `StarArmDegrees` |
| Ball trail | `PresentationConfig.Ball` | `TrailLifetime` (0 = off), `TrailColor` |
| Camera shake / FOV punch on impact | `FeedbackConfig.Camera.Styles` | `Impact.FOVDelta`, `Impact.ShakeStuds` |
| Dunk sounds | `FeedbackConfig` audio | asset IDs you own (empty = silent) |
| Jump hang time / fall speed | `ProgressionConfig.Jump.Gravity`, `PresentationConfig.Air.FallGravityMultiplier` | |
| Ball size | `DunkConfig` | `BallDiameter` |
| Ball seams / spin | `PresentationConfig.Ball` | `SeamColor`, `SeamWidth`, `DribbleSpin` |
| Where the ball rests during a workout | `PresentationConfig.Ball` | `RestSide`, `RestForward`, `RestBlendSeconds` |
| Workout order, reps and speed | `PresentationConfig.Workout` | `Routine` (`Exercise` = `Squat`, `Lunge`, `JumpSquat`, `CalfRaise`) |
| Workout depth | `PresentationConfig.Workout` | `SquatDrop`, `LungeDrop`, `JumpHeight`, `CalfRaiseHeight` |
| Bus ride length | `CourtConfig` | `RideSeconds` |
| Bus doors / drive-off / ride camera / fades | `PresentationConfig.Transit` | `DoorOpenSeconds`, `DriveDistance`, `CameraSide`, `CameraAhead`, `ScreenFadeOutSeconds` ... |

## R15 joint sign reference

Measured in Studio on this project's rigs (both `Motor6D` and the avatar-joint-upgrade `AnimationConstraint` expose `Transform`):

| Joint | Positive X rotation |
| --- | --- |
| Root / Waist / Neck | leans **back** (negative leans forward) |
| Shoulder, Hip | swings the limb **forward** |
| Elbow | **bends** (forearm forward) |
| Knee | hyperextends; negative bends (shin back) |
| Ankle | toes **up**; negative points toes down |
| Shoulder roll (Z) | right arm moves outward, left arm inward |

The first Dunk Animation Builder pose data had torso/head pitch, feet and elbows inverted (slams leaned back, Tomahawk bowed forward, elbows hyperextended). `tools/dunkanimations/Poses.luau` now uses the conventions above. Regenerate with the builder and republish the four clips by overwriting the existing assets so the configured IDs stay valid.

## Studio checks

1. Pick up a ball. Idle, walk, run: the ball stays beside the right foot and in front, reaches the floor every bounce, and the hand rides its top. No trailing when sprinting.
2. Jump: the ball comes to the chest in both hands; knees tuck on the way up and extend on the way down. Landing from a big jump shows a short crouch, a camera dip, and dust.
3. Dunk each style: the ball stays in the hand through the wind-up and drops through the rim. No arm/body pose fights the dunk track.
4. Two players (Test > Server & Clients, 2 players): each sees the other's ball, trick and rim bend.
5. At high Vertical, press F at the top of the jump: the dunk starts there and the trick plays on the way down.
6. Reset/leave while dribbling: no leftover `LocalBallVisuals` balls, `LocalDribbleArm` IKControls, or `LocalLandingDust` attachments.
