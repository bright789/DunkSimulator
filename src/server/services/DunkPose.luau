local DunkStyleMotion = require(script.Parent.DunkStyleMotion)

local DunkPose = {}

function DunkPose.Start(character: Model, humanoid: Humanoid, root: BasePart, ball: BasePart, config)
	local controls = {}
	local resources = {}
	local session = {}
	local torsoControl = nil
	local torsoTarget = nil
	local torsoRest = nil

	function session.Update(position: Vector3, right: Vector3, weight: number, phase: string, progress: number)
		for _, entry in controls do
			entry.Target.WorldPosition = position + right * entry.Side * config.GripOffset
			entry.Control.Weight = math.clamp(weight, 0, 1) * config.Weight
			entry.Control.Enabled = weight > 0
		end
		if torsoControl then
			local body = DunkStyleMotion.Body(config.Body, phase, progress)
			torsoTarget.CFrame = torsoRest * CFrame.new(0, -body.Sink, 0)
				* CFrame.Angles(math.rad(body.Pitch), math.rad(body.Yaw), math.rad(body.Roll))
			local blend = phase == "Gather" and math.min(progress / config.Body.BlendFraction, 1)
				or (phase == "Return" and 1 - progress or 1)
			torsoControl.Weight = math.clamp(blend, 0, 1) * config.Body.Weight
			torsoControl.Enabled = blend > 0
		end
	end

	function session.Destroy()
		for index = #resources, 1, -1 do
			resources[index]:Destroy()
		end
		table.clear(resources)
		table.clear(controls)
		torsoControl = nil
		torsoTarget = nil
	end

	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return session
	end
	local torsoSuccess, torsoProblem = pcall(function()
		local upperTorso = character:FindFirstChild("UpperTorso")
		local lowerTorso = character:FindFirstChild("LowerTorso")
		if upperTorso and lowerTorso and upperTorso:IsA("BasePart") and lowerTorso:IsA("BasePart") then
			torsoRest = root.CFrame:Inverse() * upperTorso.CFrame
			torsoTarget = Instance.new("Attachment")
			table.insert(resources, torsoTarget)
			torsoTarget.Name = "DunkTorsoTarget"
			torsoTarget.CFrame = torsoRest
			torsoTarget.Parent = root
			torsoControl = Instance.new("IKControl")
			table.insert(resources, torsoControl)
			torsoControl.Name = "DunkTorsoPose"
			torsoControl.Type = Enum.IKControlType.Transform
			torsoControl.ChainRoot = lowerTorso
			torsoControl.EndEffector = upperTorso
			torsoControl.Target = torsoTarget
			torsoControl.SmoothTime = config.Body.SmoothSeconds
			torsoControl.Weight = 0
			torsoControl.Enabled = false
			torsoControl.Parent = humanoid
		end
	end)
	if not torsoSuccess then
		if torsoControl then torsoControl:Destroy() end
		if torsoTarget then torsoTarget:Destroy() end
		torsoControl = nil
		torsoTarget = nil
		warn("[DunkPose] Torso posing unavailable; retaining arm/ball motion: " .. tostring(torsoProblem))
	end
	local success, problem = pcall(function()
		for _, side in config.Hands do
			local upperArm = character:FindFirstChild(side .. "UpperArm")
			local hand = character:FindFirstChild(side .. "Hand")
			if not upperArm or not hand or not upperArm:IsA("BasePart") or not hand:IsA("BasePart") then
				continue
			end
			local target = Instance.new("Attachment")
			table.insert(resources, target)
			target.Name = "Dunk" .. side .. "Grip"
			target.Parent = root
			target.WorldPosition = ball.Position
			local control = Instance.new("IKControl")
			table.insert(resources, control)
			control.Name = "Dunk" .. side .. "Arm"
			control.Type = Enum.IKControlType.Position
			control.ChainRoot = upperArm
			control.EndEffector = hand
			control.Target = target
			control.SmoothTime = config.SmoothSeconds
			control.Priority = 1
			control.Weight = 0
			control.Enabled = false
			control.Parent = humanoid
			table.insert(controls, { Control = control, Target = target, Side = side == "Right" and 1 or -1 })
		end
	end)
	if not success then
		session.Destroy()
		warn("[DunkPose] Arm posing unavailable; retaining ball motion: " .. tostring(problem))
	end
	return session
end

return DunkPose
