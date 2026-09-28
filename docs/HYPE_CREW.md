# Hype Crew, welcome-back earnings and the phone pass (2026-09-27)

Three changes, built in this order.

## 1. Phone pass

Tested on the Studio Device Emulator as an iPhone 14 (844×390) and an iPhone 7 (667×375).

| Problem | Fix |
| --- | --- |
| Ability slots sat on top of the jump button | On touch screens the slots are a row just under the menu buttons (top right). The row follows the menu's height. |
| Training ring was too big: it covered the player and its caption ran into the goal bar | On touch the ring is 70% size at the very bottom. |
| Goal bar title ran into its progress text ("TWO-HAND PO39/50") | The title and the progress each get their own part of the bar. |
| Action feed sat on top of the goal/HEAT bars | On phones the feed is smaller (72%, max 3 lines) on the left, under the stats. |
| HEAT pill covered the dunk result popup | On touch it hides during a dunk. |
| Ability slots drew over the Daily popup; the ABILITIES panel drew under the contest banner | The slots stay on the HUD layer; the panel is on the menus' layer (like Codes and Daily). |
| Tutorial said "Hold E" / "press E" on phones | Touch versions: "Hold the Leg Day Gym button (tap PUMP on the beat for 3x reps!)" and "…tap the button". |

## 2. Welcome-back earnings

While you're away, your fans keep earning.
- **How much:** each hour away pays **10 dunks' worth of Cash** (`DailyConfig.DunkValue` at your Vertical × your Rebirth Cash bonus), up to **8 hours**.
- **VIP pass:** doubles it.
- **Short breaks:** under 15 minutes pay nothing.
- **Pop-up:** once you've spawned in, "WELCOME BACK / YOUR FANS EARNED $X / You were away 3h 0m. VIP doubled it!" (or "VIP players get 2x!"). It stays up 4.5 s.

**How it works:**
- Save format **v13** adds `LastOnline`, and every save writes the current time.
- On join, `WelcomeBackService` pays for the time since the last save, then requests a save, so the same time away can't pay twice.
- Old profiles start at 0 (no payout on the first join after the update).
- Numbers: `WelcomeBackConfig`. `StudioPretendAwaySeconds` (Studio only) fakes an absence for testing; **keep it 0**.

## 3. Hype Crew (collectible packs)

**HYPE CREW** is a new full-width menu button.

**PACKS page.** One pack per court, with its odds:

| Pack | Court | Price | Odds |
| --- | --- | --- | --- |
| Street | Neighborhood | $500 | Common 60 / Uncommon 30 / Rare 10 |
| Varsity | High School | $5,000 | Common 35 / Uncommon 35 / Rare 24 / Epic 6 |
| Campus | College | $40,000 | Uncommon 35 / Rare 38 / Epic 22 / Legendary 5 |
| Skyline | Rooftop | $200,000 | Rare 45 / Epic 40 / Legendary 15 |

**Opening a pack.** A card flips to reveal who you got:
- **NEW CREW MEMBER!**: new members join your crew automatically if you have a free slot.
- **STAR UP!**: a copy of someone you already have adds a star.
- **MAXED**: a copy past 5 stars refunds 25% of the pack price.
- Epic and Legendary pulls get a bigger sound; a Legendary is announced in the middle of the screen.

**Crew bonuses.** 20 members (5 per pack), each giving **+% dunk and air-trick Cash** or **+% Vertical per training rep**:

| Rarity | Common | Uncommon | Rare | Epic | Legendary |
| --- | --- | --- | --- | --- | --- |
| Bonus at 1 star | 4% | 7% | 12% | 20% | 35% |

- Each extra star adds 25% of the base bonus, so 5 stars = 2×.
- **3 equipped slots** (4 with a pass).
- Owning a pack's whole set gives a permanent **+5% Cash**.
- Crew bonuses stack with everything else.

**MY CREW page** (the collection book):
- Owned members show stars, bonus and EQUIP / UNEQUIP.
- Members you haven't found show "???" with their rarity and pack.
- The header shows the total crew bonus and slots.

**Followers.** Equipped members float beside you as little rarity-coloured cards that everyone can see (drawn on each screen, within 150 studs).

**Robux passes** (ids in `MonetizationConfig`; each must be set **On Sale** with a price in the Creator Hub). Icons: `assets/pass-icons/lucky-packs.png`, `triple-open.png`, `crew-slot.png` (made by `tools/pass-icons.ps1`):

| Pass | Suggested price | Effect |
| --- | --- | --- |
| Lucky Packs (`CrewLucky`, 1998015188) | 199 R$ | Epic and Legendary weights ×2 |
| Triple Open (`CrewTriple`, 1998099184) | 99 R$ | OPEN ×3 button |
| +1 Crew Slot (`CrewSlot`, 1998489170) | 149 R$ | 4 equipped instead of 3 |

**How it works:**
- Save format **v13** adds `Crew = { Owned = { id = stars }, Equipped = { ids } }`, saved and restored like every other field.
- `CrewService` is the only writer. It handles `CrewRequest("Buy", pack, 1|3)`, `("Equip"|"Unequip", id)`, and checks the court is unlocked, Cash, passes and the slot count.
- Results come back as `("Opened", pack, results)`.
- The crew is mirrored for the HUD and followers as `CrewOwned`, `CrewEquipped`, `CrewSlots`, `CrewCash` and `CrewTrain`.
- `PlayerService` multiplies the crew's Cash bonus into dunks and air tricks, and the Train bonus into every rep (station, rhythm and Auto Train).
- **Numbers:** `CrewConfig`. **Code:** `CrewService`, `CrewController`, `ui/CrewView`, `CrewFollowers`.

## Tested in Studio (fresh QA stores)

| Test | Result |
| --- | --- |
| Phone layouts | iPhone 14 and iPhone 7: HUD, ability row, goal/HEAT bars, feed, training ring, dunk meter, DUNK button, Daily popup, ABILITIES panel and HYPE CREW menu all fit with no overlaps. |
| Welcome back | Pretend 3 h away paid **$1,200**, then **$1,380** at a higher Vertical (3 h × 10 dunks × dunk value × 2 VIP). The pop-up read "YOUR FANS EARNED $1,380 / You were away 3h 0m. VIP doubled it!" |
| Packs | 6 Street packs cost exactly $3,000 and gave 4 new members plus star-ups (Ball Boy ★3, Corner Fan ★2). The first 3 were auto-equipped. Varsity without High School: "Unlock that court first." OPEN ×3 without the pass was refused. |
| Bonuses | +7% Cash / +13% Training matched the config exactly. After swapping Ball Boy for Corner Fan: +12% / +7%. A Basic dunk paid **$71** ($20 × 2 × 1.1 × **1.12** × 1.44; $63 without the crew). |
| Saving | After Stop/Play: same members, stars and equipped crew. |
| Reveal and followers | The flip reveal queues one card at a time (tap to continue). Follower cards float beside the player without blocking the camera. |

**Not tested:**
- Other players seeing your crew (needs two players).
- Buying the three passes live (ids added 2026-09-27; they need to be put on sale first).
