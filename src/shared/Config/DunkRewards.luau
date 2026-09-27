-- Dunk Cash rules shared by the server (which pays) and clients (which only display).
--
-- Dunk payout = style Reward x court DunkCashMultiplier x Vertical multiplier x slam timing.
-- Air tricks: a dunk started high above the rim drops in with a combo of tricks. Each
-- trick pays its own Cash the moment the server's timeline finishes it, before the dunk
-- lands. Higher drops fit more tricks; higher Vertical unlocks flashier tricks to mix in.
local DunkRewards = {
	Vertical = {
		-- Every Vertical point above Start adds BonusPerPoint to the dunk multiplier
		-- (0.01 = +1% per point: 75 Vertical pays x1.45, 150 Vertical pays x2.2).
		Start = 30,
		BonusPerPoint = 0.01,
		MaxMultiplier = 5,
	},
	-- Perfect-slam timing: press again right as the slam starts. The server judges the press
	-- (its own clock minus the player's latency) against the real Slam moment.
	Timing = {
		PerfectEarlySeconds = 0.09,
		PerfectLateSeconds = 0.07,
		GoodEarlySeconds = 0.22,
		GoodLateSeconds = 0.14,
		MaxLatencyCompensationSeconds = 0.25,
		-- Dunk Cash multiplier per rating (air-trick Cash is not affected).
		Multipliers = { Perfect = 1.5, Good = 1.15 },
	},
	Tricks = {
		-- Drops shorter than this play no tricks; every StudsPerTrick above it adds one.
		MinDropStuds = 12,
		StudsPerTrick = 16,
		MaxTricks = 6,
		-- Air time around the combo: tuck before the first trick, open up after the last.
		TuckSeconds = 0.15,
		OpenSeconds = 0.2,
		-- The Nth trick in a combo pays x(1 + ComboBonusPerTrick * (N - 1)).
		ComboBonusPerTrick = 0.25,
		-- Tricks are also paid the court's DunkCashMultiplier.
		-- The equipped style's DescentTrick always opens the combo; the rest are mixed from
		-- every trick unlocked at the player's Vertical.
		Definitions = {
			Spin360 = { DisplayName = "360", RequiredVertical = 0, Seconds = 0.3, Cash = 4, Order = 1 },
			FrontFlip = { DisplayName = "FRONT FLIP", RequiredVertical = 60, Seconds = 0.34, Cash = 6, Order = 2 },
			Cartwheel = { DisplayName = "CARTWHEEL", RequiredVertical = 80, Seconds = 0.34, Cash = 7, Order = 3 },
			Corkscrew = { DisplayName = "CORKSCREW", RequiredVertical = 95, Seconds = 0.4, Cash = 9, Order = 4 },
			BackFlip = { DisplayName = "BACKFLIP", RequiredVertical = 110, Seconds = 0.36, Cash = 10, Order = 5 },
			Spin720 = { DisplayName = "720", RequiredVertical = 125, Seconds = 0.42, Cash = 12, Order = 6 },
		},
	},
}

function DunkRewards.VerticalMultiplier(vertical: number): number
	local config = DunkRewards.Vertical
	local bonus = math.max(0, (tonumber(vertical) or 0) - config.Start) * config.BonusPerPoint
	return math.min(1 + bonus, config.MaxMultiplier)
end

function DunkRewards.TimingMultiplier(rating: string?): number
	return rating and DunkRewards.Timing.Multipliers[rating] or 1
end

function DunkRewards.DunkCash(styleReward: number, courtMultiplier: number, vertical: number, rating: string?): number
	return math.floor(styleReward * courtMultiplier * DunkRewards.VerticalMultiplier(vertical)
		* DunkRewards.TimingMultiplier(rating) + 0.5)
end

function DunkRewards.GetTrick(trickId)
	return type(trickId) == "string" and DunkRewards.Tricks.Definitions[trickId] or nil
end

-- Cash for the trick in position `comboIndex` (1 = first) of a combo.
function DunkRewards.TrickCash(trickId: string, comboIndex: number, courtMultiplier: number): number
	local trick = DunkRewards.GetTrick(trickId)
	if not trick then return 0 end
	local combo = 1 + DunkRewards.Tricks.ComboBonusPerTrick * math.max(comboIndex - 1, 0)
	return math.floor(trick.Cash * combo * courtMultiplier + 0.5)
end

function DunkRewards.TrickCount(dropStuds: number): number
	local config = DunkRewards.Tricks
	if dropStuds < config.MinDropStuds then return 0 end
	return math.min(1 + math.floor((dropStuds - config.MinDropStuds) / config.StudsPerTrick), config.MaxTricks)
end

function DunkRewards.UnlockedTricks(vertical: number): { string }
	local ids = {}
	for trickId, trick in DunkRewards.Tricks.Definitions do
		if vertical >= trick.RequiredVertical then table.insert(ids, trickId) end
	end
	table.sort(ids, function(a, b)
		return DunkRewards.Tricks.Definitions[a].Order < DunkRewards.Tricks.Definitions[b].Order
	end)
	return ids
end

-- Combo for one dunk: the style's signature trick first, then unlocked tricks shuffled so
-- none repeats until the pool runs out, and never the same trick twice in a row.
function DunkRewards.PlanCombo(signature: string?, vertical: number, dropStuds: number, random: Random): { string }
	local count = DunkRewards.TrickCount(dropStuds)
	local combo = {}
	if count == 0 then return combo end
	local used = {}
	if DunkRewards.GetTrick(signature) then
		table.insert(combo, signature :: string)
		used[signature :: string] = true
	end
	local pool = DunkRewards.UnlockedTricks(vertical)
	local bag = {}
	while #combo < count and #pool > 0 do
		if #bag == 0 then
			-- Refill with tricks not used yet in this combo (all of them once every one is used).
			for _, trickId in pool do
				if not used[trickId] then table.insert(bag, trickId) end
			end
			if #bag == 0 then
				table.clear(used)
				bag = table.clone(pool)
			end
			for index = #bag, 2, -1 do
				local swap = random:NextInteger(1, index)
				bag[index], bag[swap] = bag[swap], bag[index]
			end
		end
		local pick = table.remove(bag)
		if pick ~= combo[#combo] or #pool == 1 then
			table.insert(combo, pick)
			used[pick] = true
		elseif #bag > 0 then
			-- Put it back under the next candidate so a trick never repeats back to back.
			table.insert(bag, 1, pick)
		end
	end
	return combo
end

-- Air time the combo needs (0 when there are no tricks).
function DunkRewards.ComboSeconds(combo: { string }): number
	if #combo == 0 then return 0 end
	local seconds = DunkRewards.Tricks.TuckSeconds + DunkRewards.Tricks.OpenSeconds
	for _, trickId in combo do
		local trick = DunkRewards.GetTrick(trickId)
		seconds += trick and trick.Seconds or 0
	end
	return seconds
end

return DunkRewards
