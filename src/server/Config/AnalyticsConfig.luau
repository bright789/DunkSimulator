return {
	-- Name of the soft currency in the Creator Hub economy dashboards.
	CurrencyName = "Cash",
	-- Frequent Cash sources (every dunk and air trick) are added up per player and sent
	-- as one event this often, and when the player leaves, to stay under rate limits.
	BatchFlushSeconds = 60,
	-- AnalyticsService only records events in published games. In Studio each event is
	-- printed to Output instead so it can be checked; set false to silence it.
	StudioPrint = true,
	-- One-time funnel name for the progression steps in MilestoneConfig.Progression.
	ProgressionFunnel = "Progression",
}
