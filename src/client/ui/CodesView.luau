-- CODES panel: a text box, a REDEEM button and a result line. Display only; the server
-- checks and pays every code.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local UI = require(script.Parent.UIComponents)

local CodesView = {}

function CodesView.new(playerGui: PlayerGui)
	local screen = UI.Screen("Codes", 10)
	local panel = UI.Panel(screen, "Menu", UDim2.fromScale(0.7, 0.42), UDim2.fromScale(0.5, 0.5))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(380, 230)
	constraint.MinSize = Vector2.new(260, 180)
	constraint.Parent = panel
	local title = UI.Label(panel, "Title", "CODES", UDim2.fromScale(0.7, 0.16), UDim2.fromScale(0.06, 0.05), 24)
	title.Font = Config.BoldFont
	title.TextColor3 = Config.Colors.Gold
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromScale(0.09, 0.15)
	close.Position = UDim2.fromScale(0.87, 0.05)
	close.Text = "X"
	close.Font = Config.BoldFont
	close.TextColor3 = Config.Colors.Text
	close.BackgroundColor3 = Config.Colors.Button
	close.BorderSizePixel = 0
	UI.Round(close, 8)
	UI.FitText(close, 13)
	close.Parent = panel
	UI.Interactive(close)
	local hint = UI.Label(panel, "Hint", "Find codes in our group, updates and videos!",
		UDim2.fromScale(0.88, 0.12), UDim2.fromScale(0.06, 0.23), 12)
	hint.TextColor3 = Config.Colors.Muted
	local box = Instance.new("TextBox")
	box.Name = "CodeBox"
	box.Size = UDim2.fromScale(0.58, 0.22)
	box.Position = UDim2.fromScale(0.06, 0.42)
	box.BackgroundColor3 = Config.Colors.Inset
	box.BorderSizePixel = 0
	box.PlaceholderText = "Enter code"
	box.PlaceholderColor3 = Config.Colors.Muted
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Font = Config.BoldFont
	box.TextColor3 = Config.Colors.Text
	UI.Round(box, 8)
	UI.FitText(box, 18)
	box.Parent = panel
	local redeem = Instance.new("TextButton")
	redeem.Name = "Redeem"
	redeem.Size = UDim2.fromScale(0.28, 0.22)
	redeem.Position = UDim2.fromScale(0.66, 0.42)
	redeem.Text = "REDEEM"
	redeem.Font = Config.BoldFont
	redeem.TextColor3 = Config.Colors.Text
	redeem.BackgroundColor3 = Config.Colors.Button
	redeem.BorderSizePixel = 0
	UI.Round(redeem, 8)
	UI.FitText(redeem, 16)
	redeem.Parent = panel
	UI.Interactive(redeem)
	local result = UI.Label(panel, "Result", "", UDim2.fromScale(0.88, 0.2), UDim2.fromScale(0.06, 0.72), 14)
	result.TextWrapped = true
	result.TextXAlignment = Enum.TextXAlignment.Center
	screen.Parent = playerGui

	local view = { Panel = panel, Close = close, Box = box, Redeem = redeem }

	function view.SetBusy(busy: boolean)
		redeem.Text = busy and "..." or "REDEEM"
		redeem.Active = not busy
		redeem.AutoButtonColor = not busy
	end

	function view.ShowResult(ok: boolean, message: string)
		result.Text = message
		result.TextColor3 = ok and Config.Colors.Gain or Config.Colors.Warning
	end

	function view.Destroy()
		screen:Destroy()
	end

	return view
end

return CodesView
