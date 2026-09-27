-- Weekly Dunk Contest champion (ContestConfig.Weekly). Every round's best score for each
-- entrant is written to this week's OrderedDataStore (one store per week, keyed by UserId;
-- the value packs score and time so ties go to whoever set it first). Every RefreshSeconds
-- the top list is published on ReplicatedStorage.Contest (WeeklyTop, WeekEndsAt), the #1
-- gets a crown over their head, and last week's #1 is recorded in the champions store.
-- That champion gets a one-time prize the next time they join. Server only; clients display.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Contest = require(ReplicatedStorage.Shared.Config.ContestConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local DataConfig = require(script.Parent.Parent.Config.DataConfig)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local DailyService = require(script.Parent.DailyService)
local Analytics = require(script.Parent.AnalyticsReporter)

local Config = Contest.Weekly
local WeeklyChampionService = {}
local isStudio = RunService:IsStudio()
local initialized = false
local folder: Folder
local champions: DataStore? = nil
local championUserId: number? = nil
local crownConnections: { [Player]: RBXScriptConnection } = {}
local names: { [number]: string } = {}
local CROWN = "WeeklyChampCrown"
local SCORE_SCALE = 1000000 -- value = score * SCORE_SCALE + (SCORE_SCALE - 1 - seconds into the week)

local function week(): number
	return Contest.WeekNumber(os.time())
end

local function board(weekNumber: number): OrderedDataStore?
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService,
		(isStudio and DataConfig.StudioWeeklyPrefix or DataConfig.ProductionWeeklyPrefix) .. weekNumber)
	return ok and store or nil
end

local function withRetry(callback)
	for attempt = 1, 3 do
		local ok, result = pcall(callback)
		if ok then return true, result end
		if attempt < 3 then task.wait(attempt) end
	end
	return false, nil
end

-- Records a finished round's best score for this player if it beats their weekly best.
function WeeklyChampionService.RecordScore(player: Player, score: number)
	if type(score) ~= "number" or score <= 0 then return end
	score = math.clamp(math.floor(score), 0, Contest.MaxScore)
	local weekNumber = week()
	local store = board(weekNumber)
	if not store then return end
	local secondsIn = math.clamp(os.time() - (Contest.WeekEndsAt(weekNumber) - 7 * 86400), 0, SCORE_SCALE - 1)
	local value = score * SCORE_SCALE + (SCORE_SCALE - 1 - secondsIn)
	local improved = false
	withRetry(function()
		store:UpdateAsync(tostring(player.UserId), function(old)
			if type(old) == "number" and math.floor(old / SCORE_SCALE) >= score then
				improved = false
				return nil
			end
			improved = true
			return value
		end)
	end)
	if improved and player.Parent == Players then player:SetAttribute("WeeklyBest", score) end
end

local function fetchNames(userIds: { number })
	local missing = {}
	for _, userId in userIds do
		if not names[userId] then table.insert(missing, userId) end
	end
	if #missing == 0 then return end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
	if ok and type(infos) == "table" then
		for _, info in infos do names[info.Id] = info.DisplayName end
	end
	-- Keep the cache small.
	local count = 0
	for _ in names do count += 1 end
	if count > 200 then table.clear(names) end
end

local function topOf(weekNumber: number, count: number)
	local store = board(weekNumber)
	if not store then return nil end
	local ok, pages = withRetry(function() return store:GetSortedAsync(false, count) end)
	if not ok or not pages then return nil end
	local rows = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId then table.insert(rows, { UserId = userId, Score = math.floor(entry.value / SCORE_SCALE) }) end
	end
	return rows
end

local function crown(player: Player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then return end
	local old = head:FindFirstChild(CROWN)
	if old then old:Destroy() end
	if player.UserId ~= championUserId then return end
	local tag = Instance.new("BillboardGui")
	tag.Name = CROWN
	tag.Size = UDim2.fromOffset(130, 28)
	tag.StudsOffset = Vector3.new(0, 3.7, 0)
	tag.MaxDistance = 120
	tag.LightInfluence = 0
	tag.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(40, 24, 8)
	label.BackgroundTransparency = 0.15
	label.Text = "👑 " .. Config.CrownText
	label.TextColor3 = Color3.fromRGB(255, 214, 64)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(255, 214, 64)
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = tag
	tag.Parent = head
end

-- Makes sure last week's champion is written down (first writer wins).
local function recordLastWeekChampion()
	if not champions then return end
	local last = week() - 1
	local key = "W" .. last
	local ok, existing = withRetry(function() return champions:GetAsync(key) end)
	if not ok or existing ~= nil then return end
	local rows = topOf(last, 1)
	if not rows or not rows[1] then return end
	withRetry(function()
		champions:UpdateAsync(key, function(value)
			if value ~= nil then return nil end
			return { UserId = rows[1].UserId, Score = rows[1].Score, Claimed = false }
		end)
	end)
end

local function refresh()
	local weekNumber = week()
	folder:SetAttribute("WeekEndsAt", Contest.WeekEndsAt(weekNumber))
	local rows = topOf(weekNumber, Config.TopCount)
	if rows then
		local ids = {}
		for _, row in rows do table.insert(ids, row.UserId) end
		fetchNames(ids)
		for _, row in rows do row.Name = names[row.UserId] or ("Player " .. row.UserId) end
		folder:SetAttribute("WeeklyTop", HttpService:JSONEncode(rows))
		local newChampion = rows[1] and rows[1].UserId or nil
		if newChampion ~= championUserId then
			championUserId = newChampion
			for _, player in Players:GetPlayers() do crown(player) end
		end
	end
	recordLastWeekChampion()
end

-- Pays last week's champion once (claim first, then pay; the claim is undone if paying fails).
local function payPrize(player: Player)
	if not champions then return end
	local key = "W" .. (week() - 1)
	local claimed, record = false, nil
	withRetry(function()
		champions:UpdateAsync(key, function(value)
			if type(value) ~= "table" or value.UserId ~= player.UserId or value.Claimed then
				claimed = false
				return nil
			end
			claimed = true
			record = value
			value.Claimed = true
			return value
		end)
	end)
	if not claimed or not record then return end
	local cash = Config.PrizeDunks * Daily.DunkValue(PlayerService.GetVertical(player) or 0)
	local paid = PlayerService.GrantCash(player, cash, "WeeklyChampion", "Gameplay")
		and DailyService.GrantBoost(player, Config.PrizeBoostMinutes)
	if not paid then
		withRetry(function()
			champions:UpdateAsync(key, function(value)
				if type(value) == "table" and value.UserId == player.UserId then value.Claimed = false; return value end
				return nil
			end)
		end)
		return
	end
	DataService.RequestSave(player)
	Analytics.Custom(player, "WeeklyChampionPrize", record.Score)
	local notice = ReplicatedStorage.Remotes:FindFirstChild("SocialNotice")
	if notice and player.Parent == Players then
		notice:FireClient(player, "WeeklyChampion", { Cash = cash, Minutes = Config.PrizeBoostMinutes, Score = record.Score })
	end
end

-- Called (in its own thread) once a player's data is ready.
function WeeklyChampionService.OnPlayerReady(player: Player)
	if not crownConnections[player] then
		crownConnections[player] = player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			crown(player)
		end)
	end
	crown(player)
	local store = board(week())
	if store then
		local ok, value = withRetry(function() return store:GetAsync(tostring(player.UserId)) end)
		if ok and type(value) == "number" and player.Parent == Players then
			player:SetAttribute("WeeklyBest", math.floor(value / SCORE_SCALE))
		end
	end
	payPrize(player)
end

function WeeklyChampionService.Init()
	if initialized then return end
	initialized = true
	folder = ReplicatedStorage:WaitForChild("Contest")
	local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService,
		isStudio and DataConfig.StudioChampionStoreName or DataConfig.ProductionChampionStoreName)
	if ok then champions = store else warn("[WeeklyChampionService] Champion store unavailable: " .. tostring(store)) end
	Players.PlayerRemoving:Connect(function(player)
		local connection = crownConnections[player]
		if connection then connection:Disconnect() end
		crownConnections[player] = nil
	end)
	task.spawn(function()
		while true do
			local refreshed, problem = pcall(refresh)
			if not refreshed then warn("[WeeklyChampionService] Refresh failed: " .. tostring(problem)) end
			task.wait(Config.RefreshSeconds)
		end
	end)
end

-- Refresh the board right after a round so the new scores show quickly.
function WeeklyChampionService.RefreshSoon()
	task.delay(3, function()
		local ok, problem = pcall(refresh)
		if not ok then warn("[WeeklyChampionService] Refresh failed: " .. tostring(problem)) end
	end)
end

return WeeklyChampionService
