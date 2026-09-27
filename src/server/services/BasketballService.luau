local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.DunkConfig)
local DribbleConfig = require(ReplicatedStorage.Shared.Config.DribbleConfig)
local PlayerService = require(script.Parent.PlayerService)
local GameplayObjects = require(script.Parent.GameplayObjects)

type Possession = {
	Character: Model,
	Ball: Part,
	Hand: BasePart,
	Weld: WeldConstraint,
	DeathConnection: RBXScriptConnection,
	Mode: string,
	Phase: number,
	UpdateAccumulator: number,
	EntryElapsed: number,
	BaseOffset: Vector3,
	GatherFrom: CFrame,
	GatherElapsed: number,
	FloorRaycast: RaycastParams,
}

local BasketballService = {}
local possessions: { [Player]: Possession } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}
local nextPickup: { [Player]: number } = {}
local initialized = false

local function setMode(player: Player, possession: Possession, mode: string)
	if possession.Mode ~= mode then
		possession.Mode = mode
		player:SetAttribute("BasketballAction", mode)
	end
end

local function clearPossession(player: Player)
	local possession = possessions[player]
	possessions[player] = nil
	if possession then
		possession.DeathConnection:Disconnect()
		possession.Ball:Destroy()
	end
	player:SetAttribute("HasBasketball", false)
	player:SetAttribute("BasketballAction", "NoBall")
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

function BasketballService.GetBall(player: Player): Part?
	return BasketballService.HasBall(player) and possessions[player].Ball or nil
end

function BasketballService.GetHeldCFrame(player: Player): CFrame?
	if not BasketballService.HasBall(player) then
		return nil
	end
	local hand = possessions[player].Hand
	return hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, -Config.BallDiameter / 2)
end

local function attachBall(possession: Possession)
	if possession.Weld.Enabled and not possession.Ball.Anchored then return end
	possession.Ball.CFrame = possession.Hand.CFrame
		* CFrame.new(0, -possession.Hand.Size.Y / 2, -Config.BallDiameter / 2)
	possession.Ball.Anchored = false
	possession.Ball.AssemblyLinearVelocity = Vector3.zero
	possession.Ball.AssemblyAngularVelocity = Vector3.zero
	possession.Weld.Enabled = true
end

local function gatherBall(player: Player, possession: Possession, deltaTime: number)
	if possession.Mode == "Dribbling" then
		possession.GatherFrom = possession.Ball.CFrame
		possession.GatherElapsed = 0
	end
	setMode(player, possession, "Gathering")
	if possession.Weld.Enabled then return end
	possession.GatherElapsed = math.min(possession.GatherElapsed + deltaTime, DribbleConfig.GatherSeconds)
	local progress = possession.GatherElapsed / DribbleConfig.GatherSeconds
	local eased = progress * progress * (3 - 2 * progress)
	local held = possession.Hand.CFrame * CFrame.new(0, -possession.Hand.Size.Y / 2, -Config.BallDiameter / 2)
	possession.Ball.CFrame = possession.GatherFrom:Lerp(held, eased)
	if progress >= 1 then attachBall(possession) end
end

local function dribbleBall(player: Player, possession: Possession, humanoid: Humanoid, root: BasePart, deltaTime: number)
	if possession.Mode ~= "Dribbling" then
		possession.Weld.Enabled = false
		possession.Ball.Anchored = true
		possession.Phase = 0
		possession.UpdateAccumulator = DribbleConfig.UpdateIntervalSeconds
		possession.EntryElapsed = 0
		local held = possession.Hand.CFrame * CFrame.new(0, -possession.Hand.Size.Y / 2, -Config.BallDiameter / 2)
		possession.BaseOffset = root.CFrame:PointToObjectSpace(held.Position)
		setMode(player, possession, "Dribbling")
	end
	possession.UpdateAccumulator += deltaTime
	if possession.UpdateAccumulator < DribbleConfig.UpdateIntervalSeconds then return end
	local elapsed = math.min(possession.UpdateAccumulator, 0.1)
	possession.UpdateAccumulator = 0
	possession.EntryElapsed = math.min(possession.EntryElapsed + elapsed, DribbleConfig.EntryBlendSeconds)
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local cadence = speed >= DribbleConfig.RunSpeedThreshold and DribbleConfig.RunCadence
		or (speed >= DribbleConfig.WalkSpeedThreshold and DribbleConfig.WalkCadence or DribbleConfig.IdleCadence)
	possession.Phase = (possession.Phase + elapsed * cadence) % 1
	local heldPosition = root.CFrame:PointToWorldSpace(possession.BaseOffset)
		+ Vector3.new(0, DribbleConfig.TopLift * possession.EntryElapsed / DribbleConfig.EntryBlendSeconds, 0)
	local facing = root.CFrame.LookVector
	local horizontal = Vector3.new(heldPosition.X - root.Position.X, 0, heldPosition.Z - root.Position.Z)
		+ Vector3.new(facing.X, 0, facing.Z) * DribbleConfig.ForwardOffset
	local floorOrigin = root.Position + horizontal + Vector3.new(0, DribbleConfig.FloorProbeAboveRoot, 0)
	local floor = Workspace:Raycast(floorOrigin, Vector3.new(0, -DribbleConfig.FloorProbeDistance, 0), possession.FloorRaycast)
	local floorHeight = floor and floor.Position.Y or root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
	local bounceHeight = floorHeight + Config.BallDiameter / 2 + DribbleConfig.FloorClearance
	if heldPosition.Y - bounceHeight < DribbleConfig.MinimumBounceTravel then
		attachBall(possession)
		setMode(player, possession, "Holding")
		return
	end
	local bounce = (1 - math.cos(possession.Phase * math.pi * 2)) / 2
	local bottom = Vector3.new(root.Position.X + horizontal.X, bounceHeight, root.Position.Z + horizontal.Z)
	local position = heldPosition:Lerp(bottom, bounce)
	possession.Ball.CFrame = CFrame.new(position)
end

local function updatePossessions(deltaTime: number)
	for player, possession in possessions do
		if not BasketballService.HasBall(player) then continue end
		if possession.Mode == "Dunking" then continue end
		local character = possession.Character
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if player.Parent ~= Players or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			clearPossession(player)
		elseif not PlayerService.IsReady(player) or PlayerService.GetDunkState(player) ~= "Idle"
			or humanoid.FloorMaterial == Enum.Material.Air then
			gatherBall(player, possession, deltaTime)
		else
			if possession.Mode == "Gathering" and not possession.Weld.Enabled then
				gatherBall(player, possession, deltaTime)
			else
				dribbleBall(player, possession, humanoid, root, deltaTime)
			end
		end
	end
end

function BasketballService.BeginDunkMotion(player: Player)
	assert(BasketballService.HasBall(player), "Basketball possession was lost")
	local possession = possessions[player]
	attachBall(possession)
	setMode(player, possession, "Dunking")
	possession.Weld.Enabled = false
	possession.Ball.Anchored = true
end

function BasketballService.EndDunkMotion(player: Player, ball: Part)
	local possession = possessions[player]
	if not possession or possession.Ball ~= ball then
		return
	end
	local heldCFrame = BasketballService.GetHeldCFrame(player)
	if not heldCFrame then
		clearPossession(player)
		return
	end
	ball.CFrame = heldCFrame
	ball.Anchored = false
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	possession.Weld.Enabled = true
	setMode(player, possession, "Recovering")
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
	if GameplayObjects.Find("BasketballPickup", PlayerService.GetCurrentCourt(player)) ~= station or not station.Anchored
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
		Mode = "Holding",
		Phase = 0,
		UpdateAccumulator = 0,
		EntryElapsed = 0,
		BaseOffset = Vector3.zero,
		GatherFrom = ball.CFrame,
		GatherElapsed = 0,
		FloorRaycast = RaycastParams.new(),
	}
	possessions[player].FloorRaycast.FilterType = Enum.RaycastFilterType.Exclude
	possessions[player].FloorRaycast.FilterDescendantsInstances = { character }
	possessions[player].FloorRaycast.IgnoreWater = true
	player:SetAttribute("HasBasketball", true)
	player:SetAttribute("BasketballAction", "Holding")
end

local function trackPlayer(player: Player)
	if characterConnections[player] then
		return
	end
	player:SetAttribute("HasBasketball", false)
	player:SetAttribute("BasketballAction", "NoBall")
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

	GameplayObjects.BindStations("BasketballPickup", function(station, prompt)
		prompt.ActionText = "Grab a Basketball"
		prompt.ObjectText = "Hoop Shop"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Config.PickupDistance
		prompt.Triggered:Connect(function(player) pickup(player, station, prompt) end)
	end)
	RunService.Heartbeat:Connect(updatePossessions)
	print("[BasketballService] Basketball pickup ready.")
end

BasketballService.ClearPossession = clearPossession

return BasketballService
