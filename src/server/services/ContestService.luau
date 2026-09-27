-- Dunk Contest rounds. On a fixed schedule a round opens for everyone in the server; while
-- it is open, DunkService hands every completed dunk here and five judges score it (see
-- ContestConfig.Judge). Each player's best dunk counts. At the buzzer players are ranked,
-- paid (score tier + placement, priced in dunks) and their contest stats are saved.
--
-- Clients send nothing. The round state is published as attributes on
-- ReplicatedStorage.Contest (Phase, StartsAt, EndsAt, Round, Leader, Results); scorecards
-- and personal results go to each player over ContestScore / ContestResult.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.ContestConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)

local ContestService = {}
local initialized = false
local random = Random.new()
local folder: Folder? = nil
local scoreRemote: RemoteEvent? = nil
local resultRemote: RemoteEvent? = nil
local phase = "Idle"
local round = 0
-- This round's entrants: best total, when it was set (earlier wins ties), display name.
local entries: { [Player]: { Best: number, At: number, Name: string } } = {}
local judgedCount = 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function ranked()
	local list = {}
	for player, entry in entries do
		table.insert(list, { Player = player, Best = entry.Best, At = entry.At, Name = entry.Name })
	end
	table.sort(list, function(first, second)
		if first.Best ~= second.Best then return first.Best > second.Best end
		return first.At < second.At
	end)
	return list
end

local function publishLeader()
	local leader = ranked()[1]
	folder:SetAttribute("Leader", leader and HttpService:JSONEncode({ Name = leader.Name, Score = leader.Best }) or "")
end

local function setPhase(value: string)
	phase = value
	folder:SetAttribute("Phase", value)
end

-- Called by DunkService after a completed, rewarded dunk.
function ContestService.OnDunk(player: Player, styleId: string, rating: string?, tricks: { string })
	if phase ~= "Open" or not PlayerService.IsDataReady(player) then return end
	local cards = Config.Judge(styleId, tricks, rating, random)
	local total = Config.Total(cards)
	local entry = entries[player]
	local newBest = not entry or total > entry.Best
	if newBest then
		entries[player] = { Best = total, At = os.clock(), Name = player.DisplayName }
		player:SetAttribute("ContestBest", total)
		publishLeader()
	end
	judgedCount += 1
	-- Everyone's crowd reacts to big scores; the sequence number makes each one a change.
	player:SetAttribute("ContestJudged", string.format("%d:%d", judgedCount, total))
	if scoreRemote then scoreRemote:FireClient(player, cards, total, entries[player].Best, newBest) end
end

local function finishRound()
	local list = ranked()
	local contested = #list >= 2
	local podium = {}
	for rank, entry in list do
		if rank <= 3 then podium[rank] = { Name = entry.Name, Score = entry.Best } end
	end
	folder:SetAttribute("Results", HttpService:JSONEncode(podium))
	for rank, entry in list do
		local player = entry.Player
		if player.Parent == Players and PlayerService.IsDataReady(player) then
			local tier = Config.Tier(entry.Best)
			local dunks = (tier and tier.Dunks or 0) + (contested and Config.PlacementDunks[rank] or 0)
			local cash = math.floor(dunks * Daily.DunkValue(PlayerService.GetVertical(player) or 0) + 0.5)
			local paid = cash > 0 and PlayerService.GrantCash(player, cash)
			local won = contested and rank == 1
			PlayerService.RecordContest(player, entry.Best, won)
			DataService.RequestSave(player)
			if resultRemote then
				resultRemote:FireClient(player, {
					Rank = rank, Entrants = #list, Score = entry.Best, Cash = paid and cash or 0,
					Tier = tier and tier.Name or nil, Won = won,
				})
			end
		end
	end
end

local function waitUntil(time: number)
	while now() < time do task.wait(0.25) end
end

function ContestService.Init()
	if initialized then return end
	initialized = true
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	scoreRemote = remotes:WaitForChild("ContestScore")
	resultRemote = remotes:WaitForChild("ContestResult")
	folder = ReplicatedStorage:WaitForChild("Contest")
	folder:SetAttribute("OpenSeconds", Config.OpenSeconds)

	task.spawn(function()
		local startsAt = now() + (RunService:IsStudio() and Config.StudioFirstDelaySeconds or Config.FirstDelaySeconds)
		while true do
			setPhase("Idle")
			folder:SetAttribute("StartsAt", startsAt)
			waitUntil(startsAt)

			round += 1
			table.clear(entries)
			for _, player in Players:GetPlayers() do player:SetAttribute("ContestBest", nil) end
			folder:SetAttribute("Round", round)
			folder:SetAttribute("Leader", "")
			folder:SetAttribute("EndsAt", startsAt + Config.OpenSeconds)
			setPhase("Open")
			waitUntil(startsAt + Config.OpenSeconds)

			setPhase("Results")
			local ok, problem = pcall(finishRound)
			if not ok then warn("[ContestService] Results failed: " .. tostring(problem)) end
			task.wait(Config.ResultsSeconds)
			repeat startsAt += Config.IntervalSeconds until startsAt > now() + Config.AnnounceSeconds
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
		if phase == "Open" then publishLeader() end
	end)
end

return ContestService
