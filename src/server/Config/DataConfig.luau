return {
	SchemaVersion = 14,
	PrioritySaveCooldownSeconds = 10,
	ProductionStoreName = "DunkSimulator_PlayerData_v1",
	StudioStoreName = "DunkSimulator_PlayerData_DEV_v1",
	-- Leaderboard OrderedDataStores are named prefix .. board Id (see LeaderboardConfig).
	ProductionLeaderboardPrefix = "DunkSimulator_Leaderboard_v1_",
	StudioLeaderboardPrefix = "DunkSimulator_Leaderboard_DEV_v1_",
	-- Developer-product receipts already granted (keyed by PurchaseId) so a retried
	-- ProcessReceipt call never pays twice.
	ProductionReceiptStoreName = "DunkSimulator_Receipts_v1",
	StudioReceiptStoreName = "DunkSimulator_Receipts_DEV_v1",
	-- Referral records ("Invitee_<id>" = who they credited, "Inviter_<id>" = daily count and
	-- rewards waiting for an inviter who was offline). See InviteService.
	-- Weekly Dunk Contest board (OrderedDataStore per week: prefix .. week number) and the
	-- record of each week's champion and whether their prize was claimed.
	ProductionWeeklyPrefix = "DunkSimulator_WeeklyContest_v1_W",
	StudioWeeklyPrefix = "DunkSimulator_WeeklyContest_DEV_v1_W",
	ProductionChampionStoreName = "DunkSimulator_WeeklyChampions_v1",
	StudioChampionStoreName = "DunkSimulator_WeeklyChampions_DEV_v1",
	-- Codes each player has redeemed (key = UserId, value = list of codes). See CodesService.
	ProductionCodesStoreName = "DunkSimulator_Codes_v1",
	StudioCodesStoreName = "DunkSimulator_Codes_DEV_v1",
	ProductionReferralStoreName = "DunkSimulator_Referrals_v1",
	StudioReferralStoreName = "DunkSimulator_Referrals_DEV_v1",
	-- Experience notifications: players seen each UTC day ("Recent_<yyyymmdd>_<shard>" = list of
	-- UserIds) and each day's "sent" marker ("Sent_<yyyymmdd>"). See NotificationService.
	ProductionNotificationStoreName = "DunkSimulator_Notifications_v1",
	StudioNotificationStoreName = "DunkSimulator_Notifications_DEV_v1",
	KeyPrefix = "Player_",
	AutosaveSeconds = 90,
	AutosaveJitterSeconds = 10,
	MaxAttempts = 4,
	RetryBaseSeconds = 1,
	RetryMaxSeconds = 4,
	RetryJitterSeconds = 0.5,
	LoadTimeoutSeconds = 30,
	SaveTimeoutSeconds = 20,
	CloseTimeoutSeconds = 25,
	MaxCash = 9007199254740991,
	MaxVertical = 1000000,
	LoadFailureMessage = "Your player data could not be loaded safely. Please rejoin and try again.",
	ConflictMessage = "Your player data changed in another session. Please rejoin to load the latest saved progress.",
}
