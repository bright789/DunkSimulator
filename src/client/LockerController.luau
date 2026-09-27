-- Locker menu controller: opens from the HUD, asks the server for the locker, and sends
-- Buy / Equip requests by item id. The server owns prices, Cash and ownership.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Locker = require(ReplicatedStorage.Shared.Config.LockerConfig)
local Monetization = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local HUDConfig = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Feedback = require(script.Parent.FeedbackController)
local View = require(script.Parent.ui:WaitForChild("LockerView"))

local LockerController = {}

function LockerController.new(player: Player, hud)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild("LockerRequest")
	local state = remotes:WaitForChild("LockerState")
	local view = View.new(player:WaitForChild("PlayerGui"))
	local connections = {}
	local snapshot = nil
	local pending = nil
	local responseTask = nil
	local controller = {}

	local prices = {}
	local offSale = {}
	local function render()
		view.Render(snapshot, pending)
		local owned = {}
		for _, pass in Monetization.Passes do owned[pass.Key] = player:GetAttribute("Pass_" .. pass.Key) == true end
		view.RenderOffers(owned, prices, offSale)
	end
	-- Opens Roblox's own purchase prompt; the server verifies and applies the purchase.
	local function promptPass(key: string)
		local pass = Monetization.GetPass(key)
		if pass and pass.Id ~= 0 then MarketplaceService:PromptGamePassPurchase(player, pass.Id) end
	end
	-- Live Robux prices for offers that are on sale (looked up once, in the background).
	task.spawn(function()
		for _, list in { { Items = Monetization.Passes, Type = Enum.InfoType.GamePass },
			{ Items = Monetization.Products, Type = Enum.InfoType.Product } } do
			for _, offer in list.Items do
				if offer.Id ~= 0 then
					local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, offer.Id, list.Type)
					if ok and type(info) == "table" then
						if info.IsForSale == false then
							offSale[offer.Key] = true
						elseif type(info.PriceInRobux) == "number" then
							prices[offer.Key] = info.PriceInRobux
						end
					end
				end
			end
		end
		render()
	end)
	local function read()
		if player:GetAttribute("DataStatus") == "Ready" then request:FireServer("Read") end
	end

	table.insert(connections, state.OnClientEvent:Connect(function(updated, result)
		if type(updated) == "table" and type(updated.Locker) == "table" then snapshot = updated end
		if type(result) == "table" then
			if responseTask then task.cancel(responseTask); responseTask = nil end
			pending = nil
			local item = Locker.Get(result.Category, result.Id)
			if result.Kind == "Bought" and item then
				view.Feedback(item.Name .. " unlocked and equipped!", true)
				Feedback.Upgrade()
			elseif result.Kind == "Equipped" and item then
				view.Feedback(item.Name .. " equipped.", true)
			elseif result.Kind == "Rejected" then
				view.Feedback(type(result.Message) == "string" and result.Message or "Locker unavailable.", false)
			end
		end
		render()
	end))
	table.insert(connections, hud.LockerButton.Activated:Connect(function()
		view.Panel.Visible = not view.Panel.Visible
		if view.Panel.Visible then
			view.Feedback(nil)
			read()
		end
	end))
	table.insert(connections, view.Close.Activated:Connect(function() view.Panel.Visible = false end))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then view.Panel.Visible = false end
	end))
	for kind, tab in view.Tabs do
		table.insert(connections, tab.Activated:Connect(function() view.SetTab(kind) end))
	end
	for kind, list in view.Cards do
		for itemId, card in list do
			table.insert(connections, card.Button.Activated:Connect(function()
				if snapshot and card.Item.Pass and not snapshot.Locker[kind].Owned[itemId] then
					promptPass(card.Item.Pass)
					return
				end
				if not snapshot or pending or not card.Button.Active then return end
				local owned = snapshot.Locker[kind].Owned[itemId] == true
				pending = kind .. ":" .. itemId
				view.Feedback(nil)
				render()
				responseTask = task.delay(HUDConfig.ChallengeMenu.ResponseTimeoutSeconds, function()
					responseTask = nil
					pending = nil
					view.Feedback("No response. Please try again.", false)
					render()
				end)
				request:FireServer(owned and "Equip" or "Buy", kind, itemId)
			end))
		end
	end

	for key, entry in view.Offers do
		table.insert(connections, entry.Button.Activated:Connect(function()
			if not entry.Button.Active then return end
			if entry.Kind == "Pass" then
				promptPass(key)
			elseif entry.Offer.Id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, entry.Offer.Id)
			end
		end))
	end
	for _, pass in Monetization.Passes do
		table.insert(connections, player:GetAttributeChangedSignal("Pass_" .. pass.Key):Connect(render))
	end

	-- Keep prices' affordability live while the menu is open.
	function controller.SetStat(name: string, value: number)
		if name == "Cash" and snapshot then
			snapshot.Cash = value
			render()
		end
	end

	function controller.Destroy()
		for _, connection in connections do connection:Disconnect() end
		if responseTask then task.cancel(responseTask) end
		view.Destroy()
	end

	table.insert(connections, player:GetAttributeChangedSignal("DataStatus"):Connect(read))
	read()
	render()
	return controller
end

return LockerController
