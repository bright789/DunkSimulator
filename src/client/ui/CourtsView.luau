local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Feel = require(ReplicatedStorage.Shared.Config.FeedbackConfig)
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local UI = require(script.Parent.UIComponents)
local CourtsView = {}

function CourtsView.Requirement(court, snapshot): string
	local vertical = snapshot.Vertical or 0
	local cash = snapshot.Cash or 0
	local required = court.Requirements
	if snapshot.UnlockedCourts[court.Id] then return "UNLOCKED  /  FREE TRAVEL" end
	local verticalText = vertical >= required.Vertical and (tostring(required.Vertical) .. " Vertical - MET")
		or (UI.Number(vertical) .. " / " .. required.Vertical .. " Vertical")
	return verticalText .. "\n$" .. UI.Number(cash) .. " / $" .. UI.Number(required.Cash) .. " Cash"
end

function CourtsView.Bonuses(court): string
	local bonuses = court.Bonuses
	if bonuses.DunkCashMultiplier == 1 and bonuses.TrainingMultiplier == 1 then
		return "COURT BONUSES\nStandard Dunk Cash\nStandard Training"
	end
	local cashPercent = math.floor((bonuses.DunkCashMultiplier - 1) * 100 + 0.5)
	local trainingPercent = math.floor((bonuses.TrainingMultiplier - 1) * 100 + 0.5)
	return string.format("COURT BONUSES\n+%d%% Dunk Cash\n+%d%% Vertical Training", cashPercent, trainingPercent)
end

function CourtsView.new(playerGui: PlayerGui)
	local screen = UI.Screen("Courts", 9)
	local panel = UI.Panel(screen, "Menu", UDim2.fromScale(0.8, 0.7), UDim2.fromScale(0.5, 0.5))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(440, 450)
	constraint.Parent = panel
	local title = UI.Label(panel, "Title", Config.CourtMenu.Title, UDim2.fromScale(0.8, 0.1), UDim2.fromScale(0.06, 0.03), 23)
	title.Font = Config.BoldFont
	title.TextColor3 = Config.Colors.Accent
	local function button(parent, name, text, size, position)
		local result = Instance.new("TextButton")
		result.Name = name
		result.Size = size
		result.Position = position
		result.Text = text
		result.Font = Config.BoldFont
		result.TextColor3 = Config.Colors.Text
		result.BackgroundColor3 = Config.Colors.Button
		result.BorderSizePixel = 0
		UI.Round(result, 8)
		UI.FitText(result, 13)
		result.Parent = parent
		UI.Interactive(result)
		return result
	end
	local close = button(panel, "Close", "X", UDim2.fromScale(0.08, 0.09), UDim2.fromScale(0.88, 0.04))
	local list = Instance.new("Frame")
	list.Size = UDim2.fromScale(0.88, 0.7)
	list.Position = UDim2.fromScale(0.06, 0.16)
	list.BackgroundTransparency = 1
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.04, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local rows = {}
	local ids = Courts.OrderedIds()
	for _, courtId in ids do
		local court = Courts.Get(courtId)
		local row = UI.Panel(list, courtId, UDim2.fromScale(1, (1 - 0.04 * (#ids - 1)) / #ids), UDim2.new())
		row.LayoutOrder = court.Order
		row.BackgroundColor3 = Config.Colors.Inset
		local name = UI.Label(row, "Name", court.DisplayName, UDim2.fromScale(0.9, 0.22), UDim2.fromScale(0.04, 0.06), 19)
		name.Font = Config.BoldFont
		local requirement = UI.Label(row, "Requirements", "Loading...", UDim2.fromScale(0.62, 0.3), UDim2.fromScale(0.04, 0.31), 12)
		requirement.TextColor3 = Config.Colors.Muted
		requirement.TextWrapped = true
		local bonusText = UI.Label(row, "Bonuses", CourtsView.Bonuses(court),
			UDim2.fromScale(0.62, 0.32), UDim2.fromScale(0.04, 0.65), 11)
		bonusText.TextColor3 = Config.Colors.Gain
		bonusText.TextWrapped = true
		local travel = button(row, "Travel", "LOCKED", UDim2.fromScale(0.28, 0.42), UDim2.fromScale(0.68, 0.46))
		rows[courtId] = { Requirements = requirement, Button = travel }
	end
	local feedback = UI.Label(panel, "Feedback", "", UDim2.fromScale(0.88, 0.1), UDim2.fromScale(0.06, 0.88), 13)
	feedback.TextWrapped = true
	local toast = Instance.new("CanvasGroup")
	toast.Name = "Unlock"
	toast.Size = UDim2.fromScale(0.68, 0.15)
	toast.Position = UDim2.fromScale(0.5, 0.09)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Visible = false
	toast.GroupTransparency = 1
	UI.StylePanel(toast)
	toast.Parent = screen
	local toastLimit = Instance.new("UISizeConstraint")
	toastLimit.MaxSize = Vector2.new(360, 100)
	toastLimit.Parent = toast
	local toastText = UI.Label(toast, "Text", "", UDim2.fromScale(0.9, 0.8), UDim2.fromScale(0.05, 0.1), 22)
	toastText.TextXAlignment = Enum.TextXAlignment.Center
	toastText.Font = Config.BoldFont
	toastText.TextColor3 = Config.Colors.Gain
	local arrival = Instance.new("CanvasGroup")
	arrival.Name = "Arrival"
	arrival.Size = UDim2.fromScale(0.7, 0.13)
	arrival.Position = UDim2.fromScale(0.5, 0.19)
	arrival.AnchorPoint = Vector2.new(0.5, 0)
	arrival.Visible = false
	arrival.GroupTransparency = 1
	UI.StylePanel(arrival)
	arrival.Parent = screen
	local arrivalLimit = Instance.new("UISizeConstraint")
	arrivalLimit.MaxSize = Vector2.new(380, 92)
	arrivalLimit.Parent = arrival
	local arrivalName = UI.Label(arrival, "Court", "", UDim2.fromScale(0.92, 0.45), UDim2.fromScale(0.04, 0.1), 21)
	arrivalName.Font = Config.BoldFont
	arrivalName.TextXAlignment = Enum.TextXAlignment.Center
	local arrivalBonus = UI.Label(arrival, "Bonus", "", UDim2.fromScale(0.92, 0.28), UDim2.fromScale(0.04, 0.61), 12)
	arrivalBonus.TextColor3 = Config.Colors.Accent
	arrivalBonus.TextXAlignment = Enum.TextXAlignment.Center
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CourtPortalStatus"
	billboard.Size = UDim2.fromOffset(240, 110)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	billboard.MaxDistance = 35
	billboard.Enabled = false
	local statusPanel = UI.Panel(billboard, "Panel", UDim2.fromScale(1, 1), UDim2.new())
	local status = UI.Label(statusPanel, "Text", "", UDim2.fromScale(0.92, 0.9), UDim2.fromScale(0.04, 0.05), 16)
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Center
	screen.Parent = playerGui
	billboard.Parent = playerGui
	local view = { Panel = panel, Close = close, Rows = rows }
	local unlockTween = nil
	local arrivalTween = nil
	local unlockVersion = 0
	local arrivalVersion = 0

	function view.Render(snapshot, busy: boolean)
		for courtId, row in rows do
			local unlocked = snapshot and snapshot.UnlockedCourts[courtId] == true
			local current = snapshot and snapshot.CurrentCourt == courtId
			row.Requirements.Text = snapshot and CourtsView.Requirement(Courts.Get(courtId), snapshot) or "Loading..."
			local available = unlocked and not current and not busy
			row.Button.Active = available == true
			row.Button.AutoButtonColor = available == true
			row.Button.Selectable = available == true
			row.Button.BackgroundColor3 = available and Config.Colors.Button or Config.Colors.Inset
			row.Button.Text = not snapshot and "LOADING" or (not unlocked and "VISIT PORTAL" or (current and "HERE" or (busy and "WAIT" or "TRAVEL")))
		end
	end

	function view.Feedback(message: string?) feedback.Text = message or "" end
	function view.ShowUnlock(courtId: string?, instant: boolean?)
		unlockVersion += 1
		local version = unlockVersion
		if unlockTween then unlockTween:Cancel(); unlockTween:Destroy() end
		if courtId then
			toastText.Text = Courts.Get(courtId).DisplayName:upper() .. "\nUNLOCKED!"
			toast.GroupTransparency = 1
			toast.Position = UDim2.new(0.5, 0, 0.09, Feel.Unlock.SlidePixels)
			toast.Visible = true
		end
		if instant then toast.Visible = courtId ~= nil; toast.GroupTransparency = courtId and 0 or 1; return end
		local tween = TweenService:Create(toast, TweenInfo.new(Feel.Unlock.FadeSeconds,
			Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = courtId and 0 or 1,
				Position = courtId and UDim2.fromScale(0.5, 0.09)
					or UDim2.new(0.5, 0, 0.09, -Feel.Unlock.SlidePixels) })
		unlockTween = tween
		tween.Completed:Connect(function()
			if unlockVersion == version then toast.Visible = courtId ~= nil; unlockTween = nil end
			tween:Destroy()
		end)
		tween:Play()
	end
	function view.ShowArrival(courtId: string)
		arrivalVersion += 1
		if arrivalTween then arrivalTween:Cancel(); arrivalTween:Destroy() end
		local court = Courts.Get(courtId)
		arrivalName.Text = court.DisplayName:upper()
		arrivalBonus.Text = string.format("%.2fx DUNK CASH   •   %.2fx TRAINING",
			court.Bonuses.DunkCashMultiplier, court.Bonuses.TrainingMultiplier)
		arrival.GroupTransparency = 1
		arrival.Position = UDim2.new(0.5, 0, 0.19, Feel.Unlock.SlidePixels)
		arrival.Visible = true
		arrivalTween = TweenService:Create(arrival, TweenInfo.new(Feel.Arrival.FadeSeconds,
			Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.19) })
		arrivalTween:Play()
	end
	function view.HideArrival(instant: boolean?)
		arrivalVersion += 1
		local version = arrivalVersion
		if arrivalTween then arrivalTween:Cancel(); arrivalTween:Destroy() end
		if instant then arrival.Visible = false; arrival.GroupTransparency = 1; return end
		local tween = TweenService:Create(arrival, TweenInfo.new(Feel.Arrival.FadeSeconds,
			Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.19, -Feel.Unlock.SlidePixels) })
		arrivalTween = tween
		tween.Completed:Connect(function()
			if arrivalVersion == version then arrival.Visible = false; arrivalTween = nil end
			tween:Destroy()
		end)
		tween:Play()
	end
	function view.Portal(prompt: ProximityPrompt?, targetId: string?, snapshot)
		billboard.Enabled = prompt ~= nil and targetId ~= nil
		billboard.Adornee = prompt and prompt.Parent or nil
		if not prompt or not targetId then return end
		local court = Courts.Get(targetId)
		local unlocked = snapshot and snapshot.UnlockedCourts[targetId]
		prompt.ActionText = unlocked and "TRAVEL" or "UNLOCK"
		local ready = snapshot and snapshot.Vertical >= court.Requirements.Vertical and snapshot.Cash >= court.Requirements.Cash
		status.Text = court.DisplayName:upper() .. "\n" .. (snapshot and CourtsView.Requirement(court, snapshot) or "Loading player data...")
			.. (not unlocked and ready and "\nREADY TO UNLOCK" or "")
	end
	function view.Destroy()
		if unlockTween then unlockTween:Cancel(); unlockTween:Destroy() end
		if arrivalTween then arrivalTween:Cancel(); arrivalTween:Destroy() end
		billboard:Destroy()
		screen:Destroy()
	end
	return view
end

return CourtsView
