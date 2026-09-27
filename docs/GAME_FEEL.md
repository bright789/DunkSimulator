# Game Feel & Juice v0.1–v0.2

These milestones polish the existing loop without changing server eligibility, payouts, progression, persistence, or Workspace geometry. v0.2 changes only post-validation execution motion and local presentation. Stop Play, sync Rojo, and restart Play. `DunkPresentation` is a new server-to-client RemoteEvent; there are no Studio objects or map-builder steps.

## v0.2 Dunk Differentiation Audit

In v0.1 all four styles shared the same root alignment, near-identical finish/return rhythm, and short arm-only IK. Basic had no arm pose; Tomahawk's backward waypoint and Windmill's 2.5-stud circle were easy to miss at gameplay speed. The major camera/rim response started only after completion and differed mainly in intensity. Hiding the HUD exposed the lack of body motion and readable anticipation.

The pre-pass root target was `Rim.Y - 3` for all styles, with identical capped horizontal correction, and it remains so. The original ball paths were Basic hand-follow/direct; Two-Hand `(0, 0.8, -1.8) → (0, 3.1, -1.2)`; Tomahawk `(1.3, 3.3, 0.8) → (1.3, 2.8, 2.2)`; and Windmill a 2.5-stud circle about `(2.1, 0.9, 0)` from 15% to 85% of gather. All converged on the same above-rim, below-rim and hand-return points. The pre-pass camera used one .30-second profile, .09-stud base/.15-stud maximum shake and 2.2° base/3.5° maximum FOV punch, scaled only by .7/.9/1.1/1.3 intensity. Rim feedback was the same 52-pixel, .30-second ring for every style. Audio hooks existed but all IDs were blank and thus silent.

The figures below are **post-alignment motion**; server ownership handoff, height normalization, and horizontal alignment add variable time before them. Entry validation and assist tolerances are unchanged.

| Style | Before gather / slam / return | After gather / slam / return | Motion identity |
| --- | --- | --- | --- |
| Basic One-Hand | .30 / .25 / .20 = .75s | .26 / .18 / .14 = .58s | Quick right-hand/direct rise, clean single-arm extension, direct pass and fast recovery |
| Two-Hand Power | .40 / .20 / .20 = .80s | .39 / .17 / .20 = .76s | Ball moves to chest/front center, both hands load, short pause, accelerated heavy pass, torso compression |
| Tomahawk | .55 / .20 / .20 = .95s | .56 / .16 / .18 = .90s | Ball rises to `(1.6, 4.1, 3)` studs behind/above normalized root, holds, then whips forward/down while torso opens and closes |
| Windmill | .80 / .20 / .20 = 1.20s | .73 / .20 / .19 = 1.12s | Larger vertical elliptical sweep (3.15-stud vertical, 2.25-stud depth), overhead hang, synchronized torso roll and sharp finish |

Two-Hand/Tomahawk/Windmill use config-driven 0.15/0.28/0.48-stud lift and 0.16/0.12/0.15-stud impact dip *after* the same validated entry/alignment. Basic remains level. This is not a new height requirement or a far-range teleport. `DunkStyleMotion` provides smooth waypoint/circle/finish curves; `DunkPose` blends temporary R15 arm and torso IK, then destroys it on completion or interruption. R6 still gets the distinct ball/root movement but not R15 IK posing. Optional uploaded animations remain unset.

### v0.2 Configured Motion

All numbers below are in `src/shared/Config/DunkStyles.luau`; path offsets are studs in the normalized player's facing frame. Unlisted eligibility, cooldown, buffer, jump, rewards and court bonuses are unchanged.

| Style | Ball path / gather timing | Height lift / lift fraction / impact dip / slam exponent | Arm IK and body pose |
| --- | --- | --- | --- |
| Basic | Direct hand follow | 0 / .55 / 0 / smooth | Right hand; grip .5, arm weight .75, smooth .04, blend .2; torso weight .35, smooth .04, blend .18, pitch 0→8° then 12° slam |
| Two-Hand | Center `(0,1.2,-1.5)` at .23, overhead `(0,2.5,-1.4)` at .58 and hold to .71 | .15 / .55 / .16 / 2.3 | Both hands; grip .5, weight 1, smooth .035, blend .2; torso weight .55, smooth .035, blend .18, compress pitch -5°/sink .18 at .6, pitch -3°/sink .13 at 1, pitch 17°/sink .12 slam |
| Tomahawk | Up `(1.3,3.3,.6)` at .24, behind `(1.6,4.1,3)` at .62, hold to .74 | .28 / .62 / .12 / 3.0 | Right hand; grip .6, weight 1, smooth .03, blend .2; torso weight .65, smooth .03, blend .18, pullback pitch -14°/yaw 17°/roll 6° at .7, slam pitch 19°/yaw -4° |
| Windmill | Center `(2.1,1.2,-.2)`, ellipse vertical 3.15/depth 2.25/side .5, start 225°, sweep 300°; enter .11, hang .62–.73 at angle fraction .75, exit .91 | .48 / .52 / .15 / 2.2 | Right hand; grip .55, weight .9, smooth .025, blend .15; torso weight .65, smooth .03, blend .16, staged pitch/roll/yaw through the sweep and 17° slam pitch |

Pose keyframes are authored per style in the same configuration (Tomahawk: .38 `-5/7/0`, .7 `-14/17/6`, 1 `-10/14/4`; Windmill: .22 `5/-5/5`, .55 `-5/8/-8`, .75 `-4/9/10`, 1 `7/-5/-3`, where tuples are pitch/yaw/roll degrees). Two-Hand windup cue is .58 of gather; Tomahawk/Windmill cues are .62. Basic/Two-Hand whoosh hooks cue on Slam; Tomahawk/Windmill on Windup. Body pose and ball motion are best-effort procedural presentation, not new validation gates.

`DunkExecution` sends owning-client `DunkPresentation(styleId, "Gather" | "Windup" | "Slam" | "Contact")` timing cues only after the server has accepted and aligned the attempt. `Contact` fires when the server-observed ball passes below Rim height; it starts local impact camera/audio/rim visuals at physical contact but **never grants Cash or success UI**. The existing `DunkResult` remains the sole confirmed success/actual-reward signal after ball return and cleanup. If the presentation cue is unavailable, the client falls back to impact on confirmed completion. Server-driven ball/root motion is visible to nearby players; only the dunker's client receives camera/audio/UI cues. A missing presentation remote does not cancel server execution, but sync the updated Rojo project to receive cues.

Camera profiles now have different *shapes*: Basic gets only a small impact punch; Two-Hand briefly compresses FOV before a downward kick; Tomahawk pulls back during wind-up then snaps forward/down; Windmill widens during its sweep then punches at the finish. Impact FOV/short shake are Basic 1.4°/.055 stud/.22s, Two-Hand 2.25°/.10/.32s, Tomahawk 3.0°/.12/.32s, Windmill 3.4°/.14/.36s. FOV remains capped at 3.5°, shake at .15 stud, and total camera offset at .22 stud. Cue/impact effects replace and restore the previous local FOV/CameraOffset; reset stops them. No server time freeze or gameplay hit-stop is used.

The configured anticipation FOV/duration profiles are Two-Hand gather `-.8°/.28s`, windup `-1.1°/.19s`; Tomahawk gather `-.5°/.30s`, windup `-1.4°/.25s`; Windmill gather `+1.6°/.62s`, windup `+2.2°/.30s`. Impact kick vectors (local studs) are Basic `(0,-.02,0)`, Two-Hand `(0,-.085,-.02)`, Tomahawk `(0,-.09,-.05)`, Windmill `(0,-.08,-.045)`. Basic has no anticipation camera cue. Existing master shake/FOV toggles and 12 Hz shake frequency remain.

The local rim effect remains a short .30-second BillboardGui and **never moves the logical Rim**. Basic/Two-Hand/Tomahawk/Windmill use 42/54/62/72-pixel rings and 0/2/3/4 short streaks respectively; Debris cleans them. Cash popup scale rises modestly with the actual server-confirmed reward, capped at 1.08x. Each style has empty `Approach`, `Whoosh`, `Impact`, and `Rim` sound slots in `FeedbackConfig.Audio.StyleAssetIds`, with per-cue volumes; no sound plays until valid licensed IDs are supplied. Existing generic impact sound remains a fallback when a style impact ID is blank. Configure IDs as `rbxassetid://<real numeric ID>` only after uploading or approving assets accessible to the experience.

Additional presentation settings in `FeedbackConfig` are rim visibility 45 studs, streak length 16 pixels, ring colors RGB `(244,247,250)` for Basic/Two-Hand and `(255,195,120)` for Tomahawk/Windmill, reward popup scale `+.00025 × confirmed Cash` capped at 1.08, late-cue guard .5 seconds, and style sound volumes Approach .14 / Whoosh .24 / Impact .38 / Rim .20. The old .7/.9/1.1/1.3 relative impact intensities and .12/.1.05/.22-second popup entrance/hold/exit were not retuned.

### v0.2 Studio Comparison

1. Stop Play, sync `default.project.json`, and restart Play. Confirm `ReplicatedStorage.Remotes.DunkPresentation` exists. No map rebuild is needed.
2. In a disposable DEV profile at **Vertical 110+**, equip each style and perform **five successful dunks each** at Neighborhood: 5 Basic, 5 Two-Hand, 5 Tomahawk, 5 Windmill. Cover/ignore the HUD and have a second player watch. Basic should be quick/direct; Two-Hand centered/heavy; Tomahawk visibly pulled behind the body then whipped forward; Windmill a large circular sweep with hang. If visual identity depends on reading text, tune the motion profiles before acceptance.
3. Repeat a few attempts of each style at High School and at its own unlock threshold. Entry reliability should remain similar; no new narrow apex window or high-Vertical cancellation should appear. Confirm ball passes the local Rim and returns to hand.
4. Verify Neighborhood base Cash rewards $20/$35/$60/$100 and High School $25/$44/$75/$125, once per completed dunk. Spam F and request a locked style: neither may grant extra Cash. Camera/rim cues on failed/cancelled attempts must not show a confirmed reward.
5. Reset/die/leave or lose possession during each style. Confirm normal jump/movement, no lingering IKControls/attachments/AlignPosition, no stuck FOV/CameraOffset, no duplicate rewards, and no permanent local rim Gui. Try R6 and R15 if both rigs are supported.
6. Test with two players: the observer sees the server-driven ball/character motion, but their own FOV/camera never moves. Check 1920×1080, 1366×768, and a smaller window; run several minutes of repeated dunks and inspect Output/Explorer for leaks.

Live Roblox physics, R15 IK quality/replication, perceived style readability, and audio permissions cannot be proven by the local Luau/Rojo checks; this Studio comparison is the visual acceptance gate. No real sound IDs or authored animation tracks ship with v0.2.

## Feedback Flow

| Moment | Authoritative source | Client response |
| --- | --- | --- |
| Rim contact | Server `DunkPresentation` Contact after observed ball crosses Rim | Local rim/camera/audio impact only; no reward or success title |
| Dunk completion | Server `DunkResult` with awarded Cash and style ID | Style title and exact Cash popup; impact fallback if Contact cue was absent |
| Whole Vertical gain | Server-owned `leaderstats.Vertical` | Reused `+N` label and small Vertical-card pulse; optional throttled tick sound |
| Cash gain | Server-owned `leaderstats.Cash` | Reused `+$N` label and small Cash-card pulse |
| Upgrade purchase | Server `TrainingUpgradeState` Result with `purchased == true` | Panel/level pulse and level-up message; optional sound |
| Dunk unlock | In-session crossing of the server-replicated Vertical threshold | One short style toast; no historical login replay |
| Court unlock/travel | Server `CourtState` unlock ID or changed CurrentCourt snapshot | Unlock celebration or brief arrival title/bonuses |
| Ball pickup/loss | Server-owned `HasBasketball` attribute | Subtle audio hook and animated `[F] DUNK` hint |
| UI button | Local hover/activate | Small scale response and optional click sound; no gameplay mutation |

`FeedbackController` coordinates cues, `CameraFeedback` owns the temporary local camera response, and `FeedbackAudio` owns optional local sounds. Existing views own their own UI animation. The Rim ring is a local BillboardGui adorning the logical Rim; it never moves the gameplay reference, and Debris removes it. No client event grants a reward. Rejections do not trigger success effects.

## Tuning

All new presentation values live in `src/shared/Config/FeedbackConfig.luau`.

| Setting | Current prototype value |
| --- | --- |
| Relative dunk intensity: Basic / Two-Hand / Tomahawk / Windmill | 0.7 / 0.9 / 1.1 / 1.3 |
| Legacy camera defaults | enabled; 0.09 stud shake base, 0.15 cap; 2.2 degree FOV base, 3.5 cap; 0.30 seconds. v0.2 uses the style profiles above. |
| Confirmed dunk popup | 0.12-second entrance, 1.05-second hold, 0.22-second exit |
| Dunk Rim burst | 0.30 seconds; style-specific 42–72-pixel BillboardGui |
| Possession hint | 0.18-second fade/slide |
| Stat gain/pulse | 0.10-second hold + 0.35-second fade; 0.18-second card pulse |
| Dunk / court unlock hold | 2.0 / 2.2 seconds |
| Upgrade confirmation message | 2.0 seconds |
| Court arrival hold | 1.4 seconds |
| Button hover / press | 1.025x / 0.96x, 0.12 seconds |
| Training audio throttle | at least 1.5 seconds between cues |

Set `Camera.CameraShakeEnabled = false` or `Camera.FOVPunchEnabled = false` there to disable either local camera effect for comfort. Intensities affect presentation only. The actual Cash figure comes from `DunkResult` and is not recomputed from style or court config on the client. Training feedback uses the replicated *whole* Vertical delta, not a rounded fractional estimate.

## Audio Setup

Sound is on. Every ID in `FeedbackConfig.Audio` is a free Creator Store asset: Roblox's own UI sounds (`Roblox GUI - ...`, `Roblox_UI_...`) and the Pro Sound Effects library (creator `ProSoundEffects`). All of them were checked to load in Studio. Swap any entry for your own upload (`rbxassetid://<id>`); `""` silences it.

- **Your own actions (2D, `FeedbackAudio`):** pickup catch, slam clang plus rim rattle (Tomahawk and Windmill use a heavier clang), the style whoosh, the cash register, an air-trick ding that pitches up with each trick in a combo, the Perfect-slam ding, training thuds, purchase, unlock stingers, the bus air brake on arrival, UI clicks, challenge notifications and the claim payout.
- **World (3D, `WorldAudio`, heard by everyone nearby):** a dribble bounce each time the ball hits the floor (louder when running), loose-ball bounces, other players' rim clangs and rattles, crowd claps (small crowds) or a full roar (`CheerCrowdSize`+ fans) on every slam with a bigger roar for a Perfect, the bus door and brakes, and a low stadium-crowd bed while you're in the High School gym.
- Volumes and 3D roll-off live in `FeedbackConfig.Audio.Volumes`, `StyleVolumes` and `World`. All IDs are preloaded at join.

## Cleanup and Limits

The camera effect runs a RenderStepped connection only for the short impact window, then disconnects. It restores the captured FOV and Humanoid CameraOffset; if another camera script takes over, it does not overwrite that script's new values. Repeated dunks replace the prior effect, and character removal/reset stops it. UI labels/screens are reused; at most one active stat pulse/gain tween per card and one interaction tween per button are retained. Unlock/arrival/hint tweens cancel when replaced. Local rim bursts are short-lived and removed with Debris. Training makes no camera shake or repeating GUI instances. Roblox Studio is still needed to visually verify camera comfort, overlap, audio permissions, and performance.

## Manual Studio Matrix

1. **Basic dunk:** At Neighborhood, make one Basic One-Hand dunk. Check existing success/reward behavior, small impact, style title, exact `+$20`, Cash pulse, and subtle camera response; F press/failed attempts must not celebrate.
2. **Style hierarchy:** Try Basic, Two-Hand, Tomahawk, and Windmill. Impact and title emphasis should increase in that order without changing execution reliability.
3. **High School reward:** Windmill there should show `+$125`, and Cash must rise by exactly 125.
4. **FOV recovery:** Dunk several times, including rapid follow-up attempts. Check FieldOfView returns to the original value.
5. **Camera/reset recovery:** Reset during or just after impact. Check camera offset/FOV and movement are normal after respawn.
6. **Extended training:** Hold the trainer for multiple seconds. Confirm small, readable whole-Vertical gains and no growing GUI hierarchy or loud repeated sound.
7. **Fractional training:** At High School, compare each feedback `+N` with the exact displayed whole Vertical change; never show a decimal gain.
8. **Upgrade:** Make a valid Training Level purchase. Check server-confirmed level-up panel pulse/message and unchanged Cash deduction. Failed purchases must not celebrate.
9. **Dunk unlock:** Cross 75 Vertical through training. Tomahawk unlock toast should appear once, not again each tick or after rejoining with 75+.
10. **Court unlock:** Buy High School once. Check unlock title and exactly $6,000 deducted, with no duplicate celebration for failed/spam requests.
11. **Court travel:** Travel Neighborhood to High School and back. Check the brief matching arrival title/bonus line. Resetting should not display a travel title.
12. **Basketball:** Pick up and relinquish/reset/travel with the ball. Check only one subtle pickup cue per acquisition and hint fades in/out correctly.
13. **Spam:** Repeatedly press F and click DUNKS/COURTS/Upgrade/Equip/Travel/Close. Check no duplicate rewards, stuck UI scales, or lingering effects.
14. **Resolution:** Test 1920x1080, 1366x768, and a smaller Studio window. Verify HUD, toasts, panels, and buttons remain readable and do not hide the basket.
15. **Extended session:** Train, dunk, upgrade and travel for several minutes. Inspect Output, player GUI, SoundService, and performance for growing instances, errors, or permanent camera effects.
