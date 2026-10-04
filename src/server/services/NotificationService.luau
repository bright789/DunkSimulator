-- Experience notifications, server side (NotificationConfig, docs/NOTIFICATIONS.md):
--   * Recent players: everyone who joins is recorded for that UTC day. Joins are batched and
--     written every RegistryFlushSeconds to the notifications DataStore (DataConfig).
--   * Daily send: once per UTC day at the send time (or later, within CatchUpHours, if no
--     server was up then), exactly one server sends one notification to everyone seen in the
--     last RecentDays days who isn't in this server. That server is chosen with a MemoryStore
--     claim, and a "Sent_<day>" marker in the DataStore stops any later server sending again.
--     Sending uses Roblox's Open Cloud package (ServerScriptService.OpenCloud.V2.UserNotification,
--     inserted by the owner in Studio). If the package or the message id is missing, nothing is
--     sent (logged once). Studio never sends: it prints what would be sent.
--   * Joins from a notification (launch data "notif:<kind>") log NotificationJoin_<kind>.
--     InviteService only reads "ref:<id>" launch data, so the two don't clash.
--   * NotificationPrompt remote (client -> server): "Shown" / "Closed" when the opt-in prompt
--     was shown / closed. Logged once per session as NotifyPromptShown / NotifyPromptClosed.
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config.NotificationConfig)
local DataConfig = require(script.Parent.Parent.Config.DataConfig)
local Analytics = require(script.Parent.AnalyticsReporter)

local NotificationService = {}
local initialized = false
local isStudio = RunService:IsStudio()
local store = nil
local claims = nil
-- UserIds that joined since the last registry write.
local pending: { [number]: boolean } = {}
-- Day keys this server is finished with (sent, already sent elsewhere, or can't send).
local finished: { [string]: boolean } = {}
local logged: { [string]: boolean } = {}
local prompted: { [Player]: { [string]: boolean } } = {}

local function logOnce(key: string, message: string)
	if logged[key] then return end
	logged[key] = true
	warn("[NotificationService] " .. message)
end

local function recentKey(dayKey: string, shard: number): string
	return "Recent_" .. dayKey .. "_" .. shard
end

-- Writes the batched joins into today's lists (one key per shard, deduplicated and capped).
-- Joins that couldn't be written stay batched for the next try.
function NotificationService.FlushRegistry(now: number)
	if not store or next(pending) == nil then return end
	local batch = pending
	pending = {}
	local dayKey = Config.DayKey(now)
	local cap = math.ceil(Config.MaxPerDay / Config.Shards)
	local byShard = {}
	for userId in batch do
		local shard = userId % Config.Shards
		byShard[shard] = byShard[shard] or {}
		table.insert(byShard[shard], userId)
	end
	for shard, ids in byShard do
		local ok, problem = pcall(function()
			store:UpdateAsync(recentKey(dayKey, shard), function(value)
				local list = type(value) == "table" and value or {}
				local seen = {}
				for _, userId in list do seen[userId] = true end
				local changed = false
				for _, userId in ids do
					if not seen[userId] and #list < cap then
						table.insert(list, userId)
						seen[userId] = true
						changed = true
					end
				end
				return changed and list or nil
			end)
		end)
		if not ok then
			for _, userId in ids do pending[userId] = true end
			logOnce("flush", "Recent players not saved yet (will retry): " .. tostring(problem))
		end
	end
end

-- UserIds seen in the last RecentDays days, newest day first, without repeats.
function NotificationService.CollectRecent(now: number): { number }
	local ids, seen = {}, {}
	if not store then return ids end
	for daysBack = 0, Config.RecentDays - 1 do
		local dayKey = Config.DayKey(now - daysBack * 86400)
		for shard = 0, Config.Shards - 1 do
			local ok, value = pcall(store.GetAsync, store, recentKey(dayKey, shard))
			if ok and type(value) == "table" then
				for _, userId in value do
					if type(userId) == "number" and not seen[userId] then
						seen[userId] = true
						table.insert(ids, userId)
					end
				end
			elseif not ok then
				logOnce("read", "Could not read recent players: " .. tostring(value))
			end
		end
	end
	return ids
end

-- Who gets today's notification: recent players not in this server, at most MaxPerRun.
local function recipients(now: number): { number }
	local list = {}
	for _, userId in NotificationService.CollectRecent(now) do
		if #list >= Config.MaxPerRun then break end
		if not Players:GetPlayerByUserId(userId) then table.insert(list, userId) end
	end
	return list
end

-- The Open Cloud package's UserNotification module, or nil if it isn't in the place.
local function notificationApi()
	local folder = ServerScriptService:FindFirstChild("OpenCloud")
	local v2 = folder and folder:FindFirstChild("V2")
	local module = v2 and v2:FindFirstChild("UserNotification")
	if not module or not module:IsA("ModuleScript") then return nil end
	local ok, api = pcall(require, module)
	if ok and type(api) == "table" and type(api.createUserNotification) == "function" then return api end
	return nil
end

local function describe(problem): string
	if type(problem) == "table" then return tostring(problem.message or problem.code or "error") end
	return tostring(problem)
end

-- Sends one notification. Returns whether Roblox accepted it, and whether the package threw a
-- script error (as opposed to Roblox refusing, e.g. a player who didn't opt in), with a reason.
function NotificationService.SendOne(api, userId: number, messageId: string, kind: string): (boolean, boolean, string?)
	local ok, result = pcall(api.createUserNotification, userId, {
		payload = {
			messageId = messageId,
			type = "MOMENT",
			joinExperience = { launchData = "notif:" .. kind },
			analyticsData = { category = kind },
		},
	})
	if not ok then return false, true, tostring(result) end
	if type(result) == "table" then
		local status = result.statusCode
		if type(status) == "number" then
			if status >= 200 and status < 300 then return true, false, nil end
			return false, false, "status " .. status .. (result.error ~= nil and (": " .. describe(result.error)) or "")
		end
		if result.error ~= nil then return false, false, describe(result.error) end
	end
	return true, false, nil
end

-- True if this server holds today's send claim (MemoryStore, kept ClaimSeconds).
local function claimDay(dayKey: string): boolean
	if not claims then return false end
	local won = false
	local ok, problem = pcall(function()
		claims:UpdateAsync("Notify_" .. dayKey, function(holder)
			won = holder == nil or holder == game.JobId
			return won and game.JobId or nil
		end, Config.ClaimSeconds)
	end)
	if not ok then logOnce("claim", "MemoryStore claim failed: " .. tostring(problem)) end
	return ok and won
end

-- Whether any server has started today's send: true / false, or nil if the store can't be read.
local function alreadySent(dayKey: string): boolean?
	local ok, value = pcall(store.GetAsync, store, "Sent_" .. dayKey)
	if not ok then return nil end
	return value ~= nil
end

-- Writes today's "sent" marker only if there isn't one yet. Returns whether the store answered
-- and whether this server wrote the marker.
local function markSending(dayKey: string, message: string): (boolean, boolean)
	local mine = false
	local ok = pcall(function()
		store:UpdateAsync("Sent_" .. dayKey, function(value)
			mine = value == nil
			return mine and { JobId = game.JobId, At = os.time(), Message = message, State = "Sending" } or nil
		end)
	end)
	return ok, ok and mine
end

local function preview(ids: { number }): string
	local shown = {}
	for index = 1, math.min(#ids, 5) do table.insert(shown, tostring(ids[index])) end
	return #shown > 0 and (" (" .. table.concat(shown, ", ") .. (#ids > 5 and ", ..." or "") .. ")") or ""
end

-- Sends today's notification if it is due and no server has sent it yet. `force` (Studio test
-- only) skips the time check. Returns what happened, for Output and tests.
function NotificationService.RunDaily(now: number, force: boolean?): string
	local dayKey = Config.DueSend(now)
	if force then dayKey = dayKey or Config.DayKey(now) end
	if not dayKey then return "NotDue" end
	if finished[dayKey] then return "Finished" end
	local message = Config.MessageFor(now)
	local kind = message == "DunkNight" and "dunknight" or "daily"
	local messageId = Config.Templates[message]
	if type(messageId) ~= "string" or messageId == "" then
		logOnce("template" .. message, "No " .. message .. " id in NotificationConfig.Templates, so nothing is sent.")
		finished[dayKey] = true
		return "NoTemplate"
	end
	if isStudio then
		finished[dayKey] = true
		local ids = recipients(now)
		print(string.format("[NotificationService] Studio dry run for %s: would send %s (%s) to %d players%s. "
			.. "Open Cloud package %s. Nothing was sent.", dayKey, message, messageId, #ids, preview(ids),
			notificationApi() and "found" or "NOT found"))
		return "DryRun"
	end
	local api = notificationApi()
	if not api then
		logOnce("package", "Open Cloud package not found at ServerScriptService.OpenCloud.V2.UserNotification, so nothing is sent.")
		finished[dayKey] = true
		return "NoPackage"
	end
	if not store then return "NoStore" end
	local sent = alreadySent(dayKey)
	if sent == nil then return "StoreBusy" end
	if sent then
		finished[dayKey] = true
		return "AlreadySent"
	end
	-- Another server may be sending right now: try again at the next check.
	if not claimDay(dayKey) then return "NotElected" end
	local answered, mine = markSending(dayKey, message)
	if not answered then return "StoreBusy" end
	if not mine then
		finished[dayKey] = true
		return "AlreadySent"
	end
	finished[dayKey] = true
	local ids = recipients(now)
	local sentCount, failed, errorsInARow, firstProblem = 0, 0, 0, nil
	for _, userId in ids do
		if not Players:GetPlayerByUserId(userId) then
			local accepted, scriptError, problem = NotificationService.SendOne(api, userId, messageId, kind)
			if accepted then
				sentCount += 1
				errorsInARow = 0
			else
				failed += 1
				firstProblem = firstProblem or problem
				errorsInARow = scriptError and errorsInARow + 1 or 0
				if errorsInARow >= Config.MaxErrorsInARow then
					warn("[NotificationService] Stopping: the Open Cloud package keeps erroring (" .. tostring(problem) .. ").")
					break
				end
			end
			task.wait(Config.SendGapSeconds)
		end
	end
	pcall(store.SetAsync, store, "Sent_" .. dayKey,
		{ JobId = game.JobId, At = os.time(), Message = message, State = "Done", Sent = sentCount, Failed = failed })
	print(string.format("[NotificationService] %s notification for %s: %d sent, %d failed of %d recent players.",
		message, dayKey, sentCount, failed, #ids))
	if firstProblem then warn("[NotificationService] First failure: " .. tostring(firstProblem)) end
	-- Analytics events need a player, so the totals are logged on someone in this server.
	local someone = Players:GetPlayers()[1]
	if someone then
		Analytics.Custom(someone, "NotificationsSent", sentCount)
		Analytics.Custom(someone, "NotificationsFailed", failed)
	end
	return "Sent"
end

-- Called (in its own thread) once a player's data is ready.
function NotificationService.OnPlayerReady(player: Player)
	pending[player.UserId] = true
	-- Join data can arrive a moment late, so look a few times.
	for attempt = 1, 3 do
		local ok, joinData = pcall(player.GetJoinData, player)
		local data = ok and type(joinData) == "table" and joinData.LaunchData or nil
		if type(data) == "string" and data ~= "" then
			local kind = string.match(data, "^notif:(%w+)$")
			if kind then Analytics.Custom(player, "NotificationJoin_" .. string.sub(kind, 1, 20)) end
			return
		end
		if attempt < 3 then task.wait(2) end
		if player.Parent ~= Players then return end
	end
end

function NotificationService.Init()
	if initialized then return end
	initialized = true
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService,
		isStudio and DataConfig.StudioNotificationStoreName or DataConfig.ProductionNotificationStoreName)
	if ok then store = result else warn("[NotificationService] Notifications store unavailable: " .. tostring(result)) end
	if not isStudio then
		local mapOk, map = pcall(MemoryStoreService.GetHashMap, MemoryStoreService, "DunkNotify")
		if mapOk then claims = map else warn("[NotificationService] MemoryStore unavailable: " .. tostring(map)) end
	end

	local remote = ReplicatedStorage.Remotes:WaitForChild("NotificationPrompt")
	remote.OnServerEvent:Connect(function(player, action, ...)
		if (action ~= "Shown" and action ~= "Closed") or select("#", ...) ~= 0 then return end
		local mine = prompted[player] or {}
		prompted[player] = mine
		if mine[action] then return end
		mine[action] = true
		Analytics.Custom(player, "NotifyPrompt" .. action)
	end)
	Players.PlayerRemoving:Connect(function(player) prompted[player] = nil end)

	task.spawn(function()
		while true do
			task.wait(Config.RegistryFlushSeconds)
			NotificationService.FlushRegistry(os.time())
		end
	end)
	task.spawn(function()
		-- Servers start at different moments; a small random delay spreads their checks.
		task.wait(5 + math.random() * 15)
		if isStudio and Config.StudioRunNow then
			print("[NotificationService] StudioRunNow is on: running the daily send as a dry run.")
			NotificationService.FlushRegistry(os.time())
			local runOk, problem = pcall(NotificationService.RunDaily, os.time(), true)
			if not runOk then warn("[NotificationService] " .. tostring(problem)) end
		end
		while true do
			local runOk, problem = pcall(NotificationService.RunDaily, os.time())
			if not runOk then warn("[NotificationService] " .. tostring(problem)) end
			task.wait(Config.CheckSeconds)
		end
	end)
	game:BindToClose(function()
		pcall(NotificationService.FlushRegistry, os.time())
	end)
end

return NotificationService
