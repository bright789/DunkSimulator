local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local PlayerService = require(script.Parent.PlayerService)
local GameplayObjects = require(script.Parent.GameplayObjects)
local remotes = ReplicatedStorage.Remotes

local UpgradeService = {}
local sessions = {}
local nextRequest = {}
local nextPurchase = {}
local initialized = false

local function close(player: Player)
	sessions[player] = nil
	if player.Parent == Players then
		remotes.TrainingUpgradeState:FireClient(player, "Close")
	end
end

local function validCharacter(player: Player, station: BasePart, prompt: ProximityPrompt): Model?
	if not PlayerService.IsReady(player) or PlayerService.GetDunkState(player) == "Executing"
		or GameplayObjects.Find(Config.StationName) ~= station or not station.Anchored
		or prompt.Parent ~= station or not prompt.Enabled then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not character:IsDescendantOf(Workspace) or not humanoid or humanoid.Health <= 0
		or not root or not root:IsA("BasePart") then
		return nil
	end
	if not ((root.Position - station.Position).Magnitude <= math.min(Config.MaxDistance, prompt.MaxActivationDistance)) then
		return nil
	end
	if prompt.RequiresLineOfSight then
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = { character, station }
		if Workspace:Raycast(root.Position, station.Position - root.Position, parameters) then
			return nil
		end
	end
	return character
end

local function publish(player: Player, kind: string, message: string?, purchased: boolean?)
	local session = sessions[player]
	local snapshot = PlayerService.GetTrainingUpgradeSnapshot(player)
	if not session or not snapshot then
		close(player)
		return
	end
	snapshot.OfferId = session.OfferId
	snapshot.CanPurchase = not session.Processing and os.clock() >= (nextPurchase[player] or 0)
	session.LastCash = snapshot.Cash
	session.LastLevel = snapshot.TrainingLevel
	session.LastReady = snapshot.CanPurchase
	remotes.TrainingUpgradeState:FireClient(player, kind, snapshot, message, purchased)
end

function UpgradeService.Init()
	if initialized then
		return
	end
	initialized = true
	local station = GameplayObjects.Find(Config.StationName)
	local prompt = station and station:FindFirstChildOfClass("ProximityPrompt")
	if not station or not station:IsA("BasePart") or not station.Anchored or not prompt then
		warn("[UpgradeService] Upgrades unavailable: create Workspace.Gameplay.UpgradeStation (anchored Part) with a direct ProximityPrompt, then restart Play. See docs/TRAINING_UPGRADES.md.")
		return
	end
	prompt.ActionText = "Upgrades"
	prompt.ObjectText = "Training Upgrades"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.MaxDistance
	prompt.Triggered:Connect(function(player)
		local now = os.clock()
		if now < (nextRequest[player] or 0) then
			return
		end
		nextRequest[player] = now + Config.RequestCooldownSeconds
		local character = validCharacter(player, station, prompt)
		if not character then
			return
		end
		if sessions[player] and sessions[player].Character ~= character then
			sessions[player] = nil
		end
		if not sessions[player] then
			sessions[player] = {
				Character = character,
				OfferId = HttpService:GenerateGUID(false),
				Processing = false,
			}
		end
		publish(player, "Open")
	end)
	remotes.TrainingUpgradeRequest.OnServerEvent:Connect(function(player, action, offerId, ...)
		local session = sessions[player]
		if not session then
			return
		end
		if action == "Close" then
			close(player)
			return
		end
		local now = os.clock()
		if session.Processing or now < (nextPurchase[player] or 0) then
			return
		end
		nextPurchase[player] = now + Config.RequestCooldownSeconds
		if validCharacter(player, station, prompt) ~= session.Character then
			close(player)
			return
		end
		if action ~= "Buy" or type(offerId) ~= "string" or offerId ~= session.OfferId or select("#", ...) ~= 0 then
			publish(player, "Result", "Invalid request.", false)
			return
		end
		session.Processing = true
		session.OfferId = HttpService:GenerateGUID(false)
		local succeeded, purchased, message = pcall(PlayerService.BuyNextTrainingLevel, player)
		session.Processing = false
		if not succeeded then
			warn("[UpgradeService] Purchase failed: " .. tostring(purchased))
			publish(player, "Result", "Upgrade unavailable. Try again.", false)
			return
		end
		publish(player, "Result", message, purchased)
	end)
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextCheck then
			return
		end
		nextCheck = now + Config.SessionCheckSeconds
		for player, session in sessions do
			if validCharacter(player, station, prompt) ~= session.Character then
				close(player)
			else
				local snapshot = PlayerService.GetTrainingUpgradeSnapshot(player)
				local ready = not session.Processing and now >= (nextPurchase[player] or 0)
				if not snapshot then
					close(player)
				elseif snapshot.Cash ~= session.LastCash or snapshot.TrainingLevel ~= session.LastLevel or ready ~= session.LastReady then
					publish(player, "Update")
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		nextRequest[player] = nil
		nextPurchase[player] = nil
	end)
	print("[UpgradeService] Training upgrades ready at " .. station:GetFullName())
end

return UpgradeService
