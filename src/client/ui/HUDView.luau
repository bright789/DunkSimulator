local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HUDConfig"))
local UI = require(script.Parent:WaitForChild("UIComponents"))
local StatFeedback = require(script.Parent:WaitForChild("StatFeedback"))
local Styles = require(ReplicatedStorage.Shared.Config:WaitForChild("DunkStyles"))
local Courts = require(ReplicatedStorage.Shared.Config:WaitForChild("CourtConfig"))
local DunkRewards = require(ReplicatedStorage.Shared.Config:WaitForChild("DunkRewards"))
local FeedbackConfig = require(ReplicatedStorage.Shared.Config.FeedbackConfig).Stats

local HUDView = {}

local function makeCard(parent: Instance, name: string, prefix: string, order: number, accent: Color3, pulseScale: number)
	local card = UI.Panel(parent, name, UDim2.new(1, 0, 0, Config.Layout.CardHeight), UDim2.new())
	card.LayoutOrder = order
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = card
	local value = UI.Label(card, "Value", "--", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 6), 30)
	value.Font = Config.BoldFont
	value.TextColor3 = accent
	local caption = UI.Label(card, "Caption", name:upper(), UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 44), 13)
	caption.TextColor3 = Config.Colors.Muted
	-- Gain badge pops in at the right end of the value row (value is 34 tall at y 6).
	return { Card = card, Caption = caption, Value = value, Prefix = prefix, Feedback = StatFeedback.new(card, accent, pulseScale, 23) }
end

function HUDView.new(playerGui: PlayerGui)
	local screen = UI.Screen("NeighborhoodHUD", 1)
	local bounds = Instance.new("Frame")
	bounds.Name = "SafeArea"
	bounds.Size = UDim2.fromScale(1, 1)
	bounds.BackgroundTransparency = 1
	bounds.Parent = screen
	local dataStatus = UI.Label(bounds, "DataStatus", "Loading Player Data...",
		UDim2.fromScale(0.6, 0.045), UDim2.fromScale(0.5, 0.04), 16)
	dataStatus.AnchorPoint = Vector2.new(0.5, 0)
	dataStatus.TextXAlignment = Enum.TextXAlignment.Center
	dataStatus.TextColor3 = Config.Colors.Muted
	local capToast = Instance.new("CanvasGroup")
	capToast.Name = "TrainingCap"
	capToast.Size = UDim2.fromScale(0.45, 0.11)
	capToast.Position = UDim2.fromScale(0.5, 0.11)
	capToast.AnchorPoint = Vector2.new(0.5, 0)
	capToast.Visible = false
	capToast.GroupTransparency = 1
	UI.StylePanel(capToast)
	capToast.Parent = bounds
	local capSize = Instance.new("UISizeConstraint")
	capSize.MaxSize = Vector2.new(390, 82)
	capSize.Parent = capToast
	local capHeading = UI.Label(capToast, "Heading", "COURT TRAINING MAXED",
		UDim2.fromScale(0.92, 0.36), UDim2.fromScale(0.04, 0.08), 17)
	capHeading.Font = Config.BoldFont
	capHeading.TextColor3 = Config.Colors.Warning
	capHeading.TextXAlignment = Enum.TextXAlignment.Center
	local capDetail = UI.Label(capToast, "Detail", "",
		UDim2.fromScale(0.92, 0.5), UDim2.fromScale(0.04, 0.45), 12)
	capDetail.TextWrapped = true
	capDetail.TextXAlignment = Enum.TextXAlignment.Center
	local capTween = nil
	local capTask = nil
	local column = Instance.new("Frame")
	column.Name = "Stats"
	column.BackgroundTransparency = 1
	column.Position = UDim2.new(0.018, 4, 0.18, 0)
	column.Parent = bounds
	local scale = Instance.new("UIScale")
	scale.Parent = column
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Config.Layout.Gap)
	layout.Parent = column
	local courtLabel = UI.Label(column, "CurrentCourt", "COURT  /  --",
		UDim2.new(1, 0, 0, Config.Layout.CourtHeaderHeight), UDim2.new(), 12)
	courtLabel.LayoutOrder = 0
	courtLabel.Font = Config.BoldFont
	courtLabel.TextColor3 = Config.Colors.Muted
	local cards = {
		Cash = makeCard(column, "Cash", "$ ", 1, Config.Colors.Gain, FeedbackConfig.CashScale),
		Vertical = makeCard(column, "Vertical", "↑ ", 2, Config.Colors.Accent, FeedbackConfig.VerticalScale),
		TrainingLevel = makeCard(column, "Training", "LVL ", 3, Config.Colors.Gold, FeedbackConfig.LevelScale),
	}
	local progress = UI.Panel(column, "DunkProgress", UDim2.new(1, 0, 0, Config.Layout.ProgressHeight), UDim2.new())
	progress.LayoutOrder = 4
	local milestone = Config.Progression
	local heading = UI.Label(progress, "Heading", milestone.LockedHeading, UDim2.new(1, -28, 0, 16), UDim2.fromOffset(14, 10), 12)
	heading.TextColor3 = Config.Colors.Accent
	local title = UI.Label(progress, "Title", "--", UDim2.new(1, -28, 0, 25), UDim2.fromOffset(14, 29), 20)
	title.Font = Config.BoldFont
	local detail = UI.Label(progress, "Detail", "--", UDim2.new(1, -28, 0, 18), UDim2.fromOffset(14, 58), 12)
	detail.TextColor3 = Config.Colors.Muted
	local track = Instance.new("Frame")
	track.Name = "ProgressTrack"
	track.Size = UDim2.new(1, -28, 0, 5)
	track.Position = UDim2.fromOffset(14, 84)
	track.BackgroundColor3 = Config.Colors.Inset
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	UI.Round(track, 3)
	track.Parent = progress
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Config.Colors.Accent
	fill.BorderSizePixel = 0
	UI.Round(fill, 3)
	fill.Parent = track
	local preview = UI.Label(progress, "Preview", "--",
		UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 101), 11)
	preview.TextColor3 = Config.Colors.Muted
	local navigation = Instance.new("Frame")
	navigation.Name = "Navigation"
	navigation.BackgroundTransparency = 1
	navigation.Size = UDim2.new(1, 0, 0, Config.Layout.DunksButtonHeight * 4 + Config.Layout.Gap * 3)
	navigation.LayoutOrder = 5
	navigation.Parent = column
	local dunksButton = Instance.new("TextButton")
	dunksButton.Name = "Dunks"
	dunksButton.Size = UDim2.new(0.48, 0, 0, Config.Layout.DunksButtonHeight)
	dunksButton.LayoutOrder = 5
	UI.StylePanel(dunksButton)
	dunksButton.Text = Config.DunkSelection.ButtonText
	dunksButton.Font = Config.BoldFont
	dunksButton.TextSize = 14
	dunksButton.TextColor3 = Config.Colors.Accent
	dunksButton.Parent = navigation
	local courtsButton = dunksButton:Clone()
	courtsButton.Name = "Courts"
	courtsButton.Text = "COURTS"
	courtsButton.Position = UDim2.fromScale(0.52, 0)
	courtsButton.Parent = navigation
	local challengesButton = dunksButton:Clone()
	challengesButton.Name = "Challenges"
	challengesButton.Text = "CHALLENGES"
	challengesButton.Size = UDim2.new(0.48, 0, 0, Config.Layout.DunksButtonHeight)
	challengesButton.Position = UDim2.fromOffset(0, Config.Layout.DunksButtonHeight + Config.Layout.Gap)
	challengesButton.Parent = navigation
	local rebirthButton = dunksButton:Clone()
	rebirthButton.Name = "Rebirth"
	rebirthButton.Text = "REBIRTH"
	rebirthButton.TextColor3 = Config.Colors.Gold
	rebirthButton.Position = UDim2.new(0.52, 0, 0, Config.Layout.DunksButtonHeight + Config.Layout.Gap)
	rebirthButton.Parent = navigation
	local dailyButton = dunksButton:Clone()
	dailyButton.Name = "Daily"
	dailyButton.Text = "DAILY"
	dailyButton.Size = UDim2.new(0.48, 0, 0, Config.Layout.DunksButtonHeight)
	dailyButton.Position = UDim2.fromOffset(0, (Config.Layout.DunksButtonHeight + Config.Layout.Gap) * 2)
	dailyButton.Parent = navigation
	local lockerButton = dunksButton:Clone()
	lockerButton.Name = "Locker"
	lockerButton.Text = "LOCKER"
	lockerButton.TextColor3 = Config.Colors.Gold
	lockerButton.Size = UDim2.new(0.48, 0, 0, Config.Layout.DunksButtonHeight)
	lockerButton.Position = UDim2.new(0.52, 0, 0, (Config.Layout.DunksButtonHeight + Config.Layout.Gap) * 2)
	lockerButton.Parent = navigation
	local inviteButton = dunksButton:Clone()
	inviteButton.Name = "Invite"
	inviteButton.Text = "INVITE"
	inviteButton.TextColor3 = Config.Colors.Gain
	inviteButton.Size = UDim2.new(0.48, 0, 0, Config.Layout.DunksButtonHeight)
	inviteButton.Position = UDim2.fromOffset(0, (Config.Layout.DunksButtonHeight + Config.Layout.Gap) * 3)
	inviteButton.Parent = navigation
	local musicButton = dunksButton:Clone()
	musicButton.Name = "Music"
	musicButton.Text = "MUSIC: ON"
	musicButton.Size = UDim2.new(0.48, 0, 0, Config.Layout.DunksButtonHeight)
	musicButton.Position = UDim2.new(0.52, 0, 0, (Config.Layout.DunksButtonHeight + Config.Layout.Gap) * 3)
	musicButton.Parent = navigation
	-- Cash Boost countdown pill (shown only while a boost runs).
	local boost = UI.Panel(column, "CashBoost", UDim2.new(1, 0, 0, Config.Layout.BoostHeight), UDim2.new())
	boost.LayoutOrder = 6
	boost.Visible = false
	local boostLabel = UI.Label(boost, "Text", "", UDim2.new(1, -16, 1, 0), UDim2.fromOffset(8, 0), 14)
	boostLabel.Font = Config.BoldFont
	boostLabel.TextColor3 = Config.Colors.Gold
	boostLabel.TextXAlignment = Enum.TextXAlignment.Center
	-- AUTO TRAIN toggle (only shown to Auto Train pass owners).
	local autoButton = Instance.new("TextButton")
	autoButton.Name = "AutoTrain"
	autoButton.Size = UDim2.new(1, 0, 0, Config.Layout.BoostHeight)
	autoButton.LayoutOrder = 7
	autoButton.Visible = false
	UI.StylePanel(autoButton)
	autoButton.Text = "AUTO TRAIN: ON"
	autoButton.Font = Config.BoldFont
	autoButton.TextSize = 14
	autoButton.TextColor3 = Config.Colors.Gain
	autoButton.Parent = column
	UI.Interactive(dunksButton)
	UI.Interactive(courtsButton)
	UI.Interactive(challengesButton)
	UI.Interactive(rebirthButton)
	UI.Interactive(dailyButton)
	UI.Interactive(lockerButton)
	UI.Interactive(inviteButton)
	UI.Interactive(musicButton)
	UI.Interactive(autoButton)

	-- Touch devices: Roblox's movement thumbstick takes touches in the lower-left of the
	-- screen, and buttons there block it, so the menu buttons move to the top-right corner.
	-- Small screens (phones) also drop the Training and dunk-progress cards and pin the
	-- stats to the top-left, above the thumbstick area.
	local touchLayout = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local navigationScale = nil
	if touchLayout then
		navigation.Parent = bounds
		navigation.AnchorPoint = Vector2.new(1, 0)
		navigation.Position = UDim2.new(1, -10, 0, 8)
		navigation.Size = UDim2.fromOffset(Config.Layout.ColumnWidth, navigation.Size.Y.Offset)
		navigationScale = Instance.new("UIScale")
		navigationScale.Parent = navigation
	end
	screen.Parent = playerGui

	-- Height of everything stacked in the column (the boost pill's space is always kept).
	local function columnHeight(): number
		local total, count = 0, 0
		for _, child in column:GetChildren() do
			if child:IsA("GuiObject") and (child.Visible or child == boost) then
				total += child.Size.Y.Offset
				count += 1
			end
		end
		return total + Config.Layout.Gap * math.max(count - 1, 0)
	end

	local function resize()
		local size = bounds.AbsoluteSize
		local compact = touchLayout and math.min(size.X, size.Y) <= Config.Layout.CompactMaxSize
		cards.TrainingLevel.Card.Visible = not compact
		progress.Visible = not compact
		local height = columnHeight()
		column.Size = UDim2.fromOffset(Config.Layout.ColumnWidth, height)
		if compact then
			column.Position = UDim2.new(0.018, 4, 0, 6)
			scale.Scale = math.clamp(size.Y * Config.Layout.CompactStatsHeight / height, 0.4, 0.85)
		else
			column.Position = UDim2.new(0.018, 4, 0.18, 0)
			local desired = math.clamp(math.min(size.X / Config.Layout.ReferenceSize.X,
				size.Y / Config.Layout.ReferenceSize.Y), Config.Layout.MinimumScale, 1)
			scale.Scale = math.min(desired, math.max(0.1, size.Y * 0.76 / height))
		end
		if navigationScale then
			navigationScale.Scale = math.clamp(size.Y * Config.Layout.TouchMenuHeight / navigation.Size.Y.Offset, 0.6, 1.1)
		end
	end
	local resizeConnection = bounds:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	local view = { DunksButton = dunksButton, CourtsButton = courtsButton, ChallengesButton = challengesButton,
		RebirthButton = rebirthButton, DailyButton = dailyButton, LockerButton = lockerButton,
		InviteButton = inviteButton, MusicButton = musicButton, AutoTrainButton = autoButton }
	local courtName, rebirths = "--", 0

	local function refreshCourtLabel()
		courtLabel.Text = "COURT  /  " .. courtName
		rebirthButton.Text = rebirths > 0 and string.format("REBIRTH %d", rebirths) or "REBIRTH"
	end

	function view.SetChallengeBadge(count: number)
		challengesButton.Text = count > 0 and string.format("CHALLENGES (%d)", count) or "CHALLENGES"
		challengesButton.TextColor3 = count > 0 and Config.Colors.Gain or Config.Colors.Accent
	end

	function view.SetDailyBadge(count: number)
		dailyButton.Text = count > 0 and string.format("DAILY (%d)", count) or "DAILY"
		dailyButton.TextColor3 = count > 0 and Config.Colors.Gain or Config.Colors.Accent
	end

	-- Vertical card caption: notes when this court limits the jump ("JUMP 150 HERE").
	function view.SetJumpLimit(limit: number?)
		local caption = cards.Vertical.Caption
		if limit then
			caption.Text = string.format("VERTICAL  -  JUMP %d HERE", limit)
			caption.TextColor3 = Config.Colors.Warning
		else
			caption.Text = "VERTICAL"
			caption.TextColor3 = Config.Colors.Muted
		end
	end

	-- INVITE shows the friends-in-server Cash bonus when there is one.
	function view.SetFriendBonus(percent: number)
		inviteButton.Text = percent > 0 and string.format("INVITE +%d%%", percent) or "INVITE"
	end

	function view.SetAutoTrain(visible: boolean, on: boolean)
		autoButton.Text = on and "AUTO TRAIN: ON" or "AUTO TRAIN: OFF"
		autoButton.TextColor3 = on and Config.Colors.Gain or Config.Colors.Muted
		if autoButton.Visible ~= visible then
			autoButton.Visible = visible
			resize()
		end
	end

	function view.SetMusic(on: boolean)
		musicButton.Text = on and "MUSIC: ON" or "MUSIC: OFF"
		musicButton.TextColor3 = on and Config.Colors.Accent or Config.Colors.Muted
	end

	-- Cash Boost pill: pass nil to hide it.
	function view.SetBoost(text: string?)
		boost.Visible = text ~= nil
		boostLabel.Text = text or ""
	end

	function view.SetCourt(name: string)
		courtName = name
		refreshCourtLabel()
	end

	function view.SetRebirths(count: number)
		rebirths = typeof(count) == "number" and count or 0
		refreshCourtLabel()
	end

	function view.SetDataStatus(status: string?)
		dataStatus.Visible = status ~= "Ready"
		dataStatus.Text = status == "Failed" and "Player data unavailable. Please rejoin."
			or (status == "Closing" and "Saving Player Data..." or "Loading Player Data...")
	end

	function view.ShowTrainingCap(courtId: string, cap: number)
		local court = Courts.Get(courtId)
		if not court or court.TrainingVerticalCap ~= cap then return end
		if capTask then task.cancel(capTask); capTask = nil end
		if capTween then capTween:Cancel(); capTween:Destroy(); capTween = nil end
		local nextCourt = nil
		for _, id in Courts.OrderedIds() do
			if Courts.Get(id).Order == court.Order + 1 then nextCourt = Courts.Get(id) end
		end
		capDetail.Text = string.format("%s Limit: %d Vertical\n%s", court.DisplayName, cap,
			nextCourt and ("Unlock " .. nextCourt.DisplayName .. " to keep training.") or "Rebirth to start over even stronger!")
		capToast.GroupTransparency = 1
		capToast.Visible = true
		capTween = TweenService:Create(capToast, TweenInfo.new(Config.TrainingCap.FadeSeconds), { GroupTransparency = 0 })
		capTween:Play()
		capTask = task.delay(Config.TrainingCap.HoldSeconds, function()
			capTask = nil
			if capTween then capTween:Cancel(); capTween:Destroy() end
			local fade = TweenService:Create(capToast, TweenInfo.new(Config.TrainingCap.FadeSeconds), { GroupTransparency = 1 })
			capTween = fade
			fade.Completed:Connect(function()
				if capTween == fade then capToast.Visible = false; capTween = nil end
				fade:Destroy()
			end)
			fade:Play()
		end)
	end

	function view.SetStat(name: string, value: number, previous: number?)
		local card = cards[name]
		card.Value.Text = card.Prefix .. UI.Number(value)
		if previous and value > previous then
			local change = name == "TrainingLevel" and FeedbackConfig.LevelUpText
				or ("+" .. (name == "Cash" and "$" or "") .. UI.Number(value - previous))
			card.Feedback.Show(change)
		end
	end

	function view.SetDunkProgress(vertical: number, equippedId: string?)
		local equipped = Styles.Get(equippedId)
		local nextStyle = Styles.Get(Styles.NextLocked(vertical))
		local usable = equipped and Styles.IsUnlocked(equippedId, vertical)
		local required = nextStyle and nextStyle.RequiredVertical or 0
		local fraction = required > 0 and math.clamp(vertical / required, 0, 1) or 1
		heading.Text = usable and milestone.EquippedHeading or milestone.LockedHeading
		heading.TextColor3 = usable and Config.Colors.Gain or Config.Colors.Accent
		title.Text = usable and equipped.DisplayName or (nextStyle and nextStyle.DisplayName or "--")
		detail.Text = not nextStyle and milestone.AllUnlocked
			or (usable and string.format(milestone.NextFormat, nextStyle.DisplayName)
				or string.format(milestone.RequiredFormat, UI.Number(required)))
		preview.Text = nextStyle and string.format(milestone.ProgressFormat, UI.Number(vertical), UI.Number(required)) or ""
		if usable then
			local earnings = string.format(milestone.RewardFormat,
				UI.Number(DunkRewards.DunkCash(equipped.Reward, 1, vertical)),
				(string.format("%.2f", DunkRewards.VerticalMultiplier(vertical)):gsub("%.?0+$", "")))
			preview.Text = earnings .. (nextStyle and "\n" .. preview.Text or "")
		end
		fill.Size = UDim2.fromScale(fraction, 1)
		fill.BackgroundColor3 = heading.TextColor3
	end

	function view.Destroy()
		if capTask then task.cancel(capTask) end
		if capTween then capTween:Cancel(); capTween:Destroy() end
		resizeConnection:Disconnect()
		for _, card in cards do
			card.Feedback.Destroy()
		end
		screen:Destroy()
	end

	return view
end

return HUDView
