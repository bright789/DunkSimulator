-- Goal tracker (GoalService): one next goal on screen at a time, with its progress and a Cash
-- reward that is paid automatically the moment it's done. The Chain is for the first
-- sessions; after it, a repeating goal (land the next RepeatEvery dunks) runs forever.
--
-- Every goal is worked out from lifetime progress the game already saves, so goals need no
-- saved data of their own and can never pay twice (see GoalService). Kind:
--   Dunks          lifetime dunks landed
--   Vertical       best Vertical ever reached
--   TrainingLevel  Training Level owned (always done after a Rebirth)
--   Court          `Court` unlocked (always done after a Rebirth)
--   Contest        landed a judged dunk in a Dunk Contest (best contest score of 1 or more;
--                  counted at the round's buzzer)
-- Rewards are priced in "dunks": RewardDunks x the Cash of one plain dunk of your best style
-- at your Vertical (DailyConfig.DunkValue), so they stay worth it at every stage.
local GoalConfig = {
	Chain = {
		{ Id = "dunks5", Kind = "Dunks", Target = 5, Text = "Land 5 dunks", RewardDunks = 3 },
		{ Id = "vertical45", Kind = "Vertical", Target = 45, Text = "Train to 45 Vertical", RewardDunks = 3 },
		{ Id = "vertical50", Kind = "Vertical", Target = 50, Text = "Reach 50 Vertical to unlock Two-Hand Power", RewardDunks = 4 },
		{ Id = "dunks15", Kind = "Dunks", Target = 15, Text = "Land 15 dunks", RewardDunks = 4 },
		{ Id = "level3", Kind = "TrainingLevel", Target = 3, Text = "Buy Training Level 3", RewardDunks = 5 },
		{ Id = "vertical60", Kind = "Vertical", Target = 60, Text = "Train to 60 Vertical", RewardDunks = 5 },
		{ Id = "contest", Kind = "Contest", Target = 1, Text = "Dunk during a Dunk Contest", RewardDunks = 6 },
		{ Id = "dunks40", Kind = "Dunks", Target = 40, Text = "Land 40 dunks", RewardDunks = 6 },
		{ Id = "vertical75", Kind = "Vertical", Target = 75, Text = "Reach 75 Vertical to unlock the Tomahawk", RewardDunks = 8 },
		{ Id = "highschool", Kind = "Court", Court = "HighSchool", Target = 1, Text = "Unlock the High School Gym", RewardDunks = 10 },
	},
	-- After the chain: "Land N dunks", where N is the next lifetime multiple of RepeatEvery.
	RepeatEvery = 25,
	RepeatRewardDunks = 5,
	RepeatText = "Land %s dunks",
}

-- Progress toward a goal (compare with goal.Target) from a milestone snapshot
-- (PlayerService.GetMilestoneSnapshot).
function GoalConfig.Progress(goal, snapshot): number
	local kind = goal.Kind
	if kind == "Dunks" then
		return snapshot.TotalDunks
	elseif kind == "Vertical" then
		return snapshot.BestVertical
	elseif kind == "TrainingLevel" then
		return snapshot.Rebirths >= 1 and goal.Target or snapshot.TrainingLevel
	elseif kind == "Court" then
		return (snapshot.UnlockedCourts[goal.Court] == true or snapshot.Rebirths >= 1) and 1 or 0
	elseif kind == "Contest" then
		return (snapshot.BestContestScore or 0) >= 1 and 1 or 0
	end
	return 0
end

function GoalConfig.IsDone(goal, snapshot): boolean
	return GoalConfig.Progress(goal, snapshot) >= goal.Target
end

return GoalConfig
