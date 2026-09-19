# Dunk System v0.2: Basic Execution

This is the verified execution baseline. [Dunk v0.3](DUNK_PRESENTATION.md) adds smooth facing, early hand-follow gather, and optional animation playback while preserving this entry/reward/cleanup design. Use its additional test checklist and asset authoring guide.

The playtested v0.1 entry rules remain unchanged: six-stud horizontal radius, four studs below/six above the rim, 0.35-second server buffer, three-stud buffer-only extension, one-second cooldown, and +25 Cash. Keep the current regulation hoop position and Vertical curve. No new Studio objects or remotes are required; sync Rojo and restart Play.

## State and Authority

PlayerService stores `DunkState` in private session state and mirrors it to a Player attribute for inspection. Only server modules change authoritative state. The flow is `Idle -> Attempting -> Executing -> Completed -> Idle`; failure/cancellation returns to Idle. Completed is a short transition, not a timed animation state. Optional logging can make it easier to inspect.

DunkService admits requests only in Idle. Attempting includes the existing input buffer and validates possession, actual position, airborne state, life, character, and rim identity. Only a fully valid opportunity enters Executing. No animation starts on F press alone. The same server request remains active throughout execution and can grant only one reward. Cooldown still starts on admission and renews on completion.

TrainingService cancels an existing training session and refuses a new one while the private state is Executing. PlayerService also refuses training rewards in that state. Hold E again after execution to resume training. All other training timing, rewards, Vertical progression, and jump calculations are unchanged.

## Character Alignment

`DunkExecution.luau` temporarily transfers the character assembly to server network ownership. It snapshots WalkSpeed, AutoRotate, JumpHeight, JumpPower, UseJumpPower, and the previous ownership policy. It sets movement speed and both jump settings to zero, turns off AutoRotate, clears residual assembly velocity, and uses an `AlignPosition` constraint to guide the root toward the rim.

The goal stays at the validated entry height and approaches the rim horizontally by at most three studs, stopping two studs away where possible. The character is never anchored or teleported, and no upward assistance is added. Constraint force and speed are limited; it applies force at the center of mass to avoid added torque. If the character cannot approach the target within tolerance, the attempt cancels without cash. Existing collisions are preserved. See [Roblox AlignPosition](https://create.roblox.com/docs/reference/engine/classes/AlignPosition).

Holding the entry height for this short sequence is part of the committed dunk; gravity resumes when alignment is removed. Cleanup clears assisted velocity instead of replaying the pre-dunk jumping velocity, preventing a second launch. The v0.3 presentation layer smoothly turns the character toward the rim and can play an optional authored arm/body pose.

## Ball Motion and Reward

BasketballService retains private possession while temporarily disabling the hand weld and anchoring only the detached ball. The character is not anchored. DunkExecution interpolates the ball on the server, visible to all clients:

1. Gather from its hand position to two studs above the rim in 0.30 seconds.
2. Move straight downward through the rim center to two studs below it in 0.25 seconds.
3. Return toward the current hand position in 0.20 seconds.

Each phase checks character, ball, hoop, movement bounds, and timeout every Heartbeat. The server explicitly reaches the below-rim endpoint before continuing. This is scripted visual motion, not free ball physics or rim collision simulation. BasketballService then restores the original held-ball placement, unanchors the ball, and enables its weld. Its begin/end motion methods isolate possession from this visual implementation for future replacement with physics.

The complete sequence targets 0.75 seconds plus frame scheduling. Only after all phases and cleanup succeed does DunkService transition to Completed and call PlayerService.RegisterDunk once. Cash/count change and `DUNK! / +$25` follow then, never at entry or just because the ball was released. Cancellation, including during the return phase, earns no reward. Vertical is untouched.

## Cleanup

The execution body is protected by pcall. Both completion and errors run the same cleanup, destroying temporary alignment objects, restoring each saved humanoid property independently, reattaching any surviving ball, clearing assisted velocity, and restoring automatic or explicit network ownership. Every cleanup action is protected so one failure cannot skip the remaining restoration. DunkService returns private state to Idle even if execution errors. It never changes a replacement character's properties.

Death, character disappearance/replacement, player departure, lost possession, missing/replaced/unanchored/moved rim, excessive displacement, blocked alignment, and timeout cancel execution on the next server frame. Invalid/destroyed possession uses the existing ball-removal behavior. Restoration errors are logged and suppress rewards. The nominal timeout is 1.2 seconds; engine stalls may delay the next cleanup frame, but stalled execution cannot resume for a late reward beyond the timeout.

## New Configuration

All values are under `DunkConfig.Execution`; existing top-level tuning is unchanged.

| Value | Default | Purpose |
| --- | --- | --- |
| GatherSeconds | 0.30 | Ball travel from hand to above rim |
| FinishSeconds | 0.25 | Downward pass through rim |
| ReturnSeconds | 0.20 | Ball return to hand |
| TimeoutSeconds | 1.20 | Safety deadline for all phases |
| MaxAssistDistance | 3 studs | Maximum requested horizontal correction |
| RimStandOff | 2 studs | Preferred horizontal root separation from rim |
| MaxVelocity | 14 studs/second | Alignment speed limit |
| MaxForce | 60000 | Alignment force limit |
| Responsiveness | 35 | Alignment response strength |
| PositionTolerance | 1.5 studs | Target acceptance and displacement slack |
| BallAboveRim / BallBelowRim | 2 / 2 studs | Ball-center endpoints around rim |
| RimMovementTolerance | 0.25 studs | Cancel if rim moves beyond this during execution |
| DebugLogging | false | Optional state transitions and detailed cancellation reason |

Keep durations positive, the timeout longer than their sum, and force/speed/tolerances positive. Body scaling, network latency, and collisions need Studio playtesting before these execution settings are considered tuned.

## Manual Studio Checklist

- [ ] Sync and restart Play with the existing map. Recheck Vertical 30 cannot reach the regulation entry zone, about 35 can, and 40/50 preserve their easier physical reach. Slightly early airborne F still buffers.
- [ ] After validation, observe a short horizontal alignment, ball gather, downward rim pass, and return. No instant teleport, upward snap, or unbounded pulling. The character is never anchored.
- [ ] Watch Cash and Dunks in server view: unchanged at execution start, exactly +25 Cash/+1 Dunks after the full sequence, unchanged Vertical. Confirm DUNK feedback occurs only at completion.
- [ ] Hold movement/jump and spam F throughout execution: no competing dunks, duplicate rewards, or control fighting. Walk and jump normally immediately afterward; repeat many dunks.
- [ ] Inspect the same Humanoid before/after: WalkSpeed, AutoRotate, JumpHeight, JumpPower, and UseJumpPower return to their original values. No DunkAlignment/DunkAlignmentAttachment objects remain; ball is welded, unanchored, and massless again.
- [ ] Try training during execution with a nearby trainer: no training ticks or Vertical changes. Hold E again afterward: normal +1/+5 training resumes.
- [ ] Reset/kill/remove the character mid-execution: no reward, no stuck controls, and normal jump stats after respawn. Pickup works again. Disconnect one executing player in a two-client test; the other remains unaffected.
- [ ] Remove/reparent/unanchor/move the rim mid-sequence: no reward, ball/control restoration, and Idle state. Restore the hoop and retry after cooldown. Repeat by removing the ball or its weld on the server.
- [ ] Place an obstacle in the alignment path: collisions are respected; an obstructed attempt cancels instead of rewarding a ball-only visual. Verify normal controls return.
- [ ] With debug logging enabled, temporarily set MaxForce to 0 to force alignment failure on an off-center entry, or TimeoutSeconds to 0.1 to force cancellation. Confirm no cash and full cleanup. Restore defaults before normal playtesting.
- [ ] In a disposable Studio test, temporarily set BallAboveRim to a nonnumeric value to force an error after controls/weld have changed. Confirm cleanup and Idle, then restore the value and restart. Do not save the injected failure.
- [ ] Two clients observe the same ball sequence, with only the dunking player receiving reward/feedback. Test R15/R6 and repeated success/cancellation under simulated latency.

Build validation checks packaging, not Roblox physics. No standalone Luau analyzer is installed here; Studio Script Analysis and these playtests remain required.
