local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local DunkConfig = require(ReplicatedStorage.Shared.Config.DunkConfig)
local DunkStyles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local DunkRewards = require(ReplicatedStorage.Shared.Config.DunkRewards)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.AnalyticsReporter)
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local Challenges = require(ReplicatedStorage.Shared.Config.ChallengeConfig)
local Rebirths = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local Leaderboards = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local Locker = require(ReplicatedStorage.Shared.Config.LockerConfig)
local Monetization = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Events = require(ReplicatedStorage.Shared.Config.EventConfig)
local Abilities = require(ReplicatedStorage.Shared.Config.AbilityConfig)
local Crew = require(ReplicatedStorage.Shared.Config.CrewConfig)
local isStudio = game:GetService("RunService"):IsStudio()
local DataConfig = require(script.Parent.Parent.Config.DataConfig)

type PlayerState = {
	Vertical: number,
	Cash: number,
	TrainingLevel: number,
	VerticalTrainingRemainder: number,
	EquippedDunkStyle: string,
	UnlockedCourts: { [string]: boolean },
	CurrentCourt: string,
	Challenges: { [string]: { Progress: number, Completed: boolean } },
	Rebirths: number,
	-- Daily rewards/challenges record; DailyService is its only writer.
	Daily: { [string]: any },
	-- Lifetime leaderboard stats (BestVertical, TotalDunks, BestDunkCash).
	Stats: { [string]: number },
	-- Owned/equipped shoes and ball skins; LockerService is its only writer.
	Locker: { [string]: any },
	-- Robux passes this player owns (checked by MonetizationService each join; not saved).
	Passes: { [string]: boolean },
	FriendMultiplier: number,
	GroupMultiplier: number,
	Settings: { Music: boolean },
	-- Ability levels (0 = locked); AbilityService is its only writer.
	Abilities: { [string]: number },
	-- When this profile was last saved before this session (welcome-back earnings).
	LastOnline: number,
	-- Hype Crew (owned stars + equipped); CrewService is its only writer.
	Crew: { Owned: { [string]: number }, Equipped: { string } },
	CourtTransition: boolean,
	Dunks: number,
	DunkState: string,
	VerticalDisplay: IntValue,
	CashDisplay: IntValue,
	CharacterConnection: RBXScriptConnection?,
}

local PlayerService = {}
local states: { [Player]: PlayerState } = {}
local initialized = false
local placeCharacter = nil

-- Each court limits how high you jump to its training cap (Neighborhood 75, High School 150,
-- College 250, Rooftop 350) so big jumps never go through a gym ceiling. Only the jump is
-- limited: the saved Vertical, dunk unlocks and payouts all keep using the real Vertical.
local function jumpVertical(state: PlayerState): number
	local court = Courts.Get(state.CurrentCourt)
	local cap = court and court.TrainingVerticalCap or state.Vertical
	return math.min(state.Vertical, cap)
end

local function setJump(player: Player, state: PlayerState, humanoid: Humanoid?)
	local effective = jumpVertical(state)
	player:SetAttribute("JumpVertical", effective)
	if humanoid then
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = Config.GetJumpHeight(effective)
	end
end

local function applyJump(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local state = states[player]
	if not state or player.Character ~= character or player.Parent ~= Players then
		return
	end
	if not humanoid or not humanoid:IsA("Humanoid") then
		warn("[DunkSimulator] Cannot apply jump: missing Humanoid for " .. player.Name)
		return
	end

	setJump(player, state, humanoid)
end

-- "College,HighSchool,Neighborhood" style list of unlocked courts for the HUD goal bar (display only).
local function publishCourts(player: Player, state: PlayerState)
	local ids = {}
	for courtId, unlocked in state.UnlockedCourts do
		if unlocked then table.insert(ids, courtId) end
	end
	table.sort(ids)
	player:SetAttribute("UnlockedCourts", table.concat(ids, ","))
end

local function addPlayer(player: Player, profile)
	if states[player] or player.Parent ~= Players then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local verticalDisplay = Instance.new("IntValue")
	verticalDisplay.Name = "Vertical"
	verticalDisplay.Value = profile.Vertical
	verticalDisplay.Parent = leaderstats

	local cashDisplay = Instance.new("IntValue")
	cashDisplay.Name = "Cash"
	cashDisplay.Value = profile.Cash
	cashDisplay.Parent = leaderstats

	local state: PlayerState = {
		Vertical = profile.Vertical,
		Cash = profile.Cash,
		TrainingLevel = profile.TrainingLevel,
		VerticalTrainingRemainder = profile.VerticalTrainingRemainder,
		EquippedDunkStyle = profile.EquippedDunkStyle,
		UnlockedCourts = table.clone(profile.UnlockedCourts),
		CurrentCourt = profile.CurrentCourt,
		Challenges = Challenges.CopyState(profile.Challenges),
		Rebirths = profile.Rebirths,
		Daily = Daily.CopyState(profile.Daily),
		Stats = Leaderboards.CopyStats(profile.Stats),
		Locker = Locker.CopyState(profile.Locker),
		Passes = {},
		FriendMultiplier = 1,
		GroupMultiplier = 1,
		Settings = { Music = profile.Settings.Music },
		Abilities = Abilities.CopyState(profile.Abilities),
		LastOnline = profile.LastOnline,
		Crew = Crew.CopyState(profile.Crew),
		CourtTransition = placeCharacter ~= nil,
		Dunks = 0,
		DunkState = "Idle",
		VerticalDisplay = verticalDisplay,
		CashDisplay = cashDisplay,
		CharacterConnection = nil,
	}
	states[player] = state
	player:SetAttribute("Dunks", 0)
	player:SetAttribute("DunkState", "Idle")
	player:SetAttribute("TrainingLevel", state.TrainingLevel)
	player:SetAttribute("EquippedDunkStyle", state.EquippedDunkStyle)
	player:SetAttribute("CurrentCourt", state.CurrentCourt)
	publishCourts(player, state)
	player:SetAttribute("CourtTransition", state.CourtTransition)
	player:SetAttribute("Rebirths", state.Rebirths)
	player:SetAttribute("CashBoostUntil", state.Daily.BoostUntil)
	state.Stats.BestVertical = math.max(state.Stats.BestVertical, state.Vertical)
	for _, board in Leaderboards.Boards do
		player:SetAttribute(board.Stat, state.Stats[board.Stat])
	end
	player:SetAttribute("BestContestScore", state.Stats.BestContestScore)
	player:SetAttribute("ContestWins", state.Stats.ContestWins)
	player:SetAttribute("EquippedShoe", state.Locker.Shoes.Equipped)
	player:SetAttribute("BallSkin", state.Locker.Balls.Equipped)
	player:SetAttribute("SettingMusic", state.Settings.Music)
	leaderstats.Parent = player

	state.CharacterConnection = player.CharacterAdded:Connect(function(character)
		if placeCharacter then
			PlayerService.SetCourtTransition(player, true)
			task.spawn(placeCharacter, player, character)
		end
		task.spawn(applyJump, player, character)
	end)
	if player.Character then
		task.spawn(applyJump, player, player.Character)
	end
end

function PlayerService.IsReady(player: Player): boolean
	return PlayerService.IsDataReady(player) and not states[player].CourtTransition
end

function PlayerService.IsDataReady(player: Player): boolean
	return player.Parent == Players and states[player] ~= nil and DataService.IsReady(player)
end

function PlayerService.GetCurrentCourt(player: Player): string
	local state = states[player]
	return state and state.CurrentCourt or Courts.StartingId
end

function PlayerService.SetCourtTransition(player: Player, active: boolean)
	local state = states[player]
	if state then
		state.CourtTransition = active
		player:SetAttribute("CourtTransition", active)
	end
end

function PlayerService.HasCourt(player: Player, courtId: string): boolean
	return PlayerService.IsDataReady(player) and states[player].UnlockedCourts[courtId] == true
end

function PlayerService.SetCurrentCourt(player: Player, courtId: string): boolean
	if not Courts.Get(courtId) or not PlayerService.HasCourt(player, courtId) then return false end
	states[player].CurrentCourt = courtId
	player:SetAttribute("CurrentCourt", courtId)
	setJump(player, states[player], player.Character and player.Character:FindFirstChildOfClass("Humanoid"))
	return true
end

function PlayerService.GetCourtSnapshot(player: Player)
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state then return nil end
	return { Cash = state.Cash, Vertical = state.Vertical, CurrentCourt = state.CurrentCourt,
		UnlockedCourts = table.clone(state.UnlockedCourts) }
end

function PlayerService.BuyCourt(player: Player, courtId: string): (boolean, string, boolean)
	local state = states[player]
	local court = Courts.Get(courtId)
	if not court or not PlayerService.IsReady(player) or not state or state.DunkState ~= "Idle" then
		return false, "Court purchase unavailable.", false
	end
	if state.UnlockedCourts[courtId] then return true, "Already unlocked.", false end
	if state.Vertical < court.Requirements.Vertical then
		return false, string.format("Requires %d Vertical.", court.Requirements.Vertical), false
	end
	if state.Cash < court.Requirements.Cash then return false, "Not enough Cash.", false end
	state.Cash -= court.Requirements.Cash
	state.UnlockedCourts[courtId] = true
	publishCourts(player, state)
	state.CashDisplay.Value = state.Cash
	Analytics.CashSpent(player, court.Requirements.Cash, state.Cash, "Shop", "Court_" .. courtId)
	return true, court.DisplayName .. " UNLOCKED!", true
end

function PlayerService.GetVertical(player: Player): number?
	local state = states[player]
	return state and state.Vertical or nil
end

function PlayerService.GetTrainingCap(player: Player): number?
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state then return nil end
	return Courts.GetTrainingCap(state.CurrentCourt, state.UnlockedCourts)
end

function PlayerService.GetChallengeSnapshot(player: Player)
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state then return nil end
	return {
		Vertical = state.Vertical,
		UnlockedCourts = table.clone(state.UnlockedCourts),
		Challenges = Challenges.CopyState(state.Challenges),
	}
end

function PlayerService.SetChallengeProgress(player: Player, challengeId: string, progress: number): (boolean, boolean)
	local state = states[player]
	local definition = Challenges.Get(challengeId)
	if not PlayerService.IsDataReady(player) or not state or not definition or type(progress) ~= "number"
		or progress ~= progress or math.abs(progress) == math.huge then return false, false end
	local entry = state.Challenges[challengeId]
	if not entry or entry.Completed then return false, false end
	local target = Challenges.Target(definition)
	local nextProgress = math.clamp(math.floor(progress), entry.Progress, target)
	if nextProgress == entry.Progress then return false, false end
	local newlyReady = entry.Progress < target and nextProgress == target
	entry.Progress = nextProgress
	return true, newlyReady
end

function PlayerService.ClaimChallenge(player: Player, challengeId: string): (boolean, number?, string?)
	local state = states[player]
	local definition = Challenges.Get(challengeId)
	if not PlayerService.IsDataReady(player) or not state or not definition then
		return false, nil, "Challenge unavailable."
	end
	local entry = state.Challenges[challengeId]
	local target = Challenges.Target(definition)
	local reward = definition.Reward.Cash
	if not entry or entry.Completed then return false, nil, "Already claimed or unavailable." end
	if entry.Progress < target or (definition.Type == "VerticalReached" and state.Vertical < target) then
		return false, nil, "Challenge not ready to claim."
	end
	if type(reward) ~= "number" or reward % 1 ~= 0 or reward <= 0 or reward > DataConfig.MaxCash
		or state.Cash > DataConfig.MaxCash - reward then
		return false, nil, "Reward unavailable."
	end
	entry.Completed = true
	state.Cash += reward
	state.CashDisplay.Value = state.Cash
	Analytics.CashEarned(player, reward, state.Cash, "Gameplay", "Challenge_" .. challengeId)
	return true, reward, nil
end

function PlayerService.GetDunkState(player: Player): string
	local state = states[player]
	return state and state.DunkState or "Idle"
end

function PlayerService.GetEquippedDunkStyle(player: Player): string?
	local state = states[player]
	return state and state.EquippedDunkStyle or nil
end

function PlayerService.EquipDunkStyle(player: Player, styleId): (boolean, string)
	local state = states[player]
	if not PlayerService.IsReady(player) or not state then
		return false, "Player data is not ready."
	end
	local style = DunkStyles.Get(styleId)
	if not style then
		return false, "Unknown dunk style."
	end
	if state.DunkState ~= "Idle" then
		return false, "Finish your dunk before switching styles."
	end
	if not DunkStyles.IsUnlocked(styleId, state.Vertical) then
		return false, string.format("Requires %d Vertical.", style.RequiredVertical)
	end
	state.EquippedDunkStyle = styleId
	player:SetAttribute("EquippedDunkStyle", styleId)
	return true, style.DisplayName .. " equipped."
end

function PlayerService.SetDunkState(player: Player, dunkState: string)
	local state = states[player]
	if state then
		state.DunkState = dunkState
		player:SetAttribute("DunkState", dunkState)
		if DunkConfig.Execution.DebugLogging then
			print("[DunkService] " .. player.Name .. " -> " .. dunkState)
		end
	end
end

-- One training rep. `repMultiplier` (active-training PERFECT/GOOD, 1-3) scales the gain.
-- Returns whether the rep counted and the Vertical it added (fractional, before rounding).
function PlayerService.AwardTraining(player: Player, repMultiplier: number?): (boolean, number)
	local state = states[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not PlayerService.IsReady(player) or not state or state.DunkState == "Executing"
		or not humanoid or humanoid.Health <= 0 then
		return false, 0
	end

	local level = UpgradeConfig.GetLevel(state.TrainingLevel)
	if not level then
		return false, 0
	end
	local trainingCap = Courts.GetTrainingCap(state.CurrentCourt, state.UnlockedCourts)
	if state.Vertical >= trainingCap then return false, 0 end
	local rep = (type(repMultiplier) == "number" and repMultiplier >= 1 and repMultiplier <= 3) and repMultiplier or 1
	local scale = Courts.TrainingProgressScale
	local bonuses = Courts.GetBonuses(state.CurrentCourt, state.UnlockedCourts)
	local earnedUnits = math.floor(level.VerticalPerRep * bonuses.TrainingMultiplier
		* Rebirths.TrainingMultiplier(state.Rebirths) * Crew.Multipliers(state.Crew).Train * rep * scale + 0.5)
	local remainderUnits = math.floor(state.VerticalTrainingRemainder * scale + 0.5)
	local totalUnits = earnedUnits + remainderUnits
	local wholeGain = math.floor(totalUnits / scale)
	state.VerticalTrainingRemainder = (totalUnits % scale) / scale
	if state.Vertical + wholeGain >= trainingCap then
		wholeGain = trainingCap - state.Vertical
	end
	if wholeGain > 0 then
		state.Vertical += wholeGain
		state.VerticalDisplay.Value = state.Vertical
		if state.Vertical > state.Stats.BestVertical then
			state.Stats.BestVertical = state.Vertical
			player:SetAttribute("BestVertical", state.Vertical)
		end
		setJump(player, state, humanoid)
	end
	return true, earnedUnits / scale
end

function PlayerService.GetTrainingUpgradeSnapshot(player: Player)
	local state = states[player]
	if not PlayerService.IsReady(player) or not state then
		return nil
	end
	local current = UpgradeConfig.GetLevel(state.TrainingLevel)
	if not current then
		return nil
	end
	local nextLevel = UpgradeConfig.GetLevel(state.TrainingLevel + 1)
	return {
		TrainingLevel = state.TrainingLevel,
		VerticalPerRep = current.VerticalPerRep,
		Cash = state.Cash,
		MaxLevel = #UpgradeConfig.Levels,
		NextLevel = nextLevel and state.TrainingLevel + 1 or nil,
		NextVerticalPerRep = nextLevel and nextLevel.VerticalPerRep or nil,
		Price = nextLevel and nextLevel.Cost or nil,
		CanAfford = nextLevel ~= nil and state.Cash >= nextLevel.Cost,
	}
end

function PlayerService.BuyNextTrainingLevel(player: Player): (boolean, string)
	local snapshot = PlayerService.GetTrainingUpgradeSnapshot(player)
	if not snapshot then
		return false, "Invalid request."
	end
	if not snapshot.NextLevel then
		return false, "Max level."
	end
	if not snapshot.CanAfford then
		return false, "Not enough Cash."
	end
	local state = states[player]
	state.Cash -= snapshot.Price
	state.TrainingLevel = snapshot.NextLevel
	state.CashDisplay.Value = state.Cash
	Analytics.CashSpent(player, snapshot.Price, state.Cash, "Shop", "TrainingLevel_" .. state.TrainingLevel)
	player:SetAttribute("TrainingLevel", state.TrainingLevel)
	return true, "TRAINING LEVEL UP!\nLevel " .. tostring(state.TrainingLevel)
end

-- `trickCash` is the air-trick Cash DunkExecution already paid during this dunk (server value).
-- `bonusMultiplier` is DunkService's HEAT x Fireball multiplier (1-3); 1 when there is none.
function PlayerService.RegisterDunk(player: Player, styleId: string, rating: string?, trickCash: number?,
	bonusMultiplier: number?): (boolean, number?)
	local state = states[player]
	if not PlayerService.IsReady(player) or not state or state.DunkState ~= "Completed" then
		return false
	end
	local style = DunkStyles.Get(state.EquippedDunkStyle)
	if not style or state.EquippedDunkStyle ~= styleId or not DunkStyles.IsUnlocked(styleId, state.Vertical) then
		return false
	end
	local bonuses = Courts.GetBonuses(state.CurrentCourt, state.UnlockedCourts)
	local bonus = (type(bonusMultiplier) == "number" and bonusMultiplier >= 1 and bonusMultiplier <= 3)
		and bonusMultiplier or 1
	local cashReward = DunkRewards.DunkCash(style.Reward, bonuses.DunkCashMultiplier * Rebirths.CashMultiplier(state.Rebirths)
		* Daily.BoostMultiplier(state.Daily.BoostUntil, os.time())
		* (state.Passes.DoubleCash and Monetization.DoubleCashMultiplier or 1) * state.FriendMultiplier * state.GroupMultiplier
		* Events.CashMultiplier(os.time(), isStudio) * bonus * Crew.Multipliers(state.Crew).Cash, state.Vertical, rating)
	state.Cash = math.min(state.Cash + cashReward, DataConfig.MaxCash)
	state.Dunks += 1
	state.CashDisplay.Value = state.Cash
	Analytics.CashEarned(player, cashReward, state.Cash, "Gameplay", "Dunk", true)
	player:SetAttribute("Dunks", state.Dunks)
	local stats = state.Stats
	stats.TotalDunks = math.min(stats.TotalDunks + 1, Leaderboards.MaxStat)
	player:SetAttribute("TotalDunks", stats.TotalDunks)
	local payout = cashReward + (type(trickCash) == "number" and trickCash >= 0 and math.floor(trickCash) or 0)
	if payout > stats.BestDunkCash then
		stats.BestDunkCash = math.min(payout, Leaderboards.MaxStat)
		player:SetAttribute("BestDunkCash", stats.BestDunkCash)
	end
	PlayerService.SetDunkState(player, "Idle")
	return true, cashReward
end

-- Pays one air trick mid-dunk. Only DunkExecution calls this, from its own server
-- timeline, while the dunk is Executing; the amount always comes from shared config.
function PlayerService.AwardDunkTrick(player: Player, trickId: string, comboIndex: number): number?
	local state = states[player]
	if not PlayerService.IsReady(player) or not state or state.DunkState ~= "Executing"
		or not DunkRewards.GetTrick(trickId) or type(comboIndex) ~= "number" or comboIndex % 1 ~= 0
		or comboIndex < 1 or comboIndex > DunkRewards.Tricks.MaxTricks + DunkRewards.Tricks.MaxBonusTricks then
		return nil
	end
	local bonuses = Courts.GetBonuses(state.CurrentCourt, state.UnlockedCourts)
	local shoe = Locker.Get("Shoes", state.Locker.Shoes.Equipped)
	local cash = DunkRewards.TrickCash(trickId, comboIndex, bonuses.DunkCashMultiplier
		* Rebirths.CashMultiplier(state.Rebirths) * Daily.BoostMultiplier(state.Daily.BoostUntil, os.time())
		* (1 + (shoe and shoe.TrickBonus or 0)) * (state.Passes.DoubleCash and Monetization.DoubleCashMultiplier or 1)
		* state.FriendMultiplier * state.GroupMultiplier * Events.CashMultiplier(os.time(), isStudio)
		* Crew.Multipliers(state.Crew).Cash)
	if cash <= 0 or state.Cash > DataConfig.MaxCash - cash then return nil end
	state.Cash += cash
	state.CashDisplay.Value = state.Cash
	Analytics.CashEarned(player, cash, state.Cash, "Gameplay", "AirTrick", true)
	return cash
end

-- Lifetime leaderboard stats (a copy) for LeaderboardService.
function PlayerService.GetStats(player: Player)
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state then return nil end
	return Leaderboards.CopyStats(state.Stats)
end

-- Pass ownership from MonetizationService (server-verified). Mirrored to "Pass_<Key>"
-- attributes for the client's store and HUD.
function PlayerService.SetPasses(player: Player, owned: { [string]: boolean })
	local state = states[player]
	if not state then return end
	for _, pass in Monetization.Passes do
		state.Passes[pass.Key] = owned[pass.Key] == true
		player:SetAttribute("Pass_" .. pass.Key, state.Passes[pass.Key])
	end
end

-- Community group Cash bonus (InviteService is its only caller). Not saved.
function PlayerService.SetGroupMultiplier(player: Player, multiplier: number)
	local state = states[player]
	if not state or type(multiplier) ~= "number" or multiplier ~= multiplier or multiplier < 1 or multiplier > 2 then return end
	state.GroupMultiplier = multiplier
end

-- Saved player settings. Returns true if the value changed.
function PlayerService.SetMusicSetting(player: Player, on: boolean): boolean
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state or type(on) ~= "boolean" or state.Settings.Music == on then return false end
	state.Settings.Music = on
	player:SetAttribute("SettingMusic", on)
	return true
end

-- Friends-in-server Cash bonus (InviteService is its only caller). Not saved.
function PlayerService.SetFriendMultiplier(player: Player, multiplier: number)
	local state = states[player]
	if not state or type(multiplier) ~= "number" or multiplier ~= multiplier or multiplier < 1 or multiplier > 2 then return end
	state.FriendMultiplier = multiplier
end

function PlayerService.HasPass(player: Player, key: string): boolean
	local state = states[player]
	return state ~= nil and state.Passes[key] == true
end

-- The live Hype Crew record. Only CrewService may change it, and only without yielding.
function PlayerService.GetCrew(player: Player)
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state then return nil end
	return state.Crew
end

-- Unix time this profile was last saved before this session (0 = never). WelcomeBackService.
function PlayerService.GetLastOnline(player: Player): number?
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state then return nil end
	return state.LastOnline
end

-- The live ability levels (id -> level, 0 = locked). Only AbilityService may change them,
-- and only without yielding.
function PlayerService.GetAbilities(player: Player)
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state then return nil end
	return state.Abilities
end

-- The live locker record. Only LockerService may change it, and only without yielding.
function PlayerService.GetLocker(player: Player)
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state then return nil end
	return state.Locker
end

-- Plain copy of the progress that milestones are worked out from (see MilestoneConfig).
function PlayerService.GetMilestoneSnapshot(player: Player)
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state then return nil end
	return {
		Vertical = state.Vertical,
		BestVertical = state.Stats.BestVertical,
		TotalDunks = state.Stats.TotalDunks,
		TrainingLevel = state.TrainingLevel,
		Rebirths = state.Rebirths,
		ContestWins = state.Stats.ContestWins,
		Cash = state.Cash,
		HasBall = player:GetAttribute("HasBasketball") == true,
		UnlockedCourts = table.clone(state.UnlockedCourts),
	}
end

function PlayerService.GetCash(player: Player): number?
	local state = states[player]
	return state and state.Cash or nil
end

-- Takes a price the server already decided (Locker purchases). Returns false and changes
-- nothing when the amount is invalid or the player can't afford it. `sku` names what was
-- bought, for the analytics economy dashboards.
function PlayerService.SpendCash(player: Player, amount: number, sku: string?): boolean
	local state = states[player]
	if not PlayerService.IsReady(player) or not state or type(amount) ~= "number" or amount ~= amount
		or amount % 1 ~= 0 or amount < 0 or state.Cash < amount then
		return false
	end
	state.Cash -= amount
	state.CashDisplay.Value = state.Cash
	Analytics.CashSpent(player, amount, state.Cash, "Shop", sku or "Shop")
	return true
end

-- Records a finished Dunk Contest round for this player (ContestService only).
function PlayerService.RecordContest(player: Player, score: number, won: boolean)
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state or type(score) ~= "number" then return end
	local stats = state.Stats
	stats.BestContestScore = math.max(stats.BestContestScore, math.clamp(math.floor(score), 0, 50))
	if won then stats.ContestWins = math.min(stats.ContestWins + 1, Leaderboards.MaxStat) end
	player:SetAttribute("BestContestScore", stats.BestContestScore)
	player:SetAttribute("ContestWins", stats.ContestWins)
end

-- The live daily record. Only DailyService may change it, and only without yielding.
function PlayerService.GetDaily(player: Player)
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state then return nil end
	return state.Daily
end

-- What DailyService needs to roll challenges this player can finish.
function PlayerService.GetDailyContext(player: Player)
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state then return nil end
	local highestCap = 0
	for courtId in state.UnlockedCourts do
		local court = Courts.Get(courtId)
		if court then highestCap = math.max(highestCap, court.TrainingVerticalCap) end
	end
	return { Vertical = state.Vertical, UnlockedCourts = table.clone(state.UnlockedCourts), HighestTrainingCap = highestCap }
end

-- Adds a reward amount the server already decided (daily rewards, contest prizes). Refuses
-- anything that is not a whole non-negative number or would pass the Cash limit. `sku` and
-- `transactionType` (an Enum.AnalyticsEconomyTransactionType name) label it for analytics.
function PlayerService.GrantCash(player: Player, amount: number, sku: string?, transactionType: string?): boolean
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state or type(amount) ~= "number" or amount ~= amount
		or amount % 1 ~= 0 or amount < 0 or state.Cash > DataConfig.MaxCash - amount then
		return false
	end
	state.Cash += amount
	state.CashDisplay.Value = state.Cash
	Analytics.CashEarned(player, amount, state.Cash, transactionType or "Gameplay", sku or "Reward")
	return true
end

-- What the Rebirth menu shows; `CanRebirth` is advisory (ApplyRebirth re-checks everything).
function PlayerService.GetRebirthSnapshot(player: Player)
	local state = states[player]
	if not PlayerService.IsDataReady(player) or not state then return nil end
	local requirement = Rebirths.Requirement(state.Rebirths)
	return {
		Rebirths = state.Rebirths,
		MaxRebirths = Rebirths.MaxRebirths,
		Vertical = state.Vertical,
		Cash = state.Cash,
		RequiredVertical = requirement.Vertical,
		RequiredCash = requirement.Cash,
		CashMultiplier = Rebirths.CashMultiplier(state.Rebirths),
		NextCashMultiplier = Rebirths.CashMultiplier(state.Rebirths + 1),
		TrainingMultiplier = Rebirths.TrainingMultiplier(state.Rebirths),
		NextTrainingMultiplier = Rebirths.TrainingMultiplier(state.Rebirths + 1),
		CanRebirth = state.Rebirths < Rebirths.MaxRebirths and state.Vertical >= requirement.Vertical
			and state.Cash >= requirement.Cash,
	}
end

-- Starts the player over (RebirthService has already moved them to the Neighborhood).
-- Validates and applies atomically; nothing yields.
function PlayerService.ApplyRebirth(player: Player): (boolean, string)
	local state = states[player]
	if not PlayerService.IsReady(player) or not state or state.DunkState ~= "Idle" then
		return false, "Finish what you're doing first."
	end
	if state.CurrentCourt ~= Courts.StartingId then return false, "Travel unavailable." end
	if state.Rebirths >= Rebirths.MaxRebirths then return false, "Max rebirths reached." end
	local requirement = Rebirths.Requirement(state.Rebirths)
	if state.Vertical < requirement.Vertical then
		return false, string.format("Requires %d Vertical.", requirement.Vertical)
	end
	if state.Cash < requirement.Cash then return false, "Not enough Cash." end
	local cashGivenUp = state.Cash - Config.StartingCash
	state.Rebirths += 1
	state.Cash = Config.StartingCash
	state.Vertical = Config.StartingVertical
	state.TrainingLevel = UpgradeConfig.StartingLevel
	state.VerticalTrainingRemainder = 0
	state.UnlockedCourts = Courts.DefaultUnlocks()
	publishCourts(player, state)
	state.CurrentCourt = Courts.StartingId
	state.EquippedDunkStyle = DunkStyles.ResolveEquipped(state.EquippedDunkStyle, state.Vertical)
	state.CashDisplay.Value = state.Cash
	state.VerticalDisplay.Value = state.Vertical
	Analytics.CashSpent(player, cashGivenUp, state.Cash, "Gameplay", "Rebirth")
	Analytics.Custom(player, "Rebirth", state.Rebirths)
	player:SetAttribute("Rebirths", state.Rebirths)
	player:SetAttribute("TrainingLevel", state.TrainingLevel)
	player:SetAttribute("EquippedDunkStyle", state.EquippedDunkStyle)
	player:SetAttribute("CurrentCourt", state.CurrentCourt)
	setJump(player, state, player.Character and player.Character:FindFirstChildOfClass("Humanoid"))
	return true, string.format("REBIRTH %d!", state.Rebirths)
end

function PlayerService.Init(onReady, onDataReady)
	if initialized then
		return
	end
	initialized = true
	placeCharacter = onReady

	DataService.Init({
		Initialize = addPlayer,
		Ready = function(player)
			if onDataReady then
				local success, problem = pcall(onDataReady, player)
				if not success then warn("[PlayerService] Ready callback failed: " .. tostring(problem)) end
			end
			if onReady then onReady(player, player.Character) end
		end,
		Snapshot = function(player: Player)
			local state = states[player]
			if not state then
				return nil
			end
			return {
				Cash = state.Cash,
				Vertical = state.Vertical,
				TrainingLevel = state.TrainingLevel,
				VerticalTrainingRemainder = state.VerticalTrainingRemainder,
				EquippedDunkStyle = state.EquippedDunkStyle,
				UnlockedCourts = table.clone(state.UnlockedCourts),
				CurrentCourt = state.CurrentCourt,
				Challenges = Challenges.CopyState(state.Challenges),
				Rebirths = state.Rebirths,
				Daily = Daily.CopyState(state.Daily),
				Stats = Leaderboards.CopyStats(state.Stats),
				Locker = Locker.CopyState(state.Locker),
				Settings = { Music = state.Settings.Music },
				Abilities = Abilities.CopyState(state.Abilities),
				-- Every save stamps "now", so time away is measured from the last save.
				LastOnline = os.time(),
				Crew = Crew.CopyState(state.Crew),
			}
		end,
		Cleanup = function(player: Player)
			local state = states[player]
			if state and state.CharacterConnection then
				state.CharacterConnection:Disconnect()
			end
			states[player] = nil
		end,
	})
end

return PlayerService
