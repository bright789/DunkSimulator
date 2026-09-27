-- Locker menu: SHOES and BALLS tabs with a card per item (color preview, name, bonus, and
-- a BUY / EQUIP / EQUIPPED button), plus a PASSES tab for Robux game passes and the Cash
-- Boost product. Display only; the server decides everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Locker = require(ReplicatedStorage.Shared.Config.LockerConfig)
local Monetization = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local UI = require(script.Parent.UIComponents)

local LockerView = {}

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

local function swatch(parent: Instance, kind: string, item)
	local holder = Instance.new("Frame")
	holder.Name = "Preview"
	holder.Size = UDim2.fromScale(0.9, 0.42)
	holder.Position = UDim2.fromScale(0.05, 0.05)
	holder.BackgroundColor3 = Config.Colors.Panel
	holder.BorderSizePixel = 0
	UI.Round(holder, 8)
	holder.Parent = parent
	if kind == "Shoes" then
		-- A little sneaker: sole, upper, toe and stripe.
		local function block(name, size, position, color)
			local frame = Instance.new("Frame")
			frame.Name = name
			frame.Size = size
			frame.Position = position
			frame.BackgroundColor3 = color
			frame.BorderSizePixel = 0
			UI.Round(frame, 5)
			frame.Parent = holder
			return frame
		end
		block("Upper", UDim2.fromScale(0.5, 0.42), UDim2.fromScale(0.2, 0.25), item.Upper)
		block("Toe", UDim2.fromScale(0.34, 0.26), UDim2.fromScale(0.54, 0.41), item.Upper:Lerp(Color3.new(1, 1, 1), 0.25))
		block("Sole", UDim2.fromScale(0.72, 0.14), UDim2.fromScale(0.17, 0.66), item.Sole)
		block("Stripe", UDim2.fromScale(0.3, 0.08), UDim2.fromScale(0.28, 0.42), item.Accent)
	else
		local ball = Instance.new("Frame")
		ball.Name = "Ball"
		ball.Size = UDim2.fromScale(0.7, 0.7)
		ball.Position = UDim2.fromScale(0.5, 0.5)
		ball.AnchorPoint = Vector2.new(0.5, 0.5)
		ball.BackgroundColor3 = item.Color
		ball.BorderSizePixel = 0
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = ball
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = ball
		local seam = Instance.new("UIStroke")
		seam.Color = item.Seam
		seam.Thickness = 3
		seam.Parent = ball
		local line = Instance.new("Frame")
		line.Size = UDim2.new(0, 3, 1, 0)
		line.Position = UDim2.fromScale(0.5, 0)
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.BackgroundColor3 = item.Seam
		line.BorderSizePixel = 0
		line.Parent = ball
		ball.Parent = holder
	end
end

function LockerView.new(playerGui: PlayerGui)
	local screen = UI.Screen("Locker", 10)
	local panel = UI.Panel(screen, "Menu", UDim2.fromScale(0.88, 0.82), UDim2.fromScale(0.5, 0.5))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 520)
	limit.Parent = panel
	local title = UI.Label(panel, "Title", "LOCKER", UDim2.fromScale(0.4, 0.08), UDim2.fromScale(0.04, 0.03), 24)
	title.Font = Config.BoldFont
	title.TextColor3 = Config.Colors.Gold
	local cash = UI.Label(panel, "Cash", "", UDim2.fromScale(0.34, 0.06), UDim2.fromScale(0.5, 0.04), 15)
	cash.TextXAlignment = Enum.TextXAlignment.Right
	cash.TextColor3 = Config.Colors.Gain
	local close = button(panel, "Close", "X", UDim2.fromScale(0.07, 0.07), UDim2.fromScale(0.9, 0.03))
	local tabs = {}
	for index, kind in { "Shoes", "Balls", "Passes" } do
		tabs[kind] = button(panel, kind .. "Tab", kind:upper(),
			UDim2.fromScale(0.16, 0.065), UDim2.fromScale(0.04 + (index - 1) * 0.175, 0.13), 14)
	end
	local note = UI.Label(panel, "Note", "", UDim2.fromScale(0.4, 0.05), UDim2.fromScale(0.56, 0.14), 11)
	note.TextXAlignment = Enum.TextXAlignment.Right
	note.TextColor3 = Config.Colors.Muted
	local pages, cards = {}, {}
	-- Canvas height follows the grid's real content height (AutomaticCanvasSize doesn't track
	-- UIGridLayout reliably), with a visible scrollbar so players can tell there's more.
	local function scrollable(page: ScrollingFrame, grid: UIGridLayout)
		page.AutomaticCanvasSize = Enum.AutomaticSize.None
		page.ScrollingDirection = Enum.ScrollingDirection.Y
		page.ScrollBarThickness = 8
		page.ScrollBarImageColor3 = Config.Colors.Accent
		page.ScrollBarImageTransparency = 0.2
		page.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
		local function fit()
			page.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + 12)
		end
		grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
		fit()
	end
	for _, kind in Locker.Kinds do
		local page = Instance.new("ScrollingFrame")
		page.Name = kind
		page.Size = UDim2.fromScale(0.92, 0.7)
		page.Position = UDim2.fromScale(0.04, 0.22)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = 4
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.CanvasSize = UDim2.new()
		page.Parent = panel
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0.31, 0, 0, 150)
		grid.CellPadding = UDim2.new(0.02, 0, 0, 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = page
		scrollable(page, grid)
		pages[kind] = page
		cards[kind] = {}
		for order, item in Locker[kind] do
			local card = UI.Panel(page, item.Id, UDim2.new(), UDim2.new())
			card.LayoutOrder = order
			card.BackgroundColor3 = Config.Colors.Inset
			swatch(card, kind, item)
			local name = UI.Label(card, "Name", item.Name:upper(), UDim2.fromScale(0.9, 0.13), UDim2.fromScale(0.05, 0.5), 13)
			name.Font = Config.BoldFont
			name.TextXAlignment = Enum.TextXAlignment.Center
			local perk = UI.Label(card, "Perk", kind == "Shoes" and (item.TrickBonus > 0
				and string.format("+%d%% air-trick Cash", math.floor(item.TrickBonus * 100 + 0.5)) or "No bonus")
				or "Ball skin + slam trail", UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.64), 10)
			perk.TextXAlignment = Enum.TextXAlignment.Center
			perk.TextColor3 = item.TrickBonus and item.TrickBonus > 0 and Config.Colors.Gain or Config.Colors.Muted
			local action = button(card, "Action", "", UDim2.fromScale(0.86, 0.18), UDim2.fromScale(0.07, 0.78), 13)
			cards[kind][item.Id] = { Button = action, Item = item }
		end
	end
	-- Robux passes and products.
	local passPage = Instance.new("ScrollingFrame")
	passPage.Name = "Passes"
	passPage.Size = UDim2.fromScale(0.92, 0.7)
	passPage.Position = UDim2.fromScale(0.04, 0.22)
	passPage.BackgroundTransparency = 1
	passPage.BorderSizePixel = 0
	passPage.ScrollBarThickness = 4
	passPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
	passPage.CanvasSize = UDim2.new()
	passPage.Parent = panel
	local passGrid = Instance.new("UIGridLayout")
	passGrid.CellSize = UDim2.new(0.48, 0, 0, 150)
	passGrid.CellPadding = UDim2.new(0.03, 0, 0, 10)
	passGrid.SortOrder = Enum.SortOrder.LayoutOrder
	passGrid.Parent = passPage
	scrollable(passPage, passGrid)
	pages.Passes = passPage
	local offers = {}
	local order = 0
	for _, list in { { Kind = "Pass", Items = Monetization.Passes }, { Kind = "Product", Items = Monetization.Products } } do
		for _, offer in list.Items do
			order += 1
			local card = UI.Panel(passPage, offer.Key, UDim2.new(), UDim2.new())
			card.LayoutOrder = order
			card.BackgroundColor3 = Config.Colors.Inset
			local icon = UI.Label(card, "Icon", offer.Icon, UDim2.fromScale(0.26, 0.5), UDim2.fromScale(0.04, 0.08), 26)
			icon.Font = Config.BoldFont
			icon.TextColor3 = Config.Colors.Gold
			icon.TextXAlignment = Enum.TextXAlignment.Center
			local name = UI.Label(card, "Name", offer.Name:upper(), UDim2.fromScale(0.64, 0.16), UDim2.fromScale(0.33, 0.08), 15)
			name.Font = Config.BoldFont
			local about = UI.Label(card, "About", offer.Description, UDim2.fromScale(0.64, 0.38), UDim2.fromScale(0.33, 0.26), 11)
			about.TextWrapped = true
			about.TextYAlignment = Enum.TextYAlignment.Top
			about.TextColor3 = Config.Colors.Muted
			local action = button(card, "Action", "", UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.74), 14)
			offers[offer.Key] = { Button = action, Offer = offer, Kind = list.Kind }
		end
	end
	local feedback = UI.Label(panel, "Feedback", "", UDim2.fromScale(0.92, 0.05), UDim2.fromScale(0.04, 0.935), 12)
	feedback.TextXAlignment = Enum.TextXAlignment.Center
	screen.Parent = playerGui

	local view = { Panel = panel, Close = close, Tabs = tabs, Cards = cards, Offers = offers }
	local current = "Shoes"

	function view.SetTab(kind: string)
		current = kind
		for name, page in pages do page.Visible = name == kind end
		for name, tab in tabs do
			tab.BackgroundColor3 = name == kind and Config.Colors.Button or Config.Colors.Inset
		end
		note.Text = kind == "Shoes" and "Everyone sees your sneakers. Bonus applies to air tricks."
			or (kind == "Balls" and "Your ball's look and slam trail, seen by everyone."
				or "Robux passes and boosts. Prices come from Roblox.")
	end

	-- `snapshot` = { Locker, Cash } from the server; `pending` = "Kind:Id" being processed.
	function view.Render(snapshot, pending: string?)
		cash.Text = snapshot and ("$" .. UI.Number(snapshot.Cash)) or ""
		for kind, list in cards do
			local state = snapshot and snapshot.Locker[kind]
			for itemId, card in list do
				local owned = state and state.Owned[itemId] == true
				local equipped = state and state.Equipped == itemId
				local waiting = pending == kind .. ":" .. itemId
				local control = card.Button
				local passItem = card.Item.Pass
				control.Text = not state and "..." or (waiting and "WAIT" or (equipped and "EQUIPPED"
					or (owned and "EQUIP" or (passItem and (passItem .. " PASS") or ("$" .. UI.Number(card.Item.Price))))))
				local passOnSale = passItem ~= nil and (Monetization.GetPass(passItem) or { Id = 0 }).Id ~= 0
				local usable = state ~= nil and not equipped and pending == nil
					and (owned or (passItem and passOnSale) or (not passItem and snapshot.Cash >= card.Item.Price))
				control.Active = usable
				control.AutoButtonColor = usable
				control.BackgroundColor3 = equipped and Config.Colors.Gain or (usable and (owned and Config.Colors.Button
					or Config.Colors.Gold) or Config.Colors.Panel)
				control.TextColor3 = (equipped or (usable and not owned)) and Config.Colors.Panel or Config.Colors.Text
			end
		end
	end

	-- `owned[key]` = pass owned; `prices[key]` = Robux price (nil until known);
	-- `offSale[key]` = created on Roblox but not on sale.
	function view.RenderOffers(owned: { [string]: boolean }, prices: { [string]: number }, offSale: { [string]: boolean })
		for key, entry in offers do
			local control = entry.Button
			local onSale = entry.Offer.Id ~= 0 and not offSale[key]
			local has = entry.Kind == "Pass" and owned[key] == true
			control.Text = has and "OWNED" or (entry.Offer.Id == 0 and "COMING SOON" or (offSale[key] and "OFF SALE"
				or (prices[key] and ("R$ " .. UI.Number(prices[key])) or "BUY")))
			local usable = onSale and not has
			control.Active = usable
			control.AutoButtonColor = usable
			control.BackgroundColor3 = has and Config.Colors.Gain or (usable and Config.Colors.Gold or Config.Colors.Panel)
			control.TextColor3 = (has or usable) and Config.Colors.Panel or Config.Colors.Muted
		end
	end

	function view.Feedback(message: string?, success: boolean?)
		feedback.Text = message or ""
		feedback.TextColor3 = success and Config.Colors.Gain or Config.Colors.Warning
	end

	function view.Current(): string return current end
	function view.Destroy() screen:Destroy() end

	view.SetTab("Shoes")
	return view
end

return LockerView
