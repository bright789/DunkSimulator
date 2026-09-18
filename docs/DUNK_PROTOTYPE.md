# Dunk System v0.1

## Studio Setup

Quick setup: stop Play, open Studio's Command Bar, and paste the entire contents of `docs/SetupDunkStudio.luau`, then press Enter. It creates only missing pickup/prompt/hoop/rim objects and selects the pickup and rim for inspection. Existing objects and VerticalTrainer are preserved. New objects are positioned relative to the first SpawnLocation's top surface (or Y = 0 at the origin if none exists); adjust for your floor and clear approach, then save the place. This is a one-time editor helper outside Rojo's mapped source, not a gameplay script.

Stop Play, open the existing working place, and sync Rojo. Keep VerticalTrainer unchanged. Create the following objects in Explorer; names and capitalization must match exactly:

```text
Workspace
├── BasketballPickup (Part)
│   └── ProximityPrompt
└── DunkHoop (Model)
    └── Rim (Part)
```

1. Insert a Part directly under Workspace and name it `BasketballPickup`. Set Size to `3, 2, 3`, Anchored to true, CanCollide to false, Color to orange (RGB 230, 115, 25), and Material to SmoothPlastic. This is a pickup station; the held ball is created separately by the server.
2. Place it near the spawn with clear floor space. If the floor top is Y = 0 and the spawn is near the origin, use Position `6, 1, 0`. For another floor elevation, add that elevation to Y and choose X/Z near your spawn.
3. Insert a ProximityPrompt directly into BasketballPickup. Set Enabled to true, KeyboardKeyCode to E, HoldDuration to 0, MaxActivationDistance to 10, and RequiresLineOfSight to true. The server sets ActionText to `Pick Up Basketball`, ObjectText to `Basketball`, HoldDuration, and range automatically. Do not insert any scripts into the station.
4. Insert a Model directly under Workspace and name it `DunkHoop`. Insert a Part directly inside it and name it `Rim`. A PrimaryPart is not needed.
5. Set Rim Size to `4, 0.4, 4`, Anchored to true, CanCollide to false, Color to bright orange (RGB 255, 100, 0), and Material to Neon so the target is easy to see. A flat block is sufficient; a torus is unnecessary.
6. For the sample floor/spawn above, set Rim Position to `0, 12, -15`. Its center is 12 studs above the floor. Keep a clear approach and ample overhead space. For another floor, add its top elevation to Y. There must be solid ground below the approach, but no platform at rim height.
7. Save the Studio place separately. Rojo manages the source and the two remotes, not these Workspace objects. Restart Play after creating/replacing the pickup. The rim is resolved on every request.
8. Press Play, approach the pickup, and press E. Verify an orange ball follows the right hand and `F - Dunk` appears. Walk toward the rim, jump, and press F near the jump apex. A valid dunk displays `DUNK!` and `+$25` for 1.5 seconds.

No manual RemoteEvents or custom client scripts are needed in Studio; Rojo supplies them. The basic F-key dunk controller targets keyboard for v0.1. No touch/gamepad dunk binding is implemented yet.

## Tuning and Assumptions

Edit `src/shared/Config/DunkConfig.luau`, sync, and restart Play to reload module values.

| Setting | Default | Meaning |
| --- | --- | --- |
| PickupDistance | 10 studs | Root-to-pickup-center range |
| PickupCooldown | 0.5 seconds | Per-player limit on pickup processing |
| BallDiameter | 2 studs | Size of the held orange sphere |
| DunkHorizontalDistance | 6 studs | Maximum X/Z distance from character root to rim center |
| DunkMaxBelowRim | 4 studs | Maximum root distance below rim; unchanged physical reach requirement |
| DunkMaxAboveRim | 6 studs | Maximum root distance above rim (previously 4) |
| DunkInputBufferSeconds | 0.35 seconds | Maximum server request lifetime while waiting for valid height |
| DunkBufferVerticalAllowance | 3 studs | Extra height range where an airborne request can wait, never award |
| DunkCooldown | 1 second | Per-player attempt interval, including failed attempts |
| DunkCashReward | 25 | Cash per accepted dunk; Vertical stays unchanged |
| FeedbackDuration | 1.5 seconds | Confirmed-success message duration |

Keep distances and timing positive, and cash rewards nonnegative whole numbers. Preserve the current playtested regulation rim position: Vertical 30 cannot reach its dunk zone, approximately 35 is the first basic dunk milestone, and 40+ should become more comfortable. This is a physical threshold, not a stat comparison. The four-stud allowance below the rim is unchanged; only the upper window grows from four to six studs. There is no separate dunk-height stat. The earlier Y = 12 setup is an example, not a calibrated regulation height; do not reposition the existing tested rim using that example.

An airborne, ball-possessing player already within the six-stud horizontal radius can press F up to 0.35 seconds before entering the scoring height window. Requests can wait only within three additional vertical studs beyond that window. During the wait, the server samples current positions every Heartbeat. The extra buffer range never awards cash: the root must actually enter the unchanged minimum height and satisfy all checks before expiry. Grounded input is not buffered. Leaving range, landing, death, lost possession, character replacement, or rim removal/replacement cancels the pending attempt. No teleporting or character movement is applied.

Only one pending attempt exists per player. Extra requests cannot extend its expiry, bypass cooldown, or create parallel awards. The one-second cooldown starts on each admitted request and is also renewed on success to maintain at least a second between rewards. Each accepted request awards at most once. The client and remotes are unchanged.

Airborne means the server observes FloorMaterial Air and a Humanoid state of Jumping or Freefall. Standing, sitting, swimming, and climbing do not qualify. Falling into the zone may qualify. There is no animation, ball release, or actual ball-through-rim test. Possession remains after a successful dunk, and another valid request can succeed after cooldown, even in the same long jump. This is intentional for repeated testing.

Ball possession is private server state. `HasBasketball` and `Dunks` Player attributes are display/debug mirrors; changing them on the client cannot grant possession or rewards. The visible ball is massless, non-colliding, non-touching, and non-queryable, and is welded to RightHand (R15) or Right Arm (R6). Death/respawn clears it; pick up another ball. Cash and dunk count persist across respawns in the current server but reset on rejoin.

Each F press sends an empty RequestDunk message. The server validates every attempt and sends numeric success through DunkResult only after updating private cash/count state. Failed validation sends a rejection message such as "Move closer", "Jump higher", or "Jump first"; it never displays DUNK or grants cash. Eligible buffered requests delay rejection until expiry or invalidation. Distance/height messages include measured and allowed gaps. Rejections also appear in Studio Output, and the client prints a ready message at initialization. Attempts still consume the one-second cooldown; repeated inputs during cooldown are ignored. Client input throttling is only a convenience; the server also enforces it. Network latency affects arrival time; the buffer covers slightly early airborne input, not unlimited latency or a press before takeoff.

## Progression and Buffer Regression Tests

Keep the same regulation rim, avatar, floor, and gravity throughout these tests. Reach the target Vertical through training, not by editing the display-only leaderstats.

- Vertical 30: try early airborne presses, near-apex presses, and repeated requests from the normal floor. No dunk should succeed unless the avatar actually enters the reach zone; the buffer must not reward an unreachable jump.
- Vertical 35: jump toward the rim and press F slightly before reaching the old scoring window (within approximately 0.35 seconds). Expect one +25 reward on entering the zone, with Vertical unchanged. Compare centered and slightly off-center approaches inside six studs.
- Vertical 40: repeat early, apex, and descending attempts. Dunking should feel more reliable as the avatar spends longer above the minimum height; it must still fail when grounded or outside six studs.
- Vertical 50: test near/above rim height and descent. The extra two studs above the rim should reduce timing sensitivity, without allowing success while above the expanded window.
- Press too early to enter the scoring window within 0.35 seconds: no reward. Entering after expiry must require another request once cooldown permits.
- During a pending request, land, move out of range, reset, lose the ball, replace the rim, or disconnect: no delayed reward or errors. Spam starts during buffering: only one reward, no extended lifetime. Verify at least one second between successful rewards.

## Manual Test Checklist

- [ ] Start with 30 Vertical, 0 Cash, Dunks attribute 0, and no held ball/hint. Output has no script errors.
- [ ] Press F without a ball: no success message or cash. Pick up once: one ball and the hint appear. Repeated pickup presses never create duplicates.
- [ ] Inspect the ball: unanchored, welded to the right limb, Massless true, CanCollide/CanTouch/CanQuery false. Walking and jumping remain normal. Test R15 and R6 if both rigs will be supported.
- [ ] With possession, stand near the rim and press F: no cash or success. Wait at least one second, jump near the rim, and press F near the apex: exactly +25 Cash, Dunks +1, unchanged Vertical, one success message and server log.
- [ ] Try while horizontally distant, too low, or far above the rim: no reward. Try dead or with the character removed: no reward/errors. Test ground rejection with the rim temporarily lowered to root height, then restore it.
- [ ] Repeatedly press F quickly: no reward more frequently than the one-second server cooldown. Holding F does not auto-dunk. Wait, then jump/press again: one additional reward and possession retained.
- [ ] In Studio's CLIENT Command Bar, while near the rim, run `for attempt = 1, 20 do game.ReplicatedStorage.Remotes.RequestDunk:FireServer() end`. At most one attempt can be processed in that burst; no reward if grounded/invalid. Repeat airborne. Supplying fake positions, reward numbers, or success flags as extra arguments must not affect the result.
- [ ] In client view set HasBasketball to true without picking up, then request a dunk: the server rejects it. Changing client cash/Vertical/dunk mirrors must not change server state. Firing DunkResult from the client must not grant rewards.
- [ ] Reset while holding the ball: ball/hint disappear, session cash/Vertical/Dunks persist, jump height remains correct, and pickup works again. Repeated resets/disconnects produce no errors.
- [ ] Test two clients: each can possess one ball independently. Each sees the other's held ball, only the successful player receives cash/feedback, and cooldowns are independent.
- [ ] Stop Play and temporarily remove/rename BasketballPickup or its prompt: clear setup warning, no crash, training still works. Restore and restart. Repeat with missing/wrong-type/unanchored Rim or missing DunkHoop: no dunk rewards; restore valid objects to recover.
- [ ] Regress Vertical Training: hold E for several ticks and release; confirm +1 Vertical/+5 Cash per tick, correct stopping, increasing jump height, and respawn behavior. Dunking adds only cash and the session dunk count.
- [ ] Raise Rim above the starting player's reach, then train enough to physically reach it. Confirm improved real jump capability enables dunks without changing validation or adding another stat.
- [ ] Type F in chat/text entry: no dunk request. Normal F outside text entry still works. Map assets remain intact after Rojo sync.

## Validation Limits

Rojo build checks packaging, not gameplay execution or Luau type correctness. Studio Script Analysis and the checklist above are still required. These validations use server-observed Roblox instances, but normal character network ownership is not comprehensive movement/teleport anti-cheat. Competitive movement verification is deferred.
