-- Equipped Hype Crew float behind every player as little trading cards (client-only, reads the
-- replicated "CrewEquipped" attribute). Each card is an invisible anchored part with a
-- BillboardGui (rarity border, icon, name) that eases toward its spot and bobs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Crew = require(ReplicatedStorage.Shared.Config.CrewConfig)

local CrewFollowers = {}
local started = false
local MAX_DISTANCE = 150
-- player -> { Key = "id,id", Cards = { Part } }
local followers: { [Player]: { Key: string, Cards: { BasePart } } } = {}
local folder: Folder? = nil

local function getFolder(): Folder
	if folder and folder.Parent then return folder end
	local created = Instance.new("Folder")
	created.Name = "LocalCrewFollowers"
	created.Parent = Workspace
	folder = created
	return created
end

local function makeCard(memberId: string): BasePart
	local member = Crew.Members[memberId]
	local rarity = Crew.Rarities[member.Rarity]
	local anchor = Instance.new("Part")
	anchor.Name = "Crew_" .. memberId
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(1.5, 2)
	gui.LightInfluence = 0
	gui.MaxDistance = MAX_DISTANCE
	gui.Parent = anchor
	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(18, 24, 52)
	card.BackgroundTransparency = 0.1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = rarity.Color
	stroke.Thickness = 3
	stroke.Parent = card
	card.Parent = gui
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 0.62)
	icon.Position = UDim2.fromScale(0, 0.06)
	icon.TextScaled = true
	icon.Font = Enum.Font.GothamBold
	icon.Text = member.Icon
	icon.Parent = card
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(0.9, 0.22)
	name.Position = UDim2.fromScale(0.05, 0.72)
	name.TextScaled = true
	name.Font = Enum.Font.FredokaOne
	name.Text = member.Name
	name.TextColor3 = rarity.Color
	name.Parent = card
	anchor.Parent = getFolder()
	return anchor
end

local function clear(player: Player)
	local entry = followers[player]
	followers[player] = nil
	if entry then
		for _, card in entry.Cards do card:Destroy() end
	end
end

local function sync(player: Player, root: BasePart?)
	local key = tostring(player:GetAttribute("CrewEquipped") or "")
	local camera = Workspace.CurrentCamera
	local near = root ~= nil and camera ~= nil and (camera.CFrame.Position - root.Position).Magnitude <= MAX_DISTANCE
	if key == "" or not near then
		clear(player)
		return nil
	end
	local entry = followers[player]
	if entry and entry.Key == key then return entry end
	clear(player)
	entry = { Key = key, Cards = {} }
	for memberId in string.gmatch(key, "[^,]+") do
		if Crew.GetMember(memberId) then
			local card = makeCard(memberId)
			card.CFrame = (root :: BasePart).CFrame
			table.insert(entry.Cards, card)
		end
	end
	followers[player] = entry
	return entry
end

function CrewFollowers.Start()
	if started then return end
	started = true
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(function(deltaTime)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local entry = sync(player, root and root:IsA("BasePart") and root or nil)
			if entry and root then
				for index, card in entry.Cards do
					-- Pairs beside the player (left, right, then further out), never straight behind
					-- them where the camera looks, each bobbing a little out of step.
					local side = (index % 2 == 1 and -1 or 1) * (2.8 + math.floor((index - 1) / 2) * 2.2)
					local bob = math.sin(now * 2.4 + index) * 0.3
					local target = root.CFrame * CFrame.new(side, 0.6 + bob, 1.2)
					card.CFrame = card.CFrame:Lerp(CFrame.new(target.Position), math.min(1, deltaTime * 8))
				end
			end
		end
	end)
end

return CrewFollowers
