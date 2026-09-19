local DunkConfig = require(script.Parent:WaitForChild("DunkConfig"))

return {
	Colors = {
		Panel = Color3.fromRGB(23, 29, 36),
		Inset = Color3.fromRGB(37, 46, 56),
		Stroke = Color3.fromRGB(80, 97, 115),
		Text = Color3.fromRGB(244, 247, 250),
		Muted = Color3.fromRGB(167, 181, 196),
		Accent = Color3.fromRGB(100, 177, 225),
		Button = Color3.fromRGB(48, 112, 155),
		Gain = Color3.fromRGB(133, 218, 165),
		Warning = Color3.fromRGB(241, 181, 143),
	},
	Font = Enum.Font.Gotham,
	BoldFont = Enum.Font.GothamBold,
	PanelTransparency = 0.12,
	CornerRadius = 10,
	Layout = {
		ColumnWidth = 226,
		CardHeight = 74,
		ProgressHeight = 140,
		Gap = 8,
		ReferenceSize = Vector2.new(1100, 700),
		MinimumScale = 0.85,
	},
	Feedback = {
		HoldSeconds = 0.1,
		FadeSeconds = 0.35,
		RisePixels = 8,
		LevelUp = "LEVEL UP!",
	},
	Progression = {
		BasicVertical = DunkConfig.DunkMinimumVertical,
		Name = "Basic Dunk",
		LockedHeading = "NEXT GOAL",
		UnlockedHeading = "UNLOCKED",
		UnlockedDetail = "Basic Dunk unlocked",
		ProgressFormat = "%s / %s Vertical",
		PreviewHeading = "NEXT STYLE",
		PreviewDetail = "Coming Soon",
	},
}
