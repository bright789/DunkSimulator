-- Global leaderboards. Each player's lifetime stats (kept by PlayerService) are written to
-- one OrderedDataStore per board, at most every WriteSeconds and when they leave. Every
-- RefreshSeconds the server reads the top lists, merges in the live stats of players in
-- this server (so fresh records show right away), and publishes them as JSON attributes on
-- ReplicatedStorage.Leaderboards for the gym boards to draw. Clients send nothing.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Config = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local DataConfig = require(script.Parent.Parent.Config.DataConfig)
local PlayerService = require(script.Parent.PlayerService)

local LeaderboardService = {}
local initialized = false
local stores: { [string]: OrderedDataStore } = {}
local topLists: { [string]: { { UserId: number, Value: number } } } = {}
local written: { [number]: { [string]: number } } = {}
local nextWrite: { [Player]: number } = {}
local names: { [number]: string } = {}
local folder: Folder? = nil

local function storeName(boardId: string): string
	local prefix = RunService:IsStudio() and DataConfig.StudioLeaderboardPrefix or DataConfig.ProductionLeaderboardPrefix
	return prefix .. boardId
end

-- Writes any stat that grew since the last write. `stats` comes from PlayerService (or the
-- player's attributes when they are leaving).
local function flush(userId: number, stats)
	if userId <= 0 or not stats then return end
	local previous = written[userId] or {}
	written[userId] = previous
	for _, board in Config.Boards do
		local value = stats[board.Stat]
		local store = stores[board.Id]
		if store and type(value) == "number" and value > 0 and value ~= previous[board.Id] then
			local ok, problem = pcall(store.SetAsync, store, tostring(userId), math.floor(value))
			if ok then
				previous[board.Id] = value
			else
				warn("[LeaderboardService] Write failed for " .. board.Id .. ": " .. tostring(problem))
			end
		end
	end
end

local function attributeStats(player: Player)
	local stats = {}
	for _, board in Config.Boards do
		stats[board.Stat] = player:GetAttribute(board.Stat)
	end
	return stats
end

-- Display names for user ids (cached; online players use their current display name).
local function resolveNames(userIds: { number })
	local missing = {}
	for _, userId in userIds do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			names[userId] = player.DisplayName
		elseif not names[userId] then
			table.insert(missing, userId)
		end
	end
	if #missing == 0 then return end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
	if ok and type(infos) == "table" then
		for _, info in infos do
			if type(info) == "table" and type(info.Id) == "number" then
				names[info.Id] = tostring(info.DisplayName or info.Username or "")
			end
		end
	end
	for _, userId in missing do
		if not names[userId] then
			local found, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
			names[userId] = found and name or ("Player " .. userId)
		end
	end
end

local function publish()
	if not folder then return end
	local live = {}
	for _, player in Players:GetPlayers() do
		local stats = PlayerService.GetStats(player)
		if stats and player.UserId > 0 then live[player.UserId] = stats end
	end
	local allIds = {}
	local lists = {}
	for _, board in Config.Boards do
		local best: { [number]: number } = {}
		for _, entry in topLists[board.Id] or {} do
			best[entry.UserId] = entry.Value
		end
		for userId, stats in live do
			local value = stats[board.Stat]
			if value > 0 and value > (best[userId] or 0) then best[userId] = value end
		end
		local list = {}
		for userId, value in best do table.insert(list, { UserId = userId, Value = value }) end
		table.sort(list, function(first, second)
			if first.Value ~= second.Value then return first.Value > second.Value end
			return first.UserId < second.UserId
		end)
		while #list > Config.Size do table.remove(list) end
		lists[board.Id] = list
		for _, entry in list do table.insert(allIds, entry.UserId) end
	end
	-- Keep only names still on a board (the cache would otherwise grow forever).
	local shown = {}
	for _, userId in allIds do shown[userId] = true end
	for userId in names do
		if not shown[userId] then names[userId] = nil end
	end
	resolveNames(allIds)
	for boardId, list in lists do
		local rows = {}
		for rank, entry in list do
			rows[rank] = { Rank = rank, UserId = entry.UserId, Name = names[entry.UserId] or "?", Value = entry.Value }
		end
		folder:SetAttribute(boardId, HttpService:JSONEncode(rows))
	end
	folder:SetAttribute("UpdatedAt", os.time())
end

local function refresh()
	for _, board in Config.Boards do
		local store = stores[board.Id]
		if store then
			local ok, pages = pcall(store.GetSortedAsync, store, false, Config.Size)
			if ok then
				local entries = {}
				for _, item in pages:GetCurrentPage() do
					local userId = tonumber(item.key)
					if userId and userId > 0 and type(item.value) == "number" then
						table.insert(entries, { UserId = userId, Value = item.value })
					end
				end
				topLists[board.Id] = entries
			else
				warn("[LeaderboardService] Read failed for " .. board.Id .. ": " .. tostring(pages))
			end
		end
	end
	publish()
end

function LeaderboardService.Init()
	if initialized then return end
	initialized = true
	folder = ReplicatedStorage:WaitForChild("Leaderboards")
	for _, board in Config.Boards do
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, storeName(board.Id))
		if ok then
			stores[board.Id] = store
		else
			warn("[LeaderboardService] Leaderboards unavailable: " .. tostring(store))
		end
	end

	-- Top lists: read now and then every RefreshSeconds; republish live stats in between so
	-- a new record by someone in this server shows within a few seconds.
	task.spawn(function()
		local nextRefresh = 0
		while true do
			-- One bad pass (a throttled service, an odd response) must not stop the boards.
			local ok, problem = pcall(function()
				local now = os.clock()
				if now >= nextRefresh then
					nextRefresh = now + Config.RefreshSeconds
					refresh()
				else
					publish()
				end
				-- Throttled writes for players in the server.
				for _, player in Players:GetPlayers() do
					if os.clock() >= (nextWrite[player] or 0) and PlayerService.IsDataReady(player) then
						nextWrite[player] = os.clock() + Config.WriteSeconds
						flush(player.UserId, PlayerService.GetStats(player))
					end
				end
			end)
			if not ok then warn("[LeaderboardService] Update failed: " .. tostring(problem)) end
			task.wait(5)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		nextWrite[player] = nil
		flush(player.UserId, attributeStats(player))
		written[player.UserId] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			flush(player.UserId, attributeStats(player))
		end
	end)
end

return LeaderboardService
