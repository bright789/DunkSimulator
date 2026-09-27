-- Player milestones shared by the new-player tutorial (client), badges and analytics
-- funnels (server). Every check reads a plain snapshot built from progress the game already
-- saves, so milestones never need their own saved data:
--   { Vertical, BestVertical, TotalDunks, TrainingLevel, Rebirths, ContestWins, Cash,
--     HasBall, UnlockedCourts = { [courtId] = true } }
local DunkConfig = require(script.Parent.DunkConfig)
local ProgressionConfig = require(script.Parent.ProgressionConfig)
local UpgradeConfig = require(script.Parent.UpgradeConfig)

local Milestones = {}

local dunkVertical = DunkConfig.DunkMinimumVertical
local firstUpgradeCost = UpgradeConfig.Levels[UpgradeConfig.StartingLevel + 1].Cost

-- New-player tutorial, in order. `Target` names the map part the guide arrow points at
-- (the nearest one to the player); `Progress` returns (current, goal) for the progress bar.
Milestones.Tutorial = {
	{
		Id = "Train",
		Title = "TRAIN YOUR VERTICAL",
		Detail = string.format("Hold E at the Leg Day Gym until you reach %d Vertical.", dunkVertical),
		Target = ProgressionConfig.Training.StationName,
		Marker = "TRAIN HERE",
		Done = function(s) return s.BestVertical >= dunkVertical end,
		Progress = function(s) return s.Vertical, dunkVertical end,
	},
	{
		Id = "Ball",
		Title = "GRAB A BASKETBALL",
		Detail = "Walk up to the Hoop Shop and press E.",
		Target = "BasketballPickup",
		Marker = "GRAB A BALL",
		Done = function(s) return s.HasBall or s.TotalDunks >= 1 end,
	},
	{
		Id = "Dunk",
		Title = "DUNK IT!",
		Detail = "Jump at the rim, then press DUNK in the air.",
		Target = "Rim",
		Marker = "DUNK HERE",
		Done = function(s) return s.TotalDunks >= 1 end,
	},
	{
		Id = "Upgrade",
		Title = "UPGRADE YOUR TRAINING",
		Detail = string.format("Earn $%d from dunks, then buy Level 2 at Training Upgrades.", firstUpgradeCost),
		Target = UpgradeConfig.StationName,
		Marker = "UPGRADES",
		Done = function(s) return s.TrainingLevel > UpgradeConfig.StartingLevel end,
		Progress = function(s) return s.Cash, firstUpgradeCost end,
	},
}

-- Number of tutorial steps finished in order (0 to #Tutorial).
function Milestones.TutorialStepsDone(snapshot): number
	for index, step in Milestones.Tutorial do
		if not step.Done(snapshot) then return index - 1 end
	end
	return #Milestones.Tutorial
end

-- The tutorial is only for first-run players: never after a Rebirth, and not once finished.
function Milestones.TutorialActive(snapshot): boolean
	return snapshot.Rebirths == 0 and Milestones.TutorialStepsDone(snapshot) < #Milestones.Tutorial
end

-- One-time progression funnel for analytics. Each step implies the ones before it, because
-- logging a later step also marks the earlier ones as reached.
Milestones.Progression = {
	{ Id = "FirstDunk", Done = function(s) return s.TotalDunks >= 1 end },
	{ Id = "Vertical75", Done = function(s) return s.BestVertical >= 75 end },
	{ Id = "HighSchool", Done = function(s) return s.UnlockedCourts.HighSchool == true or s.Rebirths >= 1 end },
	{ Id = "Vertical150", Done = function(s) return s.BestVertical >= 150 end },
	{ Id = "College", Done = function(s) return s.UnlockedCourts.College == true or s.Rebirths >= 1 end },
	{ Id = "Vertical250", Done = function(s) return s.BestVertical >= 250 end },
	{ Id = "Rooftop", Done = function(s) return s.UnlockedCourts.Rooftop == true or s.Rebirths >= 1 end },
	{ Id = "Vertical300", Done = function(s) return s.BestVertical >= 300 end },
	{ Id = "FirstRebirth", Done = function(s) return s.Rebirths >= 1 end },
}

-- Highest progression step reached (0 = none).
function Milestones.ProgressionReached(snapshot): number
	local reached = 0
	for index, step in Milestones.Progression do
		if step.Done(snapshot) then reached = index end
	end
	return reached
end

-- Badges. Create each one in the Creator Hub (Engagement -> Badges), then paste its id here.
-- While an id is 0 the badge is skipped (Studio prints what it would award).
Milestones.Badges = {
	{ Key = "Welcome", Id = 2421074952642248, Name = "Welcome", Description = "Join Dunk Simulator.",
		Done = function() return true end },
	{ Key = "FirstDunk", Id = 414673442946406, Name = "First Slam", Description = "Land your first dunk.",
		Done = function(s) return s.TotalDunks >= 1 end },
	{ Key = "Vertical100", Id = 1200946718501511, Name = "Vertical 100", Description = "Reach 100 Vertical.",
		Done = function(s) return s.BestVertical >= 100 end },
	{ Key = "HighSchool", Id = 128763592521392, Name = "Varsity", Description = "Unlock the High School Gym.",
		Done = function(s) return s.UnlockedCourts.HighSchool == true or s.Rebirths >= 1 end },
	{ Key = "College", Id = 2582750542412877, Name = "Big Stage", Description = "Unlock the College Arena.",
		Done = function(s) return s.UnlockedCourts.College == true or s.Rebirths >= 1 end },
	{ Key = "Vertical200", Id = 0, Name = "Sky Walker", Description = "Reach 200 Vertical.",
		Done = function(s) return s.BestVertical >= 200 end },
	{ Key = "Vertical250", Id = 0, Name = "Roof Raiser", Description = "Reach 250 Vertical.",
		Done = function(s) return s.BestVertical >= 250 end },
	{ Key = "Rooftop", Id = 0, Name = "Skyline", Description = "Unlock the Skyline Rooftop.",
		Done = function(s) return s.UnlockedCourts.Rooftop == true or s.Rebirths >= 1 end },
	{ Key = "FirstRebirth", Id = 0, Name = "Born Again", Description = "Rebirth for the first time.",
		Done = function(s) return s.Rebirths >= 1 end },
	{ Key = "ContestWin", Id = 0, Name = "Dunk Champion", Description = "Win a Dunk Contest.",
		Done = function(s) return s.ContestWins >= 1 end },
}

return Milestones
