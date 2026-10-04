-- AFK Practice strip, shown while you stand on an AFK pad:
-- "AFK PRACTICE  •  next reward 1:42  •  prize in 12:10". Display only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config.HUDConfig)
local AfkConfig = require(ReplicatedStorage.Shared.Config.AfkConfig)
local UI = require(script.Parent.UIComponents)

local AfkView = {}

function AfkView.new(playerGui: PlayerGui)
	local screen = UI.Screen("AfkPractice", 4)
	-- Desktop: just above the action feed (bottom centre). Phones: the feed is on the left and
	-- the bottom is busy, so the strip sits a bit lower than the middle of the screen.
	local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	local compact = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		and math.min(viewport.X, viewport.Y) <= 500
	local panel = UI.Panel(screen, "Panel", UDim2.fromOffset(380, 40),
		compact and UDim2.fromScale(0.5, 0.7) or UDim2.new(0.5, 0, 0.94, -262))
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Visible = false
	if compact then
		local shrink = Instance.new("UIScale")
		shrink.Scale = 0.8
		shrink.Parent = panel
	end
	local label = UI.Label(panel, "Text", "", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4), 16)
	label.Font = Config.BoldFont
	label.TextColor3 = AfkConfig.Pad.Color
	label.TextXAlignment = Enum.TextXAlignment.Center
	screen.Parent = playerGui

	local view = {}

	function view.Show(text: string)
		label.Text = text
		panel.Visible = true
	end

	function view.Hide()
		panel.Visible = false
	end

	function view.Destroy()
		screen:Destroy()
	end

	return view
end

return AfkView
