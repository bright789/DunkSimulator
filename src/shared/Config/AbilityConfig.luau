-- Abilities (see docs/ABILITIES.md). Each one is EARNED for free when you reach its
-- UnlockVertical, or BOUGHT early for UnlockPrice Cash. Cash upgrades (levels 2-5) shorten
-- the cooldown. Press it and it's ARMED: your next completed dunk uses it, and it recharges
-- from the moment you pressed it. The server decides everything; clients only display.
local AbilityConfig = {
	MaxLevel = 5,
	RequestCooldownSeconds = 0.25,
	Abilities = {
		SlowMo = {
			Order = 1,
			DisplayName = "SLOW-MO SLAM",
			Icon = "⏳",
			Key = Enum.KeyCode.One,
			GamepadKey = Enum.KeyCode.DPadLeft,
			KeyLabel = "1",
			Description = "Your next dunk drops in slow motion and the PERFECT and GOOD zones are twice as wide.",
			UnlockVertical = 40,
			UnlockPrice = 1500,
			-- Seconds to recharge at levels 1-5, and the Cash to buy levels 2-5.
			Cooldowns = { 60, 52, 45, 38, 30 },
			UpgradePrices = { 3000, 9000, 25000, 60000 },
			-- Timing windows x2; the drop into the dunk takes x1.5 as long.
			TimingScale = 2,
			DescentScale = 1.5,
			Color = Color3.fromRGB(90, 190, 255),
		},
		Fireball = {
			Order = 2,
			DisplayName = "FIREBALL",
			Icon = "🔥",
			Key = Enum.KeyCode.Two,
			GamepadKey = Enum.KeyCode.DPadUp,
			KeyLabel = "2",
			Description = "Your next dunk pays 2x Cash and the ball catches fire.",
			UnlockVertical = 90,
			UnlockPrice = 8000,
			Cooldowns = { 120, 105, 90, 75, 60 },
			UpgradePrices = { 10000, 30000, 75000, 180000 },
			-- Multiplies the dunk's Cash (air tricks are not doubled).
			CashMultiplier = 2,
			Color = Color3.fromRGB(255, 120, 40),
		},
		HangTime = {
			Order = 3,
			DisplayName = "HANG TIME",
			Icon = "🕊",
			Key = Enum.KeyCode.Three,
			GamepadKey = Enum.KeyCode.DPadRight,
			KeyLabel = "3",
			Description = "Your next dunk floats down with 2 extra air tricks, and every trick pays Cash.",
			UnlockVertical = 140,
			UnlockPrice = 25000,
			Cooldowns = { 90, 78, 66, 54, 45 },
			UpgradePrices = { 25000, 60000, 150000, 350000 },
			-- Must be at most DunkRewards.Tricks.MaxBonusTricks.
			ExtraTricks = 2,
			Color = Color3.fromRGB(200, 255, 240),
		},
	},
}

function AbilityConfig.Get(abilityId)
	return type(abilityId) == "string" and AbilityConfig.Abilities[abilityId] or nil
end

-- Ability ids in display order (1, 2, 3).
function AbilityConfig.Ids(): { string }
	local ids = {}
	for abilityId in AbilityConfig.Abilities do table.insert(ids, abilityId) end
	table.sort(ids, function(a, b) return AbilityConfig.Abilities[a].Order < AbilityConfig.Abilities[b].Order end)
	return ids
end

-- Recharge seconds at a level (1-5).
function AbilityConfig.Cooldown(abilityId: string, level: number): number
	local definition = AbilityConfig.Get(abilityId)
	if not definition then return math.huge end
	return definition.Cooldowns[math.clamp(level, 1, #definition.Cooldowns)]
end

-- Cash to go from `level` to the next one (nil when locked or maxed).
function AbilityConfig.UpgradePrice(abilityId: string, level: number): number?
	local definition = AbilityConfig.Get(abilityId)
	if not definition or level < 1 or level >= AbilityConfig.MaxLevel then return nil end
	return definition.UpgradePrices[level]
end

-- Saved record (schema v12): ability id -> level, 0 = locked.
function AbilityConfig.DefaultState()
	local state = {}
	for abilityId in AbilityConfig.Abilities do state[abilityId] = 0 end
	return state
end

function AbilityConfig.Sanitize(stored)
	local state = AbilityConfig.DefaultState()
	if type(stored) ~= "table" then return state, true end
	local repaired = false
	for abilityId in AbilityConfig.Abilities do
		local level = stored[abilityId]
		if type(level) == "number" and level == level then
			state[abilityId] = math.clamp(math.floor(level), 0, AbilityConfig.MaxLevel)
		end
		if state[abilityId] ~= level then repaired = true end
	end
	for key in stored do
		if not AbilityConfig.Abilities[key] then repaired = true end
	end
	return state, repaired
end

function AbilityConfig.CopyState(state)
	return table.clone(state)
end

function AbilityConfig.SameState(first, second): boolean
	for abilityId in AbilityConfig.Abilities do
		if first[abilityId] ~= second[abilityId] then return false end
	end
	return true
end

-- A copy of DunkRewards.Timing with the Perfect/Good windows scaled (Slow-Mo Slam).
function AbilityConfig.ScaledTiming(timing, scale: number)
	local scaled = table.clone(timing)
	for _, key in { "PerfectEarlySeconds", "PerfectLateSeconds", "GoodEarlySeconds", "GoodLateSeconds" } do
		scaled[key] = timing[key] * scale
	end
	return scaled
end

-- True if `abilityId` is in a comma list like the "DunkAbilities" attribute ("SlowMo,Fireball").
function AbilityConfig.InList(list, abilityId: string): boolean
	if type(list) ~= "string" then return false end
	for item in string.gmatch(list, "[^,]+") do
		if item == abilityId then return true end
	end
	return false
end

return AbilityConfig
