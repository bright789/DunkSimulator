-- Hype Crew packs and equipping (CrewConfig). The crew record lives in the player's profile
-- (PlayerService "Crew", schema v13) and this service is its only writer. The client sends
-- CrewRequest("Buy", packId, count) / ("Equip", memberId) / ("Unequip", memberId); answers come
-- back on the same remote as ("Opened", results) or ("Result", ok, message).
-- Mirrors for the HUD and the followers: CrewOwned ("id:stars,..."), CrewEquipped ("id,id"),
-- CrewSlots, CrewCash and CrewTrain (bonus in whole percent).
local Players = game:GetService("Players")
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

-- One member from a pack: pick a rarity by the pack's odds (Lucky boosts Epic/Legendary),
-- then any member of that rarity in the pack.
local function roll(packId: string, lucky: boolean): string
	local pack = Config.Packs[packId]
	local total = 0
	local weights = {}
	for rarity, weight in pack.Odds do
		local boosted = (lucky and (rarity == "Epic" or rarity == "Legendary")) and weight * Config.LuckyMultiplier or weight
		weights[rarity] = boosted
		total += boosted
	end
	local pick = random:NextNumber(0, total)
	local chosen = nil
	for rarity, weight in weights do
		chosen = rarity
		pick -= weight
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
	Players.PlayerRemoving:Connect(function(player) nextRequest[player] = nil end)
end

return CrewService
