local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Animations = require(ReplicatedStorage.Shared.Config.DunkAnimations)
local remotes = ReplicatedStorage.Remotes

local DunkAnimationController = {}
local readiness = {}
local characterConnections = {}
local initialized = false

local function hasConfiguredAnimation(styleId: string): boolean
	local definition = Animations[styleId]
	return type(definition) == "table" and type(definition.AnimationId) == "string"
		and definition.AnimationId:match("^rbxassetid://[1-9]%d*$") ~= nil
end

local function trackCharacter(player: Player, character: Model)
	readiness[player] = { Character = character, Styles = {} }
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if player.Character ~= character or not humanoid or not humanoid:IsA("Humanoid") then return end
		if not humanoid:FindFirstChildOfClass("Animator") then
			local animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
	end)
end

function DunkAnimationController.Init()
	if initialized then return end
	initialized = true
	local function addPlayer(player: Player)
		characterConnections[player] = { player.CharacterAdded:Connect(function(character)
			trackCharacter(player, character)
		end), player.CharacterRemoving:Connect(function(character)
			local record = readiness[player]
			if record and record.Character == character then readiness[player] = nil end
		end) }
		if player.Character then trackCharacter(player, player.Character) end
	end
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player)
		readiness[player] = nil
		if characterConnections[player] then
			for _, connection in characterConnections[player] do connection:Disconnect() end
		end
		characterConnections[player] = nil
	end)
	for _, player in Players:GetPlayers() do addPlayer(player) end

	remotes.DunkAnimationStatus.OnServerEvent:Connect(function(player, character, styleId, available, ...)
		if select("#", ...) ~= 0 or typeof(character) ~= "Instance" or character ~= player.Character
			or type(styleId) ~= "string" or type(available) ~= "boolean"
			or not hasConfiguredAnimation(styleId) then return end
		local record = readiness[player]
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not record or record.Character ~= character or not humanoid
			or humanoid.RigType ~= Animations[styleId].RigType
			or not humanoid:FindFirstChildOfClass("Animator") then return end
		record.Styles[styleId] = available
	end)
end

function DunkAnimationController.Start(player: Player, humanoid: Humanoid, styleId: string)
	local character = humanoid.Parent
	local record = readiness[player]
	local useTrack = character == player.Character and record and record.Character == character
		and record.Styles[styleId] == true and hasConfiguredAnimation(styleId)
		and humanoid.RigType == Animations[styleId].RigType
	local startedTrack = useTrack == true
	local stopped = false
	local session = {}

	function session.UsingTrack(): boolean
		if stopped or not useTrack then return false end
		if readiness[player] ~= record or record.Styles[styleId] ~= true or player.Character ~= character then
			useTrack = false
			return false
		end
		return true
	end

	function session.FadeOut()
		if session.UsingTrack() then
			remotes.DunkPresentation:FireClient(player, styleId, "AnimationFadeOut", character)
		end
	end

	function session.Destroy()
		if stopped then return end
		if startedTrack and player.Parent == Players then
			remotes.DunkPresentation:FireClient(player, styleId, "AnimationStop", character)
		end
		stopped = true
	end

	remotes.DunkPresentation:FireClient(player, styleId, "AnimationStart", character, startedTrack,
		Workspace:GetServerTimeNow())
	return session
end

return DunkAnimationController
