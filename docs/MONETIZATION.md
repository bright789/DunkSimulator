# Robux Game Passes and Developer Products

Everything is built and tested, but **nothing is on sale** until you create the passes on Roblox and paste their ids into `src/shared/Config/MonetizationConfig.luau`. While an id is `0`, the Locker's **PASSES** tab shows that offer as COMING SOON and no purchase prompt can open.

## The offers

| Offer | Type | What the player gets | Suggested price |
| --- | --- | --- | --- |
| **2x Cash** (`DoubleCash`) | Game pass | Dunk and air-trick Cash ×2 forever. Stacks with court, Rebirth, shoe and Cash Boost bonuses. | 249 R$ |
| **VIP** (`VIP`) | Game pass | **Diamond Kicks** (+20% air-trick Cash, glowing) and the **Diamond** ball in the Locker, plus a gold VIP tag over your head that everyone sees. | 149 R$ |
| **2x Daily Rewards** (`DoubleDaily`) | Game pass | Daily login rewards and daily challenge rewards pay ×2. The daily panel shows the doubled amounts. | 99 R$ |
| **Cash Boost** (`CashBoost`) | Developer product (repeatable) | 15 minutes of 2x Cash, stacking up to 60 minutes. Uses the same boost as the daily rewards. | 25 R$ |

"2x Daily Rewards" replaces the earlier "second daily claim" idea. It gives the same value without adding more saved data.

## Current status

| Offer | Roblox id | Status |
| --- | --- | --- |
| Starter Pack (game pass) | 1999707117 | Created, in config. Not on sale yet (no price; suggested 49 R$). |
| Auto Train (game pass) | 1999335123 | Created, in config. **On sale at 199 R$.** |
| 2x Cash (game pass) | 1999521068 | Created, in config. Not on sale yet (no price). |
| VIP (game pass) | 1999029049 | Created, in config. Not on sale yet. |
| 2x Daily Rewards (game pass) | 1998489062 | Created, in config. Not on sale yet. |
| Cash Boost (developer product) | 3715129560 | **On sale at 25 R$.** Tested end to end with a free Studio test purchase: the receipt was recorded, the boost applied (HUD `2x CASH 14:5x`), and the save was confirmed before Roblox showed "Purchase completed". The game pass 1999779066 of the same name was a mistake; keep it off sale. |

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

They're drawn in the game's style (FredokaOne text, gold rim, sunburst) with everything important inside the circle, because Roblox shows pass icons cropped to a circle. Regenerate them with `powershell -ExecutionPolicy Bypass -File tools/pass-icons.ps1`. The script uses Windows' built-in System.Drawing and the FredokaOne font from your Roblox Studio install.

## How to put them on sale

1. Open the [Creator Hub](https://create.roblox.com/dashboard/creations) and go to your experience, then **Monetization → Passes**. Create **2x Cash**, **VIP** and **2x Daily Rewards**, uploading the matching icon from `assets/pass-icons/`, and give each a description and price. Set them **On Sale**.
2. Go to **Monetization → Developer Products** and create **Cash Boost** with `cash-boost-15min.png` and a price.
3. Copy each id into `MonetizationConfig.luau` (`Passes[...].Id` and `Products[...].Id`). The game reads the live Robux prices from Roblox.
4. Sync, then **Save to Roblox** and publish. Test purchases in Studio are free test transactions.

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
  - The purchase is only acknowledged (`PurchaseGranted`) after `DataService.SaveNowAsync` confirms the player's save with the boost in it. If that save fails, the claim is released so Roblox retries. In that rare case a player could get an extra boost, but never lose a paid one.
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
