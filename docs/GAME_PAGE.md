# Game Page: Name, Genre, Description, Thumbnails, Icon

Everything needed to fill in the experience's public page before switching it from private to public.

## Name

Use **Dunk Simulator**. The place is currently called "Dunk Simulator — Dev", so drop "— Dev" before going public.

## Genre

**Simulation → Incremental Simulator.** The core loop fits it: train a stat (Vertical), earn Cash, unlock courts and styles, then Rebirth. The "Simulator" name also matches what players browse for.

The runner-up is **Sports & Racing → Sports**. It has fewer games competing in its charts, but its players expect competitive sports gameplay rather than a progression loop.

Roblox only allows a genre change **once every three months**, so pick once.

## Description

The text below is 831 characters, under Roblox's 1000-character limit. Every claim matches the current build: Vertical runs 30 → 250, there are 4 styles and 3 courts, the contest runs every 8 minutes with prizes for the top 3, and the three leaderboard names are the real ones.

```
🏀 Train your Vertical, jump to the roof and throw down monster slams! 🏀

⬆️ TRAIN – Work out to grow your Vertical from 30 all the way to 250.
💥 DUNK – Jump at the rim and slam it! Nail the timing for a PERFECT dunk and land air tricks for bonus Cash.
🔥 4 DUNK STYLES – One-Hand, Two-Hand Power, Tomahawk and Windmill.
🏟️ 3 COURTS – Rise from the Neighborhood to the High School gym to the packed College Arena. Bigger courts, bigger Cash!
🏆 DUNK CONTESTS – Every 8 minutes the judges score the best dunk in the server. Place top 3 for big prizes!
📅 DAILY REWARDS – Login streaks, 3 daily challenges and 2x Cash boosts.
👟 LOCKER – Collect rare shoes and ball skins.
🔁 REBIRTH – Start over with a permanent Cash multiplier.
📊 LEADERBOARDS – Top Vertical, Most Dunks and Biggest Dunk.

👍 Like and ⭐ Favorite for new courts and dunks!
```

## Thumbnails and icon

The files are in `assets/thumbnails/`. Thumbnails are 1920×1080 (16:9); the icon is 512×512. Upload the thumbnails in this order, because the first one is what most players see:

| # | File | Hook |
| --- | --- | --- |
| 1 | `thumbnail-1-dunk.png` | A Windmill poster dunk in the College Arena with "DUNK SIMULATOR", "PERFECT!" and "+$1,296" (a real College Windmill payout). |
| 2 | `thumbnail-2-vertical.png` | "JUMP TO THE ROOF!" A big jumper over the arena's vertical-meter lines with a "250 VERTICAL" badge. |
| 3 | `thumbnail-3-courts.png` | "UNLOCK NEW COURTS!" Neighborhood → High School → College panels. |
| Icon | `icon-512.png` | The Tomahawk jumper on a pink/purple sunburst with "DUNK SIM". |

How they were made:
- All game footage is real in-engine Studio footage, captured at 4K in Play mode with the HUD hidden.
- The dunk poses are frames of the game's own dunk animations, frozen on an anchored character.
- The large character in #2 and on the icon was shot against a local green screen and cut out.
- The text uses the game's FredokaOne font.
- Nothing shown is fake. The College Arena, meter lines, banners, crowd and leaderboards are all in the map.

## Before switching to public

1. ~~Phones and controllers can't start a dunk.~~ **Fixed** (see Controls below).
2. Put the three passes on sale with prices. Keep the duplicate "Cash Boost" game pass 1999779066 off sale (see `MONETIZATION.md`).
3. Rename the place and experience (see Name above), then set the genre and description and upload the thumbnails and icon in the Creator Hub.
4. Save to Roblox and publish, then switch the experience to public.
5. ~~Phone HUD covers the thumbstick area.~~ **Fixed:** touch devices get the menu buttons top-right, and phones get a compact stats block top-left (see `CUSTOM_HUD.md`).
6. ~~Dunk pressed right after jumping can cancel or say "Jump first".~~ **Fixed and tested:** presses from 0 to 0.3 s after the jump all complete (see `DUNK_EXECUTION.md`).

## Controls (all devices)

| Device | Dunk | Slam timing (during the meter) |
| --- | --- | --- |
| Keyboard | **F** | F, or click the meter |
| Gamepad | **RT** (R2) | RT |
| Touch | The round **DUNK** button left of the jump button | The same button, now reading **SLAM!**, or tap the meter |

- **How it works:**
  - `DunkController` binds one ContextActionService action ("Dunk") to F and ButtonR2.
  - It shows `DunkView`'s touch button when the last input was touch.
  - Both only exist while you hold a ball or the slam meter is running, so F and RT aren't swallowed at other times.
  - Gamepad X is left free because ProximityPrompts (pickup, upgrade stations, portals) use it.
- **Hint:** the "F DUNK" hint shows RT on a gamepad and is hidden on touch, where the button replaces it.
- **Server messages:** these are now device-neutral ("Jump first, then dunk while airborne.").
- **Tested in Studio against the QA store:**
  - Keyboard: a real F press completed a College Windmill.
  - Controller Emulator: A to jump, then RT at height 175, completed a Windmill.
  - Device Emulator (iPhone XR):
    - The DUNK button showed beside the jump button.
    - Tapping it on the ground returned "Jump first".
    - Jump plus a DUNK tap completed a Windmill with air tricks.
    - The button switched to SLAM!, and tapping it registered a timing rating.
