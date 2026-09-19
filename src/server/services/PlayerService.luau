local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local DunkConfig = require(ReplicatedStorage.Shared.Config.DunkConfig)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)

type PlayerState = {
	Vertical: number,
	Cash: number,
	TrainingLevel: number,
	Dunks: number,
	DunkState: string,
	VerticalDisplay: IntValue,
	CashDisplay: IntValue,
	CharacterConnection: RBXScriptConnection?,
}

local PlayerService = {}
local states: { [Player]: PlayerState } = {}
local initialized = false

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

local function addPlayer(player: Player)
	if states[player] or player.Parent ~= Players then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local verticalDisplay = Instance.new("IntValue")
	verticalDisplay.Name = "Vertical"
	verticalDisplay.Value = Config.StartingVertical
	verticalDisplay.Parent = leaderstats

	local cashDisplay = Instance.new("IntValue")
	cashDisplay.Name = "Cash"
	cashDisplay.Value = Config.StartingCash
	cashDisplay.Parent = leaderstats

	local state: PlayerState = {
		Vertical = Config.StartingVertical,
		Cash = Config.StartingCash,
		TrainingLevel = UpgradeConfig.StartingLevel,
		Dunks = 0,
		DunkState = "Idle",
		VerticalDisplay = verticalDisplay,
		CashDisplay = cashDisplay,
		CharacterConnection = nil,
	}
	states[player] = state
	player:SetAttribute("Dunks", 0)
	player:SetAttribute("DunkState", "Idle")
	leaderstats.Parent = player

	state.CharacterConnection = player.CharacterAdded:Connect(function(character)
		applyJump(player, character)
	end)
	if player.Character then
		task.spawn(applyJump, player, player.Character)
	end
end

function PlayerService.IsReady(player: Player): boolean
	return player.Parent == Players and states[player] ~= nil
end

function PlayerService.GetDunkState(player: Player): string
	local state = states[player]
	return state and state.DunkState or "Idle"
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
	state.Vertical += level.VerticalGain
	state.VerticalDisplay.Value = state.Vertical
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Config.GetJumpHeight(state.Vertical)
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
		VerticalGain = current.VerticalGain,
		Cash = state.Cash,
		MaxLevel = #UpgradeConfig.Levels,
		NextLevel = nextLevel and state.TrainingLevel + 1 or nil,
		NextGain = nextLevel and nextLevel.VerticalGain or nil,
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
	return true, "TRAINING LEVEL UP!\nLevel " .. tostring(state.TrainingLevel)
end

function PlayerService.RegisterDunk(player: Player): boolean
	local state = states[player]
	if not PlayerService.IsReady(player) or not state or state.DunkState ~= "Completed" then
		return false
	end
	state.Cash += DunkConfig.DunkCashReward
	state.Dunks += 1
	state.CashDisplay.Value = state.Cash
	player:SetAttribute("Dunks", state.Dunks)
	return true
end

function PlayerService.Init()
	if initialized then
		return
	end
	initialized = true

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if state and state.CharacterConnection then
			state.CharacterConnection:Disconnect()
		end
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
end

return PlayerService
