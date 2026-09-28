-- Dunk Pass XP (SeasonConfig). Other services call SeasonXp.Add when a player does something
-- that earns XP (dunks, PERFECT reps, Golden Balls, crew packs, daily challenges). Kept apart
-- from SeasonService (claims and rewards) so those services can require it without loops.
-- The record lives in the profile (PlayerService "Season"); a new season resets it.
-- Mirrors for the HUD: PassSeason, PassXp, PassFree ("1,2,3"), PassPremium ("1,2").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.SeasonConfig)
local PlayerService = require(script.Parent.PlayerService)

local SeasonXp = {}

-- The player's record for the running season (reset when the season changed), or nil when no
-- season is running or data isn't ready.
function SeasonXp.Record(player: Player)
	local record = PlayerService.GetSeason(player)
	local season = Config.Current(os.time())
	if not record or not season then return nil, season end
	if record.Id ~= season.Id then
		record.Id = season.Id
		record.Xp = 0
		table.clear(record.Free)
		table.clear(record.Premium)
	end
	return record, season
end

function SeasonXp.Publish(player: Player)
	if player.Parent ~= Players then return end
	local record, season = SeasonXp.Record(player)
	player:SetAttribute("PassSeason", season and season.Id or "")
	player:SetAttribute("PassXp", record and record.Xp or 0)
	player:SetAttribute("PassFree", record and table.concat(record.Free, ",") or "")
	player:SetAttribute("PassPremium", record and table.concat(record.Premium, ",") or "")
end

-- Adds XP for the running season. A tier-up tells the client (SeasonRequest "TierUp").
function SeasonXp.Add(player: Player, amount: number)
	if type(amount) ~= "number" or amount <= 0 or amount ~= amount then return end
	local record = SeasonXp.Record(player)
	if not record then return end
	local before = Config.TierForXp(record.Xp)
	record.Xp = math.min(record.Xp + math.floor(amount), 100000000)
	local after = Config.TierForXp(record.Xp)
	if player.Parent ~= Players then return end
	player:SetAttribute("PassXp", record.Xp)
	if after > before then
		local remote = ReplicatedStorage.Remotes:FindFirstChild("SeasonRequest")
		if remote then remote:FireClient(player, "TierUp", after) end
	end
end

return SeasonXp
