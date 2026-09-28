local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local PlayerService = require(script.Parent.PlayerService)
local GameplayObjects = require(script.Parent.GameplayObjects)
local ChallengeService = require(script.Parent.ChallengeService)
local DailyService = require(script.Parent.DailyService)
local SeasonXp = require(script.Parent.SeasonXp)
local SeasonXpValues = require(ReplicatedStorage.Shared.Config.SeasonConfig).XP

local TrainingService = {}
-- Station training is a beat every TickIntervalSeconds. Beat k happens at
-- FirstBeat + (k - 1) * interval (os.clock). It is paid once late presses for it can no longer
-- arrive (JudgeDelay after the beat), with the rhythm bonus if the player pressed on it.
type TrainingSession = {
	Character: Model,
	Station: BasePart,
	Prompt: ProximityPrompt,
	FirstBeat: number,
	Beat: number,
	Presses: { number },
	LastPress: number,
	Combo: number,
}

local Rhythm = Config.Training.Rhythm
local INTERVAL = Config.Training.TickIntervalSeconds
local JUDGE_DELAY = Rhythm.GoodSeconds + Rhythm.MaxLatencyCompensationSeconds + 0.02

local sessions: { [Player]: TrainingSession } = {}
local nextCapNotice: { [Player]: number } = {}
-- Auto Train pass: next tick time per owner, and the court they were last told is maxed.
local autoNext: { [Player]: number } = {}
local autoCapCourt: { [Player]: string } = {}
local nextAutoToggle: { [Player]: number } = {}
local pulseRemote: RemoteEvent
local initialized = false

local function notifyCap(player: Player)
	local cap = PlayerService.GetTrainingCap(player)
	local vertical = PlayerService.GetVertical(player)
	if not cap or not vertical or vertical < cap or os.clock() < (nextCapNotice[player] or 0) then return end
	nextCapNotice[player] = os.clock() + Config.Training.CapFeedbackCooldownSeconds
	ReplicatedStorage.Remotes.TrainingCapNotice:FireClient(player, PlayerService.GetCurrentCourt(player), cap)
end

local function getValidCharacter(player: Player, station: BasePart, prompt: ProximityPrompt): Model?
	if not PlayerService.IsReady(player) or PlayerService.GetDunkState(player) == "Executing" then
		return nil
	end
	if GameplayObjects.Find(Config.Training.StationName, PlayerService.GetCurrentCourt(player)) ~= station or not station.Anchored
		or prompt.Parent ~= station or not prompt.Enabled then
		return nil
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not character:IsDescendantOf(Workspace) or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	if not rootPart or not rootPart:IsA("BasePart") then
		return nil
	end

	local distance = (rootPart.Position - station.Position).Magnitude
	local maxDistance = math.min(Config.Training.MaxDistance, prompt.MaxActivationDistance)
	if not (distance <= maxDistance) then
		return nil
	end

	if prompt.RequiresLineOfSight then
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { character, station }
		local obstruction = Workspace:Raycast(rootPart.Position, station.Position - rootPart.Position, raycastParams)
		if obstruction then
			return nil
		end
	end

	return character
end

-- Progress hooks shared by station training and Auto Train.
local function afterRep(player: Player)
	local tracked, problem = pcall(ChallengeService.OnVerticalChanged, player)
	if not tracked then warn("[TrainingService] Challenge tracking failed: " .. tostring(problem)) end
	local dailyTracked, dailyProblem = pcall(DailyService.OnTrainingRep, player)
	if not dailyTracked then warn("[TrainingService] Daily tracking failed: " .. tostring(dailyProblem)) end
end

local function beatTime(session: TrainingSession, beat: number): number
	return session.FirstBeat + (beat - 1) * INTERVAL
end

-- Grade for one beat from the presses around it: exactly one press within GoodSeconds is a
-- GOOD or PERFECT rep; no press, a stray press or more than one press (mashing) is a normal rep.
local function judgeBeat(session: TrainingSession, beatAt: number): string?
	local inWindow = {}
	local keep = {}
	for _, press in session.Presses do
		if press <= beatAt + INTERVAL / 2 then
			if press > beatAt - INTERVAL / 2 then table.insert(inWindow, press) end
		else
			table.insert(keep, press)
		end
	end
	session.Presses = keep
	if #inWindow ~= 1 then return nil end
	local delta = math.abs(inWindow[1] - beatAt)
	if delta <= Rhythm.PerfectSeconds then return "Perfect" end
	if delta <= Rhythm.GoodSeconds then return "Good" end
	return nil
end

-- Pays one beat. Returns false when training should stop (cap reached or rep refused).
local function payBeat(player: Player, session: TrainingSession, beatAt: number): boolean
	local grade = judgeBeat(session, beatAt)
	local multiplier = grade == "Perfect" and Rhythm.PerfectMultiplier or grade == "Good" and Rhythm.GoodMultiplier or 1
	local awarded, gain = PlayerService.AwardTraining(player, multiplier)
	if not awarded then return false end
	if grade == "Perfect" then SeasonXp.Add(player, SeasonXpValues.PerfectRep) end
	session.Combo = grade and session.Combo + 1 or 0
	afterRep(player)
	if player.Parent == Players then pulseRemote:FireClient(player, grade, gain, session.Combo) end
	local cap = PlayerService.GetTrainingCap(player)
	return not (cap and PlayerService.GetVertical(player) >= cap)
end

local function stopTraining(player: Player)
	sessions[player] = nil
	-- Presentation-only mirrors so clients can animate the workout and draw the beat.
	if player.Parent == Players then
		player:SetAttribute("Training", nil)
		player:SetAttribute("TrainingBeatAt", nil)
	end
end

local function startTraining(player: Player, station: BasePart, prompt: ProximityPrompt)
	if sessions[player] then
		return
	end
	local character = getValidCharacter(player, station, prompt)
	if character then
		local cap = PlayerService.GetTrainingCap(player)
		if cap and PlayerService.GetVertical(player) >= cap then
			notifyCap(player)
			return
		end
		sessions[player] = {
			Character = character,
			Station = station,
			Prompt = prompt,
			FirstBeat = os.clock() + INTERVAL,
			Beat = 1,
			Presses = {},
			LastPress = -math.huge,
			Combo = 0,
		}
		-- Server time of the first beat; clients draw beat k at TrainingBeatAt + (k - 1) * interval.
		player:SetAttribute("TrainingBeatAt", Workspace:GetServerTimeNow() + INTERVAL)
		player:SetAttribute("Training", true)
	end
end

-- Auto Train (game pass): the same tick as the station, anywhere on the current court, for
-- owners who have it switched on. Skipped while station training, riding the bus or dunking
-- (AwardTraining refuses during a dunk). At the court's cap it pauses quietly after one notice.
-- Auto reps are always normal reps (no rhythm bonus).
local function updateAutoTraining(now: number)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("AutoTrain") == true and not sessions[player] and PlayerService.HasPass(player, "AutoTrain")
			and not player:GetAttribute("TransitRide") and not player:GetAttribute("CourtTransition")
			and now >= (autoNext[player] or 0) then
			autoNext[player] = now + INTERVAL
			local cap = PlayerService.GetTrainingCap(player)
			local court = PlayerService.GetCurrentCourt(player)
			if cap and (PlayerService.GetVertical(player) or 0) >= cap then
				if autoCapCourt[player] ~= court then
					autoCapCourt[player] = court
					notifyCap(player)
				end
			elseif PlayerService.AwardTraining(player) then
				autoCapCourt[player] = nil
				afterRep(player)
			end
		end
	end
end

local function updateSessions()
	local now = os.clock()
	updateAutoTraining(now)
	for player, session in sessions do
		local character = getValidCharacter(player, session.Station, session.Prompt)
		if character ~= session.Character then
			stopTraining(player)
			continue
		end
		while sessions[player] == session and now >= beatTime(session, session.Beat) + JUDGE_DELAY do
			local beatAt = beatTime(session, session.Beat)
			session.Beat += 1
			if not payBeat(player, session, beatAt) then
				notifyCap(player)
				stopTraining(player)
			end
		end
	end
end

-- A rhythm press (no arguments). Stamped with the server clock minus the player's latency.
local function onPulse(player: Player, ...)
	if select("#", ...) ~= 0 then return end
	local session = sessions[player]
	if not session then return end
	local latency = math.clamp(player:GetNetworkPing(), 0, Rhythm.MaxLatencyCompensationSeconds)
	local stamp = os.clock() - latency
	if stamp - session.LastPress < Rhythm.MinPressGapSeconds then return end
	session.LastPress = stamp
	table.insert(session.Presses, stamp)
	if #session.Presses > 6 then table.remove(session.Presses, 1) end
end

function TrainingService.Init()
	if initialized then
		return
	end
	initialized = true
	assert(INTERVAL > 0 and INTERVAL < math.huge, "Training.TickIntervalSeconds must be a finite positive number")
	pulseRemote = ReplicatedStorage.Remotes:WaitForChild("TrainingPulse")
	pulseRemote.OnServerEvent:Connect(onPulse)

	Players.PlayerRemoving:Connect(function(player)
		stopTraining(player)
		nextCapNotice[player] = nil
		autoNext[player] = nil
		autoCapCourt[player] = nil
		nextAutoToggle[player] = nil
	end)
	-- AUTO TRAIN on/off from the HUD. Only pass owners can switch it on.
	ReplicatedStorage.Remotes.AutoTrainRequest.OnServerEvent:Connect(function(player, on)
		if type(on) ~= "boolean" or os.clock() < (nextAutoToggle[player] or 0) then return end
		nextAutoToggle[player] = os.clock() + 0.3
		if PlayerService.HasPass(player, "AutoTrain") then
			player:SetAttribute("AutoTrain", on)
			autoCapCourt[player] = nil
		end
	end)
	GameplayObjects.BindStations(Config.Training.StationName, function(station, prompt)
		prompt.ActionText = "Hold to Train Vertical"
		prompt.ObjectText = "Leg Day Gym"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Config.Training.MaxDistance
		prompt.TriggerEnded:Connect(function(player)
			if sessions[player] and sessions[player].Station == station then stopTraining(player) end
		end)
		prompt.Triggered:Connect(function(player) startTraining(player, station, prompt) end)
		print("[DunkSimulator] Training ready at " .. station:GetFullName() .. ".")
	end)
	RunService.Heartbeat:Connect(updateSessions)
end

TrainingService.Cancel = stopTraining

return TrainingService
