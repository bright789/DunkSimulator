-- AFK Practice Court (AfkConfig). When the server starts it places one pad per court near the
-- court's spawn: a flat, clear spot in front of the spawn, away from the rim, stations, bus
-- stops and props (or a fixed spot from AfkConfig.Offsets). Every second it checks who is
-- standing on their own court's pad (HumanoidRootPart within the pad's radius) and adds that
-- second to the player's AFK timers. Every RewardSeconds on the pad pays Cash worth
-- AfkDunks plain dunks (x2 with VIP); every PrizeSeconds gives a free prize. Leaving the
-- pad pauses the timers for this session; nothing is saved.
-- Mirrors for the client: AfkOnPad (true while on a pad), AfkRewardIn / AfkPrizeIn (seconds
-- of pad time left). AfkPractice remote, server -> client only: ("Reward", cash) and
-- ("Prize", kind, amount, text).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.AfkConfig)
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local PlayerService = require(script.Parent.PlayerService)
local DailyService = require(script.Parent.DailyService)
local GameplayObjects = require(script.Parent.GameplayObjects)
local Analytics = require(script.Parent.AnalyticsReporter)
local SeasonXp = require(script.Parent.SeasonXp)

local AfkService = {}
local initialized = false
local isStudio = RunService:IsStudio()
local random = Random.new()
local remote: RemoteEvent? = nil
local padFolder: Folder? = nil
-- Pad centre (on the floor) per court id.
local pads: { [string]: Vector3 } = {}
-- This session's pad time per player (seconds toward the next reward / prize).
local sessions: { [Player]: { Reward: number, Prize: number, OnPad: boolean } } = {}
local rewardSeconds = (isStudio and Config.StudioFastAfk) and Config.StudioRewardSeconds or Config.RewardSeconds
local prizeSeconds = (isStudio and Config.StudioFastAfk) and Config.StudioPrizeSeconds or Config.PrizeSeconds

---------------------------------------------------------------- Pad placement

local function characters(): { Instance }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(list, player.Character) end
	end
	return list
end

-- World-space box (lowest and highest corner) around a part, or around every part inside a
-- model or folder. nil when there are no parts.
local function bounds(object: Instance): (Vector3?, Vector3?)
	local parts = object:IsA("BasePart") and { object } or {}
	for _, descendant in object:GetDescendants() do
		if descendant:IsA("BasePart") then table.insert(parts, descendant) end
	end
	local low, high = nil, nil
	for _, part in parts do
		local frame, half = part.CFrame, part.Size / 2
		local right, up, look = frame.RightVector, frame.UpVector, frame.LookVector
		local extent = Vector3.new(
			math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z,
			math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z,
			math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z)
		local a, b = part.Position - extent, part.Position + extent
		low = low and Vector3.new(math.min(low.X, a.X), math.min(low.Y, a.Y), math.min(low.Z, a.Z)) or a
		high = high and Vector3.new(math.max(high.X, b.X), math.max(high.Y, b.Y), math.max(high.Z, b.Z)) or b
	end
	return low, high
end

-- Flat (X/Z) distance from a point to a box; 0 when the point is over the box.
local function flatDistance(point: Vector3, low: Vector3, high: Vector3): number
	local dx = math.max(low.X - point.X, 0, point.X - high.X)
	local dz = math.max(low.Z - point.Z, 0, point.Z - high.Z)
	return math.sqrt(dx * dx + dz * dz)
end

-- Everything a pad must keep away from: named props and stations (AfkConfig KeepAway), court
-- portals and spawns, each with its distance.
local function keepAwayList()
	local placement = Config.Placement
	local distances = table.clone(placement.KeepAway)
	for _, court in Courts.Definitions do
		for _, portalName in court.Portals do distances[portalName] = placement.PortalKeepAway end
	end
	local list = {}
	local function add(object: Instance, distance: number)
		local low, high = bounds(object)
		if low and high and math.max(high.X - low.X, high.Z - low.Z) <= placement.MaxPropSize then
			table.insert(list, { Low = low, High = high, Distance = distance })
		end
	end
	for _, object in Workspace:GetDescendants() do
		local distance = distances[object.Name]
		if distance and (object:IsA("BasePart") or object:IsA("Model") or object:IsA("Folder")) then add(object, distance) end
	end
	for courtId in Courts.Definitions do
		local spawn = GameplayObjects.FindSpawn(courtId)
		if spawn then add(spawn, placement.SpawnKeepAway) end
	end
	return list
end

-- The first solid surface below `point`, cast from 10 studs above height `top`, and its normal.
local function floorAt(point: Vector3, top: number): (Vector3?, Vector3?)
	local exclude = characters()
	if padFolder then table.insert(exclude, padFolder) end
	local balls = Workspace:FindFirstChild("GoldenBalls")
	if balls then table.insert(exclude, balls) end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, 6 do
		params.FilterDescendantsInstances = exclude
		local hit = Workspace:Raycast(Vector3.new(point.X, top + 10, point.Z), Vector3.new(0, -30, 0), params)
		if not hit then return nil, nil end
		if hit.Instance.CanCollide then return hit.Position, hit.Normal end
		table.insert(exclude, hit.Instance)
	end
	return nil, nil
end

-- The floor point for a pad at `point`, or nil when the spot is no good (not flat, not near
-- the spawn's height `baseY`, something solid in the way, or too close to a kept-away object).
local function checkSpot(point: Vector3, baseY: number, keep): Vector3?
	local placement = Config.Placement
	local radius = Config.Pad.Radius
	local floor, normal = floorAt(point, baseY)
	if not floor or not normal or normal.Y < 0.95 or math.abs(floor.Y - baseY) > placement.MaxHeightDifference then return nil end
	for step = 0, 7 do
		local angle = step * math.pi / 4
		local edge = floorAt(floor + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), floor.Y)
		if not edge or math.abs(edge.Y - floor.Y) > placement.Flatness then return nil end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characters()
	params.RespectCanCollide = true
	local box = CFrame.new(floor + Vector3.new(0, 0.6 + placement.ClearHeight / 2, 0))
	if #Workspace:GetPartBoundsInBox(box, Vector3.new(radius * 2, placement.ClearHeight, radius * 2), params) > 0 then
		return nil
	end
	for _, object in keep do
		if flatDistance(floor, object.Low, object.High) < object.Distance then return nil end
	end
	return floor
end

-- Where this court's pad goes (a floor point), or nil if no good spot was found.
local function findSpot(courtId: string, keep): Vector3?
	local spawn = GameplayObjects.FindSpawn(courtId)
	if not spawn then return nil end
	local baseY = spawn.Position.Y + spawn.Size.Y / 2
	local origin = Vector3.new(spawn.Position.X, baseY, spawn.Position.Z)
	local look = Vector3.new(spawn.CFrame.LookVector.X, 0, spawn.CFrame.LookVector.Z)
	look = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
	local right = Vector3.new(-look.Z, 0, look.X)
	local offset = Config.Offsets[courtId]
	if typeof(offset) == "Vector3" then
		local floor = floorAt(origin + right * offset.X + look * offset.Z, baseY)
		if floor then return floor end
		warn("[AfkService] " .. courtId .. ": no floor at the configured offset; searching instead.")
	end
	for _, distance in Config.Placement.Distances do
		for _, degrees in Config.Placement.Angles do
			local angle = math.rad(degrees)
			local floor = checkSpot(origin + (look * math.cos(angle) + right * math.sin(angle)) * distance, baseY, keep)
			if floor then return floor end
		end
	end
	return nil
end

local function disc(name: string, radius: number, height: number, transparency: number, floor: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	-- A cylinder's round faces point along X, so it is turned 90 degrees to lie flat.
	part.Size = Vector3.new(height, radius * 2, radius * 2)
	part.CFrame = CFrame.new(floor + Vector3.new(0, height / 2 + 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = Config.Pad.Color
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function buildPad(courtId: string, floor: Vector3)
	local pad = Config.Pad
	local model = Instance.new("Model")
	model.Name = "AfkPad_" .. courtId
	model:SetAttribute("Court", courtId)
	local ring = disc("Ring", pad.Radius + 0.6, 0.2, 0.55, floor)
	ring.Parent = model
	local center = disc("Pad", pad.Radius, 0.3, 0.3, floor)
	center.Parent = model
	model.PrimaryPart = center
	local light = Instance.new("PointLight")
	light.Color = pad.Color
	light.Brightness = 2
	light.Range = 12
	light.Parent = center
	local tag = Instance.new("BillboardGui")
	tag.Name = "Label"
	tag.Size = UDim2.fromOffset(240, 56)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	tag.MaxDistance = 90
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.6)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = pad.Name
	title.TextColor3 = pad.Color
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(10, 30, 50)
	title.Parent = tag
	local subtitle = title:Clone()
	subtitle.Position = UDim2.fromScale(0, 0.6)
	subtitle.Size = UDim2.fromScale(1, 0.4)
	subtitle.Text = pad.Subtitle
	subtitle.TextColor3 = Color3.new(1, 1, 1)
	subtitle.Parent = tag
	tag.Parent = center
	model.Parent = padFolder
	pads[courtId] = floor
end

local function placePads()
	local keep = keepAwayList()
	for _, courtId in Courts.OrderedIds() do
		local ok, result = pcall(findSpot, courtId, keep)
		if ok and result then
			buildPad(courtId, result)
			local spawn = GameplayObjects.FindSpawn(courtId)
			print(string.format("[AfkService] %s AFK pad at (%.1f, %.1f, %.1f), %.0f studs from the spawn.", courtId,
				result.X, result.Y, result.Z, spawn and (Vector3.new(spawn.Position.X, result.Y, spawn.Position.Z) - result).Magnitude or 0))
		else
			warn(string.format("[AfkService] %s: no clear spot for the AFK pad%s. Set AfkConfig.Offsets.%s to place it.",
				courtId, ok and "" or (" (" .. tostring(result) .. ")"), courtId))
		end
	end
end

---------------------------------------------------------------- Rewards

-- True while the player stands on the pad of the court they are on.
local function onPad(player: Player): boolean
	if not PlayerService.IsReady(player) or player:GetAttribute("TransitRide") then return false end
	local center = pads[PlayerService.GetCurrentCourt(player)]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not center or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return false end
	local offset = root.Position - center
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Config.Pad.Radius and offset.Y >= -1 and offset.Y <= Config.Pad.Height
end

local function vipMultiplier(player: Player): number
	return PlayerService.HasPass(player, "VIP") and Config.VipMultiplier or 1
end

local function dunks(player: Player, count: number): number
	return math.floor(count * Daily.DunkValue(PlayerService.GetVertical(player) or 0) * vipMultiplier(player) + 0.5)
end

local function send(player: Player, ...)
	if remote and player.Parent == Players then remote:FireClient(player, ...) end
end

local function payReward(player: Player)
	local cash = dunks(player, Config.AfkDunks)
	if cash > 0 and PlayerService.GrantCash(player, cash, "AfkReward", "TimedReward") then
		Analytics.Custom(player, "AfkReward")
		send(player, "Reward", cash)
	end
end

local function cashPrize(player: Player): boolean
	for _, prize in Config.Prizes do
		if prize.Kind == "Cash" then
			local cash = dunks(player, prize.Dunks)
			if PlayerService.GrantCash(player, cash, "AfkPrize", "TimedReward") then
				send(player, "Prize", "Cash", cash, prize.Text)
				return true
			end
		end
	end
	return false
end

local function givePrize(player: Player)
	local prize = Config.PickPrize(random:NextNumber())
	local given = false
	if prize.Kind == "Boost" then
		given = DailyService.GrantBoost(player, prize.Minutes)
		if given then send(player, "Prize", "Boost", prize.Minutes, prize.Text) end
	elseif prize.Kind == "PassXp" and SeasonXp.Record(player) ~= nil then
		SeasonXp.Add(player, prize.Xp)
		given = true
		send(player, "Prize", "PassXp", prize.Xp, prize.Text)
	end
	-- The Cash prize, or the fallback when the other prize couldn't be given (no season running).
	if not given then given = cashPrize(player) end
	if given then Analytics.Custom(player, "AfkPrize") end
end

local function publish(player: Player, session)
	if player.Parent ~= Players then return end
	player:SetAttribute("AfkOnPad", session.OnPad)
	player:SetAttribute("AfkRewardIn", math.max(0, math.ceil(rewardSeconds - session.Reward)))
	player:SetAttribute("AfkPrizeIn", math.max(0, math.ceil(prizeSeconds - session.Prize)))
end

-- One check of every player; `elapsed` = seconds since the last check.
function AfkService.Step(elapsed: number)
	for _, player in Players:GetPlayers() do
		local session = sessions[player]
		if not session and PlayerService.IsDataReady(player) then
			session = { Reward = 0, Prize = 0, OnPad = false }
			sessions[player] = session
		end
		if session then
			local standing = onPad(player)
			if standing then
				local rewards, prizes = Config.Accrue(session, elapsed, rewardSeconds, prizeSeconds)
				for _ = 1, rewards do payReward(player) end
				for _ = 1, prizes do givePrize(player) end
			end
			-- Attributes change every second only while someone stands on a pad.
			if standing or session.OnPad ~= standing then
				session.OnPad = standing
				publish(player, session)
			end
		end
	end
end

function AfkService.Init()
	if initialized then return end
	initialized = true
	remote = ReplicatedStorage.Remotes:WaitForChild("AfkPractice")
	padFolder = Instance.new("Folder")
	padFolder.Name = "AfkPads"
	padFolder.Parent = Workspace
	if isStudio and Config.StudioFastAfk then
		print(string.format("[AfkService] StudioFastAfk is on: reward every %d s, prize every %d s.", rewardSeconds, prizeSeconds))
	end
	local ok, problem = pcall(placePads)
	if not ok then warn("[AfkService] Pad placement failed: " .. tostring(problem)) end
	Players.PlayerRemoving:Connect(function(player) sessions[player] = nil end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			-- Capped so a server hitch can't pay for time nobody could see.
			local stepOk, stepProblem = pcall(AfkService.Step, math.min(now - last, 2))
			if not stepOk then warn("[AfkService] " .. tostring(stepProblem)) end
			last = now
		end
	end)
end

return AfkService
