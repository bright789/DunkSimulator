# Experience Notifications (2026-10-03, "Pack A")

Once a day the game can send one Roblox notification ("Your free daily reward and gifts are ready...") to players who played in the last week. On Saturdays it says Dunk Night is about to start instead. Roblox only delivers to players aged 13+ who turned notifications on for this experience, and at most one per player per day. See [Experience notifications](https://create.roblox.com/docs/production/promotion/experience-notifications).

Tuning lives in `src/shared/Config/NotificationConfig.luau`. Code: `NotificationService` (server) and `NotificationController` (client).

## What the owner must do

1. **Notification strings (done 2026-10-03).** In the Creator Hub (your experience > Engagement > Notifications) two strings were created and passed the text filter. Their ids are in `NotificationConfig.Templates`:

   | Template | Id | Text |
   | --- | --- | --- |
   | `Daily` | `665e0a10-7d5c-8f4f-93d4-3b4f1710918f` | Your free daily reward and gifts are ready. Come throw down some dunks! |
   | `DunkNight` | `39821594-1689-5d49-bdc7-b0855bf43395` | DUNK NIGHT starts soon: 2x Cash, 2x training and Golden Ball rain! Jump in! |

   Setting a template to `""` turns that notification off.
2. **Insert Roblox's Open Cloud package.** In Studio, open the Toolbox (Creator Store), search for the official **Open Cloud** package by Roblox and insert it into **ServerScriptService** so that `ServerScriptService.OpenCloud.V2.UserNotification` exists. Rojo leaves it alone because ServerScriptService has `$ignoreUnknownInstances: true` (don't name anything in `src/server` `OpenCloud`).
3. **Save to Roblox and Publish.** The package must be in the published place. Without it the server logs once ("Open Cloud package not found...") and sends nothing.
4. Roblox requires the experience to have at least 100 visits and not be under moderation, and the account sending must be able to manage the experience.

## The daily send (server)

- **Recent players.** Every player who joins is recorded for that UTC day. Each server batches joins and writes them every `RegistryFlushSeconds` (60) into the notifications DataStore (`DunkSimulator_Notifications_v1`, Studio `..._DEV_v1`, in `DataConfig`). Keys are `Recent_<yyyymmdd>_<shard>` (4 shards so many servers don't fight over one key), lists are de-duplicated and capped at 5,000 players per day in total. Joins that fail to save stay batched and are retried; they are also flushed when the server closes.
- **When.** Every day at `SendHourUtc` (21:00 UTC). On the Dunk Night day the send moves to `DunkNightLeadMinutes` (90) before Dunk Night starts: Saturday 17:30 UTC. If no server is running at that moment, the first server that is running within `CatchUpHours` (6) sends it.
- **Exactly one server.** Every server checks once a minute. When the send is due a server:
  1. reads the `Sent_<yyyymmdd>` marker in the DataStore; if it exists, today is done;
  2. takes the claim `Notify_<yyyymmdd>` in a MemoryStore hash map (`DunkNotify`) with `UpdateAsync`, only if nobody holds it (it expires after `ClaimSeconds`, 30 minutes, in case that server dies);
  3. writes the `Sent_` marker with `UpdateAsync` only if it is still empty;
  4. sends, then rewrites the marker with the counts.
  A server that loses the claim tries again a minute later and then sees the marker.
- **Who.** Everyone recorded in the last `RecentDays` (7) UTC days, newest day first, without repeats, except players in this server. At most `MaxPerRun` (2,000), `SendGapSeconds` (0.1 s) apart.
- **Which message.** `DunkNight` when Dunk Night starts within `DunkNightMessageHours` (2) of the send, otherwise `Daily`. With the defaults that is Saturday's 17:30 send; a late catch-up after Dunk Night has started uses `Daily`.
- **The call.** `require(ServerScriptService.OpenCloud.V2.UserNotification).createUserNotification(userId, { payload = { messageId = <template id>, type = "MOMENT", joinExperience = { launchData = "notif:daily" | "notif:dunknight" }, analyticsData = { category = "daily" | "dunknight" } } })`, inside `pcall`. A result with a 2xx `statusCode` counts as sent; another status or an `error` counts as failed (for example a player who didn't opt in), and the run continues. If the package itself throws `MaxErrorsInARow` (10) times in a row, the run stops and the first error is logged.
- **Analytics.** Custom events `NotificationsSent` and `NotificationsFailed` (value = the count). Roblox analytics events need a player, so they are logged on a player in the sending server. Output also prints the counts.
- **Studio never sends.** It prints what it would send ("Studio dry run for 20261003: would send DunkNight (...) to 12 players (...). Open Cloud package found. Nothing was sent.") once per session when the send is due, and doesn't touch the MemoryStore or the marker. Test flag `NotificationConfig.StudioRunNow` (default **false**): runs that dry run about 15 s after the server starts, whatever the time.

## Joining from a notification

The notification's launch data is `notif:<kind>`. On join, `NotificationService` logs the custom event `NotificationJoin_daily` / `NotificationJoin_dunknight`. `InviteService.readInviter` only accepts launch data matching `^ref:(%d+)$`, so `notif:` launch data is ignored there (checked in the logic harness).

## The opt-in prompt (client)

`NotificationController` asks `ExperienceNotificationService:CanPromptOptInAsync()` and then calls `PromptOptIn()` (both in `pcall`), **at most once per session**, at one of these moments:
- right after the new-player tutorial is finished (it was running this session and now every step is done);
- after the first playtime gift claim;
- while Dunk Night is on (including joining during it).

It never asks in the first `OptIn.MinSessionSeconds` (120) of a session, during a dunk, or while a menu or pop-up is open (any ScreenGui with DisplayOrder 8 or more showing a panel: menus, the daily reward and welcome-back pop-ups, the crew reveal, the payout card, the Dunk Contest banner and results; or the tutorial card and its Starter Pack offer). After a good moment it waits up to `OptIn.WaitSeconds` (180) for a clear one. Just before the prompt a gold feed line says "Turn on notifications to hear when Dunk Night starts!".

Analytics (through the `NotificationPrompt` remote, once per session each): `NotifyPromptShown` when the prompt opened and `NotifyPromptClosed` when Roblox's `OptInPromptClosed` fired. Roblox doesn't say whether the player accepted, so acceptance shows up in the Creator Hub's notification stats, not here.

| Remote | Direction | Payload |
| --- | --- | --- |
| `NotificationPrompt` | client -> server | `"Shown"` or `"Closed"`, nothing else. Logged once per session each; anything else is ignored. |

## Studio checklist

1. Set `StudioRunNow = true`, Play: after ~15 s Output prints the dry-run line with the message, its id, the number of DEV recent players and whether the Open Cloud package is found. Nothing is sent. Set it back to false.
2. Play for 2+ minutes, finish the tutorial on a fresh profile (or claim a gift), with no menu open: the gold nudge line and Roblox's opt-in prompt appear once, if your account can be prompted (13+, not already opted in; otherwise `CanPromptOptInAsync` returns false and nothing shows). Output shows `NotifyPromptShown`, then `NotifyPromptClosed` after closing it.
3. Live: after the first send, Output on the sending server shows "Daily notification for <day>: N sent, M failed".

## Status (2026-10-03)

- The Creator Hub strings exist and passed the text filter: Daily `665e0a10-7d5c-8f4f-93d4-3b4f1710918f` and DunkNight `39821594-1689-5d49-bdc7-b0855bf43395`.
- The official **Open Cloud** package (Creator Store asset 16584168800, by Roblox) was inserted with InsertService. `ServerScriptService.OpenCloud` (with `V2.UserNotification`) is now in the place. It isn't in the repo, because Rojo's `$ignoreUnknownInstances` keeps it, so it ships only when the place is published.
- Studio dry run: "would send Daily (665e0a10-...) to 0 players. Open Cloud package found. Nothing was sent." The count was 0 because the DEV registry was empty.
