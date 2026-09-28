-- New-player tutorial presentation: a step card at the top of the screen, a bobbing marker
-- above the step's target and a glowing guide line from the player to it. Display only;
-- TutorialController decides what to show.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HUDConfig"))
local UI = require(script.Parent:WaitForChild("UIComponents"))

local TutorialView = {}

-- The line is hidden once the player is this close to the target.
local GUIDE_HIDE_DISTANCE = 9
local MARKER_HEIGHT = 4.5
local BOB_STUDS = 0.6
local BOB_SPEED = 3

function TutorialView.new(playerGui: PlayerGui)
	local screen = UI.Screen("Tutorial", 3)
	local card = Instance.new("CanvasGroup")
	card.Name = "Step"
	card.Size = UDim2.fromScale(0.46, 0.13)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.fromScale(0.5, 0.1)
	card.Visible = false
	card.GroupTransparency = 1
	UI.StylePanel(card)
	card.Parent = screen
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(280, 78)
	limit.MaxSize = Vector2.new(440, 96)
	limit.Parent = card
	local counter = UI.Label(card, "Counter", "", UDim2.new(0.6, 0, 0.2, 0), UDim2.fromScale(0.04, 0.06), 12)
	counter.Font = Config.BoldFont
	counter.TextColor3 = Config.Colors.Gold
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.Size = UDim2.new(0.16, 0, 0.22, 0)
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.fromScale(0.97, 0.06)
	UI.StylePanel(skip)
	skip.Text = "SKIP"
	skip.Font = Config.BoldFont
	skip.TextScaled = true
	skip.TextColor3 = Config.Colors.Muted
	skip.Parent = card
	UI.Interactive(skip)
	-- GET IT button, only shown for the Starter Pack offer.
	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.Size = UDim2.new(0.22, 0, 0.3, 0)
	buy.AnchorPoint = Vector2.new(1, 0)
	buy.Position = UDim2.fromScale(0.97, 0.56)
	UI.StylePanel(buy)
	buy.BackgroundColor3 = Config.Colors.Gold
	buy.BackgroundTransparency = 0
	buy.Text = "GET IT"
	buy.Font = Config.BoldFont
	buy.TextScaled = true
	buy.TextColor3 = Config.Colors.Panel
	buy.Visible = false
	buy.Parent = card
	UI.Interactive(buy)
	local title = UI.Label(card, "Title", "", UDim2.new(0.92, 0, 0.3, 0), UDim2.fromScale(0.04, 0.26), 22)
	title.Font = Config.BoldFont
	local detail = UI.Label(card, "Detail", "", UDim2.new(0.92, 0, 0.2, 0), UDim2.fromScale(0.04, 0.56), 13)
	detail.TextColor3 = Config.Colors.Muted
	local track = Instance.new("Frame")
	track.Name = "Progress"
	track.Size = UDim2.new(0.7, 0, 0.1, 0)
	track.Position = UDim2.fromScale(0.04, 0.82)
	track.BackgroundColor3 = Config.Colors.Inset
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	UI.Round(track, 4)
	track.Parent = card
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Config.Colors.Gain
	fill.BorderSizePixel = 0
	UI.Round(fill, 4)
	fill.Parent = track
	local amount = UI.Label(card, "Amount", "", UDim2.new(0.2, 0, 0.18, 0), UDim2.fromScale(0.76, 0.78), 12)
	amount.TextXAlignment = Enum.TextXAlignment.Right
	amount.TextColor3 = Config.Colors.Gain
	screen.Parent = playerGui

	-- World guide (local only, never replicated).
	local guideFolder = Instance.new("Folder")
	guideFolder.Name = "TutorialGuide"
	local startAttachment = Instance.new("Attachment")
	startAttachment.Name = "TutorialGuideStart"
	local endAttachment = Instance.new("Attachment")
	endAttachment.Name = "TutorialGuideEnd"
	local beam = Instance.new("Beam")
	beam.Name = "GuideLine"
	beam.Attachment0 = startAttachment
	beam.Attachment1 = endAttachment
	beam.FaceCamera = true
	beam.Width0 = 0.45
	beam.Width1 = 0.45
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(Config.Colors.Gold, Config.Colors.Warning)
	beam.Transparency = NumberSequence.new(0.15, 0.55)
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = guideFolder
	local marker = Instance.new("BillboardGui")
	marker.Name = "TutorialMarker"
	marker.Size = UDim2.fromOffset(170, 74)
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.Enabled = false
	marker.ResetOnSpawn = false
	marker.Parent = playerGui
	local markerText = UI.Label(marker, "Text", "", UDim2.new(1, 0, 0, 30), UDim2.new(), 24)
	markerText.Font = Config.BoldFont
	markerText.TextColor3 = Config.Colors.Gold
	markerText.TextXAlignment = Enum.TextXAlignment.Center
	-- A gold diamond pointing down at the target.
	local gem = Instance.new("Frame")
	gem.Name = "Pointer"
	gem.Size = UDim2.fromOffset(26, 26)
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.new(0.5, 0, 0, 52)
	gem.Rotation = 45
	gem.BackgroundColor3 = Config.Colors.Gold
	gem.BorderSizePixel = 0
	UI.Round(gem, 4)
	local gemStroke = Instance.new("UIStroke")
	gemStroke.Color = Color3.new(1, 1, 1)
	gemStroke.Thickness = 3
	gemStroke.Parent = gem
	gem.Parent = marker
	guideFolder.Parent = Workspace

	local view = { SkipButton = skip, BuyButton = buy }
	local cardTween = nil
	local target: BasePart? = nil
	local root: BasePart? = nil
	local bobConnection = nil

	local function fade(visible: boolean)
		if cardTween then cardTween:Cancel() end
		if visible then card.Visible = true end
		cardTween = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = visible and 0 or 1 })
		cardTween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and not visible then card.Visible = false end
		end)
		cardTween:Play()
	end

	function view.ShowStep(index: number, total: number, step, current: number?, goal: number?)
		buy.Visible = false
		skip.Text = "SKIP"
		detail.Size = UDim2.new(0.92, 0, 0.2, 0)
		counter.Text = string.format("TUTORIAL  %d / %d", index, total)
		title.Text = step.Title
		title.TextColor3 = Config.Colors.Text
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		detail.Text = touch and step.TouchDetail or step.Detail
		skip.Visible = true
		local hasProgress = current ~= nil and goal ~= nil and goal > 0
		track.Visible = hasProgress
		amount.Visible = hasProgress
		if hasProgress then
			fill.Size = UDim2.fromScale(math.clamp(current / goal, 0, 1), 1)
			amount.Text = step.Id == "Upgrade" and string.format("$%s / $%s", UI.Number(current), UI.Number(goal))
				or string.format("%d / %d", current, goal)
		end
		if not card.Visible or card.GroupTransparency > 0.5 then fade(true) end
	end

	-- One-off offer card (Starter Pack) with GET IT and LATER.
	function view.ShowOffer(heading: string, titleText: string, detailText: string)
		counter.Text = heading
		title.Text = titleText
		title.TextColor3 = Config.Colors.Gold
		detail.Text = detailText
		detail.Size = UDim2.new(0.7, 0, 0.2, 0)
		skip.Text = "LATER"
		skip.Visible = true
		buy.Visible = true
		track.Visible = false
		amount.Visible = false
		fade(true)
	end

	function view.ShowComplete()
		buy.Visible = false
		detail.Size = UDim2.new(0.92, 0, 0.2, 0)
		counter.Text = "TUTORIAL"
		title.Text = "TUTORIAL COMPLETE!"
		title.TextColor3 = Config.Colors.Gold
		detail.Text = "Keep training and dunking to unlock bigger courts!"
		skip.Visible = false
		track.Visible = false
		amount.Visible = false
		fade(true)
		task.delay(5, function()
			if title.Text == "TUTORIAL COMPLETE!" then fade(false) end
		end)
	end

	function view.Hide()
		if card.Visible then fade(false) end
	end

	-- Points the guide at `part` (nil clears it). `label` is shown above the part.
	function view.SetGuide(characterRoot: BasePart?, part: BasePart?, label: string?)
		target, root = part, characterRoot
		if part and characterRoot then
			startAttachment.Parent = characterRoot
			startAttachment.Position = Vector3.new(0, -2.4, 0)
			endAttachment.Parent = part
			endAttachment.Position = Vector3.zero
			marker.Adornee = part
			markerText.Text = label or ""
			marker.Enabled = true
			if not bobConnection then
				bobConnection = RunService.RenderStepped:Connect(function()
					if not target or not root or not target.Parent or not root.Parent then return end
					local lift = MARKER_HEIGHT + target.Size.Y / 2 + math.sin(os.clock() * BOB_SPEED) * BOB_STUDS
					marker.StudsOffsetWorldSpace = Vector3.new(0, lift, 0)
					local flat = Vector3.new(target.Position.X - root.Position.X, 0, target.Position.Z - root.Position.Z)
					beam.Enabled = flat.Magnitude > GUIDE_HIDE_DISTANCE
				end)
			end
		else
			beam.Enabled = false
			marker.Enabled = false
			marker.Adornee = nil
			startAttachment.Parent = nil
			endAttachment.Parent = nil
			if bobConnection then
				bobConnection:Disconnect()
				bobConnection = nil
			end
		end
	end

	function view.Destroy()
		view.SetGuide(nil, nil)
		guideFolder:Destroy()
		marker:Destroy()
		screen:Destroy()
	end

	return view
end

return TutorialView
