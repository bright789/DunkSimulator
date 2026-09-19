local Workspace = game:GetService("Workspace")

local GameplayObjects = {}

function GameplayObjects.Find(name: string): Instance?
	local gameplay = Workspace:FindFirstChild("Gameplay")
	if gameplay then
		if not gameplay:IsA("Folder") then
			return nil
		end
		local object = gameplay:FindFirstChild(name)
		if object then
			return object
		end
	end
	return Workspace:FindFirstChild(name)
end

function GameplayObjects.FindRim(): BasePart?
	local hoop = GameplayObjects.Find("DunkHoop")
	local rim = hoop and hoop:FindFirstChild("Rim")
	if not hoop or not hoop:IsA("Model") or not rim or not rim:IsA("BasePart") or not rim.Anchored then
		return nil
	end
	return rim
end

return GameplayObjects
