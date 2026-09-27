local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Challenges = require(ReplicatedStorage.Shared.Config.ChallengeConfig)
local Styles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local UI = require(script.Parent.UIComponents)
local RewardPresentation = require(script.Parent.RewardPresentation)

local ChallengesView = {}

local function button(parent, name, text, size, position)
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
	UI.FitText(control, 13)
	control.Parent = parent
	UI.Interactive(control)
	return control
end

function ChallengesView.new(playerGui: PlayerGui)
	local screen = UI.Screen("Challenges", 10)
	local panel = UI.Panel(screen, "Menu", UDim2.fromScale(0.86, 0.82), UDim2.fromScale(0.5, 0.5))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(500, 570)
	limit.Parent = panel
	local title = UI.Label(panel, "Title", Config.ChallengeMenu.Title,
		UDim2.fromScale(0.78, 0.08), UDim2.fromScale(0.05, 0.03), 23)
	title.Font = Config.BoldFont
	title.TextColor3 = Config.Colors.Accent
	local close = button(panel, "Close", "X", UDim2.fromScale(0.08, 0.08), UDim2.fromScale(0.88, 0.03))
	local list = Instance.new("ScrollingFrame")
	list.Name = "ChallengeList"
	list.Size = UDim2.fromScale(0.91, 0.75)
	list.Position = UDim2.fromScale(0.05, 0.14)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Config.Colors.Accent
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list
	local rows = {}
	for _, challengeId in Challenges.OrderedIds() do
		local definition = Challenges.Get(challengeId)
		local row = UI.Panel(list, challengeId, UDim2.new(1, -8, 0, 104), UDim2.new())
		row.LayoutOrder = definition.Order
		row.BackgroundColor3 = Config.Colors.Inset
		local name = UI.Label(row, "Name", definition.DisplayName:upper(),
			UDim2.fromScale(0.64, 0.22), UDim2.fromScale(0.035, 0.05), 16)
		name.Font = Config.BoldFont
		local description = UI.Label(row, "Description", definition.Description,
			UDim2.fromScale(0.62, 0.27), UDim2.fromScale(0.035, 0.28), 12)
		description.TextColor3 = Config.Colors.Muted
		description.TextWrapped = true
		local progress = UI.Label(row, "Progress", "--", UDim2.fromScale(0.63, 0.19),
			UDim2.fromScale(0.035, 0.59), 12)
		progress.TextColor3 = Config.Colors.Accent
		local reward = UI.Label(row, "Reward", "Reward: $" .. UI.Number(definition.Reward.Cash),
			UDim2.fromScale(0.62, 0.16), UDim2.fromScale(0.035, 0.79), 12)
		reward.TextColor3 = Config.Colors.Gain
		local claim = button(row, "Claim", "IN PROGRESS", UDim2.fromScale(0.29, 0.43),
			UDim2.fromScale(0.675, 0.31))
		rows[challengeId] = { Progress = progress, Button = claim }
	end
	local feedback = UI.Label(panel, "Feedback", "", UDim2.fromScale(0.9, 0.06),
		UDim2.fromScale(0.05, 0.92), 13)
	feedback.TextXAlignment = Enum.TextXAlignment.Center
	feedback.TextWrapped = true
	screen.Parent = playerGui
	local rewardPresentation = RewardPresentation.new(screen)
	local view = { Panel = panel, Close = close, Rows = rows }

	function view.Render(snapshot, pendingId: string?)
		for challengeId, row in rows do
			local definition = Challenges.Get(challengeId)
			local entry = snapshot and snapshot.Challenges[challengeId]
			local target = Challenges.Target(definition)
			local ready = entry and entry.Progress >= target and not entry.Completed
			local detail = entry and (UI.Number(entry.Progress) .. " / " .. UI.Number(target)) or "Loading..."
			if entry and not entry.Completed and not ready then
				if definition.Type == "DunkStyleCount" then
					local styleId = definition.Requirements.DunkStyle
					if not Styles.IsUnlocked(styleId, snapshot.Vertical) then
						detail ..= "  -  Requires " .. Styles.Get(styleId).RequiredVertical .. " Vertical"
					end
				elseif definition.Type == "CourtDunkCount" and not snapshot.UnlockedCourts[definition.Requirements.Court] then
					detail ..= "  -  Requires " .. Courts.Get(definition.Requirements.Court).DisplayName
				end
			end
			row.Progress.Text = detail
			local available = ready and pendingId == nil
			row.Button.Active = available == true
			row.Button.Selectable = available == true
			row.Button.AutoButtonColor = available == true
			row.Button.BackgroundColor3 = available and Config.Colors.Button or Config.Colors.Inset
			row.Button.TextColor3 = entry and entry.Completed and Config.Colors.Gain or Config.Colors.Text
			row.Button.Text = not entry and "LOADING" or (entry.Completed and "COMPLETED"
				or (ready and (pendingId and "WAIT" or "CLAIM") or "IN PROGRESS"))
		end
	end

	function view.Feedback(message: string?, success: boolean?)
		feedback.Text = message or ""
		feedback.TextColor3 = success and Config.Colors.Gain or Config.Colors.Warning
	end

	function view.ShowReady(challengeId: string)
		local definition = Challenges.Get(challengeId)
		if definition then
			rewardPresentation.Show("CHALLENGE COMPLETE", definition.DisplayName:upper(),
				"Reward ready: $" .. UI.Number(definition.Reward.Cash), false)
		end
	end

	function view.ShowClaim(challengeId: string, cash: number)
		local definition = Challenges.Get(challengeId)
		if definition then
			rewardPresentation.Show("CHALLENGE REWARD", definition.DisplayName:upper(),
				"+$" .. UI.Number(cash), true)
		end
	end

	function view.HideToast() rewardPresentation.Hide() end
	function view.Destroy()
		rewardPresentation.Destroy()
		screen:Destroy()
	end
	return view
end

return ChallengesView
