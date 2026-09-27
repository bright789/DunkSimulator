-- Redeem codes (CODES button). Server-only, so players can't read codes before you post them.
-- Codes are case-insensitive; each works once per player (recorded in the codes DataStore).
--   Dunks        Cash worth this many dunks at the player's current Vertical.
--   BoostMinutes minutes added to the 2x Cash Boost (stacks up to 60 like other boosts).
--   Expires      Unix time (UTC) after which the code stops working (nil = never).
--   GroupOnly    only members of the game's community group can redeem it.
-- To add a code: add a line here, sync, publish. To retire one: set Expires or delete it.
return {
	Codes = {
		RELEASE = { Dunks = 20, BoostMinutes = 15 },
		DUNKSIM = { Dunks = 10 },
		GROUPDUNK = { Dunks = 30, BoostMinutes = 15, GroupOnly = true },
	},
	MaxLength = 30,
	RequestCooldownSeconds = 2,
}
