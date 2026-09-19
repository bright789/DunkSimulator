local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Config = require(script.Parent.Parent.Config.DataConfig)
local Store = require(script.Parent.Parent.data.PlayerDataStore)
local Schema = require(script.Parent.Parent.data.PlayerDataSchema)

local DataService = {}
local sessions = {}
local adapter = nil
local initialized = false
local shuttingDown = false

local function isCurrent(session): boolean
	return sessions[session.Player.UserId] == session
end

local function setStatus(session, status: string)
	session.Status = status
	session.Player:SetAttribute("DataStatus", status)
end

local function cleanup(session)
	if not isCurrent(session) then
		return
	end
	adapter.Cleanup(session.Player)
	sessions[session.Player.UserId] = nil
end

local function fail(session, message: string, reason: string)
	if not isCurrent(session) then
		return
	end
	session.Unsafe = true
	setStatus(session, "Failed")
	warn(string.format("[DataService] Player %d progression disabled: %s", session.Player.UserId, reason))
	if session.Player.Parent == Players then
		session.Player:Kick(message)
	end
end

local function startSave(session)
	if session.Saving or session.Unsafe then
		return
	end
	session.Saving = true
	task.spawn(function()
		local deadline = os.clock() + Config.SaveTimeoutSeconds
		local function canContinue()
			return isCurrent(session) and not session.Unsafe
				and os.clock() < math.min(deadline, session.CloseDeadline or math.huge)
		end
		local succeeded, failure = xpcall(function()
			while canContinue() and (session.QueuedSnapshot or session.PendingWrite) do
				local requested = session.QueuedSnapshot
				session.QueuedSnapshot = nil
				if not session.PendingWrite then
					session.PendingWrite = {
						Snapshot = requested,
						Revision = session.Revision,
						WriteId = HttpService:GenerateGUID(false),
					}
				elseif requested and not Schema.SameProgress(requested, session.PendingWrite.Snapshot) then
					session.QueuedSnapshot = requested
				end
				local saved, fatal, reason = Store.Write(session.Player.UserId, session.PendingWrite, canContinue)
				if not saved then
					if fatal then
						fail(session, Config.ConflictMessage, reason)
					end
					return
				end
				session.Revision = session.PendingWrite.Revision + 1
				session.PendingWrite = nil
				print(string.format("[DataService] Saved player %d.", session.Player.UserId))
			end
		end, debug.traceback)
		session.Saving = false
		if not succeeded then
			fail(session, Config.LoadFailureMessage, tostring(failure))
		end
		if session.Status == "Closing" or session.Status == "Failed" then
			if session.PendingWrite or session.QueuedSnapshot then
				warn(string.format("[DataService] Final save not confirmed for player %d; unsaved progress may be lost.", session.Player.UserId))
			end
			cleanup(session)
		end
	end)
end

local function queueSnapshot(session)
	local values = adapter.Snapshot(session.Player)
	local snapshot, problem = Schema.Snapshot(values)
	if not snapshot then
		fail(session, Config.LoadFailureMessage, problem)
		if not session.Saving then
			cleanup(session)
		end
		return
	end
	session.QueuedSnapshot = snapshot
	startSave(session)
end

local function closePlayer(player: Player, shutdownDeadline: number?)
	local session = sessions[player.UserId]
	if not session or session.Player ~= player then
		return
	end
	session.CloseDeadline = math.min(session.CloseDeadline or (os.clock() + Config.CloseTimeoutSeconds),
		shutdownDeadline or math.huge)
	if session.Status == "Closing" then
		return
	end
	if session.Status ~= "Ready" or session.Unsafe then
		setStatus(session, "Closing")
		if not session.Saving then
			cleanup(session)
		end
		return
	end
	setStatus(session, "Closing")
	queueSnapshot(session)
	task.delay(math.max(0, session.CloseDeadline - os.clock()), function()
		if isCurrent(session) then
			warn(string.format("[DataService] Close deadline reached for player %d; save outcome may be unknown.", player.UserId))
			cleanup(session)
		end
	end)
end

local function addPlayer(player: Player)
	local existing = sessions[player.UserId]
	if existing and existing.Player == player then
		return
	end
	if shuttingDown or sessions[player.UserId] then
		player:Kick("Your previous data session is still closing. Please rejoin in a moment.")
		return
	end
	if player.Parent ~= Players then
		return
	end
	local session = { Player = player, Status = "Loading", Saving = false, Unsafe = false }
	sessions[player.UserId] = session
	setStatus(session, "Loading")
	print(string.format("[DataService] Loading player %d (%s).", player.UserId, Store.Name()))
	local deadline = os.clock() + Config.LoadTimeoutSeconds
	local function canContinue()
		return isCurrent(session) and session.Status == "Loading" and not shuttingDown
			and player.Parent == Players and os.clock() < deadline
	end
	task.delay(Config.LoadTimeoutSeconds, function()
		if isCurrent(session) and session.Status == "Loading" then
			fail(session, Config.LoadFailureMessage, "Load deadline reached")
			cleanup(session)
		end
	end)
	local profile, revision, problem, repaired = Store.Load(player.UserId, canContinue)
	if not canContinue() then
		return
	end
	if not profile then
		fail(session, Config.LoadFailureMessage, problem)
		cleanup(session)
		return
	end
	local success, failure = pcall(adapter.Initialize, player, profile)
	if not success then
		fail(session, Config.LoadFailureMessage, tostring(failure))
		cleanup(session)
		return
	end
	session.Revision = revision
	session.NextAutosave = os.clock() + Config.AutosaveSeconds + math.random() * Config.AutosaveJitterSeconds
	setStatus(session, "Ready")
	if repaired then
		warn(string.format("[DataService] Repaired missing/invalid fields for player %d; valid fields retained.", player.UserId))
	end
	print(string.format("[DataService] Player %d data ready.", player.UserId))
end

function DataService.IsReady(player: Player): boolean
	local session = sessions[player.UserId]
	return session ~= nil and session.Player == player and session.Status == "Ready" and not session.Unsafe
end

function DataService.Init(playerAdapter)
	if initialized then
		return
	end
	initialized = true
	adapter = playerAdapter
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player)
		closePlayer(player)
	end)
	game:BindToClose(function()
		shuttingDown = true
		local deadline = os.clock() + Config.CloseTimeoutSeconds
		local closing = {}
		for _, session in sessions do
			table.insert(closing, session.Player)
		end
		for _, player in closing do
			closePlayer(player, deadline)
		end
		while next(sessions) and os.clock() < deadline do
			task.wait(0.1)
		end
		if next(sessions) then
			warn("[DataService] Shutdown deadline reached; some saves are unconfirmed.")
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(addPlayer, player)
	end
	task.spawn(function()
		while not shuttingDown do
			task.wait(1)
			for _, session in sessions do
				if session.Status == "Ready" and not session.Saving and os.clock() >= session.NextAutosave then
					session.NextAutosave = os.clock() + Config.AutosaveSeconds + math.random() * Config.AutosaveJitterSeconds
					queueSnapshot(session)
				end
			end
		end
	end)
end

return DataService
