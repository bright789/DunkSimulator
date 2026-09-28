-- Dunk streak ("HEAT", HeatConfig). DunkService calls OnDunk for every completed dunk and
-- multiplies that dunk's Cash by the result. Mirrored to the "Heat" (1-5) and "HeatUntil"
-- (server time it resets) player attributes for the HUD; not saved.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.HeatConfig)

local HeatService = {}
local heat: { [Player]: { Level: number, Until: number } } = {}
local initialized = false

local function publish(player: Player, level: number?, untilTime: number?)
	if player.Parent ~= Players then return end
	player:SetAttribute("Heat", level)
	player:SetAttribute("HeatUntil", untilTime)
end

-- A dunk just completed: raise (or restart) HEAT and return this dunk's Cash multiplier.
function HeatService.OnDunk(player: Player): number
	local now = Workspace:GetServerTimeNow()
	local entry = heat[player]
	local level = (entry and now <= entry.Until) and math.min(entry.Level + 1, #Config.Multipliers) or 1
	local untilTime = now + Config.WindowSeconds
	heat[player] = { Level = level, Until = untilTime }
	publish(player, level, untilTime)
	return Config.Multipliers[level]
end

function HeatService.Init()
	if initialized then return end
	initialized = true
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() < nextCheck then return end
		nextCheck = os.clock() + 0.25
		local now = Workspace:GetServerTimeNow()
		for player, entry in heat do
			if now > entry.Until then
				heat[player] = nil
				publish(player, nil, nil)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player) heat[player] = nil end)
end

return HeatService
