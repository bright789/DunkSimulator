# Launch check (2026-09-27, before the first ad campaign)

## Server settings (Creator Hub, done by the owner)

| Setting | Was | Should be | Where |
| --- | --- | --- | --- |
| Max players per server | 50 | **12–16** | Creations → Dunk Simulator → Places → (start place) → Access → Maximum Visitor Count |
| Private servers | Off | **On** (free, or ~25 R$) | Creations → Dunk Simulator → Audience → Access Settings → Allow private servers |

Why:
- Each court has **one hoop and one ball station**, so 50 players on the Neighborhood court would be a crowd around a single rim.
- Phones also have to draw every nearby player's dunk effects, auras and crew cards.
- Private servers let friends and YouTubers play together.

## 3-player test (Studio "Server & Clients", QA store `DunkSimulator_PlayerData_QA_MP1_v1`)

Three test players (UserIds -1, -2, -3) were seeded with $500,000, 150 Vertical, High School unlocked, all three abilities, and different Hype Crews.

| Check | Result |
| --- | --- |
| Other players' crew cards | All 8 cards (3 + 3 + 2) show beside their owners on every screen. |
| Seeded saves (v13) | Loaded with the right Cash, Vertical, abilities and crew. |
| Golden Ball race | Seen by everyone. The first player to reach it got 8 dunks' worth ($2,288 at 150 Vertical). The other players were told "Player2 grabbed the Golden Ball!" (`GoldenGrab`, `isYou = false`), and the next ball was announced to all. |
| PERFECT label and VFX over another player | A watching player saw "PERFECT!" over the dunker, the court-coloured floor ring and the burst. |
| Both players pay correctly | Perfect $781 (with Perfect grade), Good $342 / $406 (Good grade). |
| Server load | 3 players dunking: the worst server frame was 20 ms (fine). The clients ran at ~15 FPS only because 3 clients + a server + Studio shared one PC. |

### Two players dunking at the same moment

When two players jumped and pressed DUNK in the same instant on the same hoop, one of them was often refused with "Jump first, then dunk while airborne." (4 of 5 tries).
- **Server logs:** the refused player's jump never reached the server in time. Its state flipped to Freefall, but its position stayed on the ground, while its own screen showed the jump.
- **Solo and not-at-once dunks** always worked, from the same spots.
- **No dunk code touches another player's character**, so this looks like the one-PC test setup delaying that client's movement updates. It can't be fully ruled out live, though.

Changes made because of it:
- **Longer takeoff wait:** `DunkConfig.DunkTakeoffGraceSeconds` 0.35 → **0.8 s**. `DunkService` now keeps waiting that long for the jump to reach the server. It still only starts a dunk once the server itself sees the player airborne, so cheating isn't any easier. This also helps real players on laggy phones.
- **Refusal analytics:** every refused dunk now logs a custom analytics event **`DunkRejected_<REASON>`** (e.g. `DunkRejected_NOT_AIRBORNE`, `DunkRejected_TOO_FAR`, `DunkRejected_NO_BALL`). After the ads, check Creator Hub → Analytics → Custom events. Lots of `NOT_AIRBORNE` would mean real players hit this.

## Small fix

- **Goal bar:** a goal with no numbers ("MAXED HERE! TRAIN AT HIGH SCHOOL GYM") now uses the whole bar instead of wrapping onto two lines.
