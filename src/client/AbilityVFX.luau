-- Client-only looks for armed abilities, on every player (reads replicated attributes):
--   Slow-Mo Slam: slow blue sparkles swirl around the player; the dunker's own screen gets
--                 a cool slow-motion tint during that dunk.
--   Fireball:     the ball (or the hand, when not holding one) is on fire.
--   Hang Time:    pale feathers drift down around the player.
-- The Fireball impact burst lives in DunkVFX.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Abilities = require(ReplicatedStorage.Shared.Config.AbilityConfig)
local Textures = require(ReplicatedStorage.Shared.Config.DunkVFXConfig).Textures

local AbilityVFX = {}
local localPlayer = Players.LocalPlayer
local started = false

local function emitter(name: string, props)
	local created = Instance.new("ParticleEmitter")
	created.Name = name
	created.Texture = Textures[props.Texture]
	created.Color = ColorSequence.new(props.Color)
	created.LightEmission = props.LightEmission or 1
	created.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, props.Size), NumberSequenceKeypoint.new(1, props.Size * (props.EndSize or 0)) })
	created.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, props.Transparency or 0), NumberSequenceKeypoint.new(1, 1) })
	created.Lifetime = NumberRange.new(props.Lifetime[1], props.Lifetime[2])
	created.Speed = NumberRange.new(props.Speed[1], props.Speed[2])
	created.SpreadAngle = Vector2.new(props.Spread, props.Spread)
	created.Rate = props.Rate
	created.Drag = props.Drag or 0
	created.Acceleration = props.Acceleration or Vector3.zero
	created.Rotation = NumberRange.new(0, 360)
	created.RotSpeed = NumberRange.new(-(props.Spin or 0), props.Spin or 0)
	created.LockedToPart = props.Locked == true
	return created
end

local AURAS = {
	SlowMo = function(color: Color3)
		return emitter("AbilityAura_SlowMo", { Texture = "Spark", Color = color, Size = 0.45, Lifetime = { 1, 1.5 },
			Speed = { 1, 2.5 }, Spread = 180, Rate = 10, Drag = 1 })
	end,
	HangTime = function(color: Color3)
		return emitter("AbilityAura_HangTime", { Texture = "Square", Color = color, Size = 0.18, EndSize = 1,
			Lifetime = { 1.4, 2 }, Speed = { 0.5, 1.5 }, Spread = 180, Rate = 7, Acceleration = Vector3.new(0, -1.5, 0),
			Spin = 160, LightEmission = 0.3, Transparency = 0.2 })
	end,
	-- Roblox's classic Fire reads best in daylight: the ball looks properly on fire.
	Fireball = function(color: Color3)
		local fire = Instance.new("Fire")
		fire.Name = "AbilityAura_Fireball"
		fire.Color = color
		fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
		fire.Size = 3
		fire.Heat = 7
		return fire
	end,
}

-- Where each aura sits: Fireball on the visual ball (or right hand), the rest on the body.
local function anchorFor(player: Player, abilityId: string): BasePart?
	local character = player.Character
	if not character then return nil end
	if abilityId == "Fireball" then
		local folder = Workspace:FindFirstChild("LocalBallVisuals")
		local ball = folder and folder:FindFirstChild(player.Name .. "_Basketball")
		if ball and ball:IsA("BasePart") then return ball end
		local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		return hand and hand:IsA("BasePart") and hand or nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil
end

local function syncPlayer(player: Player)
	for _, abilityId in Abilities.Ids() do
		local armed = player:GetAttribute("AbilityArmed_" .. abilityId) == true
		local anchor = armed and anchorFor(player, abilityId) or nil
		local name = "AbilityAura_" .. abilityId
		-- Remove auras that are no longer armed or sit on the wrong part (ball picked up / dropped).
		for _, part in { anchor, player.Character and player.Character:FindFirstChild("HumanoidRootPart"),
			player.Character and player.Character:FindFirstChild("RightHand") } do
			if part and part ~= anchor then
				local stale = part:FindFirstChild(name)
				if stale then stale:Destroy() end
			end
		end
		local folder = Workspace:FindFirstChild("LocalBallVisuals")
		local ball = folder and folder:FindFirstChild(player.Name .. "_Basketball")
		if ball and ball ~= anchor then
			local stale = ball:FindFirstChild(name)
			if stale then stale:Destroy() end
		end
		if anchor and not anchor:FindFirstChild(name) then
			local aura = AURAS[abilityId](Abilities.Abilities[abilityId].Color)
			aura.Parent = anchor
		end
	end
end

-- The dunker's slow-motion tint while a Slow-Mo Slam dunk runs.
local tint: ColorCorrectionEffect? = nil
local function syncTint()
	local wanted = localPlayer:GetAttribute("DunkPhase") ~= nil
		and Abilities.InList(localPlayer:GetAttribute("DunkAbilities"), "SlowMo")
	local camera = Workspace.CurrentCamera
	if wanted and not tint and camera then
		local effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "LocalSlowMoTint"
		effect.Saturation = 0
		effect.TintColor = Color3.new(1, 1, 1)
		effect.Parent = camera
		TweenService:Create(effect, TweenInfo.new(0.25), { Saturation = -0.35, TintColor = Color3.fromRGB(205, 230, 255) }):Play()
		tint = effect
	elseif not wanted and tint then
		local effect = tint
		tint = nil
		local fade = TweenService:Create(effect, TweenInfo.new(0.3), { Saturation = 0, TintColor = Color3.new(1, 1, 1) })
		fade.Completed:Once(function() effect:Destroy() end)
		fade:Play()
	end
end

function AbilityVFX.Start()
	if started then return end
	started = true
	localPlayer:GetAttributeChangedSignal("DunkPhase"):Connect(syncTint)
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local ok, problem = pcall(syncPlayer, player)
				if not ok then warn("[AbilityVFX] " .. tostring(problem)) end
			end
			task.wait(0.2)
		end
	end)
end

return AbilityVFX
