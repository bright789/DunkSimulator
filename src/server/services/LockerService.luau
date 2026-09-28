-- Locker: buying and equipping sneakers and ball skins. A client may only ask to read its
-- locker, buy an item by id, or equip an owned item by id; prices and ownership are the
-- server's. Equipped shoes are built here as non-colliding, massless parts welded to the
-- character's feet (so everyone sees them); the ball skin is an attribute ("BallSkin") the
-- clients' ball renderer reads.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.LockerConfig)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)

local LockerService = {}
local initialized = false
local processing: { [Player]: boolean } = {}
local nextRequest: { [Player]: number } = {}
local nextRead: { [Player]: number } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}
local stateRemote: RemoteEvent? = nil
local SHOES_NAME = "LockerShoes"

local function shoePart(folder: Folder, name: string, foot: BasePart, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = foot.CFrame * offset
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = foot
	weld.Part1 = part
	weld.Parent = part
	part.Parent = folder
	return part
end

-- Rebuilds the equipped sneakers on the character (R15 feet; other rigs are skipped).
local function dressShoes(player: Player)
	local character = player.Character
	local locker = PlayerService.GetLocker(player)
	if not character or not locker then return end
	local old = character:FindFirstChild(SHOES_NAME)
	if old then old:Destroy() end
	local shoe = Config.Get("Shoes", locker.Shoes.Equipped)
	if not shoe then return end
	local folder = Instance.new("Folder")
	folder.Name = SHOES_NAME
	for _, side in { "Left", "Right" } do
		local foot = character:FindFirstChild(side .. "Foot")
		if foot and foot:IsA("BasePart") then
			local size = foot.Size
			local outward = side == "Left" and -1 or 1
			local soleHeight = math.max(size.Y * 0.4, 0.12)
			local glow = shoe.Glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
			-- Front of the foot is -Z. The sole sits under the foot; the upper wraps it.
			shoePart(folder, side .. "Sole", foot, Vector3.new(size.X * 1.1, soleHeight, size.Z * 1.14),
				CFrame.new(0, -size.Y / 2 - soleHeight / 2 + 0.04, -size.Z * 0.04), shoe.Sole, glow)
			shoePart(folder, side .. "Upper", foot, Vector3.new(size.X * 1.06, size.Y * 1.05, size.Z * 1.04),
				CFrame.new(0, size.Y * 0.04, 0), shoe.Upper)
			shoePart(folder, side .. "Toe", foot, Vector3.new(size.X * 1.08, size.Y * 0.6, size.Z * 0.28),
				CFrame.new(0, -size.Y * 0.2, -size.Z * 0.42), shoe.Upper:Lerp(Color3.new(1, 1, 1), 0.25))
			shoePart(folder, side .. "Stripe", foot, Vector3.new(0.06, size.Y * 0.45, size.Z * 0.62),
				CFrame.new(outward * size.X * 0.545, 0, -size.Z * 0.02), shoe.Accent, shoe.Glow and Enum.Material.Neon or nil)
			shoePart(folder, side .. "Heel", foot, Vector3.new(size.X * 0.9, size.Y * 0.55, 0.08),
				CFrame.new(0, 0, size.Z * 0.53), shoe.Accent)
		end
	end
	folder.Parent = character
end

local function snapshot(player: Player)
	local locker = PlayerService.GetLocker(player)
	if not locker then return nil end
	return { Locker = Config.CopyState(locker), Cash = PlayerService.GetCash(player) or 0 }
end

local function publish(player: Player, result)
	local data = snapshot(player)
	if data and stateRemote and player.Parent == Players then stateRemote:FireClient(player, data, result) end
end

local function buy(player: Player, kind: string, itemId: string)
	local locker = PlayerService.GetLocker(player)
	local item = Config.Get(kind, itemId)
	if not locker or not item then return nil, "Item unavailable." end
	if locker[kind].Owned[itemId] then return nil, "You already own this." end
	if item.Pass then return nil, "Unlocked with the " .. item.Pass .. " pass." end
	if item.Season then return nil, "A Dunk Pass reward." end
	if not PlayerService.SpendCash(player, item.Price, kind .. "_" .. itemId) then return nil, "Not enough Cash." end
	locker[kind].Owned[itemId] = true
	locker[kind].Equipped = itemId
	return { Kind = "Bought", Category = kind, Id = itemId, Price = item.Price }
end

local function equip(player: Player, kind: string, itemId: string)
	local locker = PlayerService.GetLocker(player)
	if not locker or not Config.Get(kind, itemId) then return nil, "Item unavailable." end
	if not locker[kind].Owned[itemId] then return nil, "Buy it first." end
	locker[kind].Equipped = itemId
	return { Kind = "Equipped", Category = kind, Id = itemId }
end

local function applyLooks(player: Player)
	local locker = PlayerService.GetLocker(player)
	if not locker then return end
	player:SetAttribute("EquippedShoe", locker.Shoes.Equipped)
	player:SetAttribute("BallSkin", locker.Balls.Equipped)
	dressShoes(player)
end

-- Adds the Locker items of every pass this player owns (MonetizationService calls this
-- after checking ownership). Items stay owned once granted.
function LockerService.GrantPassItems(player: Player)
	local locker = PlayerService.GetLocker(player)
	if not locker then return end
	local changed = false
	for _, kind in Config.Kinds do
		for _, item in Config[kind] do
			if item.Pass and PlayerService.HasPass(player, item.Pass) and not locker[kind].Owned[item.Id] then
				locker[kind].Owned[item.Id] = true
				changed = true
			end
		end
	end
	if changed then
		DataService.RequestSave(player)
		publish(player)
	end
end

-- Adds one item to the player's Locker for free (Starter Pack). Returns true if it's owned
-- afterwards (including when it already was).
function LockerService.GrantItem(player: Player, kind: string, itemId: string): boolean
	local locker = PlayerService.GetLocker(player)
	if not locker or not locker[kind] or not Config.Get(kind, itemId) then return false end
	if not locker[kind].Owned[itemId] then
		locker[kind].Owned[itemId] = true
		DataService.RequestSave(player)
		publish(player)
	end
	return true
end

-- Called once a player's data is ready: dress them now and on every respawn.
function LockerService.OnPlayerReady(player: Player)
	if connections[player] then return end
	connections[player] = {
		player.CharacterAppearanceLoaded:Connect(function() dressShoes(player) end),
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("RightFoot", 5)
			dressShoes(player)
		end),
	}
	applyLooks(player)
end

function LockerService.Init()
	if initialized then return end
	initialized = true
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild("LockerRequest")
	stateRemote = remotes:WaitForChild("LockerState")

	request.OnServerEvent:Connect(function(player, action, ...)
		if player.Parent ~= Players or not PlayerService.IsDataReady(player) then return end
		local count = select("#", ...)
		local now = os.clock()
		if action == "Read" and count == 0 then
			if now >= (nextRead[player] or 0) then
				nextRead[player] = now + Config.ReadCooldownSeconds
				publish(player)
			end
			return
		end
		local kind, itemId = ...
		if (action ~= "Buy" and action ~= "Equip") or count ~= 2 or (kind ~= "Shoes" and kind ~= "Balls")
			or type(itemId) ~= "string" or processing[player] or now < (nextRequest[player] or 0) then
			return
		end
		nextRequest[player] = now + Config.RequestCooldownSeconds
		processing[player] = true
		local ok, result, problem = pcall(action == "Buy" and buy or equip, player, kind, itemId)
		processing[player] = nil
		if not ok then
			warn("[LockerService] " .. action .. " failed: " .. tostring(result))
			result, problem = nil, "Locker unavailable. Please try again."
		end
		if result then
			applyLooks(player)
			if result.Kind == "Bought" then DataService.RequestSave(player) end
		end
		publish(player, result or { Kind = "Rejected", Message = problem })
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, connection in connections[player] or {} do connection:Disconnect() end
		connections[player] = nil
		processing[player] = nil
		nextRequest[player] = nil
		nextRead[player] = nil
	end)
end

return LockerService
