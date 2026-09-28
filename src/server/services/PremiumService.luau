-- Roblox Premium perk (SocialConfig.PremiumBonus): Premium members earn extra dunk and
-- air-trick Cash. Checked on join and whenever membership changes (e.g. someone subscribes
-- from the HUD's Premium button). Mirrored to the "Premium" attribute for the HUD. Not saved.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.SocialConfig)
local PlayerService = require(script.Parent.PlayerService)
local Analytics = require(script.Parent.AnalyticsReporter)

local PremiumService = {}
local initialized = false

local function isPremium(player: Player): boolean
	if RunService:IsStudio() and Config.StudioPretendPremium then return true end
	return player.MembershipType == Enum.MembershipType.Premium
end

local function refresh(player: Player)
	if not PlayerService.IsDataReady(player) or player.Parent ~= Players then return end
	local premium = isPremium(player)
	PlayerService.SetPremiumMultiplier(player, premium and 1 + Config.PremiumBonus or 1)
	player:SetAttribute("Premium", premium)
end

function PremiumService.OnPlayerReady(player: Player)
	refresh(player)
end

function PremiumService.Init()
	if initialized then return end
	initialized = true
	Players.PlayerMembershipChanged:Connect(function(player)
		local was = player:GetAttribute("Premium") == true
		refresh(player)
		if not was and player:GetAttribute("Premium") == true then Analytics.Custom(player, "PremiumJoined") end
	end)
end

return PremiumService
