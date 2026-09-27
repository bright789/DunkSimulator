local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local DunkConfig = require(ReplicatedStorage.Shared.Config.DunkConfig)
local DunkStyles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local DunkRewards = require(ReplicatedStorage.Shared.Config.DunkRewards)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local DataService = require(script.Parent.DataService)
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local Challenges = require(ReplicatedStorage.Shared.Config.ChallengeConfig)
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

	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Config.GetJumpHeight(state.Vertical)
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
	player:SetAttribute("CourtTransition", state.CourtTransition)
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
	state.CashDisplay.Value = state.Cash
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

function PlayerService.AwardTraining(player: Player): boolean
	local state = states[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not PlayerService.IsReady(player) or not state or state.DunkState == "Executing"
		or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local level = UpgradeConfig.GetLevel(state.TrainingLevel)
	if not level then
		return false
	end
	local trainingCap = Courts.GetTrainingCap(state.CurrentCourt, state.UnlockedCourts)
	if state.Vertical >= trainingCap then return false end
	local scale = Courts.TrainingProgressScale
	local bonuses = Courts.GetBonuses(state.CurrentCourt, state.UnlockedCourts)
	local earnedUnits = math.floor(Config.Training.BaseProgressPerTick * level.TrainingMultiplier
		* bonuses.TrainingMultiplier * scale + 0.5)
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
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = Config.GetJumpHeight(state.Vertical)
	end
	return true
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
		TrainingMultiplier = current.TrainingMultiplier,
		Cash = state.Cash,
		MaxLevel = #UpgradeConfig.Levels,
		NextLevel = nextLevel and state.TrainingLevel + 1 or nil,
		NextMultiplier = nextLevel and nextLevel.TrainingMultiplier or nil,
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
	player:SetAttribute("TrainingLevel", state.TrainingLevel)
	return true, "TRAINING LEVEL UP!\nLevel " .. tostring(state.TrainingLevel)
end

function PlayerService.RegisterDunk(player: Player, styleId: string, rating: string?): (boolean, number?)
	local state = states[player]
	if not PlayerService.IsReady(player) or not state or state.DunkState ~= "Completed" then
		return false
	end
	local style = DunkStyles.Get(state.EquippedDunkStyle)
	if not style or state.EquippedDunkStyle ~= styleId or not DunkStyles.IsUnlocked(styleId, state.Vertical) then
		return false
	end
	local bonuses = Courts.GetBonuses(state.CurrentCourt, state.UnlockedCourts)
	local cashReward = DunkRewards.DunkCash(style.Reward, bonuses.DunkCashMultiplier, state.Vertical, rating)
	state.Cash = math.min(state.Cash + cashReward, DataConfig.MaxCash)
	state.Dunks += 1
	state.CashDisplay.Value = state.Cash
	player:SetAttribute("Dunks", state.Dunks)
	PlayerService.SetDunkState(player, "Idle")
	return true, cashReward
end

-- Pays one air trick mid-dunk. Only DunkExecution calls this, from its own server
-- timeline, while the dunk is Executing; the amount always comes from shared config.
function PlayerService.AwardDunkTrick(player: Player, trickId: string, comboIndex: number): number?
	local state = states[player]
	if not PlayerService.IsReady(player) or not state or state.DunkState ~= "Executing"
		or not DunkRewards.GetTrick(trickId) or type(comboIndex) ~= "number" or comboIndex % 1 ~= 0
		or comboIndex < 1 or comboIndex > DunkRewards.Tricks.MaxTricks then
		return nil
	end
	local bonuses = Courts.GetBonuses(state.CurrentCourt, state.UnlockedCourts)
	local cash = DunkRewards.TrickCash(trickId, comboIndex, bonuses.DunkCashMultiplier)
	if cash <= 0 or state.Cash > DataConfig.MaxCash - cash then return nil end
	state.Cash += cash
	state.CashDisplay.Value = state.Cash
	return cash
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
