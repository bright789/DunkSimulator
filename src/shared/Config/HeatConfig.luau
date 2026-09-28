-- Dunk streak ("HEAT", see docs/ENGAGEMENT.md): every dunk that lands less than WindowSeconds
-- after your last one raises HEAT by 1 (up to 5), and each level multiplies dunk Cash. Stop
-- dunking for WindowSeconds and it resets. The server pays; clients only display it.
return {
	WindowSeconds = 15,
	Multipliers = { 1, 1.1, 1.2, 1.3, 1.4 },
	Names = { "WARMING UP", "HEATING UP", "HOT", "BLAZING", "ON FIRE!" },
	Colors = {
		Color3.fromRGB(255, 214, 120),
		Color3.fromRGB(255, 180, 80),
		Color3.fromRGB(255, 140, 50),
		Color3.fromRGB(255, 100, 40),
		Color3.fromRGB(255, 70, 30),
	},
}
