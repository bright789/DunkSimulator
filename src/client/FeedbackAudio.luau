-- Local (2D) feedback sounds for this player's own actions. IDs and volumes come from
-- FeedbackConfig.Audio; an empty ID plays nothing.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Config = require(ReplicatedStorage.Shared.Config.FeedbackConfig).Audio

local FeedbackAudio = {}
local sounds = {}
local nextTrainingSound = 0

local function valid(assetId): boolean
	return type(assetId) == "string" and assetId:match("^rbxassetid://%d+$") ~= nil
end

local function play(category: string, assetId: string?, volume: number, pitch: number?): boolean
	if not valid(assetId) then
		return false
	end
	local sound = sounds[category]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "DunkSimulator" .. category
		sound.SoundId = assetId :: string
		sound.Parent = SoundService
		sounds[category] = sound
	end
	sound.Volume = math.clamp(volume, 0, 1)
	sound.PlaybackSpeed = pitch or 1
	sound:Play()
	return true
end

function FeedbackAudio.Play(category: string, intensity: number?, pitch: number?): boolean
	if category == "TrainingTick" then
		if os.clock() < nextTrainingSound then return false end
	end
	local played = play(category, Config.AssetIds[category], (Config.Volumes[category] or 0.2) * (intensity or 1), pitch)
	if played and category == "TrainingTick" then
		nextTrainingSound = os.clock() + Config.TrainingMinIntervalSeconds
	end
	return played
end

function FeedbackAudio.PlayStyle(styleId: string, moment: string, intensity: number?): boolean
	local style = Config.StyleAssetIds[styleId]
	if not style then return false end
	return play(styleId .. moment, style[moment], (Config.StyleVolumes[moment] or 0.2) * (intensity or 1))
end

-- Warm the cache so the first slam or cha-ching isn't silent while it downloads.
task.spawn(function()
	local ids = {}
	for _, id in Config.AssetIds do
		if valid(id) then table.insert(ids, id) end
	end
	for _, style in Config.StyleAssetIds do
		for _, id in style do
			if valid(id) and not table.find(ids, id) then table.insert(ids, id) end
		end
	end
	for _, id in Config.World.AssetIds do
		if valid(id) and not table.find(ids, id) then table.insert(ids, id) end
	end
	local preload = {}
	for _, id in ids do
		local sound = Instance.new("Sound")
		sound.SoundId = id
		table.insert(preload, sound)
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, preload)
end)

return FeedbackAudio
