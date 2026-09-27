# Automatic Dribbling v0.1

After server-validated pickup, `BasketballService` keeps one private possession record and one `HeldBasketball` Part per player. While grounded and not attempting a dunk, the server disables that ball's hand weld, anchors it, and moves it smoothly from the hand side to the detected floor and back. Idle, walking, and running select progressively faster cadences from `DribbleConfig`; a downward raycast finds the current floor without changing ball ownership. The 30 Hz update is bounded and uses the same existing ball. Clients hide this authoritative ball and render their own smooth visual copy; see [Movement Presentation](MOVEMENT_PRESENTATION.md).

On jump or dunk attempt, the server eases the ball back to the hand. An accepted dunk forces the single ball into the existing `DunkExecution` motion; its ball-through-rim, reward, and return logic are unchanged. After return or landing, grounded dribbling resumes. Court travel, death/reset, and player leave use the existing possession cleanup, which also removes the client visuals. `BasketballAction` is a server-written presentation mirror (`NoBall`, `Holding`, `Dribbling`, `Gathering`, `Dunking`, `Recovering`); `HasBall` still consults only the private possession table.

Dribble posing (right-hand IK on the ball, forward lean, athletic crouch, guard arm) is now client-side in `BallPresentation`/`BodyPresentation` and stops before a dunk track plays. R6 keeps the visual ball bounce without R15 posing. The ball is non-colliding and follows a scripted bounce rather than a physics-simulated rebound. Future crossover/between-the-legs moves can add distinct presentation states without letting the client authoritatively spawn or move the ball.

## Studio checks

1. Pick up one ball. Stand, walk, and run: verify hand-to-floor-to-hand motion with increasing cadence, no extra balls, and a small R15 arm/torso response. `[F] DUNK` stays contextual.
2. Jump repeatedly, including while the ball is near the floor. It must gather smoothly into the hand. Land and confirm dribbling resumes.
3. At each eligible dunk style, jump and press F. Verify dribble stops before dunk alignment, no competing IK or ball path, one reward only after completion, the same ball returns, and grounded dribble resumes.
4. Spam F, reset/die during dribble/gather/dunk, leave while dribbling, and travel with a ball. Verify no duplicate, orphaned, or cross-court ball; no stuck arm pose; fresh pickup works.
5. Test two players, including one dribbling while the other dunks. Their balls, actions, Cash, and camera feedback must stay isolated. Check a several-minute session for accumulating `IKControl`, `Attachment`, or ball instances.

Normal gameplay needs only Rojo sync and Play restart; no map rebuild, asset publication, or data migration is required for dribbling. Studio visual/network smoothing needs live acceptance before claiming production polish.
