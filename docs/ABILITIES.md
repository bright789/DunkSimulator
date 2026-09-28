# Abilities

Three abilities you **arm** before a dunk. Each one is **earned** for free at a Vertical milestone or **bought** early with Cash, then **upgraded** with Cash for a shorter recharge. All numbers are in `src/shared/Config/AbilityConfig.luau`.

| Key | Ability | What your next dunk gets | Earned at | Buy early | Recharge (L1→L5) | Upgrades (L2 / L3 / L4 / L5) |
| --- | --- | --- | --- | --- | --- | --- |
| **1** | ⏳ SLOW-MO SLAM | Drops in 1.5x slow motion with a cool screen tint. PERFECT and GOOD windows are **2x wide**. | 40 Vertical | $1,500 | 60 → 30 s | $3,000 / $9,000 / $25,000 / $60,000 |
| **2** | 🔥 FIREBALL | **2x dunk Cash** (air tricks not doubled). Ball on fire, flame burst out of the rim. | 90 Vertical | $8,000 | 120 → 60 s | $10,000 / $30,000 / $75,000 / $180,000 |
| **3** | 🕊 HANG TIME | Floats down with **+2 air tricks**, even from a low jump, and each trick pays Cash. | 140 Vertical | $25,000 | 90 → 45 s | $25,000 / $60,000 / $150,000 / $350,000 |

## For players

- **Hotbar:** three slots on the right edge. Each shows its key, **READY**, a recharge countdown, **ARMED** (coloured glow) or 🔒 and the Vertical it unlocks at.
- **Arming:** press **1 / 2 / 3** (gamepad D-pad left / up / right, or tap the slot) to arm one.
  - The recharge starts the moment you press it.
  - Your next completed dunk uses everything armed; you can stack all three.
  - A cancelled dunk keeps them armed.
  - Anything armed during a dunk waits for the next one.
- **ABILITIES panel** (next to CODES, or tap a locked slot): shows each ability's level and recharge, plus a **BUY NOW** or **UPGRADE** button.
- **Unlocks:** reaching the Vertical milestone unlocks an ability for free, with an "UNLOCKED! Press 1" message.
- **Rebirth** keeps every ability and level.
- **Everyone sees your armed abilities:** blue sparkles for Slow-Mo, a flaming ball or hand for Fireball, drifting feathers for Hang Time. A Fireball dunk also bursts into flame at the rim.

## How it works

**Server:**
- `AbilityService` owns cooldowns and ARMED flags, which are not saved. It answers `AbilityRequest("Use" | "Unlock" | "Upgrade", id)` on the same remote with `(ok, message, id)`.
- It mirrors state to the `AbilityLevel_<id>`, `AbilityReadyAt_<id>` (server time) and `AbilityArmed_<id>` player attributes.
- Earned unlocks are checked on join and whenever Vertical changes.
- Purchases go through `PlayerService.SpendCash` (analytics: `Ability_<id>`, `Ability_<id>_L<n>`) and request a save.

**Dunk flow:**
1. When a dunk starts, `DunkService` snapshots the armed set (`AbilityService.ArmedFor`).
2. It passes the set to `DunkExecution.Run`:
   - Slow-Mo scales the drop time and the `SlamTiming.Judge` windows.
   - Hang Time adds bonus tricks through `DunkRewards.PlanCombo`.
   - The run publishes a presentation-only `DunkAbilities` attribute (e.g. `"SlowMo,Fireball"`).
3. `PlayerService.RegisterDunk` takes the Fireball multiplier.
4. `AbilityService.Consume` disarms the set once the dunk completes.

**Saving:** schema **v12** adds `Abilities = { SlowMo, Fireball, HangTime }` (the levels). See `DATA_PERSISTENCE.md`.

**Client:**
- `AbilitiesController` + `ui/AbilitiesView` handle the hotbar, panel, toast and key bindings.
- `AbilityVFX` draws the armed auras and the dunker's slow-mo tint.
- `DunkVFX` draws the Fireball impact burst.
- `DunkController` widens the meter zones and adds "SLOW-MO!" to the meter caption.

## Tuning

`AbilityConfig`:
- **Unlocks and prices:** `UnlockVertical`, `UnlockPrice`, `Cooldowns` (levels 1-5) and `UpgradePrices` (levels 2-5).
- **Effects:** Slow-Mo `TimingScale` and `DescentScale`, Fireball `CashMultiplier`, Hang Time `ExtraTricks` (at most `DunkRewards.Tricks.MaxBonusTricks`).
- **Controls and colours:** `Key`, `GamepadKey`, `KeyLabel`, `Icon` and `Color`.

## Tested in Studio (QA store, 2026-09-27)

For the buy-early test, Hang Time's unlock was temporarily raised to 999 Vertical, then put back to 140.

| Test | Result |
| --- | --- |
| Migration and earned unlocks | A v11 profile at 350 Vertical loaded as v12. Slow-Mo and Fireball unlocked for free; Hang Time stayed locked. |
| Buy early | Hang Time BUY NOW: −$25,000, "HANG TIME UNLOCKED! Press 3 to use it." |
| Upgrade | Slow-Mo L2: −$3,000, recharge 60 → 52 s. Cash went $776,603 → $748,603, and analytics logged both sinks. |
| Arming with keys | 1, 2 and 3 armed each ability: toast, coloured ARMED slot, recharge shown on the slot. |
| Slow-Mo dunk | A press 0.15 s late graded **Good** (normally Late). The drop took 0.47 s instead of ~0.31 s. Disarmed after the dunk. |
| Fireball + Hang Time dunk | **$5,821** = 2 × $2,911. **3 air tricks** (1 + 2 bonus) paid $130 over a 1.51 s drop. Flaming ball and a fire burst at the rim. Both disarmed. |
| Save | After Stop/Play, levels were still Slow-Mo L2, Fireball L1, Hang Time L1. |
| Server checks | "Already armed", "Already unlocked" and the Hang Time L2 upgrade (−$25,000) all answered correctly; bad actions and unknown ids were ignored. |

**Not tested:**
- The layout on a real phone. The hotbar sits at the right edge, below the touch menu and above the jump button.
- What other players see (auras and fire burst), which needs a second player.
