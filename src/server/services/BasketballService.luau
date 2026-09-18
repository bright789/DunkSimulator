local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.DunkConfig)
local PlayerService = require(script.Parent.PlayerService)

type Possession = {
	Character: Model,
	Ball: Part,
	Hand: BasePart,
	Weld: WeldConstraint,
	DeathConnection: RBXScriptConnection,
}

local BasketballService = {}
local possessions: { [Player]: Possession } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}
local nextPickup: { [Player]: number } = {}
local initialized = false

local function clearPossession(player: Player)
	local possession = possessions[player]
	possessions[player] = nil
	if possession then
		possession.DeathConnection:Disconnect()
		possession.Ball:Destroy()
	end
	player:SetAttribute("HasBasketball", false)
end

function BasketballService.HasBall(player: Player): boolean
	local possession = possessions[player]
	if not possession then
		return false
	end
	if possession.Character ~= player.Character or possession.Ball.Parent ~= possession.Character
		or not possession.Hand:IsDescendantOf(possession.Character)
		or possession.Weld.Parent ~= possession.Ball
		or possession.Weld.Part0 ~= possession.Hand or possession.Weld.Part1 ~= possession.Ball then
		clearPossession(player)
		return false
	end
	return true
end

local function pickup(player: Player, station: BasePart, prompt: ProximityPrompt)
	if not PlayerService.IsReady(player) then
		return
	end
	local now = os.clock()
	if now < (nextPickup[player] or 0) then
		return
	end
	nextPickup[player] = now + Config.PickupCooldown
	if BasketballService.HasBall(player) then
		return
	end
	if station.Parent ~= Workspace or station.Name ~= "BasketballPickup" or not station.Anchored
		or prompt.Parent ~= station or not prompt.Enabled then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not character:IsDescendantOf(Workspace) or not humanoid or humanoid.Health <= 0
		or not rootPart or not rootPart:IsA("BasePart") then
		return
	end
	local distance = (rootPart.Position - station.Position).Magnitude
	if not (distance <= math.min(Config.PickupDistance, prompt.MaxActivationDistance)) then
		return
	end
	if prompt.RequiresLineOfSight then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, station }
		if Workspace:Raycast(rootPart.Position, station.Position - rootPart.Position, params) then
			return
		end
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		warn("[BasketballService] Cannot attach basketball: " .. player.Name .. " needs an R15 RightHand or R6 Right Arm.")
		return
	end

	local ball = Instance.new("Part")
	ball.Name = "HeldBasketball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(Config.BallDiameter, Config.BallDiameter, Config.BallDiameter)
	ball.Color = Config.BallColor
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = false
	ball.CanCollide = false
	ball.CanTouch = false
	ball.CanQuery = false
	ball.Massless = true
	ball.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, -Config.BallDiameter / 2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = ball
	weld.Parent = ball
	ball.Parent = character

	possessions[player] = {
		Character = character,
		Ball = ball,
		Hand = hand,
		Weld = weld,
		DeathConnection = humanoid.Died:Connect(function()
			clearPossession(player)
		end),
	}
	player:SetAttribute("HasBasketball", true)
end

local function trackPlayer(player: Player)
	if characterConnections[player] then
		return
	end
	player:SetAttribute("HasBasketball", false)
	characterConnections[player] = player.CharacterRemoving:Connect(function()
		clearPossession(player)
	end)
end

function BasketballService.Init()
	if initialized then
		return
	end
	initialized = true
	Players.PlayerAdded:Connect(trackPlayer)
	Players.PlayerRemoving:Connect(function(player)
		clearPossession(player)
		local connection = characterConnections[player]
		if connection then
			connection:Disconnect()
		end
		characterConnections[player] = nil
		nextPickup[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end

	local station = Workspace:FindFirstChild("BasketballPickup")
	if not station or not station:IsA("BasePart") or not station.Anchored then
		warn("[BasketballService] Create an anchored Part at Workspace.BasketballPickup with a ProximityPrompt directly inside it. Restart Play after setup.")
		return
	end
	local prompt = station:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		warn("[BasketballService] Missing ProximityPrompt directly inside Workspace.BasketballPickup. Add it and restart Play.")
		return
	end
	prompt.ActionText = "Pick Up Basketball"
	prompt.ObjectText = "Basketball"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.PickupDistance
	prompt.Triggered:Connect(function(player)
		pickup(player, station, prompt)
	end)
	print("[BasketballService] Basketball pickup ready.")
end

return BasketballService
