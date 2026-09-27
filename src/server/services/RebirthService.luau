-- Rebirth requests. The client can only ask to read its rebirth state or to rebirth; the
-- server checks the requirement from RebirthConfig, sends the player back to the
-- Neighborhood through the normal court travel, then applies the reset atomically in
-- PlayerService and saves right away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local PlayerService = require(script.Parent.PlayerService)
local CourtTravel = require(script.Parent.CourtTravel)
local DataService = require(script.Parent.DataService)

local RebirthService = {}
local nextRequest: { [Player]: number } = {}
local nextRead: { [Player]: number } = {}
local processing: { [Player]: boolean } = {}
local initialized = false

function RebirthService.Init()
	if initialized then return end
	initialized = true
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild("RebirthRequest")
	local state = remotes:WaitForChild("RebirthState")

	local function publish(player: Player, message: string?, rebirthed: boolean?)
		if player.Parent == Players then
			state:FireClient(player, PlayerService.GetRebirthSnapshot(player), message, rebirthed == true)
		end
	end

	local function rebirth(player: Player): (boolean, string)
		local snapshot = PlayerService.GetRebirthSnapshot(player)
		if not snapshot or not PlayerService.IsReady(player) or PlayerService.GetDunkState(player) ~= "Idle" then
			return false, "Finish what you're doing first."
		end
		if not snapshot.CanRebirth then
			return false, snapshot.Rebirths >= snapshot.MaxRebirths and "Max rebirths reached."
				or string.format("Reach %d Vertical and $%d first.", snapshot.RequiredVertical, snapshot.RequiredCash)
		end
		-- Back to the Neighborhood spawn first (ends training, closes upgrades, drops the ball).
		local moved, message = CourtTravel.Move(player, Courts.StartingId)
		if not moved then return false, message end
		return PlayerService.ApplyRebirth(player)
	end

	request.OnServerEvent:Connect(function(player, action, ...)
		if player.Parent ~= Players or select("#", ...) ~= 0 then return end
		local now = os.clock()
		if action == "Read" then
			if now >= (nextRead[player] or 0) then
				nextRead[player] = now + Config.ReadCooldownSeconds
				publish(player)
			end
			return
		end
		if action ~= "Rebirth" or processing[player] or now < (nextRequest[player] or 0) then return end
		nextRequest[player] = now + Config.RequestCooldownSeconds
		processing[player] = true
		local ok, success, message = pcall(rebirth, player)
		processing[player] = nil
		if not ok then
			warn("[RebirthService] Rebirth failed: " .. tostring(success))
			publish(player, "Rebirth unavailable. Please try again.")
			return
		end
		if success then DataService.RequestSave(player) end
		publish(player, message, success)
	end)
	Players.PlayerRemoving:Connect(function(player)
		nextRequest[player] = nil
		nextRead[player] = nil
		processing[player] = nil
	end)
end

return RebirthService
