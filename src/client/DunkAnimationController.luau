local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Animations = require(ReplicatedStorage.Shared.Config.DunkAnimations)
local Styles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local statusRemote = ReplicatedStorage.Remotes:WaitForChild("DunkAnimationStatus")
local player = Players.LocalPlayer

local DunkAnimationController = {}
local entries = {}
local connections = {}
local active = nil
local currentCharacter = nil
local generation = 0
local markerCallback = nil
local initialized = false

local function studioWarning(message: string)
	if RunService:IsStudio() then warn("[DunkAnimation] " .. message) end
end

local function isCurrent(character: Model, expectedGeneration: number): boolean
	return generation == expectedGeneration and player.Character == character
		and currentCharacter == character and character:IsDescendantOf(Workspace)
end

local function report(character: Model, styleId: string, available: boolean)
	if player.Character == character then
		statusRemote:FireServer(character, styleId, available)
	end
end

local function clearCharacter()
	generation += 1
	active = nil
	for _, entry in entries do
		for _, connection in entry.Connections do connection:Disconnect() end
		entry.Track:Stop(0)
		entry.Track:Destroy()
		entry.Animation:Destroy()
	end
	table.clear(entries)
	currentCharacter = nil
end

local function loadStyle(character: Model, expectedGeneration: number, animator: Animator, styleId: string)
	local definition = Animations[styleId]
	if not definition or definition.AnimationId == nil or definition.AnimationId == "" then return end
	if type(definition.AnimationId) ~= "string"
		or not definition.AnimationId:match("^rbxassetid://[1-9]%d*$") then
		studioWarning(styleId .. " has an invalid AnimationId; using procedural fallback.")
		return
	end
	local animation = Instance.new("Animation")
	animation.Name = "Dunk" .. styleId
	animation.AnimationId = definition.AnimationId
	local track = nil
	local success, problem = pcall(function()
		local fetched = false
		ContentProvider:PreloadAsync({ animation }, function(_assetId, status)
			fetched = status == Enum.AssetFetchStatus.Success
		end)
		assert(fetched, "animation asset did not load; check ID and experience permissions")
		assert(isCurrent(character, expectedGeneration), "character changed while loading")
		track = animator:LoadAnimation(animation)
		local expiresAt = os.clock() + Animations.LoadTimeoutSeconds
		while track.Length <= 0 and os.clock() < expiresAt and isCurrent(character, expectedGeneration) do
			task.wait(0.1)
		end
		assert(track.Length > 0 and isCurrent(character, expectedGeneration), "animation track did not become ready")
		track.Priority = definition.Priority
		track.Looped = false
	end)
	if not success then
		if track then track:Destroy() end
		animation:Destroy()
		if isCurrent(character, expectedGeneration) then
			studioWarning(styleId .. " unavailable; using procedural fallback: " .. tostring(problem))
			report(character, styleId, false)
		end
		return
	end
	if not isCurrent(character, expectedGeneration) then
		track:Destroy()
		animation:Destroy()
		return
	end
	local entry = { Character = character, StyleId = styleId, Track = track, Animation = animation, Connections = {} }
	entries[styleId] = entry
	for cue, markerName in definition.Markers do
		table.insert(entry.Connections, track:GetMarkerReachedSignal(markerName):Connect(function()
			if active == entry and markerCallback then markerCallback(styleId, cue) end
		end))
	end
	table.insert(entry.Connections, track.Stopped:Connect(function()
		if active == entry then
			active = nil
			studioWarning(styleId .. " stopped before server recovery; falling back to procedural posing.")
			report(character, styleId, false)
		end
	end))
	report(character, styleId, true)
end

local function prepareCharacter(character: Model)
	clearCharacter()
	currentCharacter = character
	local expectedGeneration = generation
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") or not isCurrent(character, expectedGeneration) then return end
		if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
			studioWarning("R15 character required for custom tracks; procedural ball motion remains available.")
			return
		end
		local animator = humanoid:WaitForChild("Animator", 10)
		if not animator or not animator:IsA("Animator") or not isCurrent(character, expectedGeneration) then
			studioWarning("Server-created Animator unavailable; using procedural fallback.")
			return
		end
		for _, styleId in Styles.OrderedIds() do
			if not isCurrent(character, expectedGeneration) then return end
			loadStyle(character, expectedGeneration, animator, styleId)
		end
	end)
end

function DunkAnimationController.Init(onMarker)
	if initialized then return end
	initialized = true
	markerCallback = onMarker
	table.insert(connections, player.CharacterAdded:Connect(prepareCharacter))
	table.insert(connections, player.CharacterRemoving:Connect(function(character)
		if currentCharacter == character then clearCharacter() end
	end))
	if player.Character then prepareCharacter(player.Character) end
end

function DunkAnimationController.Start(styleId: string, character: Model, serverStartedAt: number): boolean
	if currentCharacter ~= character then return false end
	DunkAnimationController.Stop(character)
	local entry = entries[styleId]
	if not entry or entry.Character ~= character then
		report(character, styleId, false)
		return false
	end
	local definition = Animations[styleId]
	local elapsed = typeof(serverStartedAt) == "number"
		and math.max(0, Workspace:GetServerTimeNow() - serverStartedAt) * definition.PlaybackSpeed or 0
	if elapsed >= entry.Track.Length then
		report(character, styleId, false)
		return false
	end
	active = entry
	local success, problem = pcall(function()
		entry.Track:Play(definition.FadeInSeconds, 1, definition.PlaybackSpeed)
		entry.Track.TimePosition = elapsed
	end)
	if not success then
		active = nil
		studioWarning(styleId .. " playback failed; using procedural fallback: " .. tostring(problem))
		report(character, styleId, false)
		return false
	end
	return true
end

function DunkAnimationController.FadeOut(character: Model)
	if not active or active.Character ~= character then return end
	local entry = active
	active = nil
	local definition = Animations[entry.StyleId]
	entry.Track:Stop(definition.FadeOutSeconds)
end

function DunkAnimationController.Stop(character: Model?)
	if not active or active.Character ~= character then return end
	local entry = active
	active = nil
	entry.Track:Stop(0)
end

function DunkAnimationController.Destroy()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	clearCharacter()
	markerCallback = nil
	initialized = false
end

return DunkAnimationController
