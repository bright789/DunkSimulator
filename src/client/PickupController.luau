-- Court pickups on this client (PickupConfig; the server decides and pays everything):
--   Cash bills: after each of your dunks the server sends a few drops. They burst out of the
--     rim, land around the hoop, fly to you inside MagnetRadius, and ask the server to
--     collect ("Collect", id) when they reach you. CASH RAIN bills ("Rain") fall from the sky
--     around you instead.
--   Golden Ball: an announcement and a gold beam from you to the ball while it's up; the
--     server tells everyone on the court who grabbed it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.PickupConfig)
local HUDConfig = require(ReplicatedStorage.Shared.Config.HUDConfig)
local UI = require(script.Parent.ui:WaitForChild("UIComponents"))
local ActionFeed = require(script.Parent:WaitForChild("ActionFeed"))
local Feedback = require(script.Parent:WaitForChild("FeedbackController"))
local DunkVFX = require(script.Parent:WaitForChild("DunkVFX"))

local PickupController = {}

local function makeBill(position: Vector3): BasePart
	local bill = Instance.new("Part")
	bill.Name = "CashBill"
	bill.Size = Vector3.new(1.6, 0.12, 0.8)
	bill.Color = Config.Bills.Color
	bill.Material = Enum.Material.SmoothPlastic
	bill.Anchored = true
	bill.CanCollide = false
	bill.CanQuery = false
	bill.CanTouch = false
	bill.CastShadow = false
	bill.CFrame = CFrame.new(position)
	local face = Instance.new("SurfaceGui")
	face.Face = Enum.NormalId.Top
	face.CanvasSize = Vector2.new(80, 40)
	local mark = Instance.new("TextLabel")
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromScale(1, 1)
	mark.Text = "$"
	mark.TextScaled = true
	mark.Font = Enum.Font.FredokaOne
	mark.TextColor3 = Color3.fromRGB(20, 90, 30)
	mark.Parent = face
	face.Parent = bill
	return bill
end

function PickupController.new(player: Player)
	local remote = ReplicatedStorage.Remotes:WaitForChild("PickupEvent")
	local connections = {}
	local folder = Instance.new("Folder")
	folder.Name = "LocalPickups"
	folder.Parent = Workspace
	-- id -> { Part, Spawned, Collecting }
	local bills: { [number]: { Part: BasePart, Spawned: number, Collecting: boolean } } = {}
	local beam: Beam? = nil
	local beamEnd: Attachment? = nil
	local beamStart: Attachment? = nil
	local ballHome: { [BasePart]: Vector3 } = {}

	local function clearBeam()
		if beam then beam:Destroy() end
		if beamEnd then beamEnd:Destroy() end
		if beamStart then beamStart:Destroy() end
		beam, beamEnd, beamStart = nil, nil, nil
	end

	local function pointAt(ball: BasePart)
		clearBeam()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local from = Instance.new("Attachment")
		from.Name = "LocalGoldenBeam"
		from.Parent = root
		local to = Instance.new("Attachment")
		to.Name = "LocalGoldenBeam"
		to.Parent = ball
		local created = Instance.new("Beam")
		created.Attachment0 = from
		created.Attachment1 = to
		created.Color = ColorSequence.new(Config.GoldenBall.Color)
		created.Transparency = NumberSequence.new(0.35, 0.75)
		created.Width0 = 0.35
		created.Width1 = 0.9
		created.FaceCamera = true
		created.LightEmission = 1
		created.Parent = from
		beam, beamStart, beamEnd = created, from, to
	end

	-- The server's ball can take a moment to stream in; find the one on your court.
	local function findBall(): BasePart?
		local balls = Workspace:FindFirstChild("GoldenBalls")
		if not balls then return nil end
		for _, ball in balls:GetChildren() do
			if ball:IsA("BasePart") and ball:GetAttribute("Court") == player:GetAttribute("CurrentCourt") then return ball end
		end
		return nil
	end

	table.insert(connections, remote.OnClientEvent:Connect(function(kind, a, b, c, d)
		if kind == "Bills" and type(a) == "table" then
			local rain = b == "Rain"
			local rim = not rain and DunkVFX.FindRim(player) or nil
			local from = rim and rim.Position or nil
			for _, drop in a do
				if type(drop) == "table" and type(drop.Id) == "number" and typeof(drop.Position) == "Vector3" then
					local bill = makeBill(rain and drop.Position + Vector3.new(0, 30, 0) or from or drop.Position)
					bill.Parent = folder
					-- Rain bills take longer to land, so they start flying to you a little later.
					bills[drop.Id] = { Part = bill, Spawned = os.clock() + (rain and 0.4 or 0), Collecting = false }
					-- Burst out of the rim (or fall from the sky) and land where the server put it.
					local landing = CFrame.new(drop.Position) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
					local info = rain and TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						or TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
					TweenService:Create(bill, info, { CFrame = landing }):Play()
				end
			end
		elseif kind == "Collected" and typeof(b) == "number" then
			Feedback.Coin()
			ActionFeed.Add("bills", b, function(amount) return "+$" .. UI.Number(amount) .. " CASH BILLS" end,
				HUDConfig.Colors.Gain, true)
		elseif kind == "GoldenSpawn" then
			ActionFeed.Announce("GOLDEN BALL ON THE COURT!", Config.GoldenBall.Color)
			Feedback.ChallengeReady()
			task.spawn(function()
				for _ = 1, 20 do
					local ball = findBall()
					if ball then pointAt(ball) return end
					task.wait(0.1)
				end
			end)
		elseif kind == "GoldenGrab" and type(a) == "string" and typeof(b) == "number" then
			clearBeam()
			if d == true then
				ActionFeed.Announce("GOLDEN BALL!  +$" .. UI.Number(b), Config.GoldenBall.Color)
				Feedback.DunkUnlock()
			else
				ActionFeed.Push(a .. " grabbed the Golden Ball!", Config.GoldenBall.Color)
			end
		end
	end))

	table.insert(connections, RunService.RenderStepped:Connect(function(deltaTime)
		local now = os.clock()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		for id, bill in bills do
			local part = bill.Part
			if now - bill.Spawned > Config.Bills.LifetimeSeconds or not part.Parent then
				bills[id] = nil
				part:Destroy()
			elseif root and now - bill.Spawned > 0.5 then
				local offset = root.Position - part.Position
				if bill.Collecting or offset.Magnitude <= Config.Bills.MagnetRadius then
					bill.Collecting = true
					local step = math.min(1, deltaTime * 12)
					part.CFrame = CFrame.new(part.Position:Lerp(root.Position, step)) * part.CFrame.Rotation
						* CFrame.Angles(0, deltaTime * 12, 0)
					if (root.Position - part.Position).Magnitude < 2.5 then
						bills[id] = nil
						part:Destroy()
						remote:FireServer("Collect", id)
					end
				else
					part.CFrame = part.CFrame * CFrame.Angles(0, deltaTime * 2, 0)
				end
			end
		end
		-- Golden balls bob and spin (locally; the server's part stays put).
		local balls = Workspace:FindFirstChild("GoldenBalls")
		if balls then
			for _, ball in balls:GetChildren() do
				if ball:IsA("BasePart") then
					local home = ballHome[ball]
					if not home then
						home = ball.Position
						ballHome[ball] = home
					end
					ball.CFrame = CFrame.new(home + Vector3.new(0, math.sin(now * 3) * 0.5, 0)) * CFrame.Angles(0, now * 2, 0)
				end
			end
		end
		for ball in ballHome do
			if not ball.Parent then ballHome[ball] = nil end
		end
		if beamEnd and not (beamEnd.Parent and beamEnd.Parent.Parent) then clearBeam() end
	end))

	local controller = {}
	function controller.Destroy()
		for _, connection in connections do connection:Disconnect() end
		clearBeam()
		folder:Destroy()
	end
	return controller
end

return PickupController
