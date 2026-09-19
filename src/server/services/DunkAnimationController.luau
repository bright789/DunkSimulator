local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Shared.Config.DunkAnimations)
local DebugLogging = require(ReplicatedStorage.Shared.Config.DunkConfig).Execution.DebugLogging

local DunkAnimationController = {}

function DunkAnimationController.Start(humanoid: Humanoid, name: string, onCue)
	local definition = assert(Animations[name], "Unknown dunk animation: " .. name)
	local track: AnimationTrack? = nil
	local animation: Animation? = nil
	local connections = {}
	local seen = {}
	local stopped = false
	local session = {}

	local function cue(marker: string, source: string)
		if stopped or seen[marker] then
			return
		end
		seen[marker] = true
		if DebugLogging then
			print("[DunkAnimation] " .. name .. ": " .. marker .. " (" .. source .. ")")
		end
		if onCue then
			local success, message = pcall(onCue, marker, source)
			if not success then
				warn("[DunkAnimation] Presentation callback failed: " .. tostring(message))
			end
		end
	end

	function session.Cue(marker: string)
		cue(marker, "server timeline")
	end

	function session.FadeOut()
		if track then
			track:Stop(definition.FadeOutSeconds)
		end
	end

	function session.Destroy()
		if stopped then
			return
		end
		stopped = true
		for _, connection in connections do
			connection:Disconnect()
		end
		if track then
			track:Stop(0)
			track:Destroy()
		end
		if animation then
			animation:Destroy()
		end
	end

	local assetId = definition.AnimationId
	if assetId == "" or humanoid.RigType ~= definition.RigType then
		return session
	end
	if typeof(assetId) ~= "string" or not string.match(assetId, "^rbxassetid://[1-9]%d*$") then
		warn("[DunkAnimation] Configure a real rbxassetid:// ID or leave AnimationId empty; using scripted fallback.")
		return session
	end

	local success, message = pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		animation = Instance.new("Animation")
		animation.AnimationId = assetId
		track = animator:LoadAnimation(animation)
		track.Priority = definition.Priority
		track.Looped = false
		for _, marker in definition.Markers do
			table.insert(connections, track:GetMarkerReachedSignal(marker):Connect(function()
				cue(marker, "animation marker")
			end))
		end
		track:Play(definition.FadeInSeconds, 1, definition.Speed)
	end)
	if not success then
		warn("[DunkAnimation] Animation unavailable; using scripted fallback: " .. tostring(message))
		for _, connection in connections do
			connection:Disconnect()
		end
		if track then
			track:Destroy()
			track = nil
		end
		if animation then
			animation:Destroy()
			animation = nil
		end
	end
	return session
end

return DunkAnimationController
