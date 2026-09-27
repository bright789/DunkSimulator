# Friend Invites, Music, Auto Train and Starter Pack

## Friend invites and friend bonus

**For players:**
- **INVITE** (fourth row of the HUD) opens Roblox's own friend-invite prompt with the message "Invite friends to dunk with you! You both get a 2x Cash Boost when they join."
- **Friend bonus:** every Roblox friend in the same server adds **+10% dunk and air-trick Cash**, up to **+30%**. The button shows it, for example "INVITE +20%".
- **Referral reward:** when a friend joins through your invite for the first time:
  - The friend gets a **15-minute 2x Cash Boost**.
  - You get **Cash worth 20 dunks** at your Vertical plus a **15-minute boost**.
  - If you're offline or in another server, your reward waits and is paid (with a pop-up) the next time you join.

**Rules (server-side in `InviteService`, numbers in `SocialConfig`):**
- **Launch data:** invites carry `ref:<inviter UserId>`, read from `Player:GetJoinData().LaunchData` with retries (it can arrive a few seconds late).
- **Who can credit an inviter:** a player counts only if they:
  - are **fresh** (no dunks, no Rebirth),
  - have an account at least **7 days** old (anyone can craft a join link with `ref:` launch data, so this plus the friend check and the daily cap slows farming with alt accounts),
  - are actually **friends** with the inviter (`IsFriendsWith`),
  - and have **never credited anyone before**.
- **Records:** `Invitee_<id>` in the referral DataStore (`DunkSimulator_Referrals_v1`; Studio uses `..._DEV_v1`). The same store holds `Inviter_<id>`, the daily count and pending rewards.
- **Daily cap:** inviters earn at most **5 referral rewards per UTC day**.
- **Rule note:** Roblox doesn't allow rewarding players for likes or favorites. We only reward invites, which is allowed.
- **Analytics:** `JoinedFromInvite`, `InviteRewarded`, and an `InviteReward` Cash source.

**Studio testing flags** (`SocialConfig`, ignored on live servers):
- `StudioPretendFriendsOnline`
- `StudioLaunchData`: skips the friend and account-age checks.

**Tested with both** (a fresh profile, 2 pretend friends, launch data `ref:1`):
- The INVITE button showed "+20%".
- A Between the Legs dunk paid exactly $3,463, the old $2,886 × 1.2.
- The invitee got the boost.
- Inviter 1's reward was saved as pending.
- A planted pending reward for the tester paid $400 plus a boost on join.
- Rejoining paid nothing again.
- Clicking INVITE opened Roblox's real invite prompt.

## Music and ambience

**Music:**
- A shuffled playlist per court crossfades when you travel (`MusicController`, `FeedbackConfig.Audio.Music`, volume 0.2).
- All tracks are from Roblox's licensed **APM Music** library (creator APMOfficial), free to use in any experience.

| Court | Tracks |
| --- | --- |
| Neighborhood | All It Takes (a), Just Chilling, Slow Rush (chill / lo-fi) |
| High School | Game Day Warrior (b), Believe The Hype (a), American Way (a) (hip-hop hype) |
| College | Bring The Heat (a), Wildcat (a), Gimme Sauce (b) (glam-rock / hip-hop anthems) |
| Skyline Rooftop | Neon Sky, Real Worlds (a), Don't Play With Me (c) (night electronic) |

- **MUSIC: ON/OFF** (next to INVITE) turns music off for the session. The setting isn't saved yet.
- **Ambience:**
  - The Rooftop now has a **city night ambience** loop (ProSoundEffects, the same licensed library as the other effects).
  - The High School and College keep their stadium crowd loop, cheers and claps.
  - The three new dunks got whoosh, impact and rim sounds.
- **Tested:** all 13 sounds preload successfully in Studio, the Rooftop playlist and ambience play, and MUSIC: OFF stops the track.

## Auto Train (game pass)

- **What it does:** trains Vertical automatically, anywhere on your current court, at the same rate as the station, even while you dunk.
- **HUD toggle:** an **AUTO TRAIN: ON/OFF** toggle appears on the HUD for owners and starts ON each session.
- **When it pauses:**
  - It skips while you station-train or ride the bus.
  - Nothing is earned during a dunk's execution.
  - At the court cap it stops quietly after one notice.
- **Sound:** the training tick sound only plays for station training now, so Auto Train isn't noisy.
- **Code:** `TrainingService` (`updateAutoTraining`), `AutoTrainRequest` remote, `AutoTrainController`.
- **Daily challenge:** Auto Train reps count toward the "Leg Day" training-reps challenge.
- **Tested with `StudioOwnedPasses`:** Vertical climbed 30 → 46 without a station, OFF stopped it, and the tutorial's first step completed by itself.

## Starter Pack (game pass)

**What's in it** (one time only): **$2,500 Cash + 30 minutes of 2x Cash + Sky Risers shoes** (a $7,500 Locker item).

**How it works:**
- The grant is claimed in the receipts store (`StarterPack_<userId>`) before paying. It's released again if paying or saving fails, so it's paid once per account, even across servers and rejoins.
- It's listed first in the Locker's **PASSES** tab.
- New players also see a **one-time offer card** 6 seconds after "TUTORIAL COMPLETE!", with GET IT and LATER buttons. The card only appears once the pass has a real id.

**Tested:**
- The first join paid $2,500 and the boost.
- Sky Risers showed as owned in the Locker.
- An `IAP StarterPack` analytics source was logged.
- Rejoining paid nothing.

## To put the passes on sale

1. Creator Hub → Dunk Simulator → **Monetization → Passes**. Create:
   - **Starter Pack**, icon `assets/pass-icons/starter-pack.png`, suggested **49 R$**.
   - **Auto Train**, icon `assets/pass-icons/auto-train.png`, suggested **199 R$**.
2. Paste their ids into `MonetizationConfig.Passes` (`StarterPack` / `AutoTrain`), sync, and publish. Until then both show **COMING SOON** and the offer card never appears.

**Status:** Starter Pack is `1999707117` (created, not on sale yet) and Auto Train is `1999335123` (on sale, 199 R$). Both are in `MonetizationConfig`.

## Files

- **New:**
  - `src/shared/Config/SocialConfig.luau`
  - `src/server/services/InviteService.luau`
  - `src/client/InviteController.luau`
  - `src/client/MusicController.luau`
  - `src/client/AutoTrainController.luau`
  - `assets/pass-icons/auto-train.png`, `starter-pack.png`
- **Changed:**
  - `PlayerService`: friend multiplier
  - `TrainingService`: Auto Train
  - `MonetizationService`: Starter Pack grant, Auto Train default
  - `LockerService`: `GrantItem`
  - `MonetizationConfig`: two passes
  - `FeedbackConfig`: music, city ambience, new style sounds
  - `CrowdPresentation`
  - `HUDView`: INVITE, MUSIC, AUTO TRAIN
  - `HUDController`
  - `TutorialView` / `TutorialController`: offer card
  - `DataConfig`: referral store names
  - `ServerMain`
  - `default.project.json`: `SocialNotice`, `AutoTrainRequest` remotes
  - `tools/pass-icons.ps1`
