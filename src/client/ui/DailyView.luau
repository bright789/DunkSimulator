-- Daily menu: the 7-day login ladder with today's claim, the streak, and today's three
-- daily challenges with progress bars. Display only; the server decides everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local UI = require(script.Parent.UIComponents)
local RewardPresentation = require(script.Parent.RewardPresentation)

local DailyView = {}

local function button(parent, name, text, size, position, textSize)
	local control = Instance.new("TextButton")
	control.Name = name
	control.Size = size
	control.Position = position
	control.Text = text
	control.Font = Config.BoldFont
	control.TextColor3 = Config.Colors.Text
	control.BackgroundColor3 = Config.Colors.Button
	control.BorderSizePixel = 0
	UI.Round(control, 8)
	UI.FitText(control, textSize or 13)
	control.Parent = parent
	UI.Interactive(control)
	return control
end

local function setEnabled(control: TextButton, enabled: boolean, color: Color3?)
	control.Active = enabled
	control.Selectable = enabled
	control.AutoButtonColor = enabled
	control.BackgroundColor3 = enabled and (color or Config.Colors.Button) or Config.Colors.Inset
	control.TextColor3 = enabled and (color == Config.Colors.Gold and Config.Colors.Panel or Config.Colors.Text) or Config.Colors.Muted
end

-- "4h 12m" / "12m 30s".
function DailyView.Duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then return string.format("%dh %02dm", hours, minutes) end
	return string.format("%dm %02ds", minutes, seconds % 60)
end

function DailyView.new(playerGui: PlayerGui)
	local screen = UI.Screen("Daily", 10)
	local panel = UI.Panel(screen, "Menu", UDim2.fromScale(0.88, 0.86), UDim2.fromScale(0.5, 0.5))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(480, 580)
	limit.Parent = panel
	local title = UI.Label(panel, "Title", "DAILY REWARDS", UDim2.fromScale(0.78, 0.07), UDim2.fromScale(0.05, 0.025), 24)
	title.Font = Config.BoldFont
	title.TextColor3 = Config.Colors.Gold
	local close = button(panel, "Close", "X", UDim2.fromScale(0.08, 0.065), UDim2.fromScale(0.88, 0.025))

	-- Login streak ladder.
	local streak = UI.Label(panel, "Streak", "--", UDim2.fromScale(0.5, 0.045), UDim2.fromScale(0.05, 0.1), 15)
	streak.Font = Config.BoldFont
	local timer = UI.Label(panel, "Timer", "", UDim2.fromScale(0.42, 0.04), UDim2.fromScale(0.53, 0.105), 12)
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.TextColor3 = Config.Colors.Muted
	local tiles = {}
	for index = 1, #Daily.Ladder do
		local tile = Instance.new("Frame")
		tile.Name = "Day" .. index
		tile.Size = UDim2.fromScale(0.122, 0.13)
		tile.Position = UDim2.fromScale(0.05 + (index - 1) * 0.1285, 0.16)
		tile.BackgroundColor3 = Config.Colors.Inset
		tile.BorderSizePixel = 0
		UI.Round(tile, 8)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Config.Colors.Gold
		stroke.Transparency = 1
		stroke.Parent = tile
		tile.Parent = panel
		local dayLabel = UI.Label(tile, "Day", "DAY " .. index, UDim2.fromScale(0.9, 0.26), UDim2.fromScale(0.05, 0.06), 11)
		dayLabel.TextXAlignment = Enum.TextXAlignment.Center
		dayLabel.TextColor3 = Config.Colors.Muted
		local cash = UI.Label(tile, "Cash", "--", UDim2.fromScale(0.92, 0.3), UDim2.fromScale(0.04, 0.36), 13)
		cash.Font = Config.BoldFont
		cash.TextXAlignment = Enum.TextXAlignment.Center
		cash.TextColor3 = Config.Colors.Gain
		local extra = UI.Label(tile, "Extra", "", UDim2.fromScale(0.92, 0.24), UDim2.fromScale(0.04, 0.7), 10)
		extra.TextXAlignment = Enum.TextXAlignment.Center
		extra.TextColor3 = Config.Colors.Gold
		tiles[index] = { Frame = tile, Stroke = stroke, Day = dayLabel, Cash = cash, Extra = extra }
	end
	local claim = button(panel, "ClaimReward", "LOADING", UDim2.fromScale(0.9, 0.07), UDim2.fromScale(0.05, 0.305), 16)
	local notice = UI.Label(panel, "Notice", "", UDim2.fromScale(0.9, 0.035), UDim2.fromScale(0.05, 0.38), 11)
	notice.TextXAlignment = Enum.TextXAlignment.Center

	-- Daily challenges.
	local heading = UI.Label(panel, "ChallengesHeading", "DAILY CHALLENGES", UDim2.fromScale(0.6, 0.05), UDim2.fromScale(0.05, 0.425), 18)
	heading.Font = Config.BoldFont
	heading.TextColor3 = Config.Colors.Accent
	local rows = {}
	for slot = 1, Daily.Challenges.PerDay do
		local row = UI.Panel(panel, "Challenge" .. slot, UDim2.fromScale(0.9, 0.125), UDim2.fromScale(0.05, 0.48 + (slot - 1) * 0.137))
		row.BackgroundColor3 = Config.Colors.Inset
		local name = UI.Label(row, "Name", "--", UDim2.fromScale(0.64, 0.28), UDim2.fromScale(0.035, 0.07), 15)
		name.Font = Config.BoldFont
		local description = UI.Label(row, "Description", "", UDim2.fromScale(0.64, 0.24), UDim2.fromScale(0.035, 0.37), 11)
		description.TextColor3 = Config.Colors.Muted
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.Size = UDim2.fromScale(0.42, 0.13)
		track.Position = UDim2.fromScale(0.035, 0.73)
		track.BackgroundColor3 = Config.Colors.Panel
		track.BorderSizePixel = 0
		track.ClipsDescendants = true
		UI.Round(track, 4)
		track.Parent = row
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Config.Colors.Accent
		fill.BorderSizePixel = 0
		UI.Round(fill, 4)
		fill.Parent = track
		local progress = UI.Label(row, "Progress", "", UDim2.fromScale(0.2, 0.24), UDim2.fromScale(0.47, 0.67), 11)
		local reward = UI.Label(row, "Reward", "", UDim2.fromScale(0.28, 0.26), UDim2.fromScale(0.69, 0.08), 13)
		reward.Font = Config.BoldFont
		reward.TextXAlignment = Enum.TextXAlignment.Center
		reward.TextColor3 = Config.Colors.Gain
		local claimChallenge = button(row, "Claim", "--", UDim2.fromScale(0.28, 0.46), UDim2.fromScale(0.69, 0.44), 13)
		rows[slot] = { Frame = row, Name = name, Description = description, Fill = fill, Progress = progress,
			Reward = reward, Button = claimChallenge }
	end
	local sweep = UI.Label(panel, "Sweep", "", UDim2.fromScale(0.9, 0.04), UDim2.fromScale(0.05, 0.895), 12)
	sweep.TextXAlignment = Enum.TextXAlignment.Center
	sweep.TextColor3 = Config.Colors.Gold
	local feedback = UI.Label(panel, "Feedback", "", UDim2.fromScale(0.9, 0.04), UDim2.fromScale(0.05, 0.94), 12)
	feedback.TextXAlignment = Enum.TextXAlignment.Center
	screen.Parent = playerGui
	local rewardPresentation = RewardPresentation.new(screen)

	local view = { Panel = panel, Close = close, ClaimButton = claim, Rows = rows }

	-- `pending` is "Reward", a challenge slot number, or nil; `resetIn` is seconds to the
	-- next UTC day.
	function view.Render(snapshot, pending, resetIn: number)
		if not snapshot then
			streak.Text = "Loading..."
			claim.Text = "LOADING"
			setEnabled(claim, false)
			for _, row in rows do row.Frame.Visible = false end
			return
		end
		local newDay = "New day in " .. DailyView.Duration(resetIn)
		timer.Text = newDay
		local shownStreak = snapshot.CanClaim and snapshot.ClaimStreak - 1 or snapshot.Streak
		streak.Text = string.format("STREAK: %d DAY%s", shownStreak, shownStreak == 1 and "" or "S")
		for index, tile in tiles do
			local step = snapshot.Ladder[index]
			local done = index < snapshot.ClaimDay or (index == snapshot.ClaimDay and not snapshot.CanClaim)
			local today = index == snapshot.ClaimDay and snapshot.CanClaim
			tile.Cash.Text = "$" .. UI.Number(step.Cash)
			tile.Extra.Text = done and "CLAIMED" or (step.BoostMinutes > 0 and string.format("+%dx %dm", snapshot.BoostMultiplier, step.BoostMinutes) or "")
			tile.Extra.TextColor3 = done and Config.Colors.Gain or Config.Colors.Gold
			tile.Frame.BackgroundTransparency = done and 0.45 or 0
			tile.Stroke.Transparency = today and 0 or 1
			tile.Day.TextColor3 = today and Config.Colors.Gold or Config.Colors.Muted
		end
		if snapshot.CanClaim then
			local step = snapshot.Ladder[snapshot.ClaimDay]
			claim.Text = pending == "Reward" and "WAIT" or string.format("CLAIM DAY %d:  $%s%s", snapshot.ClaimDay,
				UI.Number(step.Cash), step.BoostMinutes > 0 and string.format("  +  %dx CASH %d MIN", snapshot.BoostMultiplier, step.BoostMinutes) or "")
			setEnabled(claim, pending == nil, Config.Colors.Gold)
		else
			claim.Text = "CLAIMED!  NEXT REWARD IN " .. DailyView.Duration(resetIn):upper()
			setEnabled(claim, false)
		end
		notice.Text = snapshot.StreakLost and "You missed a day, so your streak starts over at Day 1."
			or "Come back every day: the reward grows until Day 7, then repeats."
		notice.TextColor3 = snapshot.StreakLost and Config.Colors.Warning or Config.Colors.Muted

		local claimedAll = #snapshot.Challenges > 0
		for slot, row in rows do
			local entry = snapshot.Challenges[slot]
			row.Frame.Visible = entry ~= nil
			if entry then
				local definition = Daily.Challenges.Pool[entry.Id]
				local ready = entry.Progress >= entry.Target and not entry.Claimed
				claimedAll = claimedAll and entry.Claimed
				row.Name.Text = definition and definition.Title:upper() or "--"
				row.Description.Text = Daily.Describe(entry)
				row.Fill.Size = UDim2.fromScale(math.clamp(entry.Progress / entry.Target, 0, 1), 1)
				row.Fill.BackgroundColor3 = (entry.Claimed or ready) and Config.Colors.Gain or Config.Colors.Accent
				row.Progress.Text = UI.Number(entry.Progress) .. " / " .. UI.Number(entry.Target)
				row.Reward.Text = "$" .. UI.Number(entry.Reward)
				row.Button.Text = entry.Claimed and "DONE" or (ready and (pending == slot and "WAIT" or "CLAIM") or "IN PROGRESS")
				setEnabled(row.Button, ready and pending == nil)
				if entry.Claimed then row.Button.TextColor3 = Config.Colors.Gain end
			end
		end
		sweep.Text = claimedAll and "ALL DONE! Sweep bonus earned. New challenges tomorrow."
			or string.format("Claim all %d for a bonus: %dx Cash for %d min", #snapshot.Challenges,
				snapshot.BoostMultiplier, snapshot.SweepBoostMinutes)
	end

	function view.Feedback(message: string?, success: boolean?)
		feedback.Text = message or ""
		feedback.TextColor3 = success and Config.Colors.Gain or Config.Colors.Warning
	end

	function view.Toast(headingText: string, titleText: string, detailText: string, claimed: boolean)
		rewardPresentation.Show(headingText, titleText, detailText, claimed)
	end

	function view.Destroy()
		rewardPresentation.Destroy()
		screen:Destroy()
	end

	return view
end

return DailyView
