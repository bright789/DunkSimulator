# Dunk Impact VFX (court themes × meter grade)

Every slam now has an impact effect themed to the court it happens on. How big it is depends on how well you hit the Perfect-slam meter. Everything is client-only (`src/client/DunkVFX.luau`) and every number and colour is in `src/shared/Config/DunkVFXConfig.luau`. All textures are built-in Roblox particles, so nothing needs uploading.

## What players see

| Meter grade | Effect |
| --- | --- |
| **PERFECT** | The court's big signature effect, two floor shockwaves, a strong light flash, a harder rim kick, a longer freeze frame (0.12 s), extra camera shake and a quick court-coloured screen flash (the dunker only, drawn under the HUD). |
| **GOOD** | Court sparks and rim shockwave, one floor shockwave, and a small version of the court effect. Slightly harder rim kick and freeze. |
| **EARLY / LATE** | A small grey smoke puff and a few dull sparks: a "brick". Other players don't see it. |
| No press | The court's normal impact: coloured sparks, a shockwave around the rim and a light flash. |

Other players' PERFECT and GOOD slams also show a floating **PERFECT!** / **GOOD!** over the dunker's head.

### Court themes

| Court | Colours | GOOD | PERFECT signature |
| --- | --- | --- | --- |
| Neighborhood | street orange, warm white | dust puff across the asphalt | dust shockwave, flying asphalt chips, spark fountain off the rim |
| High School | Dunk High blue and gold | confetti pop off the rim | two confetti cannons beside the hoop plus gold stars |
| College | Dunk U purple and gold | ember shower off the rim | two pyro fire columns beside the hoop plus a purple/gold confetti drop |
| Skyline Rooftop | neon cyan and pink | electric crackle | lightning strike from the night sky into the rim, neon crackle and three fireworks over the city |

Bigger dunk styles hit a little harder: 0.85× for the first dunk, up to 1.2× for the top styles.

## How it works

1. **Server grade.** `SlamTiming.Judge` now returns `Perfect`, `Good`, `Early` or `Late` (nil if there was no press).
   - `DunkExecution` publishes that on the player as `SlamRating`.
   - Only Perfect and Good become the dunk's reward rating, so Cash, daily challenges and contest scores are unchanged.
   - It judges as soon as no Good press can still arrive (about 0.41 s after the slam), not at the end of the rim hang. Long-hang dunks like Elbow Hang therefore show their grade right after the impact. Rewards are identical, because a press that late could never have counted.
2. **The dunker's own grade is predicted.** When you press the meter, `DunkController` passes its local rating to `DunkVFX.SetPrediction`, so the full effect lands on the impact frame. The prediction is cleared when the next dunk's meter starts or the dunk ends.
3. **Impact** (`RimPresentation.Impact`, every player's dunk, when the ball leaves the hand at the rim):
   - plays the predicted grade for you, and the normal impact for everyone else;
   - scales the rim kick and hit-stop from the grade (`RimKick`, `HitStopSeconds`);
   - `FeedbackController` scales the dunker's camera shake by `CameraBoost`.
4. **Payoff** (`SlamRating` changes, all clients): plays the graded effect unless it was already predicted and shown. This is what other players see for your PERFECT or GOOD, about 0.3 s after the normal impact.
5. **Performance:**
   - slams more than `MaxDistance` (260 studs) from the camera are skipped;
   - other players' slams use `OthersScale` (0.6×) of the particles;
   - every effect cleans itself up with Debris within about 3 s. Parts (lightning) go in `Workspace.LocalDunkVFX`; emitters sit on attachments in `Terrain`.

## Tuning

`DunkVFXConfig`:

- **`Grades`:** each grade's `Scale`, `FloorRings`, `Light`, `Signature` (`"Big"`/`"Small"`), `Flash`, `Label`, `RimKick`, `HitStopSeconds` and `CameraBoost`.
- **`Themes`:** each court's colours and which signature it uses. A new court needs a `Themes` entry keyed by its `CourtConfig` id. It can reuse an existing `Signature`, or you can add a new function to `SIGNATURES` in `DunkVFX`.
- **Shared numbers:** `RimSparks`, `RimShockwaveSize`, `FloorRingSize`, `ConfettiCount`, `PyroSeconds`, `PyroSideOffset`, `CannonSideOffset`, `LightningHeight` and `FireworkBursts`.
- **Screen flash:** `FlashTransparency` and `FlashSeconds`.

## Tested in Studio (QA store, scripted dunks)

Grades were forced by firing the `SlamTiming` remote at the Slam phase. The local-prediction path was tested with a real **F** press.

| Test | Result |
| --- | --- |
| Rooftop, no press | Cyan sparks, pink rim shockwave and light. |
| Rooftop, PERFECT | Lightning bolt, neon crackle, floor rings, screen flash. Cash $4,574 → **$6,861** (×1.5). |
| College, PERFECT | Twin fire columns and a confetti drop. The columns and confetti were scaled down after the first look (they filled the screen). |
| High School, GOOD | Blue, gold and white confetti pop plus a blue floor ring. Cash $3,638 → **$4,184** (×1.15). |
| High School, LATE | Normal impact, then the grey fizzle. No bonus. |
| Neighborhood, PERFECT | Dust shockwave, chips and spark fountain. Dust and chips were toned down after the first look (the haze covered the screen). |
| Real F press (early) | The meter said EARLY, the fizzle played on the impact frame, and nothing played again when the server's `Early` arrived **0.42 s after the slam** (before this change it came at the end of the hang, about 2.4 s). |
| Popup | The long "PERFECT ROCK THE CRADLE!" heading used to be cut off; it now shows "BETWEEN THE LEGS!" + "PERFECT" on the detail line. |

**Not tested:** the floating PERFECT!/GOOD! label over *other* players needs two players (a Studio 2-player local server or a live server).

**Note:** Studio captures were taken with f.lux on, so colours in test screenshots look warmer than in game.
