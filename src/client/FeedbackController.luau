local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage.Shared.Config.FeedbackConfig)
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local Styles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local Audio = require(script.Parent.FeedbackAudio)
local Camera = require(script.Parent.CameraFeedback)

local FeedbackController = {}
local contacted = false

local function rimBurst(style)
	local court = Courts.Get(Players.LocalPlayer:GetAttribute("CurrentCourt"))
	if not court then return end
	local container = Workspace
	for _, name in court.GameplayPath do
		container = container and container:FindFirstChild(name)
	end
	local hoop = container and container:FindFirstChild("DunkHoop")
	local rim = hoop and hoop:FindFirstChild("Rim")
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not rim or not rim:IsA("BasePart") or not playerGui then return end
	local burst = Instance.new("BillboardGui")
	burst.Name = "LocalDunkImpact"
	burst.Adornee = rim
	burst.AlwaysOnTop = true
	burst.MaxDistance = Config.Dunk.RimMaxDistance
	burst.Size = UDim2.fromOffset(style.RimSizePixels, style.RimSizePixels)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.Parent = burst
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = style.RimColor
	stroke.Thickness = math.clamp(1.5 * style.ImpactIntensity, 1, 2.5)
	stroke.Transparency = 0.15
	stroke.Parent = ring
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = ring
	burst.Parent = playerGui
	for index = 1, style.RimStreaks do
		local angle = 2 * math.pi * index / style.RimStreaks
		local direction = Vector2.new(math.cos(angle), math.sin(angle))
		local streak = Instance.new("Frame")
		streak.Name = "Streak"
		streak.AnchorPoint = Vector2.new(0.5, 0.5)
		streak.Position = UDim2.fromScale(0.5, 0.5)
			+ UDim2.fromOffset(direction.X * style.RimSizePixels * 0.24, direction.Y * style.RimSizePixels * 0.24)
		streak.Size = UDim2.fromOffset(2, Config.Dunk.RimStreakLengthPixels)
		streak.Rotation = math.deg(angle) - 90
		streak.BackgroundColor3 = style.RimColor
		streak.BorderSizePixel = 0
		streak.Parent = burst
		TweenService:Create(streak, TweenInfo.new(Config.Dunk.RimBurstSeconds), {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5)
				+ UDim2.fromOffset(direction.X * style.RimSizePixels * 0.42, direction.Y * style.RimSizePixels * 0.42),
		}):Play()
	end
	TweenService:Create(scale, TweenInfo.new(Config.Dunk.RimBurstSeconds, Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out), { Scale = 1.2 + 0.2 * style.ImpactIntensity }):Play()
	TweenService:Create(stroke, TweenInfo.new(Config.Dunk.RimBurstSeconds), { Transparency = 1 }):Play()
	Debris:AddItem(burst, Config.Dunk.RimBurstSeconds + 0.1)
end

local function impact(styleId: string)
	local style = Config.Dunk.Styles[styleId] or Config.Dunk.Styles.BasicOneHand
	local intensity = style.ImpactIntensity
	Camera.Impact(styleId)
	if not Audio.PlayStyle(styleId, "Impact", intensity) then
		Audio.Play("DunkImpact", intensity)
	end
	Audio.PlayStyle(styleId, "Rim", intensity)
	rimBurst(style)
end

function FeedbackController.OnDunkImpact(styleId: string)
	if contacted then return end
	contacted = true
	impact(styleId)
end

function FeedbackController.OnDunkCompleted(styleId: string)
	if not contacted then impact(styleId) end
	contacted = false
	Audio.Play("CashReward")
end

function FeedbackController.DunkPhase(styleId: string, moment: string)
	local definition = Styles.Get(styleId)
	if not definition then return end
	if moment == "Gather" then
		contacted = false
		Camera.Cue(styleId, moment)
		Audio.PlayStyle(styleId, "Approach")
	elseif moment == "Contact" then
		FeedbackController.OnDunkImpact(styleId)
	else
		Camera.Cue(styleId, moment)
		if definition.Presentation.WhooshCue == moment then
			Audio.PlayStyle(styleId, "Whoosh")
		end
	end
end

function FeedbackController.Pickup() Audio.Play("BasketballPickup") end
-- Each trick in a combo rings a little higher.
function FeedbackController.AirTrick(comboIndex: number) Audio.Play("AirTrick", 1, 1 + 0.12 * (comboIndex - 1)) end
function FeedbackController.PerfectSlam() Audio.Play("PerfectSlam") end
function FeedbackController.Rebirth() Audio.Play("Rebirth") end
function FeedbackController.Training() Audio.Play("TrainingTick") end
function FeedbackController.Upgrade() Audio.Play("UpgradePurchase") end
function FeedbackController.DunkUnlock() Audio.Play("DunkUnlock") end
function FeedbackController.CourtUnlock() Audio.Play("CourtUnlock") end
function FeedbackController.CourtArrival() Audio.Play("CourtArrival") end
function FeedbackController.ChallengeReady() Audio.Play("ChallengeReady") end
function FeedbackController.ChallengeClaim() Audio.Play("ChallengeClaim") end
function FeedbackController.StopCamera()
	contacted = false
	Camera.Stop()
end

return FeedbackController
