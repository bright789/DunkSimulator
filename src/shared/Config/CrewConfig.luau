-- Hype Crew (see docs/HYPE_CREW.md): collectible crew members from Cash packs. Each one gives
-- +% dunk Cash or +% training while equipped (3 slots, 4 with the Crew Slot pass). Copies add
-- stars (up to MaxStars) and every star makes the bonus bigger; copies past MaxStars refund
-- some Cash. Owning a whole pack's set gives a permanent SetBonus. Server decides everything.
local CrewConfig = {
	MaxStars = 5,
	-- Each star past the first adds this much of the base bonus (5 stars = x2).
	StarStep = 0.25,
	Slots = 3,
	PassSlots = 4,
	-- Share of the pack price refunded for a copy of a member already at MaxStars.
	MaxedRefund = 0.25,
	-- Permanent +Cash for owning every member of a pack's set.
	SetBonusCash = 0.05,
	-- Lucky Packs pass: the weights of these rarities are multiplied by LuckyMultiplier.
	LuckyMultiplier = 2,
	LuckyRarities = { Epic = true, Legendary = true },
	RequestCooldownSeconds = 0.4,
	-- Packs cost Cash, and Cash can be bought with Robux, so packs are paid random items. Where
	-- Roblox restricts those (PolicyService ArePaidRandomItemsRestricted) packs can't be opened.
	RestrictedMessage = "Hype Crew packs aren't available in your region.",

	Rarities = {
		Common = { Order = 1, Bonus = 0.04, Color = Color3.fromRGB(200, 205, 215) },
		Uncommon = { Order = 2, Bonus = 0.07, Color = Color3.fromRGB(90, 220, 110) },
		Rare = { Order = 3, Bonus = 0.12, Color = Color3.fromRGB(70, 160, 255) },
		Epic = { Order = 4, Bonus = 0.2, Color = Color3.fromRGB(190, 90, 255) },
		Legendary = { Order = 5, Bonus = 0.35, Color = Color3.fromRGB(255, 200, 40) },
	},

	-- Packs unlock with their court. Odds are weights per rarity.
	Packs = {
		Street = { Order = 1, Name = "STREET PACK", Court = "Neighborhood", Price = 500,
			Color = Color3.fromRGB(255, 150, 50), Odds = { Common = 60, Uncommon = 30, Rare = 10 } },
		Varsity = { Order = 2, Name = "VARSITY PACK", Court = "HighSchool", Price = 5000,
			Color = Color3.fromRGB(60, 130, 255), Odds = { Common = 35, Uncommon = 35, Rare = 24, Epic = 6 } },
		Campus = { Order = 3, Name = "CAMPUS PACK", Court = "College", Price = 40000,
			Color = Color3.fromRGB(160, 80, 255), Odds = { Uncommon = 35, Rare = 38, Epic = 22, Legendary = 5 } },
		Skyline = { Order = 4, Name = "SKYLINE PACK", Court = "Rooftop", Price = 200000,
			Color = Color3.fromRGB(255, 60, 200), Odds = { Rare = 45, Epic = 40, Legendary = 15 } },
		-- Dunk Pass exclusives (SeasonConfig rewards). Hidden: never sold, no set bonus.
		Season1 = { Order = 5, Name = "DUNK PASS S1", Hidden = true, Price = 0,
			Color = Color3.fromRGB(255, 170, 40), Odds = {} },
	},

	-- Boost: "Cash" (dunk and air-trick Cash) or "Train" (Vertical per training rep).
	Members = {
		corner_fan = { Name = "Corner Fan", Icon = "🙋", Pack = "Street", Rarity = "Common", Boost = "Cash" },
		ball_boy = { Name = "Ball Boy", Icon = "🏀", Pack = "Street", Rarity = "Common", Boost = "Train" },
		street_mc = { Name = "Streetball MC", Icon = "🎤", Pack = "Street", Rarity = "Uncommon", Boost = "Cash" },
		park_coach = { Name = "Park Coach", Icon = "📋", Pack = "Street", Rarity = "Uncommon", Boost = "Train" },
		graffiti_artist = { Name = "Graffiti Artist", Icon = "🎨", Pack = "Street", Rarity = "Rare", Boost = "Cash" },

		band_kid = { Name = "Band Kid", Icon = "🥁", Pack = "Varsity", Rarity = "Common", Boost = "Train" },
		cheer_captain = { Name = "Cheer Captain", Icon = "📣", Pack = "Varsity", Rarity = "Uncommon", Boost = "Cash" },
		hawk_mascot = { Name = "Hawk Mascot", Icon = "🦅", Pack = "Varsity", Rarity = "Rare", Boost = "Cash" },
		varsity_coach = { Name = "Varsity Coach", Icon = "🧢", Pack = "Varsity", Rarity = "Rare", Boost = "Train" },
		team_captain = { Name = "Team Captain", Icon = "🏅", Pack = "Varsity", Rarity = "Epic", Boost = "Cash" },

		pep_trumpet = { Name = "Pep Band Trumpet", Icon = "🎺", Pack = "Campus", Rarity = "Uncommon", Boost = "Train" },
		dunk_u_bear = { Name = "Dunk U Bear", Icon = "🐻", Pack = "Campus", Rarity = "Rare", Boost = "Cash" },
		announcer = { Name = "Arena Announcer", Icon = "🎙", Pack = "Campus", Rarity = "Rare", Boost = "Train" },
		star_guard = { Name = "Star Point Guard", Icon = "⭐", Pack = "Campus", Rarity = "Epic", Boost = "Cash" },
		hall_coach = { Name = "Hall of Fame Coach", Icon = "🏆", Pack = "Campus", Rarity = "Legendary", Boost = "Train" },

		neon_dj = { Name = "Neon DJ", Icon = "🎧", Pack = "Skyline", Rarity = "Rare", Boost = "Cash" },
		hype_photographer = { Name = "Hype Photographer", Icon = "📸", Pack = "Skyline", Rarity = "Rare", Boost = "Train" },
		sneaker_mogul = { Name = "Sneaker Mogul", Icon = "👟", Pack = "Skyline", Rarity = "Epic", Boost = "Cash" },
		city_legend = { Name = "City Legend", Icon = "🏙", Pack = "Skyline", Rarity = "Legendary", Boost = "Train" },
		goat = { Name = "The GOAT", Icon = "🐐", Pack = "Skyline", Rarity = "Legendary", Boost = "Cash" },

		rookie_s1 = { Name = "Season Rookie", Icon = "🎟", Pack = "Season1", Rarity = "Epic", Boost = "Train" },
		hype_man_s1 = { Name = "Hype Man", Icon = "🎉", Pack = "Season1", Rarity = "Epic", Boost = "Cash" },
		launch_legend = { Name = "Launch Legend", Icon = "🚀", Pack = "Season1", Rarity = "Legendary", Boost = "Cash" },
	},
}

function CrewConfig.GetMember(memberId)
	return type(memberId) == "string" and CrewConfig.Members[memberId] or nil
end

function CrewConfig.GetPack(packId)
	return type(packId) == "string" and CrewConfig.Packs[packId] or nil
end

-- Pack ids that can be opened, in order (Street first). Hidden packs (Dunk Pass) are left out.
function CrewConfig.PackIds(): { string }
	local ids = {}
	for packId, pack in CrewConfig.Packs do
		if not pack.Hidden then table.insert(ids, packId) end
	end
	table.sort(ids, function(a, b) return CrewConfig.Packs[a].Order < CrewConfig.Packs[b].Order end)
	return ids
end

-- Member ids in collection-book order: by pack, then rarity, then name.
function CrewConfig.MemberIds(): { string }
	local ids = {}
	for memberId in CrewConfig.Members do table.insert(ids, memberId) end
	table.sort(ids, function(a, b)
		local ma, mb = CrewConfig.Members[a], CrewConfig.Members[b]
		local pa, pb = CrewConfig.Packs[ma.Pack].Order, CrewConfig.Packs[mb.Pack].Order
		if pa ~= pb then return pa < pb end
		local ra, rb = CrewConfig.Rarities[ma.Rarity].Order, CrewConfig.Rarities[mb.Rarity].Order
		if ra ~= rb then return ra < rb end
		return ma.Name < mb.Name
	end)
	return ids
end

-- The odds of one pull from `packId` for a player who does (`lucky`) or doesn't own the Lucky
-- Packs pass: a list of { Rarity, Weight, Chance } (Chance 0-1), most common rarity first.
-- CrewService rolls with these weights and CrewView shows these chances, so the odds on
-- screen always match the real roll.
function CrewConfig.Odds(packId, lucky: boolean?): { { Rarity: string, Weight: number, Chance: number } }
	local pack = CrewConfig.GetPack(packId)
	local list = {}
	if not pack then return list end
	local total = 0
	for rarity, weight in pack.Odds do
		if lucky and CrewConfig.LuckyRarities[rarity] then weight *= CrewConfig.LuckyMultiplier end
		table.insert(list, { Rarity = rarity, Weight = weight, Chance = 0 })
		total += weight
	end
	table.sort(list, function(a, b) return CrewConfig.Rarities[a.Rarity].Order < CrewConfig.Rarities[b.Rarity].Order end)
	for _, entry in list do
		entry.Chance = total > 0 and entry.Weight / total or 0
	end
	return list
end

-- Bonus (e.g. 0.12 = +12%) of one member at `stars`.
function CrewConfig.Bonus(memberId: string, stars: number): number
	local member = CrewConfig.GetMember(memberId)
	if not member then return 0 end
	return CrewConfig.Rarities[member.Rarity].Bonus * (1 + CrewConfig.StarStep * (math.clamp(stars, 1, CrewConfig.MaxStars) - 1))
end

-- Pack ids whose whole set is owned.
function CrewConfig.CompletedSets(owned: { [string]: number }): { string }
	local complete = {}
	for _, packId in CrewConfig.PackIds() do
		local all = true
		for memberId, member in CrewConfig.Members do
			if member.Pack == packId and not owned[memberId] then all = false break end
		end
		if all then table.insert(complete, packId) end
	end
	return complete
end

-- Multipliers from a crew record: { Cash = 1.xx, Train = 1.xx }.
function CrewConfig.Multipliers(crew): { Cash: number, Train: number }
	local cash, train = 0, 0
	for _, memberId in crew.Equipped do
		local member = CrewConfig.GetMember(memberId)
		local stars = crew.Owned[memberId]
		if member and stars then
			if member.Boost == "Cash" then cash += CrewConfig.Bonus(memberId, stars) else train += CrewConfig.Bonus(memberId, stars) end
		end
	end
	cash += CrewConfig.SetBonusCash * #CrewConfig.CompletedSets(crew.Owned)
	return { Cash = 1 + cash, Train = 1 + train }
end

-- Saved record (schema v13): Owned = { memberId = stars }, Equipped = { memberId, ... }.
function CrewConfig.DefaultState()
	return { Owned = {}, Equipped = {} }
end

function CrewConfig.Sanitize(stored)
	local state = CrewConfig.DefaultState()
	if type(stored) ~= "table" then return state, true end
	local repaired = false
	if type(stored.Owned) == "table" then
		for memberId, stars in stored.Owned do
			if CrewConfig.GetMember(memberId) and type(stars) == "number" and stars == stars then
				local clean = math.clamp(math.floor(stars), 1, CrewConfig.MaxStars)
				state.Owned[memberId] = clean
				if clean ~= stars then repaired = true end
			else
				repaired = true
			end
		end
	elseif stored.Owned ~= nil then
		repaired = true
	end
	if type(stored.Equipped) == "table" then
		for index, memberId in stored.Equipped do
			if type(index) == "number" and state.Owned[memberId] and not table.find(state.Equipped, memberId)
				and #state.Equipped < CrewConfig.PassSlots then
				table.insert(state.Equipped, memberId)
			else
				repaired = true
			end
		end
	elseif stored.Equipped ~= nil then
		repaired = true
	end
	return state, repaired
end

function CrewConfig.CopyState(state)
	return { Owned = table.clone(state.Owned), Equipped = table.clone(state.Equipped) }
end

function CrewConfig.SameState(first, second): boolean
	if #first.Equipped ~= #second.Equipped then return false end
	for index, memberId in first.Equipped do
		if second.Equipped[index] ~= memberId then return false end
	end
	for memberId, stars in first.Owned do
		if second.Owned[memberId] ~= stars then return false end
	end
	for memberId in second.Owned do
		if first.Owned[memberId] == nil then return false end
	end
	return true
end

return CrewConfig
