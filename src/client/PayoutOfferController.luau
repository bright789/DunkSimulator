-- "Boost that payout!" offer on this client (PayoutOfferService decides everything).
--   ("Offer", { Amount, Source }): right after a big payout, show the card for OfferSeconds.
--     Its buttons only open Roblox's purchase prompt for the PayoutX2 / X4 / X7 products.
--   ("Boosted", { Multiplier, Bonus }) / ("CashPack", { Cash, Key }): a purchase was paid and
--     saved, so celebrate it.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Monetization = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local HUDConfig = require(ReplicatedStorage.Shared.Config.HUDConfig)
local UI = require(script.Parent.ui:WaitForChild("UIComponents"))
local View = require(script.Parent.ui:WaitForChild("PayoutOfferView"))
local ActionFeed = require(script.Parent:WaitForChild("ActionFeed"))
local Feedback = require(script.Parent.FeedbackController)

local PayoutOfferController = {}

local SOURCE_NAMES = { Contest = "Contest prize", GoldenBall = "Golden Ball", Dunk = "Big dunk" }

function PayoutOfferController.new(player: Player)
	local remote = ReplicatedStorage.Remotes:WaitForChild("PayoutOffer")
	local view = View.new(player:WaitForChild("PlayerGui"))
	local products = Monetization.PayoutProducts()
	local connections = {}
	local prices = {}
	local hideTask = nil
	-- Touch screens: the card shares the bottom of the screen with the slam meter and the
	-- training ring, so it steps aside while a dunk runs or you train.
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local function busy(): boolean
		return touch and (player:GetAttribute("Training") == true or player:GetAttribute("DunkState") == "Executing")
	end

	local function hide()
		if hideTask then task.cancel(hideTask); hideTask = nil end
		view.Hide()
	end

	-- Live Robux prices (looked up once, in the background); SuggestedRobux until then.
	task.spawn(function()
		for _, product in products do
			if product.Id ~= 0 then
				local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, product.Id, Enum.InfoType.Product)
				if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
					prices[product.Key] = info.PriceInRobux
				end
			end
		end
	end)

	-- A new offer replaces the one on screen.
	local function show(amount: number, source)
		local lowest = products[1]
		if not lowest or busy() then return end
		view.Show(string.format("%s: $%s. Make it $%s with x%d!", SOURCE_NAMES[source] or "Payout",
			UI.Number(amount), UI.Number(amount * lowest.Multiplier), lowest.Multiplier), prices)
		if hideTask then task.cancel(hideTask) end
		hideTask = task.delay(Monetization.PayoutOffer.OfferSeconds, function()
			hideTask = nil
			view.Hide()
		end)
	end

	table.insert(connections, remote.OnClientEvent:Connect(function(kind, data)
		if type(data) ~= "table" then return end
		if kind == "Offer" and type(data.Amount) == "number" then
			show(data.Amount, data.Source)
		elseif kind == "Boosted" and type(data.Multiplier) == "number" and type(data.Bonus) == "number" then
			hide()
			ActionFeed.Announce(string.format("x%d PAYOUT!  +$%s", data.Multiplier, UI.Number(data.Bonus)), HUDConfig.Colors.Gold)
			Feedback.DunkUnlock()
		elseif kind == "CashPack" and type(data.Cash) == "number" then
			ActionFeed.Announce("+$" .. UI.Number(data.Cash) .. " CASH!", HUDConfig.Colors.Gain)
			Feedback.DunkUnlock()
		end
	end))
	for _, entry in view.Buttons do
		table.insert(connections, entry.Button.Activated:Connect(function()
			hide()
			if entry.Product.Id ~= 0 then MarketplaceService:PromptProductPurchase(player, entry.Product.Id) end
		end))
	end
	table.insert(connections, view.Close.Activated:Connect(hide))
	for _, attribute in { "Training", "DunkState" } do
		table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(function()
			if busy() then hide() end
		end))
	end

	local controller = {}
	function controller.Destroy()
		if hideTask then task.cancel(hideTask) end
		for _, connection in connections do connection:Disconnect() end
		view.Destroy()
	end
	return controller
end

return PayoutOfferController
