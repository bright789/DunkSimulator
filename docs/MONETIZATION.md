# Robux Game Passes and Developer Products

Every offer below is created on Roblox, on sale, and has its id in `src/shared/Config/MonetizationConfig.luau` (live state checked 2026-10-03). While an id is `0`, the Locker's **PASSES** tab shows that offer as COMING SOON and no purchase prompt can open.

## The offers

| Offer | Type | What the player gets | Suggested price |
| --- | --- | --- | --- |
| **2x Cash** (`DoubleCash`) | Game pass | Dunk and air-trick Cash ×2 forever. Stacks with court, Rebirth, shoe and Cash Boost bonuses. | 249 R$ |
| **VIP** (`VIP`) | Game pass | **Diamond Kicks** (+20% air-trick Cash, glowing) and the **Diamond** ball in the Locker, plus a gold VIP tag over your head that everyone sees. | 149 R$ |
| **2x Daily Rewards** (`DoubleDaily`) | Game pass | Daily login rewards and daily challenge rewards pay ×2. The daily panel shows the doubled amounts. | 99 R$ |
| **Cash Boost** (`CashBoost`) | Developer product (repeatable) | 15 minutes of 2x Cash, stacking up to 60 minutes. Uses the same boost as the daily rewards. | 25 R$ |
| **x2 / x4 / x7 Reward** (`PayoutX2`, `PayoutX4`, `PayoutX7`) | Developer products (repeatable), hidden from the Locker | Multiplies the payout you just got (contest prize, Golden Ball or big dunk) by 2, 4 or 7. Only sold from the "Boost that payout!" card. | 12 / 39 / 99 R$ |
| **Cash Stack** (`CashPackSmall`) | Developer product (repeatable) | Cash worth 150 dunks at your Vertical. | 29 R$ |
| **Cash Vault** (`CashPackLarge`) | Developer product (repeatable) | Cash worth 1,000 dunks at your Vertical. | 149 R$ |

"2x Daily Rewards" replaces the earlier "second daily claim" idea. It gives the same value without adding more saved data.

## Current status

| Offer | Roblox id | Status |
| --- | --- | --- |
| Starter Pack (game pass) | 1999707117 | **On sale at 49 R$.** |
| Auto Train (game pass) | 1999335123 | **On sale at 199 R$.** |
| 2x Cash (game pass) | 1999521068 | **On sale at 249 R$.** |
| VIP (game pass) | 1999029049 | **On sale at 199 R$.** |
| 2x Daily Rewards (game pass) | 1998489062 | **On sale at 149 R$.** |
| Dunk Pass: Season 1 (game pass) | 1998615194 | **On sale at 299 R$** since 2026-09-28, but its id only reached the config on 2026-10-03, so until that publish the in-game screen said "PASS COMING SOON". Pass 2006397014 ("Unused duplicate") was created by mistake; keep it off sale. |
| Cash Boost (developer product) | 3715129560 | **On sale at 25 R$.** Tested end to end with a free Studio test purchase: the receipt was recorded, the boost applied (HUD `2x CASH 14:5x`), and the save was confirmed before Roblox showed "Purchase completed". The game pass 1999779066 of the same name was a mistake; keep it off sale. |
| x2 Reward (`PayoutX2`, developer product) | 3716333601 | **On sale at 12 R$.** The payout card stays off if any Reward product id is 0. |
| x4 Reward (`PayoutX4`, developer product) | 3716334299 | **On sale at 39 R$.** |
| x7 Reward (`PayoutX7`, developer product) | 3716334447 | **On sale at 99 R$.** |
| Cash Stack (`CashPackSmall`, developer product) | 3716334976 | **On sale at 29 R$.** |
| Cash Vault (`CashPackLarge`, developer product) | 3716335075 | **On sale at 149 R$.** |

Roblox's text filter rejects the word "Payout" in product names and descriptions, so the products are named **x2 Reward**, **x4 Reward** and **x7 Reward** ("Doubles / Quadruples / Multiplies by 7 the Cash you just won from a contest, a Golden Ball or a big dunk."). The config Keys stay `PayoutX2/X4/X7`, and the in-game card still says "BOOST THAT PAYOUT!".

**Tested in Studio (2026-10-03, QA profile at 350 Vertical, free Studio test purchases):**
- A $10,584 contest payout showed the card bottom-right: "BOOST THAT PAYOUT! Contest prize: $10,584. Make it $21,168 with x2!" with live prices R$12 / R$39 / R$99. Analytics logged `PayoutOfferShown_Contest`.
- Buying x2 Reward paid exactly +$10,584 (economy event `IAP` / `PayoutX2`, `PayoutBoost 2`), and the save was confirmed before "Purchase completed".
- After the 2-minute cooldown, a $17,640 Golden Ball payout showed the card again. Its own **x4** button opened the x4 Reward prompt, and buying it paid exactly +$52,920 (3 x $17,640).
- The PASSES tab hid the Reward products and showed Cash Stack (R$29, "Right now: $132,300.") and Cash Vault (R$149, "Right now: $882,000."). Buying Cash Stack paid exactly +$132,300.
- Dunk Pass showed OWNED (the creator owns every pass). No script errors.
- The payout was triggered with a temporary Studio-only BindableFunction, removed afterwards. Natural contest, Golden Ball and big-dunk triggers weren't separately played through.

Passes that exist but aren't for sale show **OFF SALE** in the PASSES tab. The experience's creator automatically owns every pass they made, so the creator's own sessions have all pass effects (verified: all three showed OWNED). To balance without them, test with Studio's Server & Clients players or an alt account.

## Icons

Ready-made 512×512 PNG icons are in `assets/pass-icons/`:
- `2x-cash.png`
- `vip.png`
- `2x-daily-rewards.png`
- `cash-boost-15min.png`
- `auto-train.png`, `starter-pack.png`
- `lucky-packs.png`, `triple-open.png`, `crew-slot.png` (Hype Crew passes, see `HYPE_CREW.md`)
- `dunk-pass-s1.png` (Dunk Pass: Season 1, see `DUNK_PASS.md`)
- `payout-x2.png`, `payout-x4.png`, `payout-x7.png` (x2 / x4 / x7 Reward), `cash-stack.png`, `cash-vault.png` (Cash packs)

They're drawn in the game's style (FredokaOne text, gold rim, sunburst) with everything important inside the circle, because Roblox shows pass icons cropped to a circle. Regenerate them with `powershell -ExecutionPolicy Bypass -File tools/pass-icons.ps1`. The script uses Windows' built-in System.Drawing and the FredokaOne font from your Roblox Studio install.

## How to put them on sale

1. Open the [Creator Hub](https://create.roblox.com/dashboard/creations) and go to your experience, then **Monetization → Passes**. Create **2x Cash**, **VIP** and **2x Daily Rewards**, uploading the matching icon from `assets/pass-icons/`, and give each a description and price. Set them **On Sale**.
2. Go to **Monetization → Developer Products** and create **Cash Boost** with `cash-boost-15min.png` and a price. Create **x2 Reward**, **x4 Reward**, **x7 Reward**, **Cash Stack** and **Cash Vault** the same way (names and descriptions are in `MonetizationConfig`; don't use the word "Payout", Roblox's filter rejects it).
3. Copy each id into `MonetizationConfig.luau` (`Passes[...].Id` and `Products[...].Id`). The game reads the live Robux prices from Roblox.
4. Sync, then **Save to Roblox** and publish. Test purchases in Studio are free test transactions.

## "Boost that payout!" offer

A cheap, in-the-moment first purchase. Right after a worthwhile lump payout, a small card offers to multiply it: **x2 / x4 / x7 for 12 / 39 / 99 R$** (live prices from Roblox once the products exist). Tuning is `MonetizationConfig.PayoutOffer`.

- **Triggers** (each reports the Cash just paid to `PayoutOfferService.OnPayout`):
  - **Contest prize**: at the buzzer, when a prize above $0 was paid (`ContestService`).
  - **Golden Ball**: when you grab it (`PickupService`). Cash bills don't count.
  - **Big dunk** (`DunkService`): the dunk's Cash plus its air-trick Cash, but only for a **Fireball** dunk or a **new personal-best** dunk payout (the `BestDunkCash` leaderboard stat went up). Ordinary dunks are never reported, so they can't trigger a card or replace a bigger payout that is waiting to be boosted.
- **When the card shows** (all must be true):
  - all three Reward products have a non-zero id;
  - the payout is at least `MinDunks` (3) plain dunks: `3 x DailyConfig.DunkValue(your Vertical)`;
  - at least `CooldownSeconds` (120) since your last card;
  - the new-player tutorial is finished (`MilestoneConfig.TutorialActive`, the same rule the tutorial and onboarding funnel use).
- **The card** stays up `OfferSeconds` (8), a new offer replaces it, and X closes it. A button opens Roblox's purchase prompt and hides the card. On touch screens the card also steps aside (or isn't shown) while a dunk runs or you train, because it shares the bottom of the screen with the slam meter and the training ring.
- **What a boost pays**: `(multiplier - 1) x` your remembered payout, if it is at most `WindowSeconds` (300) old and hasn't been boosted yet. Otherwise it pays `(multiplier - 1) x FallbackDunks (10) x DunkValue`. Each payout can be boosted once.
- **Which payout is remembered**: every reported payout, even when no card shows (cooldown, small payout, tutorial), except that a smaller payout never replaces a bigger one that can still be boosted. That way a boost is never smaller than the card on screen promised.
- **Cash limit**: the bonus is cut to whatever fits under the Cash limit (possibly $0), so a maxed-out player's receipt never retries forever.
- **Retries**: if paying or saving fails, the receipt claim is released and Roblox retries later. The remembered payout is already marked boosted by then, so a retried boost pays the `FallbackDunks` amount instead.
- After the save is confirmed, the buyer sees "x4 PAYOUT!  +$3,720" in the middle of the screen.

### Where the card sits

- **Keyboard/mouse**: the bottom-right corner. The ability hotbar is above it (right edge, centred at 52% height) and the bottom-centre column (action feed, slam meter, training ring, contest results, all at most 400 px wide) is to its left. On small windows a UIScale shrinks it so both gaps hold.
- **Touch**: the bottom edge between Roblox's thumbstick area (left 40%) and the jump / DUNK buttons. The touch menu and ability row are higher up on the right. It's shrunk to fit that gap.
- It is drawn above the HUD and contest results but below full-screen menus. On phones it can cover the bottom of the contest results podium for a few seconds.

## Cash packs

**Cash Stack** (150 dunks) and **Cash Vault** (1,000 dunks) pay `PackDunks x DailyConfig.DunkValue(your Vertical)` Cash, so they're worth the same number of dunks at every stage of the game. They're listed in the Locker's PASSES tab, and their Locker card shows what the pack is worth right now (e.g. "Right now: $18,500."). The Cash is cut to fit under the Cash limit. After the save is confirmed the buyer sees "+$18,500 CASH!".

## Paid random items (Hype Crew packs, 2026-10-03)

Because Cash can be bought with Robux (Cash Stack/Vault, payout boosts, Starter Pack) and Hype Crew packs cost Cash, packs are **paid random items** ([Roblox rules](https://create.roblox.com/docs/production/monetization/paid-random-items)). Details in `HYPE_CREW.md`; in short:
- **Odds shown = odds rolled.** `CrewConfig.Odds` is used by both the server roll and the PACKS page. Lucky Packs owners see their boosted odds labelled **LUCKY ODDS**.
- **Restricted regions** (`PolicyService` `ArePaidRandomItemsRestricted`, checked on the server, cached per player, a failed lookup counts as restricted): opening packs is refused ("Hype Crew packs aren't available in your region."), the 30-minute playtime gift pays the pack's price as Cash instead, the PACKS page shows NOT AVAILABLE, and the **Lucky Packs** and **Triple Open** passes are hidden in the PASSES tab (`PackPass = true`). The server publishes the answer as the `PacksRestricted` player attribute for the client.
- Dunk Pass rewards and codes are not purchases of random items and are unchanged.

## How it works (server-authoritative)

- **Ownership:** `MonetizationService` checks each pass with `MarketplaceService:UserOwnsGamePassAsync` when a player's data is ready (retrying up to 3 times). After an in-game purchase it applies the pass immediately using Roblox's `PromptGamePassPurchaseFinished` result; the next join re-checks. Ownership lives in PlayerService (not saved) and is mirrored to `Pass_<Key>` attributes for the UI.
- **Pass effects:**
  - `PlayerService.RegisterDunk` and `AwardDunkTrick` apply `DoubleCashMultiplier` for 2x Cash.
  - `DailyService` doubles login and challenge payouts (and the amounts shown) for 2x Daily Rewards.
  - For VIP, `LockerService.GrantPassItems` adds the Diamond items to the saved Locker (they stay owned), and a server-made BillboardGui "VIP" tag is added to the head on every spawn.
  - Locker items with `Pass = "VIP"` can never be bought with Cash. Their button reads "VIP PASS" and opens the pass prompt.
- **Developer products:** `ProcessReceipt` first claims the `PurchaseId` in a receipts DataStore (`DunkSimulator_Receipts_v1`; Studio uses `..._DEV_v1`) with `UpdateAsync`.
  - A receipt that was already claimed is acknowledged without paying again.
  - If the player isn't in the server, isn't loaded, or the grant fails, the claim is released and Roblox retries later (`NotProcessedYet`).
  - Products: `CashBoost` -> `DailyService.GrantBoost`; `PayoutX*` -> `PayoutOfferService.Grant(player, Multiplier)`; `CashPack*` -> `PlayerService.GrantCash` with `PackDunks x DunkValue` (analytics transaction type `IAP`, sku = the product Key).
  - The purchase is only acknowledged (`PurchaseGranted`) after `DataService.SaveNowAsync` confirms the player's save with the boost in it. If that save fails, the claim is released so Roblox retries. In that rare case a player could get an extra boost, but never lose a paid one.
  - Only after that confirmed save does the buyer's client get `PayoutOffer("Boosted", { Multiplier, Bonus })` or `PayoutOffer("CashPack", { Cash, Key })` for the celebration.
- **PayoutOffer remote** (server -> client only; there is no server listener): `("Offer", { Amount, Source })` with Source `"Contest"`, `"GoldenBall"` or `"Dunk"`, plus the two purchase celebrations above.
- **Analytics** (custom events): `PayoutOfferShown_Contest` / `_GoldenBall` / `_Dunk` (value 1) when a card is shown, and `PayoutBoost` (value = the multiplier) when a boost is paid. Pack and boost Cash also appear in the economy events as `IAP` with skus `CashPackSmall`, `CashPackLarge`, `PayoutX2`, `PayoutX4`, `PayoutX7`.
- **Clients:** they only open Roblox's own purchase prompt (`PromptGamePassPurchase` / `PromptProductPurchase`). Nothing a client sends can grant anything.

## Testing in Studio before the passes exist

Set `StudioOwnedPasses = { "DoubleCash", "VIP", "DoubleDaily" }` in `MonetizationConfig` to pretend you own them. The setting is ignored on live servers. **Put it back to `{}` afterwards.** Tested this way against the QA store:

- The VIP tag appeared. Diamond Kicks and the Diamond ball were granted and equippable, with a white sneaker, glowing sole and glowing white ball.
- The daily ladder showed doubled values, and the Day 2 claim paid $3,240 instead of $1,620.
- A College Windmill paid $1,296 instead of $648.
- The PASSES tab showed OWNED for all three passes and COMING SOON for Cash Boost.
- With the setting cleared, all four offers showed COMING SOON.
- No errors on the client or server.

With the real ids, Studio showed the live price (R$ 25), and a test purchase of Cash Boost completed successfully. Pass prompts will show once the passes are on sale.

## Files

Payout offer and Cash packs (2026-10-03):

- **New:**
  - `src/server/services/PayoutOfferService.luau` (offer rules, remembered payouts, `Grant`)
  - `src/client/PayoutOfferController.luau` and `src/client/ui/PayoutOfferView.luau` (the card and celebrations)
- **Changed:**
  - `MonetizationConfig`: the five products, `PayoutOffer` tuning, `PayoutProducts()`
  - `MonetizationService`: `PayoutX*` and `CashPack*` receipts, celebration after the confirmed save
  - `ContestService`, `PickupService`, `DunkService`: report payouts to `PayoutOfferService`
  - `LockerView` and `LockerController`: skip `Hidden` products, show Cash pack values
  - `HUDController` (starts the controller), `ServerMain` (starts the service)
  - `default.project.json`: `PayoutOffer` RemoteEvent

Original passes and Cash Boost:

- **New:**
  - `src/shared/Config/MonetizationConfig.luau`
  - `src/server/services/MonetizationService.luau`
- **Changed:**
  - `PlayerService`: `SetPasses`, `HasPass`, 2x Cash
  - `DailyService`: 2x Daily, `GrantBoost`, `Refresh`
  - `LockerConfig`: Diamond items
  - `LockerService`: `GrantPassItems`, pass items can't be bought with Cash
  - `LockerView` and `LockerController`: PASSES tab and prompts
  - `DataConfig`: receipt store names
  - `ServerMain`
