-- Watches each player's progress for the milestones in MilestoneConfig: awards badges and
-- logs the analytics onboarding and progression funnels. Everything is worked out from
-- progress the game already saves, so nothing new is stored. On join, badges the player
-- already qualifies for (but doesn't own) are awarded too. Badges with id 0 are skipped.
-- The onboarding funnel (Milestones.Onboarding) also has three steps the server sees happen
-- during the session: Moved (checked here), DunkTry (DunkService) and FirstRep
-- (TrainingService). Each step is logged at most once per session, always in order.
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Milestones = require(ReplicatedStorage.Shared.Config.MilestoneConfig)
local PlayerService = require(script.Parent.PlayerService)
local Analytics = require(script.Parent.AnalyticsReporter)

local MilestoneService = {}

-- Player attributes that can change a milestone; a slow sweep also catches court unlocks.
local WATCHED = { "TotalDunks", "BestVertical", "TrainingLevel", "Rebirths", "ContestWins", "HasBasketball", "CurrentCourt" }
local SWEEP_SECONDS = 5
-- How often onboarding players are checked for the Moved step.
local MOVE_CHECK_SECONDS = 1
local isStudio = RunService:IsStudio()
local initialized = false

type Entry = {
	Badges: { [string]: boolean },
	Onboarding: boolean,
	-- Highest onboarding funnel step logged this session.
	OnboardingLogged: number,
	-- Funnel steps the server saw happen this session (Moved, DunkTry, FirstRep), by index.
	Reached: { [number]: boolean },
	-- Moved check: the character being watched and where it was first seen.
	MoveCharacter: Model?,
	MoveOrigin: Vector3?,
	ProgressionLogged: number,
	Connections: { RBXScriptConnection },
}
local entries: { [Player]: Entry } = {}

local function withRetry(callback: () -> any): (boolean, any)
	local ok, result = false, nil
	for attempt = 1, 3 do
		ok, result = pcall(callback)
		if ok then return true, result end
		if attempt < 3 then task.wait(attempt * 2) end
	end
	return false, result
end

local function awardBadge(player: Player, badge)
	if badge.Id == 0 then
		if isStudio then print(string.format("[Badges] %s earned \"%s\" (no badge id set yet)", player.Name, badge.Name)) end
		return
	end
	local ok, result = withRetry(function() return BadgeService:AwardBadgeAsync(player.UserId, badge.Id) end)
	if not ok then
		warn(string.format("[Badges] Could not award %s to %s: %s", badge.Key, player.Name, tostring(result)))
	elseif result == false then
		warn(string.format("[Badges] %s was not awarded to %s (is the badge enabled?)", badge.Key, player.Name))
	elseif isStudio then
		print(string.format("[Badges] Awarded \"%s\" to %s", badge.Name, player.Name))
	end
end

-- Awards badges the player qualified for before (e.g. before badges existed) but doesn't own.
local function awardMissingBadges(player: Player, earned)
	local ids = {}
	for _, badge in earned do
		if badge.Id ~= 0 then table.insert(ids, badge.Id) end
	end
	if #ids == 0 then
		for _, badge in earned do awardBadge(player, badge) end -- Studio notes only
		return
	end
	local ok, owned = withRetry(function() return BadgeService:CheckUserBadgesAsync(player.UserId, ids) end)
	if not ok then
		warn("[Badges] Could not check owned badges for " .. player.Name .. ": " .. tostring(owned))
		return
	end
	local ownedSet = {}
	for _, id in owned do ownedSet[id] = true end
	for _, badge in earned do
		if player.Parent ~= Players then return end
		if badge.Id ~= 0 and not ownedSet[badge.Id] then awardBadge(player, badge) end
	end
end

-- Logs every onboarding funnel step the player has now reached, in order. A done tutorial
-- step (from saved progress) implies every funnel step before it, so missing earlier steps
-- are logged first; a step seen this session (Moved, DunkTry, FirstRep) is logged once the
-- step before it has been.
local function logOnboarding(player: Player, entry: Entry, snapshot)
	local reached = entry.OnboardingLogged
	local done = Milestones.TutorialStepsDone(snapshot)
	if done > 0 then
		reached = math.max(reached, Milestones.OnboardingStep(Milestones.Tutorial[done].Id) or 0)
	end
	while entry.Reached[reached + 1] do
		reached += 1
	end
	for step = entry.OnboardingLogged + 1, reached do
		Analytics.OnboardingStep(player, step, Milestones.Onboarding[step])
	end
	entry.OnboardingLogged = math.max(entry.OnboardingLogged, reached)
	if entry.OnboardingLogged >= #Milestones.Onboarding then
		entry.Onboarding = false
		Analytics.Custom(player, "TutorialComplete")
	end
end

local function check(player: Player)
	local entry = entries[player]
	local snapshot = entry and PlayerService.GetMilestoneSnapshot(player)
	if not snapshot then return end
	for _, badge in Milestones.Badges do
		if not entry.Badges[badge.Key] and badge.Done(snapshot) then
			entry.Badges[badge.Key] = true
			task.spawn(awardBadge, player, badge)
		end
	end
	if entry.Onboarding then logOnboarding(player, entry, snapshot) end
	local reached = Milestones.ProgressionReached(snapshot)
	if reached > entry.ProgressionLogged then
		entry.ProgressionLogged = reached
		Analytics.ProgressionStep(player, reached, Milestones.Progression[reached].Id)
	end
end

local function safeCheck(player: Player)
	local ok, problem = pcall(check, player)
	if not ok then warn("[MilestoneService] Check failed: " .. tostring(problem)) end
end

-- Records an onboarding step the server saw happen (once per session) and logs what it can.
local function reach(player: Player, stepName: string)
	local entry = entries[player]
	local step = Milestones.OnboardingStep(stepName)
	if not entry or not entry.Onboarding or not step or entry.Reached[step] or entry.OnboardingLogged >= step then
		return
	end
	entry.Reached[step] = true
	safeCheck(player)
end

-- Moved: the character has walked MoveStuds (flat) from where it was first seen once the
-- player was ready (after court placement). A respawned character starts a new check.
local function checkMoved(player: Player, entry: Entry)
	local step = Milestones.OnboardingStep("Moved")
	if not entry.Onboarding or not step or entry.Reached[step] or entry.OnboardingLogged >= step
		or not PlayerService.IsReady(player) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	if entry.MoveCharacter ~= character or not entry.MoveOrigin then
		entry.MoveCharacter = character
		entry.MoveOrigin = root.Position
		return
	end
	local offset = root.Position - entry.MoveOrigin
	if Vector3.new(offset.X, 0, offset.Z).Magnitude >= Milestones.MoveStuds then
		reach(player, "Moved")
	end
end

-- DunkService: a dunk request reached the server while the player held a ball.
function MilestoneService.OnDunkRequest(player: Player)
	reach(player, "DunkTry")
end

-- TrainingService: a training rep counted (station or Auto Train).
function MilestoneService.OnTrainingRep(player: Player)
	reach(player, "FirstRep")
end

-- Called once the player's saved data has loaded.
function MilestoneService.OnPlayerReady(player: Player)
	local snapshot = PlayerService.GetMilestoneSnapshot(player)
	if not snapshot or entries[player] then return end
	local entry: Entry = { Badges = {}, Onboarding = false, OnboardingLogged = 0, Reached = {}, MoveCharacter = nil,
		MoveOrigin = nil, ProgressionLogged = 0, Connections = {} }
	entries[player] = entry

	local earned = {}
	for _, badge in Milestones.Badges do
		if badge.Done(snapshot) then
			entry.Badges[badge.Key] = true
			table.insert(earned, badge)
		end
	end
	task.spawn(awardMissingBadges, player, earned)

	if Milestones.TutorialActive(snapshot) then
		-- Returning players also log the steps their saved progress already implies.
		entry.Onboarding = true
		Analytics.OnboardingStep(player, 1, Milestones.Onboarding[1])
		entry.OnboardingLogged = 1
		logOnboarding(player, entry, snapshot)
	end
	local reached = Milestones.ProgressionReached(snapshot)
	if reached > 0 then Analytics.ProgressionStep(player, reached, Milestones.Progression[reached].Id) end
	entry.ProgressionLogged = reached

	for _, attribute in WATCHED do
		table.insert(entry.Connections, player:GetAttributeChangedSignal(attribute):Connect(function() safeCheck(player) end))
	end
end

function MilestoneService.Init()
	if initialized then return end
	initialized = true
	Players.PlayerRemoving:Connect(function(player)
		local entry = entries[player]
		entries[player] = nil
		if entry then
			for _, connection in entry.Connections do connection:Disconnect() end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(SWEEP_SECONDS)
			for player in entries do safeCheck(player) end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(MOVE_CHECK_SECONDS)
			for player, entry in entries do
				local ok, problem = pcall(checkMoved, player, entry)
				if not ok then warn("[MilestoneService] Move check failed: " .. tostring(problem)) end
			end
		end
	end)
end

return MilestoneService
