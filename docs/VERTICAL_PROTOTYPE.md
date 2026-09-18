# Vertical Progression Prototype

## Studio Setup

1. Open your working place in Studio and stop any Play session. Start Rojo and connect as described in the repository README.
2. In Explorer, insert a **Part directly under Workspace**, named exactly `VerticalTrainer` (case-sensitive). Use one trainer with that name, not a Model or a Part nested in another Model.
3. Set the Part's `Anchored` to true, `CanCollide` to true, and `Size` to `4, 2, 4`. Place it on the floor near your spawn with clear standing space beside it. For a floor whose top is Y = 0, a sample Position is `10, 1, 0`; adjust to your own court.
4. Insert one **ProximityPrompt directly inside VerticalTrainer**. Leave its name as `ProximityPrompt`. Set `Enabled` to true, `KeyboardKeyCode` to E, `HoldDuration` to 0, `MaxActivationDistance` to 10, and `RequiresLineOfSight` to true. Set `ActionText` to `Hold to Train Vertical` and `ObjectText` to `Vertical Trainer`.
5. Save the Studio place. The server sets the prompt text, hold duration, and range at startup. Workspace is not synced into source control; the trainer must remain saved in the place.
6. Press **Play** (not Run, which does not spawn your player). Output should show the training-ready message and the progression-initialized message. Walk within 10 studs of the trainer's center and hold E continuously. The first reward arrives after approximately 0.5 seconds, then repeats while held. Release E to stop.

Existing trainers need no manual property changes for this update: sync and restart Play. The server overrides HoldDuration to 0, the action text, and range. HoldDuration is not the training tick timer; the server session supplies that timer. The standard prompt has no filling hold-progress ring in this mode.

No scripts need to be inserted into the trainer. The built-in prompt provides keyboard, gamepad, and touch interaction. If setup is missing or invalid, Output explains the required object; stop Play, fix the saved place, then restart. Adding a station after service startup does not bind it automatically.

## Progression and Tuning

Edit `src/shared/Config/ProgressionConfig.luau`, save, and restart Play to reload required modules. The starting state is Vertical 30 and Cash 0. Each server tick awards +1 Vertical and +5 Cash. Set `Training.TickIntervalSeconds` to a finite positive number to tune the default 0.5-second interval. Each player has an independent session. The first tick requires a full interval, including after a release and re-press. Duplicate starts cannot add sessions or award ticks. Lag does not produce catch-up rewards. Death, character replacement/removal, leaving range, obstruction, disabled prompt, or invalid trainer ends the session; release and press again after conditions are valid.

`GetJumpHeight` computes `BaseHeight * (Vertical / ReferenceVertical)^Exponent`. Its starting parameters are 7.2 studs, Vertical 30, and exponent 1.7. The curve keeps increasing beyond Vertical 100; later balancing may introduce a cap. Keep tuning inputs positive.

| Vertical | JumpHeight (studs, approximate) | Intended feel |
| --- | --- | --- |
| 30 | 7.200 | Normal athletic |
| 31 | 7.613 | First improvement |
| 40 | 11.742 | Noticeably stronger |
| 50 | 17.158 | Elite/exaggerated |
| 75 | 34.185 | Superhuman |
| 100 | 55.748 | Ridiculous |

These are configured Humanoid heights, not measured avatar clearance. Test on level ground with normal gravity and sufficient headroom. `UseJumpPower` is false; `JumpHeight` drives jumping. The next jump uses the new height; an already airborne character is not boosted mid-flight. See [Roblox Humanoid documentation](https://create.roblox.com/docs/reference/engine/classes/Humanoid).

View `Players > your player > leaderstats > Vertical/Cash` in Explorer or the built-in player list. These IntValues are display mirrors of private server state; editing them is not a supported way to grant progression. Cash has no spending path. Resetting the character retains stats; leaving/rejoining or restarting the server resets them.

## Manual Acceptance Checklist

- [ ] Fresh Play: Vertical = 30, Cash = 0. In the server view inspect the character Humanoid: `UseJumpPower = false`, `JumpHeight = 7.2`. Output has no script errors.
- [ ] Hold E for one tick then release: Vertical = 31, Cash = 5, JumpHeight approximately 7.613. Wait two seconds after release and verify no further awards (allow for release-message network latency).
- [ ] Hold continuously for roughly five seconds: about ten ticks, approximately Vertical = 40 and Cash = 50, without re-pressing E. Every tick changes stats by exactly +1/+5 and updates JumpHeight. Continue to 20/45/70 total ticks for Vertical 50/75/100 and Cash 100/225/350.
- [ ] Release before 0.5 seconds: no reward. Rapidly tap/re-press E: no instant rewards or accelerated ticks. Start a new sustained hold: first reward again waits a full interval, and only one stream of rewards runs.
- [ ] Reset or remove the character while holding: training stops. The respawn retains session stats and current jump height, but cannot resume rewards without a fresh press.
- [ ] Walk farther than 10 studs while holding: training stops. Return and verify a new press is needed. Repeat with a wall between the character and trainer while server-side `RequiresLineOfSight` is true.
- [ ] In server view disable/remove the prompt, rename/remove the trainer, or unanchor it during a hold: training stops. Restoring valid conditions requires a fresh press; replacing a destroyed station/prompt requires restarting Play.
- [ ] Use Studio's Server & Clients test with two players: hold simultaneously and verify independent rewards. Release or disconnect one player: their session stops while the other continues. Output contains no errors on disconnect.
- [ ] Hold using a gamepad or touch prompt and release: rewards repeat during the hold and stop on release. Switch window focus during a hold and verify input cancellation does not leave unintended training active.
- [ ] In client view change that client's displayed Vertical/Cash values: server-view state is unchanged and the next accepted training action restores displays from the true server totals. Client-side changes to prompt range/enabled state must not authorize rewards outside the server rules.
- [ ] Stop Play, temporarily rename VerticalTrainer, then Play: one actionable warning, no crash, and normal initial jump. Repeat with the prompt missing or Part unanchored. Restore the setup and restart Play.
- [ ] Stop and restart Play (or leave and rejoin): stats return to 30/0. Verify the saved trainer and existing map assets remain intact after Rojo synchronization.

## Validation Limits

Rojo build validates project mappings and packaging; it does not execute or typecheck Luau. Use Studio Script Analysis and complete the checklist to validate engine behavior and tune feel. Movement anti-cheat, persistence, spending, and competition remain deferred. Dunking is covered separately in `DUNK_PROTOTYPE.md`.
