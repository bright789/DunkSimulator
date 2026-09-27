local markers = {
	Gather = "Gather",
	Slam = "Slam",
	Release = "Release",
	Recover = "Recover",
}

local function definition(animationId)
	return {
		AnimationId = animationId,
		RigType = Enum.HumanoidRigType.R15,
		Priority = Enum.AnimationPriority.Action,
		PlaybackSpeed = 1,
		FadeInSeconds = 0.05,
		FadeOutSeconds = 0.12,
		Markers = markers,
	}
end

return {
	LoadTimeoutSeconds = 5,
	BasicOneHand = definition("rbxassetid://135348962515793"),
	TwoHandPower = definition("rbxassetid://71449337106724"),
	Tomahawk = definition("rbxassetid://78661065332826"),
	Windmill = definition("rbxassetid://105217887029678"),
}
