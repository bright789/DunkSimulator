-- Goal tracker (GoalConfig): always one next goal on the player's screen, with its progress
-- and a Cash reward that is paid automatically the moment it's done. Goals are worked out
-- from lifetime progress the game already saves (PlayerService.GetMilestoneSnapshot), so they
-- have no saved data of their own. A goal pays only when the server sees it become done
-- during a session, which can happen once per player:
--   * At join, goals the player already meets are skipped without a reward (met in an
--     earlier session, or before goals existed).
--   * Players still in the new-player tutorial get no goals until it is finished (the card
--     would clash with the tutorial). When it finishes, goals they met during it are paid.
--   * The repeating goal after the chain counts from the dunks the player had when it
--     started this session.
-- Clients send nothing. GoalState (server -> client): ("Goal", goal or nil) where goal is
-- { Text, Progress, From, Target, Reward } (the bar fills from From to Target), and
-- ("Complete", { Text, Cash }) for each paid goal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GoalConfig)
local Milestones = require(ReplicatedStorage.Shared.Config.MilestoneConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.AnalyticsReporter)

local GoalService = {}

-- Player attributes that can finish a goal; a sweep also refreshes the reward shown (it
-- grows with Vertical).
local WATCHED = { "TotalDunks", "BestVertical", "TrainingLevel", "Rebirths", "BestContestScore", "UnlockedCourts" }
local SWEEP_SECONDS = 2
local initialized = false
local remote: RemoteEvent? = nil

type Tracker = {
	-- False while the new-player tutorial is running (no goals yet).
	Armed: boolean,
	-- Chain goals that can't pay this session: already met at join, or paid.
	Done: { [string]: boolean },
	-- Repeating goal: lifetime dunks / RepeatEvery already counted (nil until it starts).
	RepeatBase: number?,
	-- Last goal sent to the client, so unchanged goals aren't re-sent.
	LastSent: string?,
	Connections: { RBXScriptConnection },
}
local trackers: { [Player]: Tracker } = {}

local function rewardFor(rewardDunks: number, vertical: number): number
	return math.max(1, math.floor(rewardDunks * Daily.DunkValue(vertical) + 0.5))
end

local function send(player: Player, tracker: Tracker, goal)
	local key = goal and string.format("%s|%d|%d|%d", goal.Text, goal.Progress, goal.Target, goal.Reward) or "none"
	if tracker.LastSent == key or player.Parent ~= Players or not remote then return end
	tracker.LastSent = key
	remote:FireClient(player, "Goal", goal)
end

-- Pays a finished goal. Returns true if the Cash was added.
local function pay(player: Player, text: string, cash: number, sku: string, index: number): boolean
	if not PlayerService.GrantCash(player, cash, sku, "Gameplay") then return false end
	Analytics.Custom(player, "GoalComplete", index)
	if player.Parent == Players and remote then remote:FireClient(player, "Complete", { Text = text, Cash = cash }) end
	return true
end

-- Pays every goal that just became done, then sends the current goal. Nothing yields.
local function evaluate(player: Player)
	local tracker = trackers[player]
	local snapshot = tracker and PlayerService.GetMilestoneSnapshot(player)
	if not snapshot then return end
	if not tracker.Armed then
		if Milestones.TutorialActive(snapshot) then
			send(player, tracker, nil)
			return
		end
		-- The tutorial just finished: goals met during it are paid below.
		tracker.Armed = true
	end
	local paid = false
	local current = nil
	for index, goal in Config.Chain do
		if not tracker.Done[goal.Id] then
			if Config.IsDone(goal, snapshot) then
				-- Marked first, so a refused payment (Cash limit) can never be retried into a double pay.
				tracker.Done[goal.Id] = true
				paid = pay(player, goal.Text, rewardFor(goal.RewardDunks, snapshot.Vertical), "Goal_" .. goal.Id, index) or paid
			elseif not current then
				current = goal
			end
		end
	end
	local shown = nil
	if current then
		shown = { Text = current.Text, Progress = math.min(Config.Progress(current, snapshot), current.Target), From = 0,
			Target = current.Target, Reward = rewardFor(current.RewardDunks, snapshot.Vertical) }
	else
		-- Chain finished: land the next RepeatEvery dunks, forever.
		local counted = math.floor(snapshot.TotalDunks / Config.RepeatEvery)
		if tracker.RepeatBase == nil then
			tracker.RepeatBase = counted
		elseif counted > tracker.RepeatBase then
			local reached = counted * Config.RepeatEvery
			tracker.RepeatBase = counted
			paid = pay(player, string.format(Config.RepeatText, tostring(reached)),
				rewardFor(Config.RepeatRewardDunks, snapshot.Vertical), "Goal_Repeat", #Config.Chain + 1) or paid
		end
		local target = (tracker.RepeatBase + 1) * Config.RepeatEvery
		shown = { Text = string.format(Config.RepeatText, tostring(target)), Progress = math.min(snapshot.TotalDunks, target),
			From = target - Config.RepeatEvery, Target = target, Reward = rewardFor(Config.RepeatRewardDunks, snapshot.Vertical) }
	end
	if paid then DataService.RequestSave(player) end
	send(player, tracker, shown)
end

local function safeEvaluate(player: Player)
	local ok, problem = pcall(evaluate, player)
	if not ok then warn("[GoalService] Evaluate failed: " .. tostring(problem)) end
end

-- Called once the player's saved data has loaded.
function GoalService.OnPlayerReady(player: Player)
	local snapshot = PlayerService.GetMilestoneSnapshot(player)
	if not snapshot or trackers[player] or player.Parent ~= Players then return end
	local tracker: Tracker = { Armed = false, Done = {}, RepeatBase = nil, LastSent = nil, Connections = {} }
	trackers[player] = tracker
	if not Milestones.TutorialActive(snapshot) then
		-- Goals met before this session were paid then (or came before goals existed).
		tracker.Armed = true
		for _, goal in Config.Chain do
			if Config.IsDone(goal, snapshot) then tracker.Done[goal.Id] = true end
		end
	end
	for _, attribute in WATCHED do
		table.insert(tracker.Connections, player:GetAttributeChangedSignal(attribute):Connect(function()
			safeEvaluate(player)
		end))
	end
	safeEvaluate(player)
end

function GoalService.Init()
	if initialized then return end
	initialized = true
	remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GoalState")
	Players.PlayerRemoving:Connect(function(player)
		local tracker = trackers[player]
		trackers[player] = nil
		if tracker then
			for _, connection in tracker.Connections do connection:Disconnect() end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(SWEEP_SECONDS)
			for player in trackers do safeEvaluate(player) end
		end
	end)
end

return GoalService
