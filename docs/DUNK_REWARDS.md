# Dunk Rewards: Vertical Bonus and Air Tricks

Two server-authoritative Cash sources on top of the style reward. All numbers live in `src/shared/Config/DunkRewards.luau`; the server pays, clients only display.

## Vertical bonus on every dunk

```
dunk Cash = style Reward x court DunkCashMultiplier x Vertical multiplier
Vertical multiplier = min(1 + (Vertical - 30) x 0.01, 5)      -- +1% per Vertical point
```

| Vertical | Multiplier | Basic ($20) | Two-Hand ($35) | Tomahawk ($60) | Windmill ($100) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 35 | x1.05 | $21 | | | |
| 50 | x1.20 | $24 | $42 | | |
| 75 | x1.45 | $29 | $51 | $87 | |
| 110 | x1.80 | $36 | $63 | $108 | $180 |
| 150 | x2.20 | $44 | $77 | $132 | $220 |

High School multiplies these by 1.25 (Windmill at 150 Vertical = **$275**, was $125). The HUD's equipped-dunk line shows the boosted payout, for example `+$220 / DUNK (VERT x2.2)` (before the court bonus).

## Perfect slam (timing)

Once the dunk starts, a meter appears. The needle sweeps toward the slam line; press **F** again (or click/tap the meter) as the slam hits.

- **Server-judged:** the `SlamTiming` remote carries no data. The server stamps the press with its own clock minus the player's measured latency (capped at `MaxLatencyCompensationSeconds`). It compares that to the real moment the Slam phase started and judges it after the hang, so late presses still count. Only the first press counts.
- **Ratings (`DunkRewards.Timing`):**

| Rating | Window around the slam | Dunk Cash |
| --- | --- | --- |
| Perfect | 0.09 s early to 0.07 s late | x1.5 |
| Good | 0.22 s early to 0.14 s late | x1.15 |

- Air-trick Cash isn't multiplied. The rating replicates as `SlamRating` (presentation only). A Perfect gets a gold "PERFECT!" call, a ding, a `PERFECT WINDMILL!` result and a bigger crowd roar.
- The client only predicts where to draw the needle (`FeedbackConfig.SlamMeter`: `SettleSeconds`, `SlamLine`). The rating shown on the meter is a local guess; the server's rating decides the Cash.

## Air tricks (paid before the dunk lands)

When a dunk starts high above the rim, the Descent phase becomes an air-trick combo:

1. **How many:** none below a 12-stud drop, then one more trick per 16 studs of drop, up to 6. A higher Vertical means a higher jump, so a longer drop fits more tricks.
2. **Which ones:** the equipped style's `DescentTrick` always opens the combo. The rest are shuffled from every trick unlocked at your Vertical. A trick isn't reused until the whole pool has been used, and the same trick never plays twice in a row.
3. **Air time:** the descent lasts at least as long as the combo needs (0.15 s tuck + each trick's seconds + 0.2 s open-up).
4. **Cash:** when the server's timeline finishes each trick it pays `trick Cash x combo bonus x court multiplier`, updates Cash and fires `DunkTrick` so the dunker sees `FRONT FLIP! +$13  COMBO 4/4`. The combo bonus is x1.25 for the 2nd trick, x1.5 for the 3rd, and so on. The dunk result then shows `+$275  (+$47 AIR)`.

| Trick | Unlocks at Vertical | Seconds | Base Cash | Shape |
| --- | ---: | ---: | ---: | --- |
| 360 (`Spin360`) | 0 | 0.30 | $4 | layout spin |
| Front Flip | 60 | 0.34 | $6 | tuck |
| Cartwheel | 80 | 0.34 | $7 | star (legs and free arm out) |
| Corkscrew | 95 | 0.40 | $9 | pike + twist |
| Backflip | 110 | 0.36 | $10 | tuck |
| 720 (`Spin720`) | 125 | 0.42 | $12 | pike spin |

Typical combos when pressing F at the top of a jump:

| Vertical | Jump apex | Tricks |
| ---: | ---: | ---: |
| 50 | ~17 studs | 0 |
| 60 | ~23 studs | 1 |
| 75 | ~34 studs | 2 |
| 100 | ~56 studs | 3 |
| 125 | ~81 studs | 4 |
| 150 | ~111 studs | 6 |

Pressing F lower (closer to the rim) plays fewer tricks, so there's a skill reward for dunking from the apex.

## Security

- The client never names a trick, a count or an amount. `RequestDunk` still takes no arguments.
- `DunkExecution` plans the combo from the server-measured drop and the private Vertical, and pays from its own clock. `PlayerService.AwardDunkTrick` only pays while that player's dunk is `Executing`, and only for a configured trick with a combo index from 1 to `MaxTricks`. It also clamps to `DataConfig.MaxCash`.
- Tricks already paid are kept if the dunk is cancelled later. The normal dunk cooldown and engagement checks still bound how often a combo can happen.
- The `DunkTricks` / `DunkDescentSeconds` attributes and the `DunkTrick` remote are presentation-only.

## Tuning knobs (`DunkRewards.luau`)

| Knob | Effect |
| --- | --- |
| `Vertical.BonusPerPoint`, `Vertical.Start`, `Vertical.MaxMultiplier` | How strongly Vertical boosts dunk Cash |
| `Tricks.MinDropStuds`, `StudsPerTrick`, `MaxTricks` | How many tricks a drop fits |
| `Tricks.Definitions[*].RequiredVertical` | When each trick joins the mix |
| `Tricks.Definitions[*].Seconds` | Trick speed (and total air time) |
| `Tricks.Definitions[*].Cash`, `ComboBonusPerTrick` | Trick payouts |
| `Tricks.TuckSeconds`, `OpenSeconds` | Air time before the first and after the last trick |

Client look: `PresentationConfig.Descent.Shapes` (tuck/layout/pike/star angles), `ShapeBlendRate`, `StarArmDegrees`. The popup timing lives in `FeedbackConfig.Dunk.Trick*`, and an optional sound goes in `FeedbackConfig.Audio.AssetIds.AirTrick`.

**Balance note:** this roughly doubles dunk income at high Vertical (a High School Windmill with a 4-trick combo pays about $320, versus $125 before). Early game changes little (Basic at 35 Vertical: $21 vs $20). Re-check the High School and upgrade pacing in a real playtest.
