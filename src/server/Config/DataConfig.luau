return {
	SchemaVersion = 10,
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
	ProductionReferralStoreName = "DunkSimulator_Referrals_v1",
	StudioReferralStoreName = "DunkSimulator_Referrals_DEV_v1",
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
