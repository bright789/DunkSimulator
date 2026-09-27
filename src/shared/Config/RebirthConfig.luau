-- Rebirth: once you are strong enough (only reachable at College Arena), start over from
-- the Neighborhood with permanent Cash and Training multipliers. Server-authoritative:
-- RebirthService validates everything; clients only display these numbers.
local RebirthConfig = {
	-- Needed for the next rebirth (n = rebirths already done).
	RequiredVertical = 200,
	BaseCash = 100000,
	CashGrowth = 1.6, -- each rebirth costs 1.6x the previous one
	-- Permanent bonuses per rebirth (stack additively).
	CashBonusPerRebirth = 0.5, -- dunk and air-trick Cash x(1 + 0.5 n)
	TrainingBonusPerRebirth = 0.25, -- Vertical training x(1 + 0.25 n)
	MaxRebirths = 99,
	RequestCooldownSeconds = 1.5,
	ReadCooldownSeconds = 0.5,
	-- Reset on rebirth: Cash, Vertical, Training level, court unlocks and current court (back
	-- to the Neighborhood). Kept: rebirths and claimed challenges.
}

function RebirthConfig.Requirement(rebirths: number)
	return {
		Vertical = RebirthConfig.RequiredVertical,
		Cash = math.floor(RebirthConfig.BaseCash * RebirthConfig.CashGrowth ^ math.max(rebirths, 0) + 0.5),
	}
end

function RebirthConfig.CashMultiplier(rebirths: number): number
	return 1 + RebirthConfig.CashBonusPerRebirth * math.max(rebirths or 0, 0)
end

function RebirthConfig.TrainingMultiplier(rebirths: number): number
	return 1 + RebirthConfig.TrainingBonusPerRebirth * math.max(rebirths or 0, 0)
end

return RebirthConfig
