-- Dunk impact VFX, client only (numbers and colours live in DunkVFXConfig). Every slam gets
-- its court's theme, and the Perfect-slam meter grade decides how big it is. The dunker's own
-- grade is predicted on the meter press so the boom lands on impact; other players' grades
-- come from the server's SlamRating attribute a moment later. Nothing here talks to the server.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local Styles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local Config = require(ReplicatedStorage.Shared.Config.DunkVFXConfig)
local Abilities = require(ReplicatedStorage.Shared.Config.AbilityConfig)

local DunkVFX = {}
local localPlayer = Players.LocalPlayer
local random = Random.new()
local prediction: string? = nil
local shown: { [Player]: string } = {}
local floors: { [BasePart]: { Base: CFrame, Height: number } } = {}
local folder: Folder? = nil
local started = false

local GOLD = Color3.fromRGB(255, 214, 70)
local INK = Color3.fromRGB(20, 10, 40)

local function getFolder(): Folder
	if folder and folder.Parent then return folder end
	local created = Instance.new("Folder")
	created.Name = "LocalDunkVFX"
	created.Parent = Workspace
	folder = created
	return created
end

-- The logical rim of the court this player is on.
function DunkVFX.FindRim(player: Player): BasePart?
	local court = Courts.Get(player:GetAttribute("CurrentCourt"))
	if not court then return nil end
	local container: Instance? = Workspace
	for _, name in court.GameplayPath do
		container = container and container:FindFirstChild(name)
	end
	local hoop = container and container:FindFirstChild("DunkHoop")
	local rim = hoop and hoop:FindFirstChild("Rim")
	return rim and rim:IsA("BasePart") and rim or nil
end

-- Floor point under the rim, facing out from the backboard toward the court (cached per rim).
local function hoopFloor(rim: BasePart)
	local cached = floors[rim]
	if cached then return cached end
	local hoop = rim.Parent
	local bracket = hoop and hoop:FindFirstChild("RimBracket", true)
	local back = bracket and bracket:IsA("BasePart") and bracket.Position - rim.Position or Vector3.new(0, 0, -1)
	back = Vector3.new(back.X, 0, back.Z)
	back = back.Magnitude > 1e-3 and back.Unit or Vector3.new(0, 0, -1)
	local exclude: { Instance } = { getFolder() }
	if hoop then table.insert(exclude, hoop) end
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(exclude, player.Character) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local floorY = rim.Position.Y - 10
	-- Skip loose things (balls, props) until we hit the anchored floor.
	for _ = 1, 6 do
		params.FilterDescendantsInstances = exclude
		local hit = Workspace:Raycast(rim.Position, Vector3.new(0, -100, 0), params)
		if not hit then break end
		if hit.Instance.Anchored and hit.Instance.CanCollide then
			floorY = hit.Position.Y
			break
		end
		table.insert(exclude, hit.Instance)
	end
	local base = Vector3.new(rim.Position.X, floorY, rim.Position.Z)
	cached = { Base = CFrame.lookAt(base, base - back), Height = rim.Position.Y - floorY }
	floors[rim] = cached
	return cached
end

-- An attachment frame whose up vector (the direction particles fly) points along `direction`.
local function aim(position: Vector3, direction: Vector3?): CFrame
	if not direction or direction.Magnitude < 1e-3 then return CFrame.new(position) end
	local unit = direction.Unit
	if math.abs(unit.Y) > 0.999 then
		return unit.Y > 0 and CFrame.new(position) or CFrame.new(position) * CFrame.Angles(math.pi, 0, 0)
	end
	return CFrame.lookAt(position, position + unit) * CFrame.Angles(-math.pi / 2, 0, 0)
end

-- One burst (or short stream) of particles. `spec` fields:
--   Texture (key in Config.Textures), Colors (one emitter each), Count, Size, Lifetime {min, max},
--   Speed {min, max}, Spread (degrees), and optionally Direction, Drag, Gravity, Spin,
--   EndSize (size multiplier at the end), Grow (start small, end at Size), Flat (lie flat on
--   the floor), Transparency, LightEmission, Fixed (count ignores scale), Rate + Seconds (stream).
local function emit(position: Vector3, spec, scale: number)
	local attachment = Instance.new("Attachment")
	attachment.Name = "LocalDunkVFX"
	attachment.WorldCFrame = aim(position, spec.Direction)
	attachment.Parent = Workspace.Terrain
	local grow = math.sqrt(scale)
	local size = spec.Size * grow
	local fade = spec.Transparency or 0
	for _, color in spec.Colors do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = Config.Textures[spec.Texture]
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = spec.LightEmission or 1
		emitter.Size = spec.Grow
			and NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.15), NumberSequenceKeypoint.new(1, size) })
			or NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * (spec.EndSize or 0)) })
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, fade),
			NumberSequenceKeypoint.new(0.6, math.min(1, fade + 0.2)),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(spec.Lifetime[1], spec.Lifetime[2])
		emitter.Speed = NumberRange.new(spec.Speed[1] * grow, spec.Speed[2] * grow)
		emitter.SpreadAngle = Vector2.new(spec.Spread, spec.Spread)
		emitter.Drag = spec.Drag or 0
		emitter.Acceleration = Vector3.new(0, -(spec.Gravity or 0), 0)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-(spec.Spin or 0), spec.Spin or 0)
		emitter.Orientation = spec.Flat and Enum.ParticleOrientation.VelocityPerpendicular
			or Enum.ParticleOrientation.FacingCamera
		emitter.Parent = attachment
		if spec.Rate then
			emitter.Rate = spec.Rate * scale / #spec.Colors
			task.delay(spec.Seconds or 0.5, function() emitter.Enabled = false end)
		else
			emitter.Rate = 0
			local count = spec.Fixed and spec.Count or spec.Count * scale
			emitter:Emit(math.max(1, math.round(count / #spec.Colors)))
		end
	end
	Debris:AddItem(attachment, (spec.Rate and spec.Seconds or 0) + spec.Lifetime[2] + 0.2)
end

local function light(position: Vector3, color: Color3, brightness: number, range: number, seconds: number)
	local attachment = Instance.new("Attachment")
	attachment.Name = "LocalDunkVFX"
	attachment.WorldPosition = position
	attachment.Parent = Workspace.Terrain
	local point = Instance.new("PointLight")
	point.Color = color
	point.Brightness = brightness
	point.Range = math.min(range, 60)
	point.Shadows = false
	point.Parent = attachment
	TweenService:Create(point, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0 }):Play()
	Debris:AddItem(attachment, seconds + 0.1)
end

-- A jagged neon lightning bolt that thins out and fades.
local function bolt(from: Vector3, to: Vector3, color: Color3, width: number, seconds: number)
	local points = { from }
	local segments = 8
	local jitter = (from - to).Magnitude * 0.06
	for index = 1, segments - 1 do
		local offset = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-0.3, 0.3), random:NextNumber(-1, 1))
		table.insert(points, from:Lerp(to, index / segments) + offset * jitter)
	end
	table.insert(points, to)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local part = Instance.new("Part")
		part.Name = "Bolt"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Size = Vector3.new(width, width, (b - a).Magnitude + width)
		part.CFrame = CFrame.lookAt((a + b) / 2, b)
		part.Parent = getFolder()
		TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Transparency = 1, Size = Vector3.new(width * 0.2, width * 0.2, part.Size.Z) }):Play()
		Debris:AddItem(part, seconds + 0.05)
	end
end

local function confetti(colors: { Color3 }, count: number, direction: Vector3, speed: { number }, spread: number)
	return { Texture = "Square", Colors = colors, Count = count, Size = 0.28, EndSize = 1, Lifetime = { 2, 3.2 },
		Speed = speed, Spread = spread, Gravity = 22, Drag = 1.6, Spin = 500, LightEmission = 0.2, Direction = direction }
end

-- The dunker's gold-tinted screen flash on a Perfect (drawn under the HUD).
local function screenFlash(color: Color3)
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end
	local gui = Instance.new("ScreenGui")
	gui.Name = "LocalPerfectFlash"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -1
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = Config.FlashTransparency
	frame.BorderSizePixel = 0
	frame.Parent = gui
	gui.Parent = playerGui
	TweenService:Create(frame, TweenInfo.new(Config.FlashSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }):Play()
	Debris:AddItem(gui, Config.FlashSeconds + 0.1)
end

-- Floating "PERFECT!" / "GOOD!" over another player's head.
local function label(player: Player, text: string, color: Color3)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not head or not head:IsA("BasePart") or not playerGui then return end
	local gui = Instance.new("BillboardGui")
	gui.Name = "LocalDunkGrade"
	gui.Adornee = head
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(220, 56)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.MaxDistance = Config.MaxDistance
	local caption = Instance.new("TextLabel")
	caption.BackgroundTransparency = 1
	caption.Size = UDim2.fromScale(1, 1)
	caption.Font = Enum.Font.FredokaOne
	caption.TextScaled = true
	caption.Text = text
	caption.TextColor3 = color
	caption.TextStrokeColor3 = INK
	caption.TextStrokeTransparency = 0
	caption.Parent = gui
	local pop = Instance.new("UIScale")
	pop.Scale = 0.4
	pop.Parent = caption
	gui.Parent = playerGui
	TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(Config.LabelSeconds), { StudsOffset = Vector3.new(0, 6, 0) }):Play()
	task.delay(Config.LabelSeconds * 0.6, function()
		TweenService:Create(caption, TweenInfo.new(Config.LabelSeconds * 0.4),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(gui, Config.LabelSeconds + 0.1)
end

-- Court signature effects. `ctx.Big` is true for a Perfect, false for a Good.
local SIGNATURES = {}

-- Neighborhood: a dust shockwave rolls across the asphalt, chips fly and sparks pour off the rim.
function SIGNATURES.Street(ctx)
	local theme, scale = ctx.Theme, ctx.Scale
	emit(ctx.Floor.Position + Vector3.new(0, 0.5, 0), { Texture = "Smoke", Colors = { theme.Dust },
		Count = ctx.Big and 20 or 10, Size = ctx.Big and 3.2 or 2.6, EndSize = 1.5, Lifetime = { 0.6, 1 },
		Speed = { 12, 22 }, Spread = 88, Drag = 3, LightEmission = 0, Transparency = 0.5 }, scale)
	if not ctx.Big then return end
	emit(ctx.Floor.Position + Vector3.new(0, 1, 0), { Texture = "Square", Colors = theme.Chips, Count = 30,
		Size = 0.22, EndSize = 1, Lifetime = { 0.7, 1.1 }, Speed = { 20, 32 }, Spread = 40, Gravity = 120,
		Spin = 400, LightEmission = 0 }, scale)
	emit(ctx.Rim, { Texture = "Spark", Colors = { theme.Spark }, Count = 35, Size = 0.5, Lifetime = { 0.5, 0.9 },
		Speed = { 14, 24 }, Spread = 30, Gravity = 60, Drag = 1 }, scale)
end

-- High School: blue-and-gold confetti. Good pops it off the rim; Perfect fires two cannons.
function SIGNATURES.PepRally(ctx)
	local theme, scale = ctx.Theme, ctx.Scale
	if not ctx.Big then
		emit(ctx.Rim, confetti(theme.Confetti, Config.ConfettiCount * 0.4, Vector3.yAxis, { 16, 28 }, 70), scale)
		return
	end
	local side = ctx.Floor.RightVector * Config.CannonSideOffset
	local forward = ctx.Floor.LookVector * 4
	for _, sign in { -1, 1 } do
		local origin = ctx.Floor.Position + side * sign + forward + Vector3.new(0, 1, 0)
		local toward = ctx.Rim + Vector3.new(0, 12, 0) - origin
		emit(origin, confetti(theme.Confetti, Config.ConfettiCount, toward, { 55, 75 }, 14), scale)
		emit(origin, { Texture = "Smoke", Colors = { Color3.new(1, 1, 1) }, Count = 6, Size = 3, EndSize = 2,
			Lifetime = { 0.4, 0.7 }, Speed = { 8, 14 }, Spread = 20, Direction = toward, Drag = 3,
			LightEmission = 0, Transparency = 0.5 }, scale)
	end
	emit(ctx.Rim, { Texture = "Spark", Colors = { theme.Spark }, Count = 30, Size = 1, Lifetime = { 0.5, 0.9 },
		Speed = { 12, 22 }, Spread = 180, Drag = 2 }, scale)
end

-- College: embers off the rim for a Good; fire columns and a confetti drop for a Perfect.
function SIGNATURES.Pyro(ctx)
	local theme, scale = ctx.Theme, ctx.Scale
	if not ctx.Big then
		emit(ctx.Rim, { Texture = "Embers", Colors = { theme.Fire }, Count = 30, Size = 0.9, Lifetime = { 0.6, 1.1 },
			Speed = { 10, 20 }, Spread = 70, Gravity = 25, Drag = 1 }, scale)
		return
	end
	local side = ctx.Floor.RightVector * Config.PyroSideOffset
	for _, sign in { -1, 1 } do
		local base = ctx.Floor.Position + side * sign + Vector3.new(0, 0.5, 0)
		emit(base, { Texture = "Fire", Colors = { theme.Fire, theme.Spark }, Rate = 50, Seconds = Config.PyroSeconds,
			Size = 2.6, EndSize = 0.3, Lifetime = { 0.5, 0.8 }, Speed = { 40, 55 }, Spread = 5, Drag = 0.5,
			LightEmission = 0.7 }, scale)
		emit(base, { Texture = "Embers", Colors = { theme.Spark }, Rate = 25, Seconds = Config.PyroSeconds,
			Size = 0.7, Lifetime = { 0.8, 1.4 }, Speed = { 45, 65 }, Spread = 14, Gravity = 30 }, scale)
		light(base + Vector3.new(0, 8, 0), theme.Fire, 3, 30, Config.PyroSeconds + 0.4)
	end
	local drop = ctx.Rim + ctx.Floor.LookVector * 6 + Vector3.new(0, 22, 0)
	emit(drop, confetti(theme.Confetti, Config.ConfettiCount * 1.2, -Vector3.yAxis, { 6, 12 }, 70), scale)
end

-- Rooftop: electric crackle; a Perfect adds a lightning strike and fireworks over the city.
function SIGNATURES.Neon(ctx)
	local theme, scale = ctx.Theme, ctx.Scale
	emit(ctx.Rim, { Texture = "Spark", Colors = { theme.Spark, theme.Glow }, Count = ctx.Big and 60 or 26, Size = 0.8,
		Lifetime = { 0.15, 0.35 }, Speed = { 30, 55 }, Spread = 180, Drag = 8 }, scale)
	if not ctx.Big then return end
	local rim = ctx.Rim
	local sky = rim + Vector3.new(random:NextNumber(-12, 12), Config.LightningHeight, random:NextNumber(-12, 12))
	bolt(sky, rim, theme.Bolt, 0.7, 0.3)
	task.delay(0.08, function()
		bolt(sky + Vector3.new(random:NextNumber(-4, 4), 0, random:NextNumber(-4, 4)), rim, theme.Spark, 0.45, 0.25)
	end)
	light(rim + Vector3.new(0, 6, 0), theme.Bolt, 12, 60, 0.4)
	for index = 1, Config.FireworkBursts do
		task.delay(0.12 + 0.2 * index, function()
			local at = rim + Vector3.new(random:NextNumber(-35, 35), random:NextNumber(35, 60), random:NextNumber(-35, 35))
			local color = theme.Fireworks[(index - 1) % #theme.Fireworks + 1]
			emit(at, { Texture = "Spark", Colors = { color }, Count = 45, Size = 1.1, Lifetime = { 0.8, 1.2 },
				Speed = { 22, 30 }, Spread = 180, Drag = 2, Gravity = 8 }, scale)
			light(at, color, 5, 60, 0.6)
		end)
	end
end

-- Early / Late: a small grey puff and a few dull sparks.
local function fizzle(position: Vector3, scale: number)
	emit(position, { Texture = "Smoke", Colors = { Color3.fromRGB(150, 150, 160) }, Count = 8, Size = 3, EndSize = 1.8,
		Lifetime = { 0.5, 0.8 }, Speed = { 3, 6 }, Spread = 180, Drag = 2, LightEmission = 0, Transparency = 0.3 }, scale)
	emit(position, { Texture = "Spark", Colors = { Color3.fromRGB(200, 200, 210) }, Count = 8, Size = 0.5,
		Lifetime = { 0.15, 0.3 }, Speed = { 8, 14 }, Spread = 180, Drag = 4 }, scale)
end

-- Bigger dunk styles hit a little harder (0.85x for the first dunk up to 1.2x).
local function styleScale(player: Player): number
	local style = Styles.Get(player:GetAttribute("EquippedDunkStyle"))
	return style and math.clamp(0.8 + style.Order * 0.06, 0.85, 1.2) or 1
end

local function play(player: Player, gradeName: string, position: Vector3)
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > Config.MaxDistance then return end
	local grade = Config.Grades[gradeName] or Config.Grades.None
	local isLocal = player == localPlayer
	local scale = grade.Scale * styleScale(player) * (isLocal and 1 or Config.OthersScale)
	if grade.Fizzle then
		fizzle(position, scale)
		return
	end
	local theme = Config.Themes[player:GetAttribute("CurrentCourt")] or Config.Themes[Courts.StartingId]
	-- Every slam: court-coloured sparks, a shockwave around the rim and a flash of light.
	emit(position, { Texture = "Spark", Colors = { theme.Spark }, Count = Config.RimSparks, Size = 0.6,
		Lifetime = { 0.2, 0.45 }, Speed = { 14, 28 }, Spread = 180, Drag = 5 }, scale)
	emit(position, { Texture = "Shockwave", Colors = { theme.Glow }, Count = 1, Fixed = true,
		Size = Config.RimShockwaveSize, Grow = true, Lifetime = { 0.3, 0.3 }, Speed = { 0, 0 }, Spread = 0,
		Transparency = 0.1 }, scale)
	local rim = DunkVFX.FindRim(player)
	local floor = rim and hoopFloor(rim)
	-- The flash sits a little in front of the rim so it lights the dunker, not the backboard.
	light(position + (floor and floor.Base.LookVector * 4 or Vector3.zero), theme.Glow, grade.Light or 4, 24, 0.35)
	if floor and grade.FloorRings then
		for index = 1, grade.FloorRings do
			task.delay((index - 1) * 0.12, function()
				emit(floor.Base.Position + Vector3.new(0, 0.2, 0), { Texture = "Shockwave",
					Colors = { index == 1 and theme.Glow or theme.Spark }, Count = 1, Fixed = true,
					Size = Config.FloorRingSize * index, Grow = true, Flat = true, Lifetime = { 0.5, 0.5 },
					Speed = { 0.1, 0.1 }, Spread = 0, Transparency = 0.05 }, scale)
			end)
		end
	end
	local signature = grade.Signature and SIGNATURES[theme.Signature]
	if signature and floor then
		signature({ Theme = theme, Rim = position, Floor = floor.Base, Height = floor.Height, Scale = scale,
			Big = grade.Signature == "Big" })
	end
	if grade.Flash and isLocal then screenFlash(theme.Flash) end
	if grade.Label and not isLocal then label(player, grade.Label, gradeName == "Perfect" and GOLD or theme.Spark) end
end

-- The dunker's own meter press (DunkController). Cleared when the next dunk starts or ends.
function DunkVFX.SetPrediction(grade: string?)
	prediction = grade
end

-- Extra camera shake for the dunker's impact (FeedbackController).
function DunkVFX.LocalCameraBoost(): number
	local grade = prediction and Config.Grades[prediction]
	return grade and grade.CameraBoost or 1
end

-- The grade to show at impact: the dunker's predicted press, or "None" for everyone else
-- (their real grade arrives with SlamRating). Returns the name and its settings.
function DunkVFX.ImpactGrade(player: Player): (string, any)
	local gradeName = player == localPlayer and prediction or "None"
	return gradeName, Config.Grades[gradeName] or Config.Grades.None
end

-- Fireball ability: a burst of flame and embers out of the rim.
local function fireBurst(player: Player, position: Vector3)
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > Config.MaxDistance then return end
	local color = Abilities.Abilities.Fireball.Color
	local scale = player == localPlayer and 1 or Config.OthersScale
	emit(position, { Texture = "Fire", Colors = { color, Color3.fromRGB(255, 210, 90) }, Count = 26, Size = 2.4, EndSize = 0.4,
		Lifetime = { 0.35, 0.6 }, Speed = { 10, 18 }, Spread = 180, Drag = 4, LightEmission = 0.8 }, scale)
	emit(position, { Texture = "Embers", Colors = { color }, Count = 24, Size = 0.7, Lifetime = { 0.6, 1 },
		Speed = { 14, 24 }, Spread = 60, Gravity = 30, Drag = 1 }, scale)
	light(position, color, 6, 26, 0.45)
end

-- The ball leaves the dunker's hand at the rim (RimPresentation, every player's dunk).
function DunkVFX.Impact(player: Player, position: Vector3, gradeName: string)
	shown[player] = gradeName
	play(player, gradeName, position)
	if Abilities.InList(player:GetAttribute("DunkAbilities"), "Fireball") then fireBurst(player, position) end
end

-- The server's judged grade arrived. Skipped if the dunker's prediction already played it.
local function onGraded(player: Player)
	local gradeName = player:GetAttribute("SlamRating")
	if gradeName == nil then
		shown[player] = nil
		return
	end
	local grade = type(gradeName) == "string" and Config.Grades[gradeName]
	if not grade then return end
	local already = shown[player]
	shown[player] = gradeName
	if already and already ~= "None" then return end
	if grade.Fizzle and player ~= localPlayer then return end
	local rim = DunkVFX.FindRim(player)
	if rim then play(player, gradeName, rim.Position) end
end

function DunkVFX.Start()
	if started then return end
	started = true
	local function watch(player: Player)
		player:GetAttributeChangedSignal("SlamRating"):Connect(function() onGraded(player) end)
	end
	for _, player in Players:GetPlayers() do watch(player) end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player) shown[player] = nil end)
	localPlayer:GetAttributeChangedSignal("DunkPhase"):Connect(function()
		local phase = localPlayer:GetAttribute("DunkPhase")
		if phase == "Descent" or phase == nil then prediction = nil end
	end)
end

return DunkVFX
