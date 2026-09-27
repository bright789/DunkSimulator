-- Draws the global leaderboards on the builder-made board panels (CollectionService tag
-- "LeaderboardPanel", attribute "Board") in every gym. The top lists come from the server
-- as JSON attributes on ReplicatedStorage.Leaderboards; this player's own line comes from
-- their stat attributes. Display only.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LeaderboardConfig"))
local HUDConfig = require(ReplicatedStorage.Shared.Config.HUDConfig)

local localPlayer = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("Leaderboards")
local boards: { [BasePart]: any } = {}
local PIXELS = 40
local RANK_COLORS = { Color3.fromRGB(255, 214, 64), Color3.fromRGB(214, 224, 240), Color3.fromRGB(230, 150, 90) }

local function number(value: number): string
	return (string.format("%.0f", value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function label(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, color: Color3, bold: boolean?)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Size = size
	item.Position = position
	item.BackgroundTransparency = 1
	item.Text = text
	item.TextColor3 = color
	item.TextScaled = true
	item.Font = bold and HUDConfig.BoldFont or HUDConfig.Font
	item.TextXAlignment = Enum.TextXAlignment.Left
	local outline = Instance.new("UIStroke")
	outline.Color = HUDConfig.Colors.TextOutline
	outline.Thickness = 2
	outline.Parent = item
	item.Parent = parent
	return item
end

local function build(panel: BasePart, board)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardDisplay"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(panel.Size.X * PIXELS, panel.Size.Y * PIXELS)
	gui.LightInfluence = 0
	gui.MaxDistance = 260
	gui.Parent = panel
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = HUDConfig.Colors.Panel
	background.BorderSizePixel = 0
	background.Parent = gui
	local title = label(background, "Title", board.Title, UDim2.fromScale(0.9, 0.1), UDim2.fromScale(0.05, 0.02), board.Color, true)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local caption = label(background, "Caption", board.Caption, UDim2.fromScale(0.9, 0.045), UDim2.fromScale(0.05, 0.12), HUDConfig.Colors.Muted)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	local rows = {}
	for rank = 1, Config.Size do
		local y = 0.18 + (rank - 1) * 0.066
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.fromScale(0.94, 0.06)
		stripe.Position = UDim2.fromScale(0.03, y)
		stripe.BackgroundColor3 = HUDConfig.Colors.Inset
		stripe.BackgroundTransparency = rank % 2 == 0 and 1 or 0.4
		stripe.BorderSizePixel = 0
		stripe.Parent = background
		local rankColor = RANK_COLORS[rank] or HUDConfig.Colors.Muted
		rows[rank] = {
			Rank = label(stripe, "Rank", "#" .. rank, UDim2.fromScale(0.14, 0.8), UDim2.fromScale(0.02, 0.1), rankColor, true),
			Name = label(stripe, "Name", "", UDim2.fromScale(0.52, 0.8), UDim2.fromScale(0.17, 0.1), HUDConfig.Colors.Text),
			Value = label(stripe, "Value", "", UDim2.fromScale(0.28, 0.8), UDim2.fromScale(0.7, 0.1), board.Color, true),
		}
		rows[rank].Value.TextXAlignment = Enum.TextXAlignment.Right
	end
	local you = label(background, "You", "", UDim2.fromScale(0.9, 0.08), UDim2.fromScale(0.05, 0.9), HUDConfig.Colors.Gold, true)
	you.TextXAlignment = Enum.TextXAlignment.Center
	return { Gui = gui, Rows = rows, You = you, Board = board }
end

local function render(display)
	local board = display.Board
	local raw = folder:GetAttribute(board.Id)
	local ok, list = pcall(HttpService.JSONDecode, HttpService, typeof(raw) == "string" and raw or "[]")
	if not ok or type(list) ~= "table" then list = {} end
	local myRank = nil
	for rank, row in display.Rows do
		local entry = list[rank]
		row.Name.Text = entry and tostring(entry.Name) or (rank == 1 and "Be the first!" or "")
		row.Value.Text = entry and (board.Prefix .. number(entry.Value)) or ""
		local mine = entry and entry.UserId == localPlayer.UserId
		if mine then myRank = rank end
		row.Name.TextColor3 = mine and HUDConfig.Colors.Gain or HUDConfig.Colors.Text
	end
	local myValue = localPlayer:GetAttribute(board.Stat)
	display.You.Text = typeof(myValue) == "number"
		and string.format("YOU: %s%s%s", board.Prefix, number(myValue), myRank and ("  (#" .. myRank .. ")") or "")
		or ""
end

local function renderAll()
	for _, display in boards do render(display) end
end

local function add(panel: Instance)
	if not panel:IsA("BasePart") or boards[panel] then return end
	local board = Config.Get(panel:GetAttribute("Board"))
	if not board then return end
	boards[panel] = build(panel, board)
	render(boards[panel])
end

local function remove(panel: Instance)
	local display = boards[panel :: BasePart]
	if display then
		display.Gui:Destroy()
		boards[panel :: BasePart] = nil
	end
end

CollectionService:GetInstanceAddedSignal(Config.PanelTag):Connect(add)
CollectionService:GetInstanceRemovedSignal(Config.PanelTag):Connect(remove)
for _, panel in CollectionService:GetTagged(Config.PanelTag) do add(panel) end
folder.AttributeChanged:Connect(renderAll)
for _, board in Config.Boards do
	localPlayer:GetAttributeChangedSignal(board.Stat):Connect(renderAll)
end
