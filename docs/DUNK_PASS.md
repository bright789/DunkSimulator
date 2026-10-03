# Premium perk and Dunk Pass (2026-09-27)

## Roblox Premium perk

- **Bonus:** Roblox Premium members earn **+10% dunk and air-trick Cash** (`SocialConfig.PremiumBonus`).
- **HUD:** members see **⭐ PREMIUM BONUS +10%**. Everyone else sees **⭐ PREMIUM: +10% CASH**, which opens Roblox's Premium offer.
- **Why it's worth it:** Roblox pays you more the longer Premium members play (Premium Payouts), so perks that keep them around earn Robux without a sale.
- **How it works:** `PremiumService` checks membership on join and on `Players.PlayerMembershipChanged` (someone subscribing mid-game), then publishes the `Premium` attribute. It multiplies into the same Cash formula as the group and friend bonuses; nothing is saved.
- **Studio only:** `SocialConfig.StudioPretendPremium` fakes membership. **Keep it false.**

## Dunk Pass (Season 1: Launch Season)

A 30-tier season track. Opened from the **DUNK PASS** button (next to HYPE CREW); the button shows how many rewards are ready, e.g. "DUNK PASS (3)".

### Earning XP

| Action | Pass XP |
| --- | --- |
| Any dunk | 4 |
| PERFECT slam / GOOD slam | +4 / +2 |
| Each air trick | +1 |
| PERFECT training rep | 1 |
| Grab the Golden Ball | 25 |
| Open a crew pack | 15 each |
| Claim a daily challenge | 50 |

- **Tiers:** tier 1 needs 100 XP, and each next tier needs 20 more (tier 30 ≈ 11,700 XP in total).
- **Feed:** XP shows in the action feed as "+N PASS XP", and a new tier announces "DUNK PASS TIER 8!".

### Rewards

Every tier has a **FREE** reward and a **PREMIUM** reward.
- **Cash:** "N dunks' worth" at your Vertical (`DailyConfig.DunkValue`).
- **Boosts:** minutes of 2x Cash, capped at 60 like every boost.
- **Crew packs:** a free pack from the best pack your courts have unlocked, with the usual card-flip reveal.
- **Season exclusives** (never sold for Cash):

| Reward | Track, tier | What |
| --- | --- | --- |
| Launch Day ball | Free 10 | orange ball with a white trail |
| Season Rookie | Free 30 | Epic crew, +training |
| Launch Jets | Premium 1 | glowing orange shoes, +20% trick Cash |
| Hype Man | Premium 10 | Epic crew, +Cash |
| Rocket ball | Premium 20 | chrome ball with glowing red seams |
| Launch Legend | Premium 30 | Legendary crew, +Cash |

The exclusives show "DUNK PASS" in the Locker until earned, and the Season crew don't appear in any pack.

### Buying the premium track

**Dunk Pass: Season 1** is a game pass (`MonetizationConfig` key `DunkPass`, suggested **299 R$**, icon `assets/pass-icons/dunk-pass-s1.png`). It is pass **1998615194**, on sale at 299 R$. Its id only reached the config on 2026-10-03, so until that publish the screen said "PASS COMING SOON" (it still does whenever the id is `0`). Premium tiers reached before buying can be claimed afterwards, so the pass never feels "too late" to buy.

### Seasons

- **Dates:** Season 1 runs **Mon 28 Sep → Mon 2 Nov 2026 (00:00 UTC)**. The header shows the countdown.
- **What resets:** a new season starts everyone at 0 XP with nothing claimed. Rewards already earned (shoes, balls, crew, Cash) stay.
- **Making Season 2:** add a new entry to `SeasonConfig.Seasons` with a new `Id`, dates, `PassKey`, and Free/Premium lists. Also create a new pass for it.
- **Between seasons:** the screen says "No season is running".

### How it works

**Code:**
- `SeasonXp`: adds XP; called by DunkService, TrainingService, PickupService, CrewService and DailyService.
- `SeasonService`: claims. `SeasonRequest("Claim", tier, "Free"|"Premium")` / `("ClaimAll")`. It checks the tier is reached, not already claimed and (for premium) that the pass is owned, marks it claimed *before* paying, and undoes that if paying fails.
- `CrewService.GrantPack` / `GrantMember`: the pack and member rewards.
- `LockerService.GrantItem`: shoes and balls.
- **Client:** `SeasonController` + `ui/SeasonView`.

**Saving:** save format **v14** adds `Season = { Id, Xp, Free = {tiers}, Premium = {tiers} }`. v13 profiles migrate with an empty record.

**Mirrors for the HUD:** `PassSeason`, `PassXp`, `PassFree`, `PassPremium`.

## Tested in Studio (fresh QA store, seeded at 1,500 XP = tier 8)

| Test | Result |
| --- | --- |
| Screen | Header "SEASON 1: LAUNCH SEASON • ENDS IN 34d 21h", tier-8 XP bar, 30 tier cards with icons, CLAIM ALL (8), "PASS COMING SOON". HUD button "DUNK PASS (8)". |
| Free claims | CLAIM ALL paid tiers 1–8 exactly: $2,288 + $3,432 + $4,290 (8/12/15 dunks × $286), 25 min boost, 3 crew packs (Hawk Mascot ×2, Cheer Captain). All marked ✓ and still ✓ after Stop/Play. |
| Premium claims | With the pass (Studio pretend), tiers 1–8 paid +$14,300 (50 dunks), boosts (capped at 60 min) and 3 packs, plus the **Launch Jets** now in the Locker. The crew reveal shows on top of the Dunk Pass screen (it was hidden behind it before the fix). |
| XP | A PERFECT dunk with one air trick: 1,500 → 1,509 XP (4 + 4 + 1). The feed showed "+9 PASS XP". |
| Premium perk | HUD "⭐ PREMIUM BONUS +10%". The dunk paid $2,569, exactly the formula with ×1.1 (it would be $2,336 without). |
| Locker | Launch Jets: EQUIP. Launch Day and Rocket balls: "DUNK PASS", not buyable. |

**Fixed after launch (v96):** on the live game the tier cards ran past the right edge of the Dunk Pass panel, and the scrollbar hung below it. A `UIScale` on the ScrollingFrame scaled the whole scroll area (1.2×), not just the cards. The cards now sit in a `Row` frame that gets the `UIScale`, and the scroll area stays 736×320 inside the 760×470 panel.

**Not tested:**
- Buying the real pass (it needs an id).
- A season change (only one season is defined).
