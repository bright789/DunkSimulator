-- Global leaderboards shown on the boards in every gym. LeaderboardService keeps each
-- player's lifetime stats in OrderedDataStores and publishes the top lists; clients only
-- draw them.
local LeaderboardConfig = {
	Size = 10,
	-- How often the server re-reads the top lists (3 reads per refresh).
	RefreshSeconds = 60,
	-- Minimum seconds between a player's leaderboard writes (also written when they leave).
	WriteSeconds = 120,
	Boards = {
		{ Id = "Vertical", Stat = "BestVertical", Title = "TOP VERTICAL", Caption = "Best Vertical ever reached",
			Prefix = "", Color = Color3.fromRGB(64, 204, 255) },
		{ Id = "Dunks", Stat = "TotalDunks", Title = "MOST DUNKS", Caption = "Lifetime dunks landed",
			Prefix = "", Color = Color3.fromRGB(255, 214, 64) },
		{ Id = "BestDunk", Stat = "BestDunkCash", Title = "BIGGEST DUNK", Caption = "Most Cash from one dunk",
			Prefix = "$", Color = Color3.fromRGB(88, 255, 138) },
	},
	-- CollectionService tag on the board panels the map builders create; each panel has a
	-- "Board" attribute with one of the Ids above.
	PanelTag = "LeaderboardPanel",
	MaxStat = 1e15,
}

function LeaderboardConfig.Get(boardId)
	for _, board in LeaderboardConfig.Boards do
		if board.Id == boardId then return board end
	end
	return nil
end

-- Lifetime stats saved in the player profile (schema v8; contest fields since v9).
local STAT_NAMES = { "BestVertical", "TotalDunks", "BestDunkCash", "BestContestScore", "ContestWins" }

function LeaderboardConfig.DefaultStats(vertical: number)
	return { BestVertical = vertical, TotalDunks = 0, BestDunkCash = 0, BestContestScore = 0, ContestWins = 0 }
end

function LeaderboardConfig.CopyStats(stats)
	local copy = {}
	for _, name in STAT_NAMES do copy[name] = stats[name] end
	return copy
end

function LeaderboardConfig.SameStats(first, second): boolean
	if type(first) ~= "table" or type(second) ~= "table" then return false end
	for _, name in STAT_NAMES do
		if first[name] ~= second[name] then return false end
	end
	return true
end

-- Cleans saved stats. BestVertical is never below the starting Vertical. Returns (stats, repaired).
function LeaderboardConfig.SanitizeStats(stored, minimumVertical: number, maximumVertical: number)
	local stats = LeaderboardConfig.DefaultStats(minimumVertical)
	if type(stored) ~= "table" then return stats, true end
	local repaired = false
	for name, bounds in {
		BestVertical = { minimumVertical, maximumVertical },
		TotalDunks = { 0, LeaderboardConfig.MaxStat },
		BestDunkCash = { 0, LeaderboardConfig.MaxStat },
		BestContestScore = { 0, 50 },
		ContestWins = { 0, LeaderboardConfig.MaxStat },
	} do
		local value = stored[name]
		local clean = stats[name]
		if type(value) == "number" and value == value and math.abs(value) ~= math.huge then
			clean = math.clamp(math.floor(value), bounds[1], bounds[2])
		end
		if clean ~= value then repaired = true end
		stats[name] = clean
	end
	return stats, repaired
end

return LeaderboardConfig
