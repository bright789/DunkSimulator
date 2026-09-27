local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config.FeedbackConfig).Camera

local CameraFeedback = {}
local active = nil

function CameraFeedback.Stop()
	local effect = active
	if not effect then return end
	active = nil
	if effect.Connection then effect.Connection:Disconnect() end
	if effect.Camera.Parent and math.abs(effect.Camera.FieldOfView - effect.LastFOV) < 0.05 then
		effect.Camera.FieldOfView = effect.BaseFOV
	end
	if effect.Humanoid.Parent and (effect.Humanoid.CameraOffset - effect.LastOffset).Magnitude < 0.02 then
		effect.Humanoid.CameraOffset = effect.BaseOffset
	end
end

local function start(profile)
	CameraFeedback.Stop()
	if not Config.CameraShakeEnabled and not Config.FOVPunchEnabled then return end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = Workspace.CurrentCamera
	if not humanoid or humanoid.Health <= 0 or not camera or camera.CameraType == Enum.CameraType.Scriptable then return end
	local effect = {
		Character = character,
		Humanoid = humanoid,
		Camera = camera,
		BaseFOV = camera.FieldOfView,
		LastFOV = camera.FieldOfView,
		BaseOffset = humanoid.CameraOffset,
		LastOffset = humanoid.CameraOffset,
		StartedAt = os.clock(),
	}
	active = effect
	effect.Connection = RunService.RenderStepped:Connect(function()
		if active ~= effect or Players.LocalPlayer.Character ~= character or Workspace.CurrentCamera ~= camera
			or humanoid.Health <= 0 or camera.CameraType == Enum.CameraType.Scriptable then
			CameraFeedback.Stop()
			return
		end
		local progress = math.clamp((os.clock() - effect.StartedAt) / profile.DurationSeconds, 0, 1)
		if progress >= 1 then CameraFeedback.Stop(); return end
		if Config.FOVPunchEnabled then
			if math.abs(camera.FieldOfView - effect.LastFOV) >= 0.05 then effect.BaseFOV = camera.FieldOfView end
			local punch = math.clamp(profile.FOVDelta or 0, -Config.MaxFOVDegrees, Config.MaxFOVDegrees)
				* math.sin(math.pi * progress)
			camera.FieldOfView = effect.BaseFOV + punch
			effect.LastFOV = camera.FieldOfView
		end
		if Config.CameraShakeEnabled then
			if (humanoid.CameraOffset - effect.LastOffset).Magnitude >= 0.02 then effect.BaseOffset = humanoid.CameraOffset end
			local envelope = (1 - progress) ^ 2
			local displacement = math.min(profile.ShakeStuds or 0, Config.MaxShakeStuds) * envelope
			local angle = (os.clock() - effect.StartedAt) * Config.ShakeFrequency * math.pi * 2
			local offset = (profile.Kick or Vector3.zero) * envelope
				+ Vector3.new(math.sin(angle), math.cos(angle * 0.73), 0) * displacement
			if offset.Magnitude > Config.MaxCameraOffsetStuds then
				offset = offset.Unit * Config.MaxCameraOffsetStuds
			end
			humanoid.CameraOffset = effect.BaseOffset + offset
			effect.LastOffset = humanoid.CameraOffset
		end
	end)
end

function CameraFeedback.Cue(styleId: string, moment: string)
	local style = Config.Styles[styleId]
	local profile = style and style[moment]
	if profile then start(profile) end
end

function CameraFeedback.Impact(styleId: string)
	local style = Config.Styles[styleId] or Config.Styles.BasicOneHand
	start(style.Impact)
end

function CameraFeedback.Play(intensity: number)
	local strength = math.clamp(intensity, 0, 1.5)
	start({ DurationSeconds = Config.DurationSeconds, FOVDelta = Config.FOVDegrees * strength,
		ShakeStuds = Config.ShakeStuds * strength })
end

return CameraFeedback
