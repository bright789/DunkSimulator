# Friend Invites, Music, Auto Train and Starter Pack

## Friend invites and friend bonus

**For players:**
- **INVITE** (fourth row of the HUD) opens Roblox's own friend-invite prompt with the message "Invite friends to dunk with you! You both get a 2x Cash Boost when they join."
- **Friend bonus:** every Roblox friend in the same server adds **+10% dunk and air-trick Cash**, up to **+30%**. The button shows it, for example "INVITE +20%".
- **Referral reward:** when someone joins through any invite from you for the first time (the INVITE button, Roblox's own invite menu, a shared link, or the Referral Rewards banner on the game page):
  - The friend gets a **15-minute 2x Cash Boost**.
  - You get **Cash worth 20 dunks** at your Vertical plus a **15-minute boost**.
  - If you're offline or in another server, your reward waits and is paid (with a pop-up) the next time you join.

**Rules (server-side in `InviteService`, numbers in `SocialConfig`):**
- **Who invited them:** read from `Player:GetJoinData()` with retries (it can arrive a few seconds late):
  1. `ReferredByPlayerId` first. Roblox's referral system sets it for every kind of invite, including share links and the Referral Rewards banner, and it can't be faked.
  2. Otherwise the INVITE button's launch data, `ref:<inviter UserId>`.
- **Who can credit an inviter:** a player counts only if they:
  - are **fresh** (no dunks, no Rebirth),
  - have an account at least **7 days** old (with the daily cap, this slows farming with alt accounts),
  - for launch-data invites only, are actually **friends** with the inviter (`IsFriendsWith`). Anyone can craft a join link with `ref:` launch data; `ReferredByPlayerId` can't be crafted, and share links reach people who aren't friends yet, so it skips this check.
  - and have **never credited anyone before**.
- **Records:** `Invitee_<id>` in the referral DataStore (`DunkSimulator_Referrals_v1`; Studio uses `..._DEV_v1`), with `InviterId`, `At` and `Source` (`roblox` or `launch`). The same store holds `Inviter_<id>`, the daily count and pending rewards.
- **Daily cap:** inviters earn at most **5 referral rewards per UTC day**.
- **Rule note:** Roblox doesn't allow rewarding players for likes or favorites. We only reward invites, which is allowed.
- **Analytics:** `JoinedFromInvite` (value 2 = Roblox referral, 1 = launch data), `InviteRewarded`, and an `InviteReward` Cash source.

**Studio testing flags** (`SocialConfig`, ignored on live servers):
- `StudioPretendFriendsOnline`
- `StudioLaunchData` (e.g. `"ref:1"`) or `StudioReferredBy` (e.g. `1`): pretend this join came from an invite. Both skip the friend and account-age checks.

**Tested with both** (a fresh profile, 2 pretend friends, launch data `ref:1`):
- The INVITE button showed "+20%".
- A Between the Legs dunk paid exactly $3,463, the old $2,886 × 1.2.
- The invitee got the boost.
- Inviter 1's reward was saved as pending.
- A planted pending reward for the tester paid $400 plus a boost on join.
- Rejoining paid nothing again.
- Clicking INVITE opened Roblox's real invite prompt.

**Roblox referral system (2026-10-03).** Invites are now read from `ReferredByPlayerId` first, so every invite type counts, including the Creator Hub **Referral Rewards** banner (Engagement → Referral rewards). Tested in Studio with `StudioReferredBy = 1` and fresh QA stores:
- The log showed `JoinedFromInvite 2`, and the fresh player got "2x CASH 15:00".
- The store held `Invitee_<id> = {InviterId 1, Source "roblox"}` and `Inviter_1 = {Pending 1, DayCount 1}`.
- The flags and store names were reverted afterwards.

The code went live with the place publish at 2026-10-03 22:42Z. The **Creator Hub banner** was published 2026-10-03 (the owner agreed to the Referral Program Terms):
- Name "2x Cash Boost"; the image is `assets/thumbnails/icon-512.png`.
- Description: "Friends get 2x Cash for 15 min, and you get Cash + 2x Cash!"
- Limits: "Only brand-new players count (account 7+ days old). Your friend gets 15 min of 2x Cash on first join. You get Cash worth 20 dunks + 15 min of 2x Cash, for up to 5 friends a day."
- Runs 2026-10-03 → 2027-03-31 11:59 PM.
- Only one banner can be live per experience. If the rewards in `SocialConfig` change, edit the banner text to match.

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

## Community group bonus (2026-09-27)

- **For players:** members of the game's Roblox group earn **+10% dunk and air-trick Cash**.
- **HUD:** a pill button under AUTO TRAIN shows **JOIN GROUP: +10% CASH** for non-members. It opens Roblox's own join prompt (`GroupService:PromptJoinAsync`). Members see **GROUP BONUS +10%**.
- **Membership check:** `InviteService` reads membership with `GroupService:GetGroupsAsync`, which isn't cached. It runs on join and again when the client asks after the prompt (`GroupRequest("Check")`, at most every 10 s). The bonus is multiplied in `PlayerService` next to the friend bonus.
- **Rules:** Roblox allows group-join rewards (it doesn't allow rewards for likes or favorites).
- **Turning it on:** create the group (Creator Hub → Communities), then put its id in `SocialConfig.GroupId`. While it's `0`, the button is hidden and there's no bonus.
- **Status:** turned on with **Dunk Simulator Official** (id `292818851`, "Anyone can join"), owned by Bryte213.
- **Studio testing:** `SocialConfig.StudioPretendInGroup` fakes membership in Studio.
- **Tested with group id 7 as a stand-in:**
  - Faking membership showed "GROUP BONUS +10%".
  - A High School Between the Legs dunk paid $2,102, the old $1,911 × 1.1.
  - Without it, the button read "JOIN GROUP: +10% CASH". I didn't click it, because 7 is a real Roblox group.

## Saved music setting (schema v11)

**How it's saved:**
- The MUSIC button now saves the choice. Player data is **schema v11**, with a new `Settings = { Music = true/false }` field.
- Migration v10 → v11 turns music ON for everyone, and `Schema.Decode` repairs a non-boolean value.

**How it flows:**
- The client sends `SettingsRequest("Music", bool)`.
- `SettingsService` validates it (0.5 s rate limit), stores it through `PlayerService.SetMusicSetting` and requests a save.
- The `SettingMusic` attribute tells `MusicController` the saved value on join.

**Tested on the QA store:**
- A v10 profile loaded as v11 with music ON.
- Turning music OFF, stopping and rejoining came back OFF, with no track playing.

