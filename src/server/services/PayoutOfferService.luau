-- "Boost that payout!" offer (MonetizationConfig.PayoutOffer). Right after a worthwhile lump
-- payout (a Dunk Contest prize, the Golden Ball or a big dunk) the player's screen shows a
-- small card offering the PayoutX2 / X4 / X7 developer products.
--   OnPayout: ContestService, PickupService and DunkService report a payout here. It is
--     remembered as the player's boostable payout, and a card is offered when the payout is
--     big enough, the cooldown has passed, the tutorial is over and all three products exist.
--   Grant: MonetizationService calls this from ProcessReceipt. The boost pays
--     (multiplier - 1) x the remembered payout once (if it is at most WindowSeconds old),
--     otherwise (multiplier - 1) x FallbackDunks dunks.
-- Events to the client on PayoutOffer: ("Offer", { Amount, Source }) from here, and
-- ("Boosted", { Multiplier, Bonus }) / ("CashPack", { Cash, Key }) from MonetizationService
-- once the purchase is saved. Clients send nothing on this remote.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local Milestones = require(ReplicatedStorage.Shared.Config.MilestoneConfig)
local DataConfig = require(script.Parent.Parent.Config.DataConfig)
local PlayerService = require(script.Parent.PlayerService)
local Analytics = require(script.Parent.AnalyticsReporter)

local PayoutOfferService = {}
local initialized = false
local remote: RemoteEvent? = nil
local SOURCES = { Contest = true, GoldenBall = true, Dunk = true }
-- Each player's boostable payout and when they may next be offered a card (os.clock times).
local payouts: { [Player]: { Amount: number, At: number, Boosted: boolean } } = {}
local nextOffer: { [Player]: number } = {}

-- The card is only offered once every payout product has a real Id.
local function onSale(): boolean
	local products = Monetization.PayoutProducts()
	for _, product in products do
		if product.Id == 0 then return false end
	end
	return #products > 0
end

-- `source` is "Contest", "GoldenBall" or "Dunk"; `amount` is the Cash just paid.
function PayoutOfferService.OnPayout(player: Player, amount: number, source: string)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or not SOURCES[source]
		or not PlayerService.IsDataReady(player) then
		return
	end
	local tuning = Monetization.PayoutOffer
	local now = os.clock()
	amount = math.floor(amount)
	-- Remember it even when no card is shown. A smaller payout never replaces a bigger one that
	-- can still be boosted, so a bonus is never less than what a card on screen promised.
	local current = payouts[player]
	if not current or current.Boosted or now - current.At > tuning.WindowSeconds or amount >= current.Amount then
		payouts[player] = { Amount = amount, At = now, Boosted = false }
	end
	if not remote or not onSale() or now < (nextOffer[player] or 0) then return end
	if amount < tuning.MinDunks * Daily.DunkValue(PlayerService.GetVertical(player) or 0) then return end
	local snapshot = PlayerService.GetMilestoneSnapshot(player)
	if not snapshot or Milestones.TutorialActive(snapshot) then return end
	nextOffer[player] = now + tuning.CooldownSeconds
	remote:FireClient(player, "Offer", { Amount = amount, Source = source })
	Analytics.Custom(player, "PayoutOfferShown_" .. source)
end

-- Pays a bought boost (MonetizationService's ProcessReceipt only). Returns true and the
-- bonus once the Cash is added. A player at the Cash limit gets what fits (maybe 0) so the
-- receipt never retries forever.
function PayoutOfferService.Grant(player: Player, multiplier: number): (boolean, number)
	local cash = PlayerService.GetCash(player)
	if type(multiplier) ~= "number" or multiplier < 2 or not cash or not PlayerService.IsDataReady(player) then
		return false, 0
	end
	local tuning = Monetization.PayoutOffer
	local payout = payouts[player]
	local base
	if payout and not payout.Boosted and os.clock() - payout.At <= tuning.WindowSeconds then
		base = payout.Amount
	else
		base = tuning.FallbackDunks * Daily.DunkValue(PlayerService.GetVertical(player) or 0)
	end
	local bonus = math.clamp(math.floor((multiplier - 1) * base + 0.5), 0, math.max(0, DataConfig.MaxCash - cash))
	if not PlayerService.GrantCash(player, bonus, "PayoutX" .. multiplier, "IAP") then return false, 0 end
	if payout then payout.Boosted = true end
	Analytics.Custom(player, "PayoutBoost", multiplier)
	return true, bonus
end

function PayoutOfferService.Init()
	if initialized then return end
	initialized = true
	remote = ReplicatedStorage.Remotes:WaitForChild("PayoutOffer")
	Players.PlayerRemoving:Connect(function(player)
		payouts[player] = nil
		nextOffer[player] = nil
	end)
end

return PayoutOfferService
