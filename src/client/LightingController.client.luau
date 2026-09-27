-- Applies the current court's lighting and post-processing on this client only and
-- blends to the next court's look on travel. Purely visual; nothing is replicated.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LightingConfig"))
local player = Players.LocalPlayer

-- Reuse the place's own effect of each class when it has one; otherwise add one locally.
local function effect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then return existing end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end

local effects = {
	ColorCorrection = effect("ColorCorrectionEffect", "CourtColorCorrection"),
	Bloom = effect("BloomEffect", "CourtBloom"),
	SunRays = effect("SunRaysEffect", "CourtSunRays"),
	Atmosphere = effect("Atmosphere", "CourtAtmosphere"),
	DepthOfField = effect("DepthOfFieldEffect", "CourtDepthOfField"),
}

local activeTweens = {}

local function cancelTweens()
	for _, tween in activeTweens do
		tween:Cancel()
		tween:Destroy()
	end
	table.clear(activeTweens)
end

local function applyTo(target: Instance, properties, info: TweenInfo?)
	local blended = {}
	for property, value in properties do
		local kind = typeof(value)
		if info and (kind == "number" or kind == "Color3") then
			blended[property] = value
		else
			(target :: any)[property] = value
		end
	end
	if info and next(blended) then
		local tween = TweenService:Create(target, info, blended)
		table.insert(activeTweens, tween)
		tween:Play()
	end
end

local function apply(courtId, instant: boolean)
	local preset = Config.Courts[courtId] or Config.Courts[Config.DefaultCourt]
	if not preset then return end
	cancelTweens()
	local info = not instant and TweenInfo.new(Config.BlendSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) or nil
	applyTo(Lighting, preset.Lighting or {}, info)
	for key, properties in preset.Effects or {} do
		local target = effects[key]
		if target then applyTo(target, properties, info) end
	end
end

apply(player:GetAttribute("CurrentCourt"), true)
player:GetAttributeChangedSignal("CurrentCourt"):Connect(function()
	apply(player:GetAttribute("CurrentCourt"), false)
end)
