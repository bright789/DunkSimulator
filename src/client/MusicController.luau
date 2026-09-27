-- Background music: a shuffled playlist per court (FeedbackConfig.Audio.Music) that
-- crossfades when this player travels. The HUD's MUSIC button turns it off and on for the
-- session. Purely local; nothing is sent to the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.FeedbackConfig).Audio.Music

local MusicController = {}

function MusicController.new(player: Player, hud)
	local enabled = true
	local court: string? = nil
	local current: Sound? = nil
	local order: { string } = {}
	local position = 0
	local generation = 0
	local connections = {}
	local random = Random.new()

	local function fade(sound: Sound, target: number, thenDestroy: boolean)
		local tween = TweenService:Create(sound, TweenInfo.new(Config.FadeSeconds), { Volume = target })
		if thenDestroy then
			tween.Completed:Once(function() sound:Destroy() end)
		end
		tween:Play()
	end

	local function shuffle(list: { string }): { string }
		local copy = table.clone(list)
		for index = #copy, 2, -1 do
			local swap = random:NextInteger(1, index)
			copy[index], copy[swap] = copy[swap], copy[index]
		end
		return copy
	end

	local playNext
	function playNext()
		generation += 1
		local mine = generation
		if current then
			fade(current, 0, true)
			current = nil
		end
		local playlist = court and Config.Playlists[court]
		if not enabled or not playlist or #playlist == 0 then return end
		position += 1
		if position > #order then
			order = shuffle(playlist)
			position = 1
		end
		local sound = Instance.new("Sound")
		sound.Name = "Music"
		sound.SoundId = order[position]
		sound.Volume = 0
		sound.Parent = SoundService
		current = sound
		sound.Ended:Once(function()
			if generation == mine then playNext() end
		end)
		sound:Play()
		fade(sound, Config.Volume, false)
	end

	local function setCourt(courtId)
		if type(courtId) ~= "string" or courtId == court then return end
		court = courtId
		order, position = {}, 0
		playNext()
	end

	table.insert(connections, player:GetAttributeChangedSignal("CurrentCourt"):Connect(function()
		setCourt(player:GetAttribute("CurrentCourt"))
	end))
	table.insert(connections, hud.MusicButton.Activated:Connect(function()
		enabled = not enabled
		hud.SetMusic(enabled)
		playNext()
	end))
	hud.SetMusic(enabled)
	setCourt(player:GetAttribute("CurrentCourt"))

	local controller = {}
	function controller.Destroy()
		generation += 1
		for _, connection in connections do connection:Disconnect() end
		if current then current:Destroy() end
	end
	return controller
end

return MusicController
