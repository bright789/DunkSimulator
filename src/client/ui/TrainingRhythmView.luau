-- Active-training beat ring, shown at the bottom centre while you train: a ring closes on the
-- target every beat. Press on the beat for a PERFECT (x3) or GOOD (x1.5) rep. Also shows the
-- rep combo and a floating "+0.3" for every rep the server pays. Display only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local UI = require(script.Parent.UIComponents)

local TrainingRhythmView = {}

local TARGET = 74
local START = 170

local function centered(label: TextLabel)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Font = Config.BoldFont
	return label
end

function TrainingRhythmView.new(playerGui: PlayerGui)
	local screen = UI.Screen("TrainingRhythm", 5)
	local root = Instance.new("Frame")
	root.Name = "Rhythm"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 0.94, -44)
	root.Size = UDim2.fromOffset(340, 190)
	root.Visible = false
	root.Parent = screen

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.64)
	ring.Size = UDim2.fromOffset(START, START)
	ring.BackgroundTransparency = 1
	UI.Round(ring, 999)
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = Config.Colors.Accent
	ringStroke.Thickness = 5
	ringStroke.Parent = ring
	ring.Parent = root

	local button = Instance.new("TextButton")
	button.Name = "Pump"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.64)
	button.Size = UDim2.fromOffset(TARGET, TARGET)
	button.BackgroundColor3 = Config.Colors.Panel
	button.BackgroundTransparency = 0.1
	button.AutoButtonColor = false
	button.Text = "PUMP"
	button.Font = Config.BoldFont
	button.TextColor3 = Config.Colors.Gold
	button.TextSize = 20
	UI.Round(button, 999)
	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	buttonStroke.Color = Config.Colors.Gold
	buttonStroke.Thickness = 3
	buttonStroke.Parent = button
	UI.Outline(button)
	local buttonScale = Instance.new("UIScale")
	buttonScale.Parent = button
	button.Parent = root

	local caption = centered(UI.Label(root, "Caption", "", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 0), 16))
	local grade = centered(UI.Label(root, "Grade", "", UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 22), 26))
	grade.Visible = false
	local gradeScale = Instance.new("UIScale")
	gradeScale.Parent = grade
	local combo = centered(UI.Label(root, "Combo", "", UDim2.fromOffset(110, 26), UDim2.new(0.5, 50, 0.64, -13), 18))
	combo.TextXAlignment = Enum.TextXAlignment.Left
	combo.TextColor3 = Config.Colors.Gold
	screen.Parent = playerGui

	local view = { Button = button }
	local gradeVersion = 0

	-- 0 right after a beat .. 1 just before the next one (the ring reaches the target).
	function view.SetPhase(fraction: number)
		local size = TARGET + (START - TARGET) * (1 - math.clamp(fraction, 0, 1))
		ring.Size = UDim2.fromOffset(size, size)
		ringStroke.Transparency = 0.6 * (1 - fraction)
	end

	function view.SetVisible(visible: boolean, text: string)
		root.Visible = visible
		caption.Text = text
		if not visible then combo.Text = "" end
	end

	function view.SetCombo(count: number)
		combo.Text = count >= 2 and ("COMBO x" .. count) or ""
	end

	-- Instant (local) call on a press: PERFECT / GOOD / MISS. The server still decides the rep.
	function view.Press(result: string)
		gradeVersion += 1
		local version = gradeVersion
		local color = result == "Perfect" and Config.Colors.Gold or result == "Good" and Config.Colors.Accent or Config.Colors.Muted
		grade.Text = result == "Perfect" and "PERFECT! x3" or result == "Good" and "GOOD! x1.5" or "MISS"
		grade.TextColor3 = color
		grade.Visible = true
		gradeScale.Scale = 1.35
		TweenService:Create(gradeScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		buttonScale.Scale = 0.86
		TweenService:Create(buttonScale, TweenInfo.new(0.15), { Scale = 1 }):Play()
		buttonStroke.Color = color
		task.delay(0.45, function()
			if gradeVersion ~= version then return end
			grade.Visible = false
			buttonStroke.Color = Config.Colors.Gold
		end)
	end

	-- Floating "+0.3" for a paid rep (gold and bigger for a bonus rep).
	function view.Gain(amount: number, bonus: string?)
		local text = string.format("+%.2f", amount):gsub("0+$", ""):gsub("%.$", "")
		local popup = centered(UI.Label(root, "Gain", text, UDim2.fromOffset(90, bonus and 30 or 22),
			UDim2.new(0.5, -45 - 70, 0.64, -10), bonus and 22 or 16))
		popup.TextColor3 = bonus == "Perfect" and Config.Colors.Gold or bonus == "Good" and Config.Colors.Accent or Config.Colors.Gain
		local outline = popup:FindFirstChild("TextOutline")
		local rise = TweenService:Create(popup, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = popup.Position - UDim2.fromOffset(0, 46), TextTransparency = 1 })
		if outline then TweenService:Create(outline, TweenInfo.new(0.8), { Transparency = 1 }):Play() end
		rise.Completed:Once(function() popup:Destroy() end)
		rise:Play()
	end

	function view.Destroy()
		screen:Destroy()
	end

	return view
end

return TrainingRhythmView
