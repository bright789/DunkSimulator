-- Court pickups (PickupConfig):
--   Cash bills: DunkService calls SpillForDunk after every completed dunk. The drops live
--     here (id, position, value, expiry) and are sent to that player only; the client draws
--     them and fires PickupEvent("Collect", id) when it touches one. The server checks the
--     drop exists, hasn't expired and the character is close enough, then pays.
--   Golden Ball: one per court with players, about every EverySeconds. It's a real part in
--     Workspace.GoldenBalls that everyone on the court sees; the first character within
--     GrabRadius (checked here, not by Touched) wins the Cash.
-- Events to clients on PickupEvent: ("Bills", { {Id, Position, Value} }), ("Collected", id, value),
-- ("GoldenSpawn", position), ("GoldenGrab", displayName, value, position, isYou).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.PickupConfig)
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local PlayerService = require(script.Parent.PlayerService)
local GameplayObjects = require(script.Parent.GameplayObjects)
local Analytics = require(script.Parent.AnalyticsReporter)

local PickupService = {}
local initialized = false
local remote: RemoteEvent
local random = Random.new()
local drops: { [Player]: { [number]: { Position: Vector3, Value: number, Expires: number } } } = {}
local nextDropId = 0
local balls: { [string]: { Part: BasePart, Expires: number } } = {}
local nextSpawn: { [string]: number } = {}
local ballFolder: Folder

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil
end

-- First anchored, collidable surface below `origin` (skips characters, balls and props).
local function floorBelow(origin: Vector3, ignore: { Instance }): Vector3?
	local exclude = table.clone(ignore)
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(exclude, player.Character) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, 6 do
		params.FilterDescendantsInstances = exclude
		local hit = Workspace:Raycast(origin, Vector3.new(0, -120, 0), params)
		if not hit then return nil end
		if hit.Instance.Anchored and hit.Instance.CanCollide then return hit.Position end
		table.insert(exclude, hit.Instance)
	end
	return nil
end

-- The floor under a court's rim, facing out from the backboard toward the court.
local function hoopFloor(courtId: string): CFrame?
	local rim = GameplayObjects.FindRim(courtId)
	if not rim then return nil end
	local hoop = rim.Parent
	local bracket = hoop and hoop:FindFirstChild("RimBracket", true)
	local back = bracket and bracket:IsA("BasePart") and bracket.Position - rim.Position or Vector3.new(0, 0, -1)
	back = Vector3.new(back.X, 0, back.Z)
	back = back.Magnitude > 1e-3 and back.Unit or Vector3.new(0, 0, -1)
	local floor = floorBelow(rim.Position, hoop and { hoop, ballFolder } or { ballFolder })
	if not floor then return nil end
	return CFrame.lookAt(floor, floor - back)
end

local function sendTo(player: Player, ...)
	if player.Parent == Players then remote:FireClient(player, ...) end
end

-- Cash bills around the hoop after a dunk worth `dunkCash`.
function PickupService.SpillForDunk(player: Player, dunkCash: number)
	local bills = Config.Bills
	if type(dunkCash) ~= "number" or dunkCash <= 0 then return end
	local base = hoopFloor(PlayerService.GetCurrentCourt(player))
	if not base then return end
	local value = math.max(1, math.floor(dunkCash * bills.ShareOfDunk + 0.5))
	local now = os.clock()
	local mine = drops[player] or {}
	drops[player] = mine
	for id, drop in mine do
		if now > drop.Expires then mine[id] = nil end
	end
	local sent = {}
	for _ = 1, bills.Count do
		local angle = math.rad(random:NextNumber(-80, 80))
		local radius = random:NextNumber(bills.MinRadius, bills.MaxRadius)
		local position = base.Position + (base.LookVector * math.cos(angle) + base.RightVector * math.sin(angle)) * radius
			+ Vector3.new(0, 1, 0)
		nextDropId += 1
		mine[nextDropId] = { Position = position, Value = value, Expires = now + bills.LifetimeSeconds }
		table.insert(sent, { Id = nextDropId, Position = position, Value = value })
	end
	sendTo(player, "Bills", sent)
end

local function collect(player: Player, dropId)
	local mine = drops[player]
	local drop = type(dropId) == "number" and mine and mine[dropId]
	if not drop then return end
	local root = rootOf(player)
	if os.clock() > drop.Expires or not root or (root.Position - drop.Position).Magnitude > Config.Bills.CollectRadius then return end
	mine[dropId] = nil
	if PlayerService.GrantCash(player, drop.Value, "PickupBills", "Gameplay") then
		sendTo(player, "Collected", dropId, drop.Value)
	end
end

local function playersOn(courtId: string): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if PlayerService.IsReady(player) and PlayerService.GetCurrentCourt(player) == courtId
			and not player:GetAttribute("TransitRide") then
			table.insert(list, player)
		end
	end
	return list
end

local function removeBall(courtId: string)
	local ball = balls[courtId]
	balls[courtId] = nil
	if ball and ball.Part.Parent then ball.Part:Destroy() end
end

-- Returns false when no good spot was found (the caller retries soon).
local function spawnBall(courtId: string, present: { Player }): boolean
	local golden = Config.GoldenBall
	local base = hoopFloor(courtId)
	if not base then return false end
	local guess = base.Position + base.LookVector * random:NextNumber(golden.MinForward, golden.MaxForward)
		+ base.RightVector * random:NextNumber(-golden.Spread, golden.Spread)
	local floor = floorBelow(guess + Vector3.new(0, 30, 0), { ballFolder })
	if not floor or math.abs(floor.Y - base.Position.Y) > 6 then return false end
	local part = Instance.new("Part")
	part.Name = "GoldenBall"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(golden.Size, golden.Size, golden.Size)
	part.Color = golden.Color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Position = floor + Vector3.new(0, golden.Size / 2 + 1, 0)
	part:SetAttribute("Court", courtId)
	local light = Instance.new("PointLight")
	light.Color = golden.Color
	light.Brightness = 3
	light.Range = 14
	light.Parent = part
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160))
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Lifetime = NumberRange.new(0.6, 1)
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Rate = 14
	sparkles.Parent = part
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(160, 36)
	tag.StudsOffset = Vector3.new(0, golden.Size + 1, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 160
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = "GOLDEN BALL"
	text.TextColor3 = golden.Color
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(40, 20, 0)
	text.Parent = tag
	tag.Parent = part
	part.Parent = ballFolder
	balls[courtId] = { Part = part, Expires = os.clock() + golden.LifetimeSeconds }
	for _, player in present do sendTo(player, "GoldenSpawn", part.Position) end
	return true
end

local function grab(player: Player, courtId: string, present: { Player })
	local ball = balls[courtId]
	if not ball then return end
	local position = ball.Part.Position
	removeBall(courtId)
	local value = Config.GoldenBall.RewardDunks * Daily.DunkValue(PlayerService.GetVertical(player) or 0)
	if not PlayerService.GrantCash(player, value, "GoldenBall", "Gameplay") then return end
	Analytics.Custom(player, "GoldenBall")
	for _, other in present do
		sendTo(other, "GoldenGrab", player.DisplayName, value, position, other == player)
	end
end

local function updateBalls()
	local now = os.clock()
	local golden = Config.GoldenBall
	for courtId in Courts.Definitions do
		local present = playersOn(courtId)
		local ball = balls[courtId]
		if #present == 0 then
			removeBall(courtId)
			nextSpawn[courtId] = nil
		elseif ball then
			if now > ball.Expires or not ball.Part.Parent then
				removeBall(courtId)
			else
				for _, player in present do
					local root = rootOf(player)
					if root and (root.Position - ball.Part.Position).Magnitude <= golden.GrabRadius then
						grab(player, courtId, present)
						break
					end
				end
			end
		elseif not nextSpawn[courtId] then
			nextSpawn[courtId] = now + golden.EverySeconds * 0.5
		elseif now >= nextSpawn[courtId] then
			nextSpawn[courtId] = spawnBall(courtId, present)
				and now + golden.EverySeconds + random:NextNumber(-golden.JitterSeconds, golden.JitterSeconds)
				or now + 2
		end
	end
end

function PickupService.Init()
	if initialized then return end
	initialized = true
	remote = ReplicatedStorage.Remotes:WaitForChild("PickupEvent")
	ballFolder = Instance.new("Folder")
	ballFolder.Name = "GoldenBalls"
	ballFolder.Parent = Workspace
	remote.OnServerEvent:Connect(function(player, action, dropId, ...)
		if action == "Collect" and select("#", ...) == 0 then collect(player, dropId) end
	end)
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() < nextCheck then return end
		nextCheck = os.clock() + 0.1
		local ok, problem = pcall(updateBalls)
		if not ok then warn("[PickupService] " .. tostring(problem)) end
	end)
	Players.PlayerRemoving:Connect(function(player) drops[player] = nil end)
end

return PickupService
