local Motion = {}

local function smooth(progress: number): number
	return progress * progress * (3 - 2 * progress)
end

local function mix(first: number?, second: number?, fraction: number): number
	return (first or 0) + ((second or 0) - (first or 0)) * fraction
end

local function between(first, second, fraction: number)
	return {
		Pitch = mix(first.Pitch, second.Pitch, fraction),
		Yaw = mix(first.Yaw, second.Yaw, fraction),
		Roll = mix(first.Roll, second.Roll, fraction),
		Sink = mix(first.Sink, second.Sink, fraction),
	}
end

function Motion.Body(body, phase: string, progress: number)
	progress = math.clamp(progress, 0, 1)
	local gather = body.Gather
	local last = gather[#gather]
	if phase == "Finish" then
		return between(last, body.Slam, smooth(progress))
	elseif phase == "Return" then
		return between(body.Slam, {}, smooth(progress))
	end
	local previous = gather[1]
	for index = 2, #gather do
		local nextPose = gather[index]
		if progress <= nextPose.Time then
			local fraction = smooth((progress - previous.Time) / (nextPose.Time - previous.Time))
			return between(previous, nextPose, fraction)
		end
		previous = nextPose
	end
	return between(last, last, 0)
end

-- Root offset from the aligned target for each dunk phase: rise above the rim while
-- winding up, drive down through it on the slam, then hang from the rim.
-- startLifted: the player dropped in from above and already starts at wind-up height.
function Motion.RootOffset(motion, phase: string, progress: number, towardRim: Vector3, hangOffset: Vector3,
	startLifted: boolean?): Vector3
	progress = math.clamp(progress, 0, 1)
	local function gatherOffset(fraction: number): Vector3
		local lift = motion.HeightLift * (startLifted and 1 or smooth(math.min(fraction / motion.LiftByFraction, 1)))
		return Vector3.new(0, lift, 0) + towardRim * motion.SlamReach * smooth(fraction)
	end
	if phase == "Gather" then
		return gatherOffset(progress)
	elseif phase == "Finish" then
		-- Accelerates into the rim like a real slam.
		return gatherOffset(1):Lerp(hangOffset, progress * progress * (3 - 2 * progress) ^ 0.5)
	end
	return hangOffset
end

-- Descent into the wind-up: eases out of the apex pause, speeds up, then brakes.
function Motion.Descent(progress: number): number
	return smooth(math.clamp(progress, 0, 1))
end

function Motion.Finish(motion, progress: number): number
	progress = math.clamp(progress, 0, 1)
	if motion.FinishExponent then
		return progress ^ motion.FinishExponent
	end
	return smooth(progress)
end

function Motion.Gather(path, progress: number, start: CFrame, approach: CFrame, aboveRim: CFrame): CFrame
	progress = math.clamp(progress, 0, 1)
	if path.Kind == "Circle" then
		local function circle(fraction: number): CFrame
			local angle = math.rad(path.StartAngleDegrees + path.TurnDegrees * fraction)
			local offset = path.Center + Vector3.new(math.cos(angle) * path.SideSweep,
				math.sin(angle) * path.VerticalRadius, math.cos(angle) * path.DepthRadius)
			return approach * CFrame.new(offset)
		end
		if progress < path.EnterFraction then
			return start:Lerp(circle(0), smooth(progress / path.EnterFraction))
		elseif progress <= path.ExitFraction then
			local fraction
			if progress < path.HangStartFraction then
				fraction = path.HangAngleFraction * smooth((progress - path.EnterFraction)
					/ (path.HangStartFraction - path.EnterFraction))
			elseif progress <= path.HangEndFraction then
				fraction = path.HangAngleFraction
			else
				fraction = path.HangAngleFraction + (1 - path.HangAngleFraction)
					* smooth((progress - path.HangEndFraction) / (path.ExitFraction - path.HangEndFraction))
			end
			return circle(fraction)
		end
		return circle(1):Lerp(aboveRim, smooth((progress - path.ExitFraction) / (1 - path.ExitFraction)))
	end
	local previousTime = 0
	local previousPoint = start
	for _, point in path.Points do
		local destination = approach * CFrame.new(point.Offset)
		if progress <= point.Time then
			return previousPoint:Lerp(destination, smooth((progress - previousTime) / (point.Time - previousTime)))
		end
		previousTime = point.Time
		previousPoint = destination
	end
	return previousPoint:Lerp(aboveRim, smooth((progress - previousTime) / (1 - previousTime)))
end

return Motion
