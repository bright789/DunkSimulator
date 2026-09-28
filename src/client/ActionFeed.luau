-- Action feed (bottom centre): a short stacking log of what you just earned or did, e.g.
-- "+2 VERTICAL (x3)", "+$1,240", "HEAT 3! x1.2 CASH". Lines with the same key merge while on
-- screen, so a burst of reps reads as one growing line. Announce() shows a big one-off
-- message in the middle of the screen. Start() watches your Vertical, Cash and HEAT.
-- Display only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local Heat = require(ReplicatedStorage.Shared.Config.HeatConfig)
local UI = require(script.Parent.ui:WaitForChild("UIComponents"))

local ActionFeed = {}

local maxLines = 4
local HOLD_SECONDS = 2.6
local screen: ScreenGui? = nil
local list: Frame? = nil
local banner: TextLabel? = nil
local bannerScale: UIScale? = nil
local lines: { [string]: { Label: TextLabel, Amount: number, Count: number, Expires: number, Format: any } } = {}
local order = 0
local bannerVersion = 0

local function ensure()
	if screen and screen.Parent then return end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local created = UI.Screen("ActionFeed", 4)
	-- Phones: the bottom centre is busy (meter, training ring) and the top has the goal bar,
	-- so the feed goes on the left under the stats, smaller and at most 3 lines.
	local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	local compact = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		and math.min(viewport.X, viewport.Y) <= 500
	maxLines = compact and 3 or 4
	local frame = Instance.new("Frame")
	frame.Name = "Feed"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = compact and Vector2.new(0, 0) or Vector2.new(0.5, 1)
	frame.Position = compact and UDim2.new(0, 12, 0.4, 8) or UDim2.new(0.5, 0, 0.94, -150)
	frame.Size = UDim2.fromOffset(400, 26 * maxLines + 6)
	frame.Parent = created
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = compact and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = compact and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.Parent = frame
	frame:SetAttribute("Compact", compact)
	if compact then
		local shrink = Instance.new("UIScale")
		shrink.Scale = 0.72
		shrink.Parent = frame
	end
	local big = UI.Label(created, "Announce", "", UDim2.fromOffset(620, 64), UDim2.fromScale(0.5, 0.42), 38)
	big.AnchorPoint = Vector2.new(0.5, 0.5)
	big.TextXAlignment = Enum.TextXAlignment.Center
	big.Font = Config.BoldFont
	big.Visible = false
	local scale = Instance.new("UIScale")
	scale.Parent = big
	if compact then big.Size = UDim2.fromOffset(430, 46) end
	created.Parent = playerGui
	screen, list, banner, bannerScale = created, frame, big, scale
end

local function fadeOut(key: string)
	local line = lines[key]
	if not line then return end
	lines[key] = nil
	local label = line.Label
	local outline = label:FindFirstChild("TextOutline")
	if outline then TweenService:Create(outline, TweenInfo.new(0.3), { Transparency = 1 }):Play() end
	local fade = TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 })
	fade.Completed:Once(function() label:Destroy() end)
	fade:Play()
end

local function oldestKey(): string?
	local found, foundOrder = nil, math.huge
	for key, line in lines do
		if line.Label.LayoutOrder < foundOrder then found, foundOrder = key, line.Label.LayoutOrder end
	end
	return found
end

-- Adds `amount` to the line `key` (creating it if needed). `format(amount, count)` builds the
-- text, e.g. function(a) return "+" .. a .. " VERTICAL" end. With `counted`, "(xN)" is
-- appended once N things were merged (e.g. "+$9 CASH BILLS (x3)").
function ActionFeed.Add(key: string, amount: number, format: (number, number) -> string, color: Color3, counted: boolean?)
	ensure()
	local line = lines[key]
	if line then
		line.Amount += amount
		line.Count += 1
	else
		local count = 0
		for _ in lines do count += 1 end
		if count >= maxLines then
			local oldest = oldestKey()
			if oldest then fadeOut(oldest) end
		end
		order += 1
		local label = UI.Label(list :: Frame, "Line", "", UDim2.fromOffset(400, 24), UDim2.new(), 18)
		label.TextXAlignment = (list :: Frame):GetAttribute("Compact") and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
		label.Font = Config.BoldFont
		label.LayoutOrder = order
		local pop = Instance.new("UIScale")
		pop.Parent = label
		line = { Label = label, Amount = amount, Count = 1, Expires = 0, Format = format }
		lines[key] = line
	end
	line.Expires = os.clock() + HOLD_SECONDS
	line.Label.TextColor3 = color
	line.Label.Text = format(line.Amount, line.Count) .. ((counted and line.Count > 1) and string.format("  (x%d)", line.Count) or "")
	local pop = line.Label:FindFirstChildOfClass("UIScale")
	if pop then
		pop.Scale = 1.18
		TweenService:Create(pop, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

-- A one-off line (its own key, never merged).
function ActionFeed.Push(text: string, color: Color3)
	order += 1
	ActionFeed.Add("once" .. order, 0, function() return text end, color)
end

-- Big centre message, e.g. "ON FIRE!" or "GOLDEN BALL! +$4,000".
function ActionFeed.Announce(text: string, color: Color3)
	ensure()
	bannerVersion += 1
	local version = bannerVersion
	local label = banner :: TextLabel
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	label.Visible = true
	local outline = label:FindFirstChild("TextOutline")
	if outline then outline.Transparency = Config.Style.TextOutlineTransparency end
	local scale = bannerScale :: UIScale
	scale.Scale = 0.5
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.6, function()
		if bannerVersion ~= version then return end
		if outline then TweenService:Create(outline, TweenInfo.new(0.35), { Transparency = 1 }):Play() end
		local fade = TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 })
		fade.Completed:Once(function() if bannerVersion == version then label.Visible = false end end)
		fade:Play()
	end)
end

local started = false
-- Watches your own Vertical, Cash and HEAT and feeds them in.
function ActionFeed.Start(player: Player)
	if started then return end
	started = true
	ensure()
	task.spawn(function()
		while true do
			local now = os.clock()
			for key, line in lines do
				if now > line.Expires then fadeOut(key) end
			end
			task.wait(0.1)
		end
	end)
	local stats = player:WaitForChild("leaderstats")
	local vertical = stats:WaitForChild("Vertical") :: IntValue
	local cash = stats:WaitForChild("Cash") :: IntValue
	local lastVertical, lastCash = vertical.Value, cash.Value
	vertical.Changed:Connect(function(value)
		local delta = value - lastVertical
		lastVertical = value
		if delta > 0 then
			ActionFeed.Add("vertical", delta, function(amount) return "+" .. UI.Number(amount) .. " VERTICAL" end, Config.Colors.Accent)
		end
	end)
	cash.Changed:Connect(function(value)
		local delta = value - lastCash
		lastCash = value
		if delta > 0 then
			ActionFeed.Add("cash", delta, function(amount) return "+$" .. UI.Number(amount) end, Config.Colors.Gain)
		elseif delta < 0 then
			ActionFeed.Push("-$" .. UI.Number(-delta), Config.Colors.Warning)
		end
	end)
	player:GetAttributeChangedSignal("Heat"):Connect(function()
		local level = tonumber(player:GetAttribute("Heat"))
		if not level or level < 2 then return end
		local text = string.format("HEAT %d! %s  x%s CASH", level, Heat.Names[level], tostring(Heat.Multipliers[level]))
		ActionFeed.Add("heat" .. level, 0, function() return text end, Heat.Colors[level])
		if level == #Heat.Multipliers then ActionFeed.Announce("ON FIRE!", Heat.Colors[level]) end
	end)
end

return ActionFeed
