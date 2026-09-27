-- Rebirth menu: current rebirths and bonuses, what the next rebirth needs, what resets,
-- and a two-step REBIRTH button. Display only; the server decides everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local UI = require(script.Parent.UIComponents)

local RebirthView = {}

local function multiplier(value: number): string
	return "x" .. (string.format("%.2f", value):gsub("%.?0+$", ""))
end

function RebirthView.new(playerGui: PlayerGui)
	local screen = UI.Screen("Rebirth", 9)
	local panel = UI.Panel(screen, "Menu", UDim2.fromScale(0.8, 0.7), UDim2.fromScale(0.5, 0.5))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(420, 360)
	constraint.Parent = panel
	local title = UI.Label(panel, "Title", "REBIRTH", UDim2.fromScale(0.8, 0.1), UDim2.fromScale(0.06, 0.03), 24)
	title.Font = Config.BoldFont
	title.TextColor3 = Config.Colors.Gold
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromScale(0.08, 0.09)
	close.Position = UDim2.fromScale(0.88, 0.04)
	close.Text = "X"
	close.Font = Config.BoldFont
	close.TextColor3 = Config.Colors.Text
	close.BackgroundColor3 = Config.Colors.Button
	close.BorderSizePixel = 0
	UI.Round(close, 8)
	UI.FitText(close, 13)
	close.Parent = panel
	UI.Interactive(close)

	local count = UI.Label(panel, "Count", "--", UDim2.fromScale(0.88, 0.08), UDim2.fromScale(0.06, 0.15), 16)
	count.Font = Config.BoldFont
	local bonuses = UI.Label(panel, "Bonuses", "--", UDim2.fromScale(0.88, 0.14), UDim2.fromScale(0.06, 0.24), 13)
	bonuses.TextColor3 = Config.Colors.Gain
	bonuses.TextWrapped = true
	local needs = UI.Panel(panel, "Needs", UDim2.fromScale(0.88, 0.2), UDim2.fromScale(0.06, 0.4))
	needs.BackgroundColor3 = Config.Colors.Inset
	local verticalNeed = UI.Label(needs, "Vertical", "--", UDim2.fromScale(0.9, 0.4), UDim2.fromScale(0.05, 0.08), 14)
	verticalNeed.Font = Config.BoldFont
	local cashNeed = UI.Label(needs, "Cash", "--", UDim2.fromScale(0.9, 0.4), UDim2.fromScale(0.05, 0.52), 14)
	cashNeed.Font = Config.BoldFont
	local warning = UI.Label(panel, "Warning",
		"Resets Cash, Vertical, Training Level and court unlocks, and sends you back to the Neighborhood. Keeps your rebirths and claimed challenges.",
		UDim2.fromScale(0.88, 0.14), UDim2.fromScale(0.06, 0.62), 11)
	warning.TextColor3 = Config.Colors.Muted
	warning.TextWrapped = true
	local button = Instance.new("TextButton")
	button.Name = "RebirthButton"
	button.Size = UDim2.fromScale(0.56, 0.11)
	button.Position = UDim2.fromScale(0.22, 0.78)
	button.Text = "REBIRTH"
	button.Font = Config.BoldFont
	button.TextColor3 = Config.Colors.Text
	button.BackgroundColor3 = Config.Colors.Inset
	button.BorderSizePixel = 0
	UI.Round(button, 10)
	UI.FitText(button, 18)
	button.Parent = panel
	UI.Interactive(button)
	local feedback = UI.Label(panel, "Feedback", "", UDim2.fromScale(0.88, 0.07), UDim2.fromScale(0.06, 0.91), 12)
	feedback.TextWrapped = true
	feedback.TextXAlignment = Enum.TextXAlignment.Center

	-- Celebration toast after a successful rebirth.
	local toast = Instance.new("CanvasGroup")
	toast.Name = "RebirthToast"
	toast.Size = UDim2.fromScale(0.6, 0.16)
	toast.Position = UDim2.fromScale(0.5, 0.1)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Visible = false
	toast.GroupTransparency = 1
	UI.StylePanel(toast)
	toast.Parent = screen
	local toastLimit = Instance.new("UISizeConstraint")
	toastLimit.MaxSize = Vector2.new(380, 110)
	toastLimit.Parent = toast
	local toastTitle = UI.Label(toast, "Title", "", UDim2.fromScale(0.9, 0.5), UDim2.fromScale(0.05, 0.08), 30)
	toastTitle.Font = Config.BoldFont
	toastTitle.TextColor3 = Config.Colors.Gold
	toastTitle.TextXAlignment = Enum.TextXAlignment.Center
	local toastDetail = UI.Label(toast, "Detail", "", UDim2.fromScale(0.9, 0.32), UDim2.fromScale(0.05, 0.6), 15)
	toastDetail.TextColor3 = Config.Colors.Gain
	toastDetail.TextXAlignment = Enum.TextXAlignment.Center
	screen.Parent = playerGui

	local view = { Panel = panel, Close = close, Button = button }
	local toastVersion = 0

	function view.Render(snapshot, confirming: boolean, busy: boolean)
		if not snapshot then
			count.Text = "Loading..."
			bonuses.Text = ""
			verticalNeed.Text, cashNeed.Text = "", ""
			button.Text = "LOADING"
			button.BackgroundColor3 = Config.Colors.Inset
			return
		end
		count.Text = string.format("REBIRTHS: %d", snapshot.Rebirths)
		bonuses.Text = string.format("Now: %s Cash  /  %s Training\nNext: %s Cash  /  %s Training",
			multiplier(snapshot.CashMultiplier), multiplier(snapshot.TrainingMultiplier),
			multiplier(snapshot.NextCashMultiplier), multiplier(snapshot.NextTrainingMultiplier))
		local verticalMet = snapshot.Vertical >= snapshot.RequiredVertical
		local cashMet = snapshot.Cash >= snapshot.RequiredCash
		verticalNeed.Text = string.format("Vertical  %s / %s%s", UI.Number(snapshot.Vertical),
			UI.Number(snapshot.RequiredVertical), verticalMet and "  - MET" or "")
		verticalNeed.TextColor3 = verticalMet and Config.Colors.Gain or Config.Colors.Text
		cashNeed.Text = string.format("Cash  $%s / $%s%s", UI.Number(snapshot.Cash),
			UI.Number(snapshot.RequiredCash), cashMet and "  - MET" or "")
		cashNeed.TextColor3 = cashMet and Config.Colors.Gain or Config.Colors.Text
		local ready = snapshot.CanRebirth and not busy
		button.Text = busy and "WAIT" or (confirming and "CONFIRM REBIRTH?" or (snapshot.CanRebirth and "REBIRTH" or "LOCKED"))
		button.BackgroundColor3 = confirming and Config.Colors.Warning or (ready and Config.Colors.Gold or Config.Colors.Inset)
		button.TextColor3 = ready and Config.Colors.Panel or Config.Colors.Muted
		button.Active = ready
		button.AutoButtonColor = ready
	end

	function view.Feedback(message: string?)
		feedback.Text = message or ""
	end

	function view.Celebrate(snapshot)
		toastVersion += 1
		local version = toastVersion
		toastTitle.Text = string.format("REBIRTH %d!", snapshot.Rebirths)
		toastDetail.Text = string.format("%s Cash  /  %s Training forever",
			multiplier(snapshot.CashMultiplier), multiplier(snapshot.TrainingMultiplier))
		toast.Visible = true
		toast.GroupTransparency = 1
		TweenService:Create(toast, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
		task.delay(3, function()
			if toastVersion ~= version then return end
			local fade = TweenService:Create(toast, TweenInfo.new(0.4), { GroupTransparency = 1 })
			fade.Completed:Once(function() if toastVersion == version then toast.Visible = false end end)
			fade:Play()
		end)
	end

	function view.Destroy()
		screen:Destroy()
	end

	return view
end

return RebirthView
