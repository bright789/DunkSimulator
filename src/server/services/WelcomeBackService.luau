-- Welcome-back earnings (WelcomeBackConfig). The profile's LastOnline (schema v13) is the time
-- of your last save; on join, time away since then (capped) pays Cash once, shown with a
-- "WELCOME BACK" pop-up (SocialNotice "WelcomeBack"). Saving writes a fresh LastOnline, so the
-- same time away can't pay twice.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config.WelcomeBackConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.AnalyticsReporter)

local WelcomeBackService = {}
local isStudio = RunService:IsStudio()

function WelcomeBackService.OnPlayerReady(player: Player)
	local last = PlayerService.GetLastOnline(player)
	local away = os.time() - (last or 0)
	if isStudio and Config.StudioPretendAwaySeconds > 0 then away = Config.StudioPretendAwaySeconds end
	if not last or (last <= 0 and not (isStudio and Config.StudioPretendAwaySeconds > 0))
		or away < Config.MinAwayMinutes * 60 then
		return
	end
	-- Pass ownership arrives a moment after data (MonetizationService); wait briefly for VIP.
	local waited = 0
	while player.Parent == Players and player:GetAttribute("Pass_VIP") == nil and waited < 10 do
		waited += task.wait(0.25)
	end
	if player.Parent ~= Players then return end
	local paidSeconds = math.min(away, Config.MaxHours * 3600)
	local vip = PlayerService.HasPass(player, "VIP")
	local rebirth = PlayerService.GetRebirthSnapshot(player)
	local cash = math.floor(paidSeconds / 3600 * Config.DunksPerHour * Daily.DunkValue(PlayerService.GetVertical(player) or 0)
		* (rebirth and rebirth.CashMultiplier or 1) * (vip and Config.VipMultiplier or 1) + 0.5)
	if cash <= 0 or not PlayerService.GrantCash(player, cash, "WelcomeBack", "Gameplay") then return end
	-- Show the pop-up once they're actually in the world (not on the loading screen).
	local character = player.Character or player.CharacterAdded:Wait()
	if character then task.wait(2.5) end
	DataService.RequestSave(player)
	Analytics.Custom(player, "WelcomeBack", math.floor(paidSeconds / 60))
	local notice = ReplicatedStorage.Remotes:FindFirstChild("SocialNotice")
	if notice then
		notice:FireClient(player, "WelcomeBack", { Cash = cash, Seconds = away, Capped = away > paidSeconds, Vip = vip })
	end
end

return WelcomeBackService
