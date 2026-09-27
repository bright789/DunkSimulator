# Locker: Shoes and Ball Skins

Collectibles bought with Cash from the **LOCKER** button on the HUD, next to DAILY. Purchases are permanent and survive Rebirth.

## Shoes

Sneakers are built on your character's feet (sole, upper, toe cap, side stripe and heel tab), so everyone in the server sees them. Each pair adds a small bonus to **air-trick Cash**.

| Shoes | Price | Air-trick Cash |
| --- | --- | --- |
| Classic Lows (white) | free | — |
| Court Kings (red) | $1,000 | +5% |
| Sky Risers (sky blue, gold stripe) | $7,500 | +10% |
| Rim Rattlers (orange, black sole) | $30,000 | +15% |
| Cloud Nines (white, glowing blue sole) | $90,000 | +20% |
| Galaxy Jets (purple, glowing cyan stripe) | $250,000 | +25% |

The bonus multiplies with the court, Rebirth and Cash Boost bonuses inside `PlayerService.AwardDunkTrick`. Example at College with 1 rebirth: a first-trick Spin720 pays $29 in Classic Lows and $33 in Rim Rattlers.

**VIP pass exclusive:** Diamond Kicks (white with a glowing blue sole, +20% air-trick Cash). It's unlocked by the VIP game pass and can't be bought with Cash; see `MONETIZATION.md`.

## Ball skins (cosmetic)

The ball's color, material, seams and slam-trail color and length. Everyone sees the skin: each client's ball renderer reads the owner's `BallSkin` attribute.

| Ball | Price | Look |
| --- | --- | --- |
| Classic | free | orange leather, dark seams, short warm trail |
| Street Black | $1,500 | black leather, orange seams and trail |
| Ice Cold | $8,000 | pale blue, white seams, blue trail |
| Gold Rush | $25,000 | gold foil, bronze seams, gold trail |
| Galaxy | $90,000 | deep purple, glowing pink seams, long purple trail |
| Lava | $200,000 | dark basalt, glowing orange seams, long fire trail |

**VIP pass exclusive:** Diamond, a pale foil ball with glowing white seams and a long ice-blue trail.

## How it works

- **LockerService (server):**
  - The client can only send `LockerRequest("Read")`, `("Buy", kind, id)` or `("Equip", kind, id)`, with kind `Shoes` or `Balls`.
  - Unknown ids, extra arguments, repeat requests inside the 0.3 s cooldown and overlapping requests are ignored.
  - **Buy** spends the configured price through `PlayerService.SpendCash` (refused if you can't afford it), marks the item owned, equips it and requests a save.
  - **Equip** requires the item to be owned.
- **Shoe parts:** non-colliding, non-queryable, massless parts welded to `LeftFoot`/`RightFoot`, in a `LockerShoes` folder on the character. They're rebuilt on every spawn and when the appearance finishes loading. Rigs without R15 feet are skipped.
- **Ball skins:** `BallPresentation` builds the visual ball from `LockerConfig.Balls[BallSkin]` and rebuilds it when the attribute changes.
- **Client:** `LockerController` and `LockerView` show a SHOES / BALLS tab grid with previews, bonuses and a BUY / EQUIP / EQUIPPED button per card. Prices you can't afford are dimmed, and your Cash stays live while the menu is open.

## Persistence (schema v10)

```lua
Locker = {
    Shoes = { Owned = { classic = true, rim_rattlers = true }, Equipped = "rim_rattlers" },
    Balls = { Owned = { classic = true, gold = true }, Equipped = "gold" },
}
```

- Migration v9 → v10 gives everyone the free Classic items.
- `LockerConfig.Sanitize` drops unknown items, always keeps Classic, and falls back to Classic if the equipped item isn't owned.
- The save writer copies `Locker` explicitly, and `SameProgress` compares it.
- Rebirth doesn't touch it.

## Files

- **New:**
  - `src/shared/Config/LockerConfig.luau`
  - `src/server/services/LockerService.luau`
  - `src/client/LockerController.luau`
  - `src/client/ui/LockerView.luau`
- **Changed:**
  - `PlayerService`: Locker state, `GetLocker`, `GetCash`, `SpendCash`, shoe bonus in trick Cash, `EquippedShoe`/`BallSkin` attributes
  - `PlayerDataSchema`, `PlayerDataStore`, and `DataConfig` (`SchemaVersion = 10`)
  - `BallPresentation`: skins
  - `HUDView`: LOCKER button
  - `HUDController`, `ServerMain`
  - `default.project.json`: `LockerRequest`, `LockerState`

## Acceptance tests (passed in Studio against the QA store)

1. A schema-9 profile loads as schema 10 with Classic shoes and ball, and the Classic sneakers appear on the feet.
2. Buying Rim Rattlers charged $30,000 and equipped them; orange sneakers appeared.
3. Buying Gold Rush charged $25,000 and turned the dribbled ball gold with bronze seams.
4. A dunk's trick payouts included the +15% shoe bonus: Spin720 #1 $33, Cartwheel #2 $24, BackFlip #3 $41.
5. Re-equipping the owned Classic Lows cost nothing.
6. The saved record had schema 10, both items owned, and the equipped choices.
7. No client or server errors.

8. **2-player test** (Studio "Server & Clients"):
   - Each client saw the other player's sneakers (10 welded parts) and ball skin.
   - In Player2's view, Player1 hung on the rim in glowing Galaxy Jets with the dark, glowing-seamed Lava ball, while Player2 had red Court Kings and the Ice ball.
   - No errors in either client.

Still worth checking: avatars with unusual foot sizes and the menu on a phone-sized screen.
