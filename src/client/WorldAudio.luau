-- 3D sounds placed in the world on this client (dribbles, rim clangs, crowd cheers, bus
-- doors) plus 2D ambience loops. IDs and volumes: FeedbackConfig.Audio.World. Purely
-- presentational; an empty ID plays nothing.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("FeedbackConfig")).Audio.World

local WorldAudio = {}
local loops: { [string]: Sound } = {}

local function assetId(category: string): string?
	local id = Config.AssetIds[category]
	return type(id) == "string" and id:match("^rbxassetid://%d+$") and id or nil
end

function WorldAudio.PlayAt(category: string, position: Vector3, volumeScale: number?, pitch: number?)
	local id = assetId(category)
	if not id then return end
	local attachment = Instance.new("Attachment")
	attachment.Name = "WorldSound_" .. category
	attachment.WorldPosition = position
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = math.clamp((Config.Volumes[category] or 0.3) * (volumeScale or 1), 0, 1)
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = Config.RollOffMinDistance
	sound.RollOffMaxDistance = Config.RollOffMaxDistance
	sound.Parent = attachment
	attachment.Parent = Workspace.Terrain
	sound:Play()
	sound.Ended:Once(function() attachment:Destroy() end)
	Debris:AddItem(attachment, 15)
end

-- Fades a looping 2D bed in (on = true) or out.
function WorldAudio.SetLoop(category: string, on: boolean)
	local id = assetId(category)
	if not id then return end
	local sound = loops[category]
	if not sound then
		if not on then return end
		sound = Instance.new("Sound")
		sound.Name = "Loop_" .. category
		sound.SoundId = id
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		loops[category] = sound
	end
	if on and not sound.IsPlaying then sound:Play() end
	local target = on and (Config.Volumes[category] or 0.1) or 0
	local tween = TweenService:Create(sound, TweenInfo.new(Config.AmbienceFadeSeconds), { Volume = target })
	tween.Completed:Once(function()
		if not on and sound.Volume <= 0.001 then sound:Stop() end
	end)
	tween:Play()
end

return WorldAudio
