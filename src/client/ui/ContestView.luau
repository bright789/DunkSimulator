-- Dunk Contest UI: a countdown/live banner at the top, the judges' scorecard after each
-- judged dunk (right side), and the round results podium. Display only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local UI = require(script.Parent.UIComponents)

local ContestView = {}

local function limit(object: GuiObject, width: number, height: number)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(width, height)
	constraint.Parent = object
end

local function fade(group: CanvasGroup, visible: boolean, seconds: number?)
	if visible then group.Visible = true end
	local tween = TweenService:Create(group, TweenInfo.new(seconds or 0.25), { GroupTransparency = visible and 0 or 1 })
	if not visible then
		tween.Completed:Once(function()
			if group.GroupTransparency >= 0.99 then group.Visible = false end
		end)
	end
	tween:Play()
end

local function group(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2)
	local frame = Instance.new("CanvasGroup")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor
	frame.Visible = false
	frame.GroupTransparency = 1
	UI.StylePanel(frame)
	frame.Parent = parent
	return frame
end

function ContestView.new(playerGui: PlayerGui)
	local screen = UI.Screen("Contest", 8)

	-- Banner: countdown before a round, live timer / your best / leader during it.
	local banner = group(screen, "Banner", UDim2.fromScale(0.5, 0.075), UDim2.fromScale(0.5, 0.012), Vector2.new(0.5, 0))
	limit(banner, 470, 60)
	local bannerTitle = UI.Label(banner, "Title", "", UDim2.fromScale(0.94, 0.5), UDim2.fromScale(0.03, 0.06), 20)
	bannerTitle.Font = Config.BoldFont
	bannerTitle.TextColor3 = Config.Colors.Gold
	bannerTitle.TextXAlignment = Enum.TextXAlignment.Center
	local bannerDetail = UI.Label(banner, "Detail", "", UDim2.fromScale(0.94, 0.36), UDim2.fromScale(0.03, 0.58), 13)
	bannerDetail.TextXAlignment = Enum.TextXAlignment.Center

	-- Judges' scorecard.
	local card = group(screen, "Scorecard", UDim2.fromScale(0.26, 0.2), UDim2.new(0.985, 0, 0.3, 0), Vector2.new(1, 0))
	limit(card, 290, 150)
	local cardTitle = UI.Label(card, "Title", "JUDGES", UDim2.fromScale(0.9, 0.18), UDim2.fromScale(0.05, 0.05), 15)
	cardTitle.Font = Config.BoldFont
	cardTitle.TextColor3 = Config.Colors.Accent
	cardTitle.TextXAlignment = Enum.TextXAlignment.Center
	local tiles = {}
	for index = 1, 5 do
		local tile = Instance.new("Frame")
		tile.Name = "Judge" .. index
		tile.Size = UDim2.fromScale(0.16, 0.36)
		tile.Position = UDim2.fromScale(0.04 + (index - 1) * 0.186, 0.27)
		tile.BackgroundColor3 = Config.Colors.Inset
		tile.BorderSizePixel = 0
		UI.Round(tile, 6)
		tile.Parent = card
		local number = UI.Label(tile, "Score", "", UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.05, 0.05), 26)
		number.Font = Config.BoldFont
		number.TextXAlignment = Enum.TextXAlignment.Center
		tiles[index] = { Frame = tile, Score = number }
	end
	local total = UI.Label(card, "Total", "", UDim2.fromScale(0.9, 0.24), UDim2.fromScale(0.05, 0.7), 22)
	total.Font = Config.BoldFont
	total.TextXAlignment = Enum.TextXAlignment.Center

	-- Results podium.
	local results = group(screen, "Results", UDim2.fromScale(0.62, 0.5), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	limit(results, 400, 300)
	local resultsTitle = UI.Label(results, "Title", "DUNK CONTEST RESULTS", UDim2.fromScale(0.8, 0.13), UDim2.fromScale(0.05, 0.04), 22)
	resultsTitle.Font = Config.BoldFont
	resultsTitle.TextColor3 = Config.Colors.Gold
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromScale(0.09, 0.12)
	close.Position = UDim2.fromScale(0.87, 0.04)
	close.Text = "X"
	close.Font = Config.BoldFont
	close.TextColor3 = Config.Colors.Text
	close.BackgroundColor3 = Config.Colors.Button
	close.BorderSizePixel = 0
	UI.Round(close, 8)
	UI.FitText(close, 13)
	close.Parent = results
	UI.Interactive(close)
	local podium = {}
	local medals = { Config.Colors.Gold, Color3.fromRGB(214, 224, 240), Color3.fromRGB(230, 150, 90) }
	for place = 1, 3 do
		local line = UI.Label(results, "Place" .. place, "", UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.2 + (place - 1) * 0.13), 17)
		line.Font = Config.BoldFont
		line.TextColor3 = medals[place]
		podium[place] = line
	end
	local yours = UI.Label(results, "You", "", UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.63), 16)
	yours.Font = Config.BoldFont
	yours.TextXAlignment = Enum.TextXAlignment.Center
	local prize = UI.Label(results, "Prize", "", UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.78), 18)
	prize.Font = Config.BoldFont
	prize.TextColor3 = Config.Colors.Gain
	prize.TextXAlignment = Enum.TextXAlignment.Center
	screen.Parent = playerGui

	local view = { Close = close }
	local cardVersion, resultsVersion = 0, 0

	-- `title`/`detail` = nil hides the banner.
	function view.SetBanner(title: string?, detail: string?, color: Color3?)
		if title then
			bannerTitle.Text = title
			bannerTitle.TextColor3 = color or Config.Colors.Gold
			bannerDetail.Text = detail or ""
			if not banner.Visible or banner.GroupTransparency > 0 then fade(banner, true) end
		elseif banner.Visible and banner.GroupTransparency < 0.5 then
			fade(banner, false)
		end
	end

	-- Reveals the five judge cards one by one; `onCard(index)` runs as each appears.
	function view.ShowScorecard(cards: { number }, sum: number, best: number, newBest: boolean, onCard)
		cardVersion += 1
		local version = cardVersion
		for _, tile in tiles do tile.Score.Text = "" end
		total.Text = ""
		fade(card, true, 0.15)
		task.spawn(function()
			for index, value in cards do
				task.wait(0.22)
				if cardVersion ~= version then return end
				local tile = tiles[index]
				if tile then
					tile.Score.Text = tostring(value)
					tile.Score.TextColor3 = value >= 10 and Config.Colors.Gold or (value >= 8 and Config.Colors.Gain or Config.Colors.Text)
					onCard(index)
				end
			end
			task.wait(0.2)
			if cardVersion ~= version then return end
			total.Text = string.format("%d / 50%s", sum, newBest and "   NEW BEST!" or string.format("   (best %d)", best))
			total.TextColor3 = sum >= 50 and Config.Colors.Gold or (newBest and Config.Colors.Gain or Config.Colors.Text)
			task.wait(3)
			if cardVersion == version then fade(card, false) end
		end)
	end

	function view.ShowResults(podiumRows, mine)
		resultsVersion += 1
		local version = resultsVersion
		for place, line in podium do
			local row = podiumRows[place]
			line.Text = row and string.format("%d.  %s   %d pts", place, tostring(row.Name), row.Score) or ""
		end
		if mine then
			yours.Text = mine.Won and string.format("YOU WON!  %d pts", mine.Score)
				or string.format("YOU: #%d of %d  -  %d pts%s", mine.Rank, mine.Entrants, mine.Score, mine.Tier and ("  (" .. mine.Tier .. ")") or "")
			yours.TextColor3 = mine.Won and Config.Colors.Gold or Config.Colors.Text
			prize.Text = mine.Cash > 0 and ("PRIZE: +$" .. UI.Number(mine.Cash)) or ""
		else
			yours.Text = "Land a dunk during the next contest to enter!"
			yours.TextColor3 = Config.Colors.Muted
			prize.Text = ""
		end
		fade(results, true)
		task.delay(10, function()
			if resultsVersion == version then fade(results, false) end
		end)
	end

	function view.HideResults()
		resultsVersion += 1
		fade(results, false, 0.15)
	end

	function view.Destroy()
		screen:Destroy()
	end

	return view
end

return ContestView
