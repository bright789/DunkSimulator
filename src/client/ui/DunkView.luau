local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HUDConfig"))
local Feel = require(ReplicatedStorage.Shared.Config.FeedbackConfig)
local Styles = require(ReplicatedStorage.Shared.Config:WaitForChild("DunkStyles"))
local UI = require(script.Parent:WaitForChild("UIComponents"))

local DunkView = {}

function DunkView.new(playerGui: PlayerGui)
	local screen = UI.Screen("DunkFeedback", 2)
	local hint = Instance.new("CanvasGroup")
	hint.Name = "DunkHint"
	hint.Size = UDim2.fromOffset(142, 40)
	hint.Position = UDim2.fromScale(0.5, 0.94)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Visible = false
	hint.GroupTransparency = 1
	UI.StylePanel(hint)
	hint.Parent = screen
	local key = UI.Label(hint, "Key", "F", UDim2.fromOffset(26, 26), UDim2.fromOffset(8, 7), 16)
	key.Font = Config.BoldFont
	key.TextXAlignment = Enum.TextXAlignment.Center
	key.BackgroundTransparency = 0
	key.BackgroundColor3 = Config.Colors.Inset
	UI.Round(key, 5)
	local action = UI.Label(hint, "Action", "DUNK", UDim2.fromOffset(88, 26), UDim2.fromOffset(44, 7), 15)
	action.Font = Config.BoldFont
	-- Touch screens: a round DUNK button beside Roblox's jump button (it reads SLAM! during
	-- the slam meter). The controller decides when it shows; nothing here sends requests.
	local dunkButton = Instance.new("TextButton")
	dunkButton.Name = "DunkButton"
	dunkButton.AnchorPoint = Vector2.new(1, 0.5)
	dunkButton.BackgroundColor3 = Config.Colors.Warning
	dunkButton.AutoButtonColor = true
	dunkButton.Text = ""
	dunkButton.Visible = false
	dunkButton.ZIndex = 6
	UI.Round(dunkButton, 999)
	local buttonTitle = UI.Label(dunkButton, "Title", "DUNK", UDim2.fromScale(0.78, 0.42), UDim2.fromScale(0.11, 0.29), 40)
	buttonTitle.Font = Config.BoldFont
	buttonTitle.TextXAlignment = Enum.TextXAlignment.Center
	buttonTitle.ZIndex = 7
	local buttonRing = Instance.new("UIStroke")
	buttonRing.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	buttonRing.Color = Config.Colors.Gold
	buttonRing.Thickness = 3
	buttonRing.Parent = dunkButton
	dunkButton.Parent = screen
	local panel = Instance.new("CanvasGroup")
	panel.Name = "DunkResult"
	panel.Size = UDim2.fromScale(0.64, 0.17)
	panel.Position = UDim2.fromScale(0.5, 0.3)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	panel.GroupTransparency = 1
	UI.StylePanel(panel)
	panel.Parent = screen
	local resultScale = Instance.new("UIScale")
	resultScale.Parent = panel
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(320, 100)
	limit.Parent = panel
	local title = UI.Label(panel, "Title", "DUNK!", UDim2.fromScale(0.9, 0.45), UDim2.fromScale(0.05, 0.08), 34)
	title.Font = Config.BoldFont
	title.TextXAlignment = Enum.TextXAlignment.Center
	-- Gold-to-orange sheen on success headings.
	local titleGradient = Instance.new("UIGradient")
	titleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.45, Config.Colors.Gold),
		ColorSequenceKeypoint.new(1, Config.Colors.Warning),
	})
	titleGradient.Rotation = 90
	titleGradient.Parent = title
	local detail = UI.Label(panel, "Detail", "", UDim2.fromScale(0.9, 0.3), UDim2.fromScale(0.05, 0.57), 20)
	detail.TextXAlignment = Enum.TextXAlignment.Center
	-- Air-trick popup: trick name, its Cash and the combo count, re-popping per trick.
	local trickPanel = Instance.new("CanvasGroup")
	trickPanel.Name = "AirTrick"
	trickPanel.Size = UDim2.fromOffset(250, 60)
	trickPanel.Position = UDim2.fromScale(0.5, 0.16)
	trickPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	trickPanel.Visible = false
	trickPanel.GroupTransparency = 1
	UI.StylePanel(trickPanel)
	trickPanel.Parent = screen
	local trickScale = Instance.new("UIScale")
	trickScale.Parent = trickPanel
	local trickName = UI.Label(trickPanel, "Trick", "", UDim2.fromScale(0.92, 0.56), UDim2.fromScale(0.04, 0.04), 28)
	trickName.Font = Config.BoldFont
	trickName.TextXAlignment = Enum.TextXAlignment.Center
	titleGradient:Clone().Parent = trickName
	local trickDetail = UI.Label(trickPanel, "Detail", "", UDim2.fromScale(0.92, 0.34), UDim2.fromScale(0.04, 0.6), 16)
	trickDetail.TextXAlignment = Enum.TextXAlignment.Center
	trickDetail.TextColor3 = Config.Colors.Gain
	-- Perfect-slam meter: the needle sweeps toward the slam line; press (F / RT / click / tap)
	-- when it is inside the gold zone. Zones are sized from DunkRewards.Timing.
	local meter = Instance.new("CanvasGroup")
	meter.Name = "SlamMeter"
	meter.Size = UDim2.fromOffset(330, 62)
	meter.AnchorPoint = Vector2.new(0.5, 1)
	meter.Position = UDim2.new(0.5, 0, 0.94, -48)
	meter.Visible = false
	UI.StylePanel(meter)
	meter.Parent = screen
	local meterCaption = UI.Label(meter, "Caption", "PRESS F TO SLAM!", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 5), 16)
	meterCaption.Font = Config.BoldFont
	meterCaption.TextXAlignment = Enum.TextXAlignment.Center
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, -28, 0, 18)
	track.Position = UDim2.fromOffset(14, 32)
	track.BackgroundColor3 = Config.Colors.Inset
	track.BorderSizePixel = 0
	track.Parent = meter
	UI.Round(track, 9)
	local function zone(name: string, color: Color3, transparency: number): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = transparency
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromScale(0, 1)
		frame.Parent = track
		UI.Round(frame, 6)
		return frame
	end
	local goodZone = zone("Good", Config.Colors.Accent, 0.45)
	local perfectZone = zone("Perfect", Config.Colors.Gold, 0)
	local slamLine = Instance.new("Frame")
	slamLine.Name = "SlamLine"
	slamLine.AnchorPoint = Vector2.new(0.5, 0.5)
	slamLine.Size = UDim2.new(0, 2, 1, 6)
	slamLine.Position = UDim2.fromScale(Feel.SlamMeter.SlamLine, 0.5)
	slamLine.BackgroundColor3 = Config.Colors.Text
	slamLine.BorderSizePixel = 0
	slamLine.Parent = track
	local needle = Instance.new("Frame")
	needle.Name = "Needle"
	needle.AnchorPoint = Vector2.new(0.5, 0.5)
	needle.Size = UDim2.new(0, 6, 1, 12)
	needle.BackgroundColor3 = Config.Colors.Text
	needle.BorderSizePixel = 0
	needle.ZIndex = 3
	needle.Parent = track
	UI.Round(needle, 3)
	local needleStroke = Instance.new("UIStroke")
	needleStroke.Color = Config.Colors.TextOutline
	needleStroke.Thickness = 1.5
	needleStroke.Parent = needle
	local meterButton = Instance.new("TextButton")
	meterButton.Name = "Tap"
	meterButton.BackgroundTransparency = 1
	meterButton.Text = ""
	meterButton.Size = UDim2.fromScale(1, 1)
	meterButton.ZIndex = 5
	meterButton.Parent = meter
	-- Big rating call ("PERFECT!") that pops above the meter when you press.
	local call = UI.Label(screen, "SlamCall", "", UDim2.fromOffset(360, 56), UDim2.new(0.5, -180, 0.94, -170), 44)
	call.Font = Config.BoldFont
	call.TextXAlignment = Enum.TextXAlignment.Center
	call.Visible = false
	local callScale = Instance.new("UIScale")
	callScale.Parent = call
	screen.Parent = playerGui
	local view = { Hint = hint, Result = panel, MeterButton = meterButton, DunkButton = dunkButton }

	-- Mirrors Roblox's touch jump button layout (small phones vs. bigger screens) so the
	-- DUNK button sits just left of it, level with its centre.
	local function placeDunkButton()
		local size = screen.AbsoluteSize
		local small = math.min(size.X, size.Y) <= 500
		local diameter = small and 64 or 96
		dunkButton.Size = UDim2.fromOffset(diameter, diameter)
		dunkButton.Position = small and UDim2.new(1, -105, 1, -55) or UDim2.new(1, -185, 1, -150)
	end
	placeDunkButton()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeDunkButton)

	function view.SetDunkButton(visible: boolean, title: string)
		buttonTitle.Text = title
		dunkButton.Visible = visible
	end

	-- The key shown in the "F  DUNK" hint (F on keyboard, RT on a gamepad).
	function view.SetHintKey(text: string)
		key.Text = text
	end
	local hintTween = nil
	local resultTween = nil
	local scaleTween = nil
	local hintVersion = 0
	local hintTarget = false
	local resultVersion = 0
	local trickVersion = 0
	local trickTween = nil
	local meterSpan = 1
	local callVersion = 0
	local hintPosition = UDim2.fromScale(0.5, 0.94)
	local hiddenHintPosition = UDim2.new(0.5, 0, 0.94, Feel.Hint.SlidePixels)
	local resultPosition = UDim2.fromScale(0.5, 0.3)

	local function cancel(tween)
		if tween then tween:Cancel(); tween:Destroy() end
	end

	function view.SetHint(visible: boolean, instant: boolean?)
		if not instant and hintTarget == visible then return end
		hintTarget = visible
		hintVersion += 1
		local version = hintVersion
		cancel(hintTween)
		hintTween = nil
		if instant then
			hint.Visible = visible
			hint.GroupTransparency = visible and 0 or 1
			hint.Position = hintPosition
			return
		end
		if visible and not hint.Visible then
			hint.GroupTransparency = 1
			hint.Position = hiddenHintPosition
		end
		hint.Visible = true
		local tween = TweenService:Create(hint,
			TweenInfo.new(Feel.Hint.FadeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = visible and 0 or 1, Position = visible and hintPosition or hiddenHintPosition })
		hintTween = tween
		tween.Completed:Connect(function()
			if hintVersion == version then hint.Visible = visible; hintTween = nil end
			tween:Destroy()
		end)
		tween:Play()
	end

	-- Time → bar position: the slam happens at SlamLine, so the bar spans total / SlamLine.
	local function barX(seconds: number): number
		return math.clamp(seconds / meterSpan, 0, 1)
	end

	function view.SetMeterTotal(totalSeconds: number, timing)
		meterSpan = math.max(totalSeconds, 0.05) / Feel.SlamMeter.SlamLine
		local slam = Feel.SlamMeter.SlamLine
		local function place(frame: Frame, early: number, late: number)
			local left = math.max(slam - early / meterSpan, 0)
			local right = math.min(slam + late / meterSpan, 1)
			frame.Position = UDim2.fromScale(left, 0)
			frame.Size = UDim2.fromScale(right - left, 1)
		end
		place(goodZone, timing.GoodEarlySeconds, timing.GoodLateSeconds)
		place(perfectZone, timing.PerfectEarlySeconds, timing.PerfectLateSeconds)
	end

	function view.StartMeter(totalSeconds: number, timing, caption: string)
		view.SetMeterTotal(totalSeconds, timing)
		meterCaption.Text = caption
		meterCaption.TextColor3 = Config.Colors.Text
		needle.BackgroundColor3 = Config.Colors.Text
		needle.Position = UDim2.fromScale(0, 0.5)
		meter.GroupTransparency = 0
		meter.Visible = true
	end

	function view.UpdateMeter(elapsed: number)
		needle.Position = UDim2.fromScale(barX(elapsed), 0.5)
	end

	-- Freezes the needle and calls the (local) rating; the server's rating decides the Cash.
	function view.MeterPressed(elapsed: number, rating: string)
		needle.Position = UDim2.fromScale(barX(elapsed), 0.5)
		local color = rating == "Perfect" and Config.Colors.Gold or rating == "Good" and Config.Colors.Accent
			or Config.Colors.Muted
		needle.BackgroundColor3 = color
		meterCaption.Text = rating:upper() .. (rating == "Perfect" and "!" or "")
		meterCaption.TextColor3 = color
		callVersion += 1
		local version = callVersion
		call.Text = rating == "Perfect" and "PERFECT!" or rating == "Good" and "GOOD!" or rating:upper()
		call.TextColor3 = color
		call.Visible = true
		call.TextTransparency = 0
		local outline = call:FindFirstChild("TextOutline")
		if outline then outline.Transparency = Config.Style.TextOutlineTransparency end
		callScale.Scale = Feel.SlamMeter.CallPopScale
		TweenService:Create(callScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(Feel.SlamMeter.CallHoldSeconds, function()
			if callVersion ~= version then return end
			if outline then TweenService:Create(outline, TweenInfo.new(0.25), { Transparency = 1 }):Play() end
			local fade = TweenService:Create(call, TweenInfo.new(0.25), { TextTransparency = 1 })
			fade.Completed:Once(function() if callVersion == version then call.Visible = false end end)
			fade:Play()
		end)
	end

	function view.HideMeter()
		meter.Visible = false
	end

	function view.ShowTrick(displayName: string, cash: number, comboIndex: number, comboSize: number)
		trickVersion += 1
		local version = trickVersion
		cancel(trickTween)
		trickName.Text = displayName .. "!"
		trickDetail.Text = "+$" .. UI.Number(cash)
			.. (comboSize > 1 and string.format("   COMBO %d/%d", comboIndex, comboSize) or "")
		trickPanel.Visible = true
		trickPanel.GroupTransparency = 0
		trickScale.Scale = Feel.Dunk.TrickPopStartScale
		trickTween = TweenService:Create(trickScale,
			TweenInfo.new(Feel.Dunk.TrickPopSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		trickTween:Play()
		task.delay(Feel.Dunk.TrickHoldSeconds, function()
			if trickVersion ~= version then return end
			local fade = TweenService:Create(trickPanel, TweenInfo.new(Feel.Dunk.TrickFadeSeconds), { GroupTransparency = 1 })
			fade.Completed:Connect(function()
				if trickVersion == version then trickPanel.Visible = false end
				fade:Destroy()
			end)
			fade:Play()
		end)
	end

	function view.ShowResult(cashReward, rejectionReason: string?, styleId: string?, trickCash: number?, rating: string?)
		resultVersion += 1
		cancel(resultTween)
		cancel(scaleTween)
		local success = typeof(cashReward) == "number"
		local style = Styles.Get(styleId)
		local intensity = Feel.Dunk.Styles[styleId] and Feel.Dunk.Styles[styleId].ImpactIntensity or 0.7
		local successHeading = style and (style.SuccessHeading or style.DisplayName:upper() .. "!") or "DUNK!"
		if rating == "Perfect" then successHeading = "PERFECT " .. successHeading end
		title.Text = success and successHeading or (rejectionReason or "Dunk unavailable.")
		title.Size = success and UDim2.fromScale(0.9, 0.45) or UDim2.fromScale(0.9, 0.84)
		title.TextWrapped = not success
		title.TextColor3 = success and Config.Colors.Text or Config.Colors.Muted
		titleGradient.Enabled = success
		title.Font = success and Config.BoldFont or Config.Font
		detail.Visible = success
		if success then
			detail.Text = "+$" .. UI.Number(cashReward)
				.. ((rating == "Perfect" or rating == "Good") and ("  " .. rating:upper()) or "")
				.. ((typeof(trickCash) == "number" and trickCash > 0) and ("   (+$" .. UI.Number(trickCash) .. " AIR)") or "")
			detail.TextColor3 = Config.Colors.Gain
		end
		panel.GroupTransparency = 1
		panel.Position = UDim2.new(0.5, 0, 0.3, Feel.Dunk.PopupRisePixels)
		-- Successful dunks pop in oversized and snap back with a bounce.
		resultScale.Scale = success and (Feel.Dunk.PopStartScale + math.min(Feel.Dunk.MaxRewardScale - 1,
			0.035 * intensity + cashReward * Feel.Dunk.RewardScalePerCash)) or 1
		panel.Visible = true
		resultTween = TweenService:Create(panel,
			TweenInfo.new(Feel.Dunk.PopupInSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = 0, Position = resultPosition })
		scaleTween = TweenService:Create(resultScale,
			TweenInfo.new(Feel.Dunk.PopupInSeconds * (success and Feel.Dunk.PopBounceLength or 1),
				success and Enum.EasingStyle.Back or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
		resultTween:Play()
		scaleTween:Play()
	end

	function view.HideResult(instant: boolean?)
		resultVersion += 1
		local version = resultVersion
		cancel(resultTween)
		cancel(scaleTween)
		resultTween = nil
		scaleTween = nil
		if instant then panel.Visible = false; panel.GroupTransparency = 1; return end
		local tween = TweenService:Create(panel,
			TweenInfo.new(Feel.Dunk.PopupOutSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.3, -Feel.Dunk.PopupRisePixels) })
		resultTween = tween
		tween.Completed:Connect(function()
			if resultVersion == version then panel.Visible = false; resultTween = nil end
			tween:Destroy()
		end)
		tween:Play()
	end

	function view.Destroy()
		cancel(trickTween)
		cancel(hintTween)
		cancel(resultTween)
		cancel(scaleTween)
		screen:Destroy()
	end

	return view
end

return DunkView
