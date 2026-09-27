-- Locker: sneakers and basketball skins bought with Cash. Shoes are visible on your feet
-- (everyone sees them) and add a small bonus to air-trick Cash; ball skins are cosmetic
-- (color, seams, slam trail). Purchases are permanent and survive Rebirth. LockerService
-- decides everything; clients only display these numbers.
local LockerConfig = {
	RequestCooldownSeconds = 0.3,
	ReadCooldownSeconds = 0.5,
	Kinds = { "Shoes", "Balls" },
	Shoes = {
		{ Id = "classic", Name = "Classic Lows", Price = 0, TrickBonus = 0,
			Upper = Color3.fromRGB(245, 245, 245), Sole = Color3.fromRGB(150, 156, 170), Accent = Color3.fromRGB(28, 40, 80) },
		{ Id = "court_kings", Name = "Court Kings", Price = 1000, TrickBonus = 0.05,
			Upper = Color3.fromRGB(220, 50, 50), Sole = Color3.fromRGB(245, 245, 245), Accent = Color3.fromRGB(26, 26, 30) },
		{ Id = "sky_risers", Name = "Sky Risers", Price = 7500, TrickBonus = 0.1,
			Upper = Color3.fromRGB(64, 170, 255), Sole = Color3.fromRGB(245, 245, 245), Accent = Color3.fromRGB(255, 196, 24) },
		{ Id = "rim_rattlers", Name = "Rim Rattlers", Price = 30000, TrickBonus = 0.15,
			Upper = Color3.fromRGB(255, 128, 28), Sole = Color3.fromRGB(26, 26, 30), Accent = Color3.fromRGB(245, 245, 245) },
		{ Id = "cloud_nines", Name = "Cloud Nines", Price = 90000, TrickBonus = 0.2,
			Upper = Color3.fromRGB(250, 250, 255), Sole = Color3.fromRGB(150, 220, 255), Accent = Color3.fromRGB(64, 170, 255), Glow = true },
		{ Id = "galaxy_jets", Name = "Galaxy Jets", Price = 250000, TrickBonus = 0.25,
			Upper = Color3.fromRGB(104, 52, 190), Sole = Color3.fromRGB(20, 18, 40), Accent = Color3.fromRGB(90, 255, 240), Glow = true },
		-- VIP pass exclusive (Pass = the MonetizationConfig pass Key that unlocks it).
		{ Id = "diamond_kicks", Name = "Diamond Kicks", Price = 0, Pass = "VIP", TrickBonus = 0.2,
			Upper = Color3.fromRGB(215, 245, 255), Sole = Color3.fromRGB(120, 220, 255), Accent = Color3.fromRGB(255, 255, 255), Glow = true },
	},
	Balls = {
		{ Id = "classic", Name = "Classic", Price = 0, Color = Color3.fromRGB(230, 115, 25), Material = Enum.Material.Leather,
			Seam = Color3.fromRGB(26, 18, 14), Trail = Color3.fromRGB(255, 190, 110), TrailLifetime = 0.1 },
		{ Id = "street", Name = "Street Black", Price = 1500, Color = Color3.fromRGB(34, 34, 40), Material = Enum.Material.Leather,
			Seam = Color3.fromRGB(255, 128, 28), Trail = Color3.fromRGB(255, 128, 28), TrailLifetime = 0.12 },
		{ Id = "ice", Name = "Ice Cold", Price = 8000, Color = Color3.fromRGB(170, 225, 255), Material = Enum.Material.SmoothPlastic,
			Seam = Color3.fromRGB(245, 250, 255), Trail = Color3.fromRGB(120, 200, 255), TrailLifetime = 0.18 },
		{ Id = "gold", Name = "Gold Rush", Price = 25000, Color = Color3.fromRGB(255, 196, 40), Material = Enum.Material.Foil,
			Seam = Color3.fromRGB(120, 80, 10), Trail = Color3.fromRGB(255, 214, 64), TrailLifetime = 0.2 },
		{ Id = "galaxy", Name = "Galaxy", Price = 90000, Color = Color3.fromRGB(60, 30, 120), Material = Enum.Material.SmoothPlastic,
			Seam = Color3.fromRGB(255, 90, 255), GlowSeams = true, Trail = Color3.fromRGB(170, 80, 255), TrailLifetime = 0.3 },
		{ Id = "lava", Name = "Lava", Price = 200000, Color = Color3.fromRGB(44, 22, 16), Material = Enum.Material.Basalt,
			Seam = Color3.fromRGB(255, 110, 20), GlowSeams = true, Trail = Color3.fromRGB(255, 90, 20), TrailLifetime = 0.35 },
		{ Id = "diamond", Name = "Diamond", Price = 0, Pass = "VIP", Color = Color3.fromRGB(205, 240, 255), Material = Enum.Material.Foil,
			Seam = Color3.fromRGB(255, 255, 255), GlowSeams = true, Trail = Color3.fromRGB(150, 230, 255), TrailLifetime = 0.4 },
	},
	DefaultId = "classic",
}

function LockerConfig.Get(kind: string, itemId): { [string]: any }?
	local list = LockerConfig[kind]
	if type(list) ~= "table" or type(itemId) ~= "string" or (kind ~= "Shoes" and kind ~= "Balls") then return nil end
	for _, item in list do
		if item.Id == itemId then return item end
	end
	return nil
end

-- Saved state (schema v10): owned ids per kind (always including the free item) and the
-- equipped id per kind.
function LockerConfig.DefaultState()
	return {
		Shoes = { Owned = { [LockerConfig.DefaultId] = true }, Equipped = LockerConfig.DefaultId },
		Balls = { Owned = { [LockerConfig.DefaultId] = true }, Equipped = LockerConfig.DefaultId },
	}
end

function LockerConfig.CopyState(state)
	local copy = {}
	for _, kind in LockerConfig.Kinds do
		copy[kind] = { Owned = table.clone(state[kind].Owned), Equipped = state[kind].Equipped }
	end
	return copy
end

function LockerConfig.SameState(first, second): boolean
	if type(first) ~= "table" or type(second) ~= "table" then return false end
	for _, kind in LockerConfig.Kinds do
		local a, b = first[kind], second[kind]
		if type(a) ~= "table" or type(b) ~= "table" or a.Equipped ~= b.Equipped
			or type(a.Owned) ~= "table" or type(b.Owned) ~= "table" then return false end
		for itemId, owned in a.Owned do
			if b.Owned[itemId] ~= owned then return false end
		end
		for itemId in b.Owned do
			if a.Owned[itemId] == nil then return false end
		end
	end
	return true
end

-- Cleans saved locker data: unknown items are dropped, the free item is always owned and
-- the equipped item must be owned. Returns (state, repaired).
function LockerConfig.Sanitize(stored)
	local state = LockerConfig.DefaultState()
	if type(stored) ~= "table" then return state, true end
	local repaired = false
	for _, kind in LockerConfig.Kinds do
		local original = stored[kind]
		if type(original) ~= "table" or type(original.Owned) ~= "table" then
			repaired = true
		else
			for itemId, owned in original.Owned do
				if owned == true and LockerConfig.Get(kind, itemId) then
					state[kind].Owned[itemId] = true
				else
					repaired = true
				end
			end
			if original.Owned[LockerConfig.DefaultId] ~= true then repaired = true end
			if state[kind].Owned[original.Equipped] then
				state[kind].Equipped = original.Equipped
			else
				repaired = true
			end
		end
	end
	return state, repaired
end

return LockerConfig
