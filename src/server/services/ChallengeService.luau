local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.ChallengeConfig)
local Styles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local remotes = ReplicatedStorage.Remotes

local ChallengeService = {}
local initialized = false
local processing = {}
local nextClaim = {}
local nextRead = {}
local orderedIds = Config.OrderedIds()

local handlers = {
	DunkStyleCount = function(definition, event, progress)
		if event.Kind == "Dunk" and event.StyleId == definition.Requirements.DunkStyle then
			return progress + 1
		end
		return progress
	end,
	VerticalReached = function(definition, event, progress)
		if event.Kind == "Vertical" then
			return math.max(progress, math.min(event.Vertical, definition.Requirements.Vertical))
		end
		return progress
	end,
	CourtDunkCount = function(definition, event, progress)
		if event.Kind == "Dunk" and event.CourtId == definition.Requirements.Court then
			return progress + 1
		end
		return progress
	end,
}

local function publish(player, readyIds, resultKind, resultId, resultValue)
	if player.Parent ~= Players then return end
	local snapshot = PlayerService.GetChallengeSnapshot(player)
	if snapshot then
		remotes.ChallengeState:FireClient(player, snapshot, readyIds, resultKind, resultId, resultValue)
	end
end

local function evaluate(player, event, silent)
	local snapshot = PlayerService.GetChallengeSnapshot(player)
	if not snapshot then return end
	local changed = false
	local readyIds = {}
	for _, challengeId in orderedIds do
		local definition = Config.Get(challengeId)
		local entry = snapshot.Challenges[challengeId]
		local handler = handlers[definition.Type]
		if not entry.Completed and handler then
			local target = Config.Target(definition)
			local candidate = math.min(target, handler(definition, event, entry.Progress))
			if candidate > entry.Progress then
				local advanced, newlyReady = PlayerService.SetChallengeProgress(player, challengeId, candidate)
				if advanced then
					changed = true
					if newlyReady and not silent then table.insert(readyIds, challengeId) end
				end
			end
		end
	end
	if changed and not silent then publish(player, readyIds) end
end

function ChallengeService.OnPlayerReady(player: Player)
	if not PlayerService.IsDataReady(player) then return end
	evaluate(player, { Kind = "Vertical", Vertical = PlayerService.GetVertical(player) }, true)
	publish(player)
end

function ChallengeService.OnVerticalChanged(player: Player)
	if not PlayerService.IsDataReady(player) then return end
	evaluate(player, { Kind = "Vertical", Vertical = PlayerService.GetVertical(player) }, false)
end

function ChallengeService.OnSuccessfulDunk(player: Player, styleId: string, courtId: string)
	if not PlayerService.IsDataReady(player) or PlayerService.GetEquippedDunkStyle(player) ~= styleId
		or not Styles.IsUnlocked(styleId, PlayerService.GetVertical(player))
		or PlayerService.GetCurrentCourt(player) ~= courtId or not PlayerService.HasCourt(player, courtId) then return end
	evaluate(player, { Kind = "Dunk", StyleId = styleId, CourtId = courtId }, false)
end

function ChallengeService.Init()
	if initialized then return end
	initialized = true
	remotes.ChallengeRequest.OnServerEvent:Connect(function(player, ...)
		if player.Parent ~= Players or not PlayerService.IsDataReady(player) then return end
		local argumentCount = select("#", ...)
		if argumentCount == 0 then
			if os.clock() >= (nextRead[player] or 0) then
				nextRead[player] = os.clock() + Config.ReadCooldownSeconds
				publish(player)
			end
			return
		end
		local requestedId = select(1, ...)
		local challengeId = Config.Get(requestedId) and requestedId or nil
		if processing[player] then return end
		if os.clock() < (nextClaim[player] or 0) then
			publish(player, nil, "Rejected", challengeId, "Please wait before claiming again.")
			return
		end
		nextClaim[player] = os.clock() + Config.ClaimCooldownSeconds
		if argumentCount ~= 1 or not challengeId then
			publish(player, nil, "Rejected", nil, "Invalid challenge request.")
			return
		end
		processing[player] = true
		local success, claimed, reward, problem = pcall(PlayerService.ClaimChallenge, player, challengeId)
		processing[player] = nil
		if not success then
			warn("[ChallengeService] Claim failed: " .. tostring(claimed))
			publish(player, nil, "Rejected", challengeId, "Claim unavailable. Please try again.")
		elseif claimed then
			DataService.RequestSave(player)
			publish(player, nil, "Claimed", challengeId, reward)
		else
			publish(player, nil, "Rejected", challengeId, problem)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		processing[player] = nil
		nextClaim[player] = nil
		nextRead[player] = nil
	end)
end

return ChallengeService
