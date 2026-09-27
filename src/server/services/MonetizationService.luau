-- Robux game passes and developer products (ids in MonetizationConfig; 0 = not on sale).
-- Pass ownership is checked on the server with MarketplaceService when a player's data is
-- ready and again after they buy a pass in-game; clients only open Roblox's purchase
-- prompt. Developer products go through ProcessReceipt, which records each PurchaseId in
-- a DataStore first so a retried receipt never pays twice, and only reports the purchase
-- granted once the player's save with the reward is confirmed.
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local DataConfig = require(script.Parent.Parent.Config.DataConfig)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local LockerService = require(script.Parent.LockerService)
local DailyService = require(script.Parent.DailyService)

local MonetizationService = {}
local initialized = false
local receipts: DataStore? = nil
local tagConnections: { [Player]: RBXScriptConnection } = {}
local TAG_NAME = "VIPTag"

local function ownsPass(player: Player, pass): boolean
	if RunService:IsStudio() and table.find(Config.StudioOwnedPasses, pass.Key) then return true end
	if pass.Id == 0 then return false end
	for attempt = 1, 3 do
		local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
		if ok then return owned == true end
		task.wait(attempt)
	end
	warn("[MonetizationService] Could not check pass " .. pass.Key .. " for " .. player.Name)
	return false
end

-- Floating gold "VIP" tag over the head (server-made, so everyone sees it).
local function tagCharacter(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	local old = head:FindFirstChild(TAG_NAME)
	if old then old:Destroy() end
	if not PlayerService.HasPass(player, "VIP") then return end
	local tag = Instance.new("BillboardGui")
	tag.Name = TAG_NAME
	tag.Size = UDim2.fromOffset(70, 26)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 80
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(18, 24, 52)
	label.BackgroundTransparency = 0.15
	label.Text = "VIP"
	label.TextColor3 = Color3.fromRGB(255, 214, 64)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(255, 214, 64)
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = tag
	tag.Parent = head
end

local function apply(player: Player, owned: { [string]: boolean })
	if player.Parent ~= Players or not PlayerService.IsDataReady(player) then return end
	PlayerService.SetPasses(player, owned)
	LockerService.GrantPassItems(player)
	DailyService.Refresh(player)
	tagCharacter(player)
end

local function refresh(player: Player)
	if player.Parent ~= Players or not PlayerService.IsDataReady(player) then return end
	local owned = {}
	for _, pass in Config.Passes do
		owned[pass.Key] = ownsPass(player, pass)
	end
	apply(player, owned)
end

-- Called (in its own thread) once a player's data is ready.
function MonetizationService.OnPlayerReady(player: Player)
	if not tagConnections[player] then
		tagConnections[player] = player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			tagCharacter(player)
		end)
	end
	refresh(player)
end

local function processReceipt(receipt)
	local product = Config.ProductById(receipt.ProductId)
	if not product then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not PlayerService.IsDataReady(player) or not receipts then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Claim the PurchaseId first: if it was already granted, just acknowledge it.
	local claimed, alreadyGranted = pcall(function()
		local previous = nil
		receipts:UpdateAsync(receipt.PurchaseId, function(value)
			previous = value
			if value then return nil end
			return { UserId = receipt.PlayerId, ProductId = receipt.ProductId, At = os.time() }
		end)
		return previous ~= nil
	end)
	if not claimed then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if alreadyGranted then return Enum.ProductPurchaseDecision.PurchaseGranted end
	local granted = false
	if product.Key == "CashBoost" then
		granted = DailyService.GrantBoost(player, product.BoostMinutes)
	end
	-- Only acknowledge once the reward is saved. If the grant or the save fails, release the
	-- claim so Roblox retries (a rare extra boost is better than a lost purchase).
	if not granted or not DataService.SaveNowAsync(player, 20) then
		pcall(receipts.RemoveAsync, receipts, receipt.PurchaseId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	if initialized then return end
	initialized = true
	local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService,
		RunService:IsStudio() and DataConfig.StudioReceiptStoreName or DataConfig.ProductionReceiptStoreName)
	if ok then receipts = store else warn("[MonetizationService] Receipts store unavailable: " .. tostring(store)) end
	MarketplaceService.ProcessReceipt = processReceipt
	-- Right after an in-game purchase the ownership check can lag, so trust Roblox's
	-- "purchased" result for that pass (the next join re-checks everything).
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased or passId == 0 then return end
		local owned, matched = {}, false
		for _, pass in Config.Passes do
			owned[pass.Key] = PlayerService.HasPass(player, pass.Key) or pass.Id == passId
			matched = matched or pass.Id == passId
		end
		if matched then apply(player, owned) end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local connection = tagConnections[player]
		if connection then connection:Disconnect() end
		tagConnections[player] = nil
	end)
end

return MonetizationService
