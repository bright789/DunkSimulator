-- Robux game passes and developer products. Paste each Id from the Creator Hub
-- (Creations > this experience > Monetization > Passes / Developer Products). An Id of 0
-- means "not on sale yet": the PASSES tab shows COMING SOON and nothing can be bought.
-- MonetizationService checks ownership on the server; clients only open Roblox's prompt.
local MonetizationConfig = {
	Passes = {
		-- One-time bundle, granted once per account (recorded in the receipts store).
		{ Key = "StarterPack", Id = 1999707117, Name = "Starter Pack", Icon = "STARTER\nPACK",
			Description = "One-time bundle: $2,500 Cash, 30 minutes of 2x Cash and Sky Risers shoes.", SuggestedRobux = 49,
			Contents = { Cash = 2500, BoostMinutes = 30, Shoe = "sky_risers" } },
		-- Trains Vertical automatically anywhere on your court (toggle on the HUD).
		{ Key = "AutoTrain", Id = 1999335123, Name = "Auto Train", Icon = "AUTO\nTRAIN",
			Description = "Train your Vertical automatically anywhere on your court, even while you dunk. Toggle it on the HUD.", SuggestedRobux = 199 },
		{ Key = "DoubleCash", Id = 1999521068, Name = "2x Cash", Icon = "2x",
			Description = "Double Cash from every dunk and air trick, forever. Stacks with Cash Boosts.", SuggestedRobux = 249 },
		{ Key = "VIP", Id = 1999029049, Name = "VIP", Icon = "VIP",
			Description = "Diamond Kicks and the Diamond ball in your Locker, plus a VIP tag.", SuggestedRobux = 149 },
		{ Key = "DoubleDaily", Id = 1998489062, Name = "2x Daily Rewards", Icon = "2x\nDAILY",
			Description = "Double Cash from daily login rewards and daily challenges.", SuggestedRobux = 99 },
		-- Hype Crew passes (see CrewConfig). PackPass = only useful for opening packs, so the
		-- PASSES tab hides it where packs (paid random items) are restricted.
		{ Key = "CrewLucky", Id = 1998015188, Name = "Lucky Packs", Icon = "LUCKY\nPACKS", PackPass = true,
			Description = "Epic and Legendary Hype Crew show up twice as often in every pack.", SuggestedRobux = 199 },
		{ Key = "CrewTriple", Id = 1998099184, Name = "Triple Open", Icon = "OPEN\nx3", PackPass = true,
			Description = "Open 3 Hype Crew packs at once.", SuggestedRobux = 99 },
		{ Key = "CrewSlot", Id = 1998489170, Name = "+1 Crew Slot", Icon = "+1\nCREW",
			Description = "Equip 4 Hype Crew members instead of 3.", SuggestedRobux = 149 },
		-- Dunk Pass premium track for Season 1 (SeasonConfig PassKey). Id 0 = not created yet.
		{ Key = "DunkPass", Id = 1998615194, Name = "Dunk Pass: Season 1", Icon = "DUNK\nPASS",
			Description = "Unlocks the premium Dunk Pass track for Season 1: Launch Jets, the Rocket ball, Hype Man, the Legendary Launch Legend, extra packs, Cash and boosts.", SuggestedRobux = 299 },
	},
	-- Must be a Developer Product (repeatable), not a game pass.
	Products = {
		{ Key = "CashBoost", Id = 3715129560, Name = "Cash Boost", Icon = "15\nMIN",
			Description = "2x Cash for 15 minutes (stacks up to 60).", BoostMinutes = 15, SuggestedRobux = 25 },
		-- "Boost that payout!" card (PayoutOffer below). Multiplier = the Cash the player just won
		-- is paid this many times in total. Hidden = only sold from that card, not in the Locker.
		-- (Roblox's filter rejects "Payout" in product names, so the products say "Reward".)
		{ Key = "PayoutX2", Id = 3716333601, Name = "x2 Reward", Icon = "x2", Hidden = true, Multiplier = 2,
			Description = "Doubles the Cash you just won from a contest, a Golden Ball or a big dunk.", SuggestedRobux = 12 },
		{ Key = "PayoutX4", Id = 3716334299, Name = "x4 Reward", Icon = "x4", Hidden = true, Multiplier = 4,
			Description = "Quadruples the Cash you just won from a contest, a Golden Ball or a big dunk.", SuggestedRobux = 39 },
		{ Key = "PayoutX7", Id = 3716334447, Name = "x7 Reward", Icon = "x7", Hidden = true, Multiplier = 7,
			Description = "Multiplies by 7 the Cash you just won from a contest, a Golden Ball or a big dunk.", SuggestedRobux = 99 },
		-- Cash packs: PackDunks dunks' worth of Cash at the buyer's Vertical (DailyConfig.DunkValue),
		-- so they stay worth buying at every stage of the game.
		{ Key = "CashPackSmall", Id = 3716334976, Name = "Cash Stack", Icon = "CASH\nSTACK", PackDunks = 150,
			Description = "Cash worth 150 dunks at your Vertical.", SuggestedRobux = 29 },
		{ Key = "CashPackLarge", Id = 3716335075, Name = "Cash Vault", Icon = "CASH\nVAULT", PackDunks = 1000,
			Description = "Cash worth 1,000 dunks at your Vertical.", SuggestedRobux = 149 },
	},
	-- "Boost that payout!" offer (PayoutOfferService). Right after a big enough payout, a card
	-- offers the PayoutX products above. It only shows once all three have an Id.
	PayoutOffer = {
		MinDunks = 3, -- a payout must be worth at least 3 plain dunks (DailyConfig.DunkValue) to be offered
		CooldownSeconds = 120, -- at most one offer per player every 2 minutes
		OfferSeconds = 8, -- how long the card stays up
		WindowSeconds = 300, -- a boost applies to a payout up to 5 minutes old
		FallbackDunks = 10, -- otherwise the boost pays (multiplier - 1) x 10 dunks
	},
	-- Players with the 2x Cash pass earn this multiplier on dunk and trick Cash.
	DoubleCashMultiplier = 2,
	DoubleDailyMultiplier = 2,
	-- Studio only: pretend to own these pass Keys so their effects can be tested before
	-- the passes exist. Ignored on live servers. Keep it empty when you're done testing.
	StudioOwnedPasses = {},
}

function MonetizationConfig.GetPass(key: string)
	for _, pass in MonetizationConfig.Passes do
		if pass.Key == key then return pass end
	end
	return nil
end

-- The payout boosts (Products with a Multiplier), lowest multiplier first.
function MonetizationConfig.PayoutProducts()
	local list = {}
	for _, product in MonetizationConfig.Products do
		if product.Multiplier then table.insert(list, product) end
	end
	table.sort(list, function(first, second) return first.Multiplier < second.Multiplier end)
	return list
end

function MonetizationConfig.ProductById(productId: number)
	for _, product in MonetizationConfig.Products do
		if product.Id ~= 0 and product.Id == productId then return product end
	end
	return nil
end

return MonetizationConfig
