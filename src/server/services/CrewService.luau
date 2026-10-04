-- Hype Crew packs and equipping (CrewConfig). The crew record lives in the player's profile
-- (PlayerService "Crew", schema v13) and this service is its only writer. The client sends
-- CrewRequest("Buy", packId, count) / ("Equip", memberId) / ("Unequip", memberId); answers come
-- back on the same remote as ("Opened", results) or ("Result", ok, message).
-- Mirrors for the HUD and the followers: CrewOwned ("id:stars,..."), CrewEquipped ("id,id"),
-- CrewSlots, CrewCash and CrewTrain (bonus in whole percent).
-- Packs cost Cash, which can be bought with Robux, so they are paid random items: in regions
-- where Roblox restricts those (PolicyService), opening packs is refused and PacksRestricted
-- is set on the player so the client can show packs as unavailable.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.CrewConfig)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.AnalyticsReporter)
local SeasonXp = require(script.Parent.SeasonXp)
local SeasonConfig = require(ReplicatedStorage.Shared.Config.SeasonConfig)

local CrewService = {}
local initialized = false
local remote: RemoteEvent
local random = Random.new()
local nextRequest: { [Player]: number } = {}
-- PolicyService answer per player (true = paid random items restricted); nil = not known yet.
local restricted: { [Player]: boolean } = {}
local nextPolicyLookup: { [Player]: number } = {}
local POLICY_RETRY_SECONDS = 60

local function slotsFor(player: Player): number
	return PlayerService.HasPass(player, "CrewSlot") and Config.PassSlots or Config.Slots
end

local function publish(player: Player)
	local crew = PlayerService.GetCrew(player)
	if not crew or player.Parent ~= Players then return end
	local owned = {}
	for memberId, stars in crew.Owned do table.insert(owned, memberId .. ":" .. stars) end
	table.sort(owned)
	local multipliers = Config.Multipliers(crew)
	player:SetAttribute("CrewOwned", table.concat(owned, ","))
	player:SetAttribute("CrewEquipped", table.concat(crew.Equipped, ","))
	player:SetAttribute("CrewSlots", slotsFor(player))
	player:SetAttribute("CrewCash", math.floor((multipliers.Cash - 1) * 100 + 0.5))
	player:SetAttribute("CrewTrain", math.floor((multipliers.Train - 1) * 100 + 0.5))
end

local function reply(player: Player, ok: boolean, message: string)
	if player.Parent == Players then remote:FireClient(player, "Result", ok, message) end
end

-- Asks PolicyService whether paid random items are restricted for this player (one retry).
-- Caches and publishes the answer. A failed lookup counts as restricted (the safe answer)
-- and isn't cached, so it can be asked again after POLICY_RETRY_SECONDS. Yields.
local function lookupPolicy(player: Player): boolean
	if restricted[player] ~= nil then return restricted[player] end
	if os.clock() < (nextPolicyLookup[player] or 0) then return true end
	for attempt = 1, 2 do
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if player.Parent ~= Players then return true end
		if ok and type(info) == "table" then
			restricted[player] = info.ArePaidRandomItemsRestricted == true
			player:SetAttribute("PacksRestricted", restricted[player])
			return restricted[player]
		end
		if attempt == 1 then task.wait(1) end
	end
	warn("[CrewService] PolicyService lookup failed for " .. player.Name .. "; packs are off for now.")
	nextPolicyLookup[player] = os.clock() + POLICY_RETRY_SECONDS
	player:SetAttribute("PacksRestricted", true)
	return true
end

-- Whether Hype Crew packs are off for this player, without waiting: an unknown answer counts
-- as restricted. GiftService uses it to give a pack's value as Cash instead.
function CrewService.PacksRestricted(player: Player): boolean
	return restricted[player] ~= false
end

-- One member from a pack: pick a rarity by the pack's odds (CrewConfig.Odds, the same odds the
-- PACKS page shows; Lucky boosts Epic/Legendary), then any member of that rarity in the pack.
local function roll(packId: string, lucky: boolean): string
	local odds = Config.Odds(packId, lucky)
	local total = 0
	for _, entry in odds do total += entry.Weight end
	local pick = random:NextNumber(0, total)
	local chosen = nil
	for _, entry in odds do
		chosen = entry.Rarity
		pick -= entry.Weight
		if pick <= 0 then break end
	end
	local pool, any = {}, {}
	for memberId, member in Config.Members do
		if member.Pack == packId then
			table.insert(any, memberId)
			if member.Rarity == chosen then table.insert(pool, memberId) end
		end
	end
	table.sort(pool)
	table.sort(any)
	local list = #pool > 0 and pool or any
	return list[random:NextInteger(1, #list)]
end

-- Adds one member to the crew (a new member, a star, or a Cash refund past MaxStars) and
-- returns the reveal result. `refundBase` is what a maxed copy refunds a share of.
local function addMember(player: Player, crew, memberId: string, refundBase: number)
	local stars = crew.Owned[memberId]
	local result = { Id = memberId, New = stars == nil, Refund = 0 }
	if not stars then
		crew.Owned[memberId] = 1
		-- New members join the crew straight away if there's a free slot.
		if #crew.Equipped < slotsFor(player) then table.insert(crew.Equipped, memberId) end
	elseif stars < Config.MaxStars then
		crew.Owned[memberId] = stars + 1
	else
		result.Refund = math.floor(refundBase * Config.MaxedRefund)
		if result.Refund > 0 then PlayerService.GrantCash(player, result.Refund, "CrewRefund", "Gameplay") end
	end
	result.Stars = crew.Owned[memberId]
	return result
end

local function finish(player: Player, packId: string, results)
	publish(player)
	DataService.RequestSave(player)
	if player.Parent == Players then remote:FireClient(player, "Opened", packId, results) end
end

local function buy(player: Player, packId, count)
	local pack = Config.GetPack(packId)
	if not pack or pack.Hidden or (count ~= 1 and count ~= 3) then return end
	if count == 3 and not PlayerService.HasPass(player, "CrewTriple") then
		return reply(player, false, "Opening 3 at once needs the Triple Open pass.")
	end
	if not PlayerService.HasCourt(player, pack.Court) then
		return reply(player, false, "Unlock that court first.")
	end
	-- May wait for PolicyService the first time; nothing has been changed yet.
	if lookupPolicy(player) then return reply(player, false, Config.RestrictedMessage) end
	local crew = PlayerService.GetCrew(player)
	if not crew then return reply(player, false, "Player data is not ready.") end
	local price = pack.Price * count
	if (PlayerService.GetCash(player) or 0) < price then return reply(player, false, "Not enough Cash.") end
	if not PlayerService.SpendCash(player, price, "CrewPack_" .. packId) then return reply(player, false, "Try again in a moment.") end
	local lucky = PlayerService.HasPass(player, "CrewLucky")
	local results = {}
	for _ = 1, count do
		local memberId = roll(packId, lucky)
		table.insert(results, addMember(player, crew, memberId, pack.Price))
		Analytics.Custom(player, "CrewPull_" .. Config.Members[memberId].Rarity)
	end
	SeasonXp.Add(player, SeasonConfig.XP.CrewPack * count)
	finish(player, packId, results)
end

-- The best pack this player's courts have unlocked (the Dunk Pass gives these for free).
local function bestPack(player: Player): string
	local best = "Street"
	for _, packId in Config.PackIds() do
		if PlayerService.HasCourt(player, Config.Packs[packId].Court) then best = packId end
	end
	return best
end

-- Price of the pack GrantPack would open (GiftService pays it as Cash where packs are restricted).
function CrewService.BestPackPrice(player: Player): number
	return Config.Packs[bestPack(player)].Price
end

-- A free pack from a reward (Dunk Pass). Returns the reveal result, or nil.
function CrewService.GrantPack(player: Player)
	local crew = PlayerService.GetCrew(player)
	if not crew then return nil end
	local packId = bestPack(player)
	local memberId = roll(packId, PlayerService.HasPass(player, "CrewLucky"))
	local result = addMember(player, crew, memberId, Config.Packs[packId].Price)
	Analytics.Custom(player, "CrewPull_" .. Config.Members[memberId].Rarity)
	finish(player, packId, { result })
	return result
end

-- A specific member from a reward (Dunk Pass exclusives). Returns the reveal result, or nil.
function CrewService.GrantMember(player: Player, memberId: string)
	local crew = PlayerService.GetCrew(player)
	local member = Config.GetMember(memberId)
	if not crew or not member then return nil end
	local result = addMember(player, crew, memberId, 0)
	finish(player, member.Pack, { result })
	return result
end

local function equip(player: Player, memberId, on: boolean)
	local crew = PlayerService.GetCrew(player)
	if not crew or not Config.GetMember(memberId) then return end
	local index = table.find(crew.Equipped, memberId)
	if on then
		if not crew.Owned[memberId] then return reply(player, false, "You don't have that crew member yet.") end
		if index then return end
		if #crew.Equipped >= slotsFor(player) then
			return reply(player, false, string.format("All %d crew slots are full. Unequip someone first.", slotsFor(player)))
		end
		table.insert(crew.Equipped, memberId)
	else
		if not index then return end
		table.remove(crew.Equipped, index)
	end
	publish(player)
	DataService.RequestSave(player)
end

function CrewService.OnPlayerReady(player: Player)
	task.spawn(function()
		-- If the lookup failed, try again a little later (the PACKS page waits for an answer).
		for _ = 1, 3 do
			lookupPolicy(player)
			if restricted[player] ~= nil or player.Parent ~= Players then return end
			task.wait(POLICY_RETRY_SECONDS)
		end
	end)
	-- Pass ownership arrives a moment after data; wait briefly so slots are right.
	local waited = 0
	while player.Parent == Players and player:GetAttribute("Pass_CrewSlot") == nil and waited < 10 do
		waited += task.wait(0.25)
	end
	local crew = PlayerService.GetCrew(player)
	if not crew then return end
	while #crew.Equipped > slotsFor(player) do table.remove(crew.Equipped) end
	publish(player)
end

function CrewService.Init()
	if initialized then return end
	initialized = true
	remote = ReplicatedStorage.Remotes:WaitForChild("CrewRequest")
	remote.OnServerEvent:Connect(function(player, action, a, b, ...)
		if type(action) ~= "string" or select("#", ...) ~= 0 or not PlayerService.IsDataReady(player) then return end
		if os.clock() < (nextRequest[player] or 0) then return end
		nextRequest[player] = os.clock() + Config.RequestCooldownSeconds
		local ok, problem = pcall(function()
			if action == "Buy" then
				buy(player, a, b)
			elseif action == "Equip" then
				equip(player, a, true)
			elseif action == "Unequip" then
				equip(player, a, false)
			end
		end)
		if not ok then
			warn("[CrewService] " .. action .. " failed: " .. tostring(problem))
			reply(player, false, "Try again.")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		nextRequest[player] = nil
		restricted[player] = nil
		nextPolicyLookup[player] = nil
	end)
end

return CrewService
