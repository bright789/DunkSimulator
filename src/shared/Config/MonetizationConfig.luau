-- Robux game passes and developer products. Paste each Id from the Creator Hub
-- (Creations > this experience > Monetization > Passes / Developer Products). An Id of 0
-- means "not on sale yet": the PASSES tab shows COMING SOON and nothing can be bought.
-- MonetizationService checks ownership on the server; clients only open Roblox's prompt.
local MonetizationConfig = {
	Passes = {
		{ Key = "DoubleCash", Id = 0, Name = "2x Cash", Icon = "2x",
			Description = "Double Cash from every dunk and air trick, forever. Stacks with Cash Boosts.", SuggestedRobux = 249 },
		{ Key = "VIP", Id = 0, Name = "VIP", Icon = "VIP",
			Description = "Diamond Kicks and the Diamond ball in your Locker, plus a VIP tag.", SuggestedRobux = 149 },
		{ Key = "DoubleDaily", Id = 0, Name = "2x Daily Rewards", Icon = "2x\nDAILY",
			Description = "Double Cash from daily login rewards and daily challenges.", SuggestedRobux = 99 },
	},
	Products = {
		{ Key = "CashBoost", Id = 0, Name = "Cash Boost", Icon = "15\nMIN",
			Description = "2x Cash for 15 minutes (stacks up to 60).", BoostMinutes = 15, SuggestedRobux = 25 },
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

function MonetizationConfig.ProductById(productId: number)
	for _, product in MonetizationConfig.Products do
		if product.Id ~= 0 and product.Id == productId then return product end
	end
	return nil
end

return MonetizationConfig
