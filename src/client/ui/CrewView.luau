-- HYPE CREW menu: a PACKS page (one card per pack: odds, OPEN / OPEN x3) and a MY CREW page
-- (the collection book: every member, owned ones with stars, bonus and EQUIP), plus the
-- pack-opening reveal (a card that flips to show who you got). Display only. The odds shown
-- are the ones the player really gets (CrewConfig.Odds, with the Lucky Packs pass if owned).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Crew = require(ReplicatedStorage.Shared.Config.CrewConfig)
local UI = require(script.Parent.UIComponents)

local CrewView = {}

local INK = Color3.fromRGB(12, 16, 36)

local function label(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number, center: boolean?)
	local created = UI.Label(parent, name, text, size, position, textSize)
	if center then created.TextXAlignment = Enum.TextXAlignment.Center end
	return created
end

local function button(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number)
	local created = Instance.new("TextButton")
	created.Name = name
	created.Size = size
	created.Position = position
	created.Text = text
	created.Font = Config.BoldFont
	created.TextColor3 = Config.Colors.Text
	created.BackgroundColor3 = Config.Colors.Button
	created.BorderSizePixel = 0
	UI.Round(created, 8)
	UI.FitText(created, textSize)
	created.Parent = parent
	UI.Interactive(created)
	return created
end

local function setEnabled(target: TextButton, enabled: boolean, color: Color3?)
	target.Active = enabled
	target.AutoButtonColor = enabled
	target.BackgroundColor3 = enabled and (color or Config.Colors.Button) or Config.Colors.Inset
	target.TextColor3 = enabled and Config.Colors.Text or Config.Colors.Muted
end

local function stars(count: number): string
	return string.rep("★", count) .. string.rep("☆", Crew.MaxStars - count)
end

-- "60%", or "27.6%" when the chance isn't a whole percent.
local function percent(chance: number): string
	local value = chance * 100
	local whole = math.floor(value + 0.5)
	if math.abs(value - whole) < 0.05 then return string.format("%d%%", whole) end
	return string.format("%.1f%%", value)
end

local function oddsText(entry): string
	return string.format("%s  %s", string.upper(entry.Rarity), percent(entry.Chance))
end

function CrewView.new(playerGui: PlayerGui)
	local screen = UI.Screen("HypeCrew", 10)
	local panel = UI.Panel(screen, "Menu", UDim2.fromScale(0.8, 0.78), UDim2.fromScale(0.5, 0.5))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(640, 440)
	limit.MinSize = Vector2.new(320, 290)
	limit.Parent = panel
	local title = label(panel, "Title", "HYPE CREW", UDim2.fromScale(0.5, 0.09), UDim2.fromScale(0.04, 0.025), 24)
	title.Font = Config.BoldFont
	title.TextColor3 = Config.Colors.Gold
	local close = button(panel, "Close", "X", UDim2.fromScale(0.07, 0.08), UDim2.fromScale(0.9, 0.025), 14)
	local bonus = label(panel, "Bonus", "", UDim2.fromScale(0.92, 0.06), UDim2.fromScale(0.04, 0.115), 13)
	bonus.TextColor3 = Config.Colors.Gain
	local packsTab = button(panel, "PacksTab", "PACKS", UDim2.fromScale(0.22, 0.075), UDim2.fromScale(0.04, 0.19), 14)
	local crewTab = button(panel, "CrewTab", "MY CREW", UDim2.fromScale(0.3, 0.075), UDim2.fromScale(0.28, 0.19), 14)
	local result = label(panel, "Result", "", UDim2.fromScale(0.92, 0.06), UDim2.fromScale(0.04, 0.925), 13, true)

	local function page(name: string, cell: Vector2)
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = name
		scroll.Size = UDim2.fromScale(0.92, 0.64)
		scroll.Position = UDim2.fromScale(0.04, 0.28)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 6
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.CanvasSize = UDim2.new()
		scroll.Parent = panel
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
		grid.CellPadding = UDim2.fromOffset(8, 8)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = scroll
		grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			scroll.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + 8)
		end)
		return scroll
	end
	local packsPage = page("Packs", Vector2.new(138, 190))
	local crewPage = page("Crew", Vector2.new(104, 136))
	crewPage.Visible = false

	-- Pack cards.
	local packCards = {}
	for _, packId in Crew.PackIds() do
		local pack = Crew.Packs[packId]
		local card = Instance.new("Frame")
		card.Name = packId
		card.LayoutOrder = pack.Order
		card.BackgroundColor3 = Config.Colors.Inset
		card.BorderSizePixel = 0
		UI.Round(card, 10)
		local stroke = Instance.new("UIStroke")
		stroke.Color = pack.Color
		stroke.Thickness = 2
		stroke.Parent = card
		card.Parent = packsPage
		local header = Instance.new("Frame")
		header.Size = UDim2.new(1, 0, 0, 34)
		header.BackgroundColor3 = pack.Color
		header.BorderSizePixel = 0
		UI.Round(header, 10)
		header.Parent = card
		label(header, "Name", pack.Name, UDim2.new(1, -8, 1, -6), UDim2.fromOffset(4, 3), 15, true).Font = Config.BoldFont
		-- "ODDS", or "LUCKY ODDS" for Lucky Packs pass owners (SetPack updates both).
		local oddsTitle = label(card, "OddsTitle", "ODDS", UDim2.new(1, -16, 0, 14), UDim2.fromOffset(8, 37), 11)
		oddsTitle.Font = Config.BoldFont
		oddsTitle.TextColor3 = Config.Colors.Muted
		local odds = {}
		for index, entry in Crew.Odds(packId, false) do
			local line = label(card, "Odds" .. index, oddsText(entry), UDim2.new(1, -16, 0, 15), UDim2.fromOffset(8, 52 + (index - 1) * 16), 12)
			line.TextColor3 = Crew.Rarities[entry.Rarity].Color
			odds[entry.Rarity] = line
		end
		local open = button(card, "Open", "", UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 1, -72), 14)
		local openThree = button(card, "OpenThree", "", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 1, -36), 12)
		packCards[packId] = { Open = open, OpenThree = openThree, Odds = odds, OddsTitle = oddsTitle }
	end

	-- Collection book cards.
	local crewCards = {}
	for index, memberId in Crew.MemberIds() do
		local member = Crew.Members[memberId]
		local rarity = Crew.Rarities[member.Rarity]
		local card = Instance.new("Frame")
		card.Name = memberId
		card.LayoutOrder = index
		card.BackgroundColor3 = Config.Colors.Inset
		card.BorderSizePixel = 0
		UI.Round(card, 10)
		local stroke = Instance.new("UIStroke")
		stroke.Color = rarity.Color
		stroke.Thickness = 2
		stroke.Parent = card
		card.Parent = crewPage
		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.new(1, 0, 0, 40)
		icon.Position = UDim2.fromOffset(0, 4)
		icon.TextScaled = true
		icon.Font = Enum.Font.GothamBold
		icon.Text = member.Icon
		icon.Parent = card
		local name = label(card, "Name", member.Name, UDim2.new(1, -8, 0, 16), UDim2.fromOffset(4, 46), 12, true)
		name.Font = Config.BoldFont
		local starLine = label(card, "Stars", "", UDim2.new(1, -8, 0, 14), UDim2.fromOffset(4, 62), 12, true)
		starLine.TextColor3 = Config.Colors.Gold
		local boost = label(card, "Boost", "", UDim2.new(1, -8, 0, 14), UDim2.fromOffset(4, 77), 11, true)
		boost.TextColor3 = rarity.Color
		local action = button(card, "Equip", "EQUIP", UDim2.new(1, -12, 0, 26), UDim2.new(0, 6, 1, -32), 12)
		crewCards[memberId] = { Card = card, Icon = icon, Name = name, Stars = starLine, Boost = boost, Action = action, Stroke = stroke }
	end

	-- Pack-opening reveal: a dim backdrop and one big card at a time. Its own screen above
	-- every menu, so packs from the Dunk Pass reveal on top of that screen too.
	local revealScreen = UI.Screen("CrewReveal", 12)
	local reveal = Instance.new("TextButton")
	reveal.Name = "Reveal"
	reveal.Size = UDim2.fromScale(1, 1)
	reveal.BackgroundColor3 = Color3.new(0, 0, 0)
	reveal.BackgroundTransparency = 0.35
	reveal.Text = ""
	reveal.AutoButtonColor = false
	reveal.Visible = false
	reveal.ZIndex = 20
	reveal.Parent = revealScreen
	local big = Instance.new("Frame")
	big.Name = "Card"
	big.AnchorPoint = Vector2.new(0.5, 0.5)
	big.Position = UDim2.fromScale(0.5, 0.47)
	big.Size = UDim2.fromOffset(210, 290)
	big.BackgroundColor3 = Config.Colors.Panel
	big.BorderSizePixel = 0
	big.ZIndex = 21
	UI.Round(big, 16)
	local bigStroke = Instance.new("UIStroke")
	bigStroke.Thickness = 5
	bigStroke.Parent = big
	local bigScale = Instance.new("UIScale")
	bigScale.Parent = big
	big.Parent = reveal
	local function revealLabel(name: string, size: UDim2, position: UDim2, textSize: number)
		local created = label(big, name, "", size, position, textSize, true)
		created.ZIndex = 22
		created.Font = Config.BoldFont
		return created
	end
	local bigIcon = revealLabel("Icon", UDim2.new(1, 0, 0, 110), UDim2.fromOffset(0, 26), 90)
	bigIcon.Font = Enum.Font.GothamBold
	bigIcon.TextScaled = true
	local bigRarity = revealLabel("Rarity", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 142), 22)
	local bigName = revealLabel("Name", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 170), 20)
	local bigStars = revealLabel("Stars", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 198), 20)
	bigStars.TextColor3 = Config.Colors.Gold
	local bigNote = revealLabel("Note", UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 224), 16)
	local tapHint = label(reveal, "Hint", "TAP TO CONTINUE", UDim2.fromOffset(300, 26), UDim2.new(0.5, -150, 0.47, 160), 16, true)
	tapHint.ZIndex = 22
	screen.Parent = playerGui
	revealScreen.Parent = playerGui

	local view = { Panel = panel, Close = close, PacksTab = packsTab, CrewTab = crewTab, PackCards = packCards,
		CrewCards = crewCards, Reveal = reveal }

	function view.ShowPage(which: string)
		packsPage.Visible = which == "Packs"
		crewPage.Visible = which == "Crew"
		setEnabled(packsTab, which ~= "Packs", Config.Colors.Inset)
		setEnabled(crewTab, which ~= "Crew", Config.Colors.Inset)
		packsTab.TextColor3 = which == "Packs" and Config.Colors.Gold or Config.Colors.Text
		crewTab.TextColor3 = which == "Crew" and Config.Colors.Gold or Config.Colors.Text
	end

	function view.SetHeader(bonusText: string, crewTabText: string)
		bonus.Text = bonusText
		crewTab.Text = crewTabText
	end

	-- `state`: Unlocked, CanAfford, CanAffordThree, HasTriple, CourtName, Lucky (owns Lucky Packs:
	-- show the boosted odds), Restricted (packs aren't available in this player's region).
	function view.SetPack(packId: string, state)
		local card = packCards[packId]
		local pack = Crew.Packs[packId]
		for _, entry in Crew.Odds(packId, state.Lucky) do
			local line = card.Odds[entry.Rarity]
			if line then line.Text = oddsText(entry) end
		end
		card.OddsTitle.Text = state.Lucky and "LUCKY ODDS" or "ODDS"
		card.OddsTitle.TextColor3 = state.Lucky and Config.Colors.Gold or Config.Colors.Muted
		if state.Restricted then
			card.Open.Text = "NOT AVAILABLE"
			setEnabled(card.Open, false)
			card.OpenThree.Text = ""
			card.OpenThree.Visible = false
			return
		end
		if not state.Unlocked then
			card.Open.Text = "UNLOCK " .. string.upper(state.CourtName)
			setEnabled(card.Open, false)
			card.OpenThree.Text = ""
			card.OpenThree.Visible = false
			return
		end
		card.Open.Text = "OPEN  $" .. UI.Number(pack.Price)
		setEnabled(card.Open, state.CanAfford, Config.Colors.Button)
		card.OpenThree.Visible = true
		card.OpenThree.Text = state.HasTriple and ("OPEN x3  $" .. UI.Number(pack.Price * 3)) or "OPEN x3  (PASS)"
		setEnabled(card.OpenThree, state.HasTriple and state.CanAffordThree, Color3.fromRGB(150, 70, 220))
	end

	-- `state`: Stars (nil = not found yet), Equipped, CanEquip.
	function view.SetMember(memberId: string, state)
		local card = crewCards[memberId]
		local member = Crew.Members[memberId]
		local owned = state.Stars ~= nil
		card.Icon.Text = owned and member.Icon or "❔"
		card.Name.Text = owned and member.Name or "???"
		card.Name.TextColor3 = owned and Config.Colors.Text or Config.Colors.Muted
		card.Stars.Text = owned and stars(state.Stars) or string.upper(member.Rarity)
		card.Boost.Text = owned and string.format("+%d%% %s", math.floor(Crew.Bonus(memberId, state.Stars) * 100 + 0.5),
			member.Boost == "Cash" and "CASH" or "TRAINING") or (Crew.Packs[member.Pack].Name)
		card.Action.Visible = owned
		card.Action.Text = state.Equipped and "UNEQUIP" or "EQUIP"
		setEnabled(card.Action, state.Equipped or state.CanEquip, state.Equipped and Color3.fromRGB(200, 70, 90) or Config.Colors.Button)
		card.Card.BackgroundColor3 = state.Equipped and Color3.fromRGB(40, 58, 110) or Config.Colors.Inset
		card.Stroke.Thickness = state.Equipped and 4 or 2
	end

	function view.ShowResult(ok: boolean, message: string)
		result.Text = message
		result.TextColor3 = ok and Config.Colors.Gain or Config.Colors.Warning
	end

	-- One reveal card: flips from the pack's colour to the member.
	function view.RevealCard(packColor: Color3, memberId: string, info)
		local member = Crew.Members[memberId]
		local rarity = Crew.Rarities[member.Rarity]
		reveal.Visible = true
		big.BackgroundColor3 = packColor
		bigStroke.Color = Color3.new(1, 1, 1)
		bigIcon.Text = "❔"
		bigRarity.Text, bigName.Text, bigStars.Text, bigNote.Text = "", "", "", ""
		bigScale.Scale = 0.6
		TweenService:Create(bigScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(0.45, function()
			local squash = TweenService:Create(big, TweenInfo.new(0.12), { Size = UDim2.fromOffset(4, 290) })
			squash:Play()
			squash.Completed:Wait()
			big.BackgroundColor3 = Config.Colors.Panel
			bigStroke.Color = rarity.Color
			bigIcon.Text = member.Icon
			bigRarity.Text = string.upper(member.Rarity) .. "!"
			bigRarity.TextColor3 = rarity.Color
			bigName.Text = member.Name
			bigName.TextColor3 = Config.Colors.Text
			bigStars.Text = stars(info.Stars)
			bigNote.Text = info.New and "NEW CREW MEMBER!" or info.Refund > 0 and ("MAXED: +$" .. UI.Number(info.Refund))
				or "STAR UP!"
			bigNote.TextColor3 = info.New and Config.Colors.Gain or Config.Colors.Gold
			TweenService:Create(big, TweenInfo.new(0.14), { Size = UDim2.fromOffset(210, 290) }):Play()
		end)
	end

	function view.HideReveal()
		reveal.Visible = false
	end

	function view.Destroy()
		screen:Destroy()
		revealScreen:Destroy()
	end

	view.ShowPage("Packs")
	return view
end

return CrewView
