-- Perfect-slam timing: while a dunk executes, the dunker may press once (SlamTiming
-- remote, no arguments). The server stamps the press with its own clock, minus the
-- player's measured latency, and DunkExecution judges it against the real Slam moment.
-- Only the grade (Perfect / Good / Early / Late, or nil with no press) ever leaves this
-- module; clients never send a time, a rating or an amount. Only Perfect and Good pay more.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Timing = require(ReplicatedStorage.Shared.Config.DunkRewards).Timing
local PlayerService = require(script.Parent.PlayerService)

local SlamTiming = {}
local sessions: { [Player]: { Press: number? } } = {}
local initialized = false

-- Opens a fresh window for this dunk (one press counts).
function SlamTiming.Begin(player: Player)
	sessions[player] = { Press = nil }
end

function SlamTiming.End(player: Player)
	sessions[player] = nil
end

-- Grade for a press relative to the server moment the slam started (nil = no press).
-- `windowScale` widens the windows (Slow-Mo Slam uses 2).
function SlamTiming.Judge(player: Player, slamAt: number, windowScale: number?): string?
	local session = sessions[player]
	local press = session and session.Press
	if not press then return nil end
	local delta = press - slamAt
	local scale = windowScale or 1
	if delta >= -Timing.PerfectEarlySeconds * scale and delta <= Timing.PerfectLateSeconds * scale then
		return "Perfect"
	elseif delta >= -Timing.GoodEarlySeconds * scale and delta <= Timing.GoodLateSeconds * scale then
		return "Good"
	end
	return delta < 0 and "Early" or "Late"
end

function SlamTiming.Init()
	if initialized then return end
	initialized = true
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SlamTiming")
	remote.OnServerEvent:Connect(function(player, ...)
		if select("#", ...) ~= 0 then return end
		local session = sessions[player]
		if not session or session.Press or PlayerService.GetDunkState(player) ~= "Executing" then return end
		local latency = math.clamp(player:GetNetworkPing(), 0, Timing.MaxLatencyCompensationSeconds)
		session.Press = os.clock() - latency
	end)
	Players.PlayerRemoving:Connect(function(player) sessions[player] = nil end)
end

return SlamTiming
