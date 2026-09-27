-- R15 dunk poses in degrees (pitch, yaw, roll) per joint. Signs, measured in Studio:
--   LowerTorso/UpperTorso/Head pitch: + leans back, - leans forward
--   UpperArm/UpperLeg pitch: + swings the limb forward/up (over 90 is overhead)
--   LowerArm pitch: + bends the elbow; LowerLeg pitch: - bends the knee
--   Foot pitch: - points the toes; UpperArm roll: right + / left - moves the arm outward
-- Values beyond +/-180 are written as the equivalent angle (e.g. -165 = arm cocked
-- behind the head). Joints omitted from a frame keep their previous angle.
local function degrees(pitch, yaw, roll)
	return Vector3.new(pitch, yaw, roll)
end

local function frame(time, joints, easingDirection)
	return {
		Time = time,
		Joints = joints,
		EasingDirection = easingDirection or Enum.PoseEasingDirection.InOut,
	}
end

local IN = Enum.PoseEasingDirection.In
local OUT = Enum.PoseEasingDirection.Out

return {
	-- Quick one-hand rise, cock high over the head, snap down, reach for the rim.
	BasicOneHand = {
		frame(0, {
			LowerTorso = degrees(-8, 0, 0), UpperTorso = degrees(-10, 0, 0), Head = degrees(6, 0, 0),
			RightUpperArm = degrees(40, 0, 10), RightLowerArm = degrees(85, 0, 0), RightHand = degrees(-10, 0, 0),
			LeftUpperArm = degrees(30, 0, -20), LeftLowerArm = degrees(40, 0, 0), LeftHand = degrees(-5, 0, 0),
			RightUpperLeg = degrees(35, 0, 4), RightLowerLeg = degrees(-55, 0, 0), RightFoot = degrees(-15, 0, 0),
			LeftUpperLeg = degrees(55, 0, -4), LeftLowerLeg = degrees(-80, 0, 0), LeftFoot = degrees(-20, 0, 0),
		}),
		frame(0.12, {
			LowerTorso = degrees(-2, 0, 0), UpperTorso = degrees(2, 0, 0), Head = degrees(8, 0, 0),
			RightUpperArm = degrees(120, 0, 15), RightLowerArm = degrees(60, 0, 0),
			LeftUpperArm = degrees(70, 0, -35), LeftLowerArm = degrees(30, 0, 0),
			RightUpperLeg = degrees(20, 0, 4), RightLowerLeg = degrees(-35, 0, 0), RightFoot = degrees(-25, 0, 0),
			LeftUpperLeg = degrees(75, 0, -4), LeftLowerLeg = degrees(-100, 0, 0), LeftFoot = degrees(-25, 0, 0),
		}, OUT),
		frame(0.26, {
			LowerTorso = degrees(4, 0, 0), UpperTorso = degrees(14, 0, 0), Head = degrees(12, 0, 0),
			RightUpperArm = degrees(170, 0, 10), RightLowerArm = degrees(35, 0, 0), RightHand = degrees(-25, 0, 0),
			LeftUpperArm = degrees(95, 0, -50), LeftLowerArm = degrees(20, 0, 0),
			RightUpperLeg = degrees(-10, 0, 4), RightLowerLeg = degrees(-70, 0, 0),
			LeftUpperLeg = degrees(60, 0, -4), LeftLowerLeg = degrees(-90, 0, 0),
		}),
		frame(0.30, {
			UpperTorso = degrees(10, 0, 0),
			RightUpperArm = degrees(178, 0, 6), RightLowerArm = degrees(15, 0, 0),
		}),
		frame(0.36, {
			LowerTorso = degrees(-6, 0, 0), UpperTorso = degrees(-18, 0, 0), Head = degrees(-5, 0, 0),
			RightUpperArm = degrees(140, 0, 8), RightLowerArm = degrees(8, 0, 0), RightHand = degrees(35, 0, 0),
			LeftUpperArm = degrees(60, 0, -40), LeftLowerArm = degrees(30, 0, 0),
			RightUpperLeg = degrees(45, 0, 4), RightLowerLeg = degrees(-40, 0, 0),
			LeftUpperLeg = degrees(50, 0, -4), LeftLowerLeg = degrees(-60, 0, 0),
		}, IN),
		frame(0.42, {
			UpperTorso = degrees(-12, 0, 0),
			RightUpperArm = degrees(155, 0, 6), RightLowerArm = degrees(10, 0, 0), RightHand = degrees(10, 0, 0),
			LeftUpperArm = degrees(40, 0, -45), LeftLowerArm = degrees(25, 0, 0),
			RightUpperLeg = degrees(30, 0, 4), RightLowerLeg = degrees(-50, 0, 0),
			LeftUpperLeg = degrees(40, 0, -4), LeftLowerLeg = degrees(-55, 0, 0),
		}, OUT),
		frame(0.48, {
			LowerTorso = degrees(-2, 0, 0), UpperTorso = degrees(-8, 0, 0), Head = degrees(4, 0, 0),
			RightUpperArm = degrees(165, 0, 4), RightLowerArm = degrees(8, 0, 0),
			LeftUpperArm = degrees(32, 0, -40), LeftLowerArm = degrees(20, 0, 0),
		}),
		frame(0.52, {
			UpperTorso = degrees(-6, 0, 0),
			RightUpperArm = degrees(168, 0, 4),
			RightUpperLeg = degrees(25, 0, 4), RightLowerLeg = degrees(-40, 0, 0), RightFoot = degrees(-20, 0, 0),
			LeftUpperLeg = degrees(30, 0, -4), LeftLowerLeg = degrees(-45, 0, 0), LeftFoot = degrees(-20, 0, 0),
		}),
	},

	-- Deep two-hand load behind the head, heels to the back, violent crunch.
	TwoHandPower = {
		frame(0, {
			LowerTorso = degrees(-12, 0, 0), UpperTorso = degrees(-15, 0, 0), Head = degrees(10, 0, 0),
			RightUpperArm = degrees(45, 0, -15), RightLowerArm = degrees(95, 0, 0), RightHand = degrees(-10, 0, 0),
			LeftUpperArm = degrees(45, 0, 15), LeftLowerArm = degrees(95, 0, 0), LeftHand = degrees(-10, 0, 0),
			RightUpperLeg = degrees(45, 0, 5), RightLowerLeg = degrees(-75, 0, 0), RightFoot = degrees(-15, 0, 0),
			LeftUpperLeg = degrees(45, 0, -5), LeftLowerLeg = degrees(-75, 0, 0), LeftFoot = degrees(-15, 0, 0),
		}),
		frame(0.14, {
			LowerTorso = degrees(-4, 0, 0), UpperTorso = degrees(0, 0, 0), Head = degrees(8, 0, 0),
			RightUpperArm = degrees(110, 0, -10), RightLowerArm = degrees(70, 0, 0),
			LeftUpperArm = degrees(110, 0, 10), LeftLowerArm = degrees(70, 0, 0),
			RightUpperLeg = degrees(60, 0, 5), RightLowerLeg = degrees(-95, 0, 0),
			LeftUpperLeg = degrees(60, 0, -5), LeftLowerLeg = degrees(-95, 0, 0),
		}, OUT),
		frame(0.30, {
			LowerTorso = degrees(8, 0, 0), UpperTorso = degrees(22, 0, 0), Head = degrees(14, 0, 0),
			RightUpperArm = degrees(180, 0, -5), RightLowerArm = degrees(80, 0, 0), RightHand = degrees(-25, 0, 0),
			LeftUpperArm = degrees(180, 0, 5), LeftLowerArm = degrees(80, 0, 0), LeftHand = degrees(-25, 0, 0),
			RightUpperLeg = degrees(10, 0, 6), RightLowerLeg = degrees(-120, 0, 0), RightFoot = degrees(-30, 0, 0),
			LeftUpperLeg = degrees(10, 0, -6), LeftLowerLeg = degrees(-120, 0, 0), LeftFoot = degrees(-30, 0, 0),
		}),
		frame(0.42, {
			UpperTorso = degrees(15, 0, 0),
			RightUpperArm = degrees(175, 0, -4), RightLowerArm = degrees(25, 0, 0),
			LeftUpperArm = degrees(175, 0, 4), LeftLowerArm = degrees(25, 0, 0),
		}),
		frame(0.48, {
			LowerTorso = degrees(-12, 0, 0), UpperTorso = degrees(-28, 0, 0), Head = degrees(-8, 0, 0),
			RightUpperArm = degrees(130, 0, -4), RightLowerArm = degrees(5, 0, 0), RightHand = degrees(40, 0, 0),
			LeftUpperArm = degrees(130, 0, 4), LeftLowerArm = degrees(5, 0, 0), LeftHand = degrees(40, 0, 0),
			RightUpperLeg = degrees(70, 0, 5), RightLowerLeg = degrees(-50, 0, 0),
			LeftUpperLeg = degrees(70, 0, -5), LeftLowerLeg = degrees(-50, 0, 0),
		}, IN),
		frame(0.54, {
			UpperTorso = degrees(-20, 0, 0),
			RightUpperArm = degrees(150, 0, -4), RightLowerArm = degrees(10, 0, 0), RightHand = degrees(10, 0, 0),
			LeftUpperArm = degrees(150, 0, 4), LeftLowerArm = degrees(10, 0, 0), LeftHand = degrees(10, 0, 0),
			RightUpperLeg = degrees(50, 0, 5), RightLowerLeg = degrees(-60, 0, 0),
			LeftUpperLeg = degrees(50, 0, -5), LeftLowerLeg = degrees(-60, 0, 0),
		}, OUT),
		frame(0.60, {
			LowerTorso = degrees(-4, 0, 0), UpperTorso = degrees(-10, 0, 0), Head = degrees(4, 0, 0),
			RightUpperArm = degrees(165, 0, -4), LeftUpperArm = degrees(165, 0, 4),
			RightUpperLeg = degrees(35, 0, 5), RightLowerLeg = degrees(-50, 0, 0),
			LeftUpperLeg = degrees(35, 0, -5), LeftLowerLeg = degrees(-50, 0, 0),
		}),
		frame(0.64, {
			UpperTorso = degrees(-8, 0, 0),
			RightUpperArm = degrees(168, 0, -4), LeftUpperArm = degrees(168, 0, 4),
		}),
	},

	-- Ball cocked far behind the head with a big back arch, then a whip down.
	Tomahawk = {
		frame(0, {
			LowerTorso = degrees(-10, 0, 0), UpperTorso = degrees(-12, 0, 0), Head = degrees(8, 0, 0),
			RightUpperArm = degrees(50, 0, 10), RightLowerArm = degrees(90, 0, 0), RightHand = degrees(-10, 0, 0),
			LeftUpperArm = degrees(45, 0, -15), LeftLowerArm = degrees(80, 0, 0), LeftHand = degrees(-5, 0, 0),
			RightUpperLeg = degrees(40, 0, 4), RightLowerLeg = degrees(-65, 0, 0), RightFoot = degrees(-15, 0, 0),
			LeftUpperLeg = degrees(55, 0, -4), LeftLowerLeg = degrees(-85, 0, 0), LeftFoot = degrees(-20, 0, 0),
		}),
		frame(0.15, {
			LowerTorso = degrees(-2, 0, 0), UpperTorso = degrees(0, 0, 0),
			RightUpperArm = degrees(130, 0, 15), RightLowerArm = degrees(70, 0, 0),
			LeftUpperArm = degrees(100, 0, -25), LeftLowerArm = degrees(40, 0, 0),
			RightUpperLeg = degrees(20, 0, 4), RightLowerLeg = degrees(-40, 0, 0),
			LeftUpperLeg = degrees(80, 0, -4), LeftLowerLeg = degrees(-105, 0, 0),
		}, OUT),
		frame(0.32, {
			LowerTorso = degrees(6, -6, 0), UpperTorso = degrees(20, -12, 4), Head = degrees(10, 6, 0),
			RightUpperArm = degrees(180, 0, 20), RightLowerArm = degrees(95, 0, 0), RightHand = degrees(-30, 0, 0),
			LeftUpperArm = degrees(120, 0, -40), LeftLowerArm = degrees(15, 0, 0),
			RightUpperLeg = degrees(-15, 0, 4), RightLowerLeg = degrees(-95, 0, 0), RightFoot = degrees(-30, 0, 0),
			LeftUpperLeg = degrees(70, 0, -4), LeftLowerLeg = degrees(-95, 0, 0),
		}),
		frame(0.46, {
			LowerTorso = degrees(10, -8, 0), UpperTorso = degrees(30, -16, 5), Head = degrees(14, 8, 0),
			RightUpperArm = degrees(-165, 0, 25), RightLowerArm = degrees(110, 0, 0), RightHand = degrees(-35, 0, 0),
			LeftUpperArm = degrees(130, 0, -50), LeftLowerArm = degrees(10, 0, 0),
			RightUpperLeg = degrees(-25, 0, 4), RightLowerLeg = degrees(-110, 0, 0),
			LeftUpperLeg = degrees(60, 0, -4), LeftLowerLeg = degrees(-80, 0, 0),
		}),
		frame(0.55, {
			UpperTorso = degrees(10, -6, 2),
			RightUpperArm = degrees(175, 0, 15), RightLowerArm = degrees(60, 0, 0),
		}, IN),
		frame(0.60, {
			LowerTorso = degrees(-12, 4, 0), UpperTorso = degrees(-25, 8, -2), Head = degrees(-10, -4, 0),
			RightUpperArm = degrees(130, 0, 10), RightLowerArm = degrees(10, 0, 0), RightHand = degrees(45, 0, 0),
			LeftUpperArm = degrees(40, 0, -60), LeftLowerArm = degrees(30, 0, 0),
			RightUpperLeg = degrees(55, 0, 4), RightLowerLeg = degrees(-45, 0, 0),
			LeftUpperLeg = degrees(40, 0, -4), LeftLowerLeg = degrees(-50, 0, 0),
		}, IN),
		frame(0.66, {
			LowerTorso = degrees(-6, 0, 0), UpperTorso = degrees(-18, 0, 0), Head = degrees(-4, 0, 0),
			RightUpperArm = degrees(150, 0, 8), RightLowerArm = degrees(10, 0, 0), RightHand = degrees(10, 0, 0),
		}, OUT),
		frame(0.72, {
			LowerTorso = degrees(-2, 0, 0), UpperTorso = degrees(-8, 0, 0), Head = degrees(4, 0, 0),
			RightUpperArm = degrees(165, 0, 6), RightLowerArm = degrees(8, 0, 0),
			LeftUpperArm = degrees(35, 0, -45), LeftLowerArm = degrees(20, 0, 0),
			RightUpperLeg = degrees(30, 0, 4), RightLowerLeg = degrees(-45, 0, 0),
			LeftUpperLeg = degrees(30, 0, -4), LeftLowerLeg = degrees(-45, 0, 0),
		}),
		frame(0.76, {
			UpperTorso = degrees(-6, 0, 0),
			RightUpperArm = degrees(168, 0, 4),
		}),
	},

	-- Full backward arm circle (front, hip, behind, over the top) with a split kick.
	Windmill = {
		frame(0, {
			LowerTorso = degrees(-10, 0, 0), UpperTorso = degrees(-10, 0, 0), Head = degrees(6, 0, 0),
			RightUpperArm = degrees(50, 0, 10), RightLowerArm = degrees(80, 0, 0), RightHand = degrees(-10, 0, 0),
			LeftUpperArm = degrees(45, 0, -15), LeftLowerArm = degrees(80, 0, 0), LeftHand = degrees(-5, 0, 0),
			RightUpperLeg = degrees(45, 0, 4), RightLowerLeg = degrees(-70, 0, 0), RightFoot = degrees(-15, 0, 0),
			LeftUpperLeg = degrees(50, 0, -4), LeftLowerLeg = degrees(-80, 0, 0), LeftFoot = degrees(-20, 0, 0),
		}),
		frame(0.12, {
			UpperTorso = degrees(-15, 8, 0),
			RightUpperArm = degrees(30, 0, 25), RightLowerArm = degrees(15, 0, 0),
			LeftUpperArm = degrees(60, 0, -30), LeftLowerArm = degrees(30, 0, 0),
			RightUpperLeg = degrees(70, 0, 4), RightLowerLeg = degrees(-100, 0, 0),
			LeftUpperLeg = degrees(60, 0, -4), LeftLowerLeg = degrees(-100, 0, 0),
		}, OUT),
		frame(0.26, {
			LowerTorso = degrees(0, -4, 0), UpperTorso = degrees(-5, -8, 0),
			RightUpperArm = degrees(-40, 0, 30), RightLowerArm = degrees(10, 0, 0),
			LeftUpperArm = degrees(90, 0, -40), LeftLowerArm = degrees(20, 0, 0),
		}),
		frame(0.40, {
			LowerTorso = degrees(3, -6, 0), UpperTorso = degrees(8, -14, 3), Head = degrees(8, 6, 0),
			RightUpperArm = degrees(-110, 0, 35), RightLowerArm = degrees(10, 0, 0),
			LeftUpperArm = degrees(120, 0, -45), LeftLowerArm = degrees(15, 0, 0),
			RightUpperLeg = degrees(20, 0, 4), RightLowerLeg = degrees(-110, 0, 0), RightFoot = degrees(-30, 0, 0),
			LeftUpperLeg = degrees(80, 0, -4), LeftLowerLeg = degrees(-90, 0, 0),
		}),
		frame(0.54, {
			LowerTorso = degrees(6, -4, 0), UpperTorso = degrees(18, -10, 3), Head = degrees(12, 4, 0),
			RightUpperArm = degrees(-160, 0, 25), RightLowerArm = degrees(15, 0, 0), RightHand = degrees(-25, 0, 0),
			LeftUpperArm = degrees(110, 0, -55), LeftLowerArm = degrees(15, 0, 0),
		}),
		frame(0.64, {
			UpperTorso = degrees(15, -4, 0),
			RightUpperArm = degrees(180, 0, 15), RightLowerArm = degrees(15, 0, 0),
		}),
		frame(0.70, {
			UpperTorso = degrees(10, 0, 0),
			RightUpperArm = degrees(165, 0, 10), RightLowerArm = degrees(10, 0, 0),
		}, IN),
		frame(0.76, {
			LowerTorso = degrees(-12, 0, 0), UpperTorso = degrees(-26, 4, 0), Head = degrees(-8, 0, 0),
			RightUpperArm = degrees(125, 0, 8), RightLowerArm = degrees(5, 0, 0), RightHand = degrees(45, 0, 0),
			LeftUpperArm = degrees(35, 0, -55), LeftLowerArm = degrees(30, 0, 0),
			RightUpperLeg = degrees(60, 0, 4), RightLowerLeg = degrees(-45, 0, 0),
			LeftUpperLeg = degrees(45, 0, -4), LeftLowerLeg = degrees(-55, 0, 0),
		}, IN),
		frame(0.82, {
			LowerTorso = degrees(-6, 0, 0), UpperTorso = degrees(-18, 0, 0), Head = degrees(-4, 0, 0),
			RightUpperArm = degrees(150, 0, 8), RightLowerArm = degrees(10, 0, 0), RightHand = degrees(10, 0, 0),
		}, OUT),
		frame(0.88, {
			LowerTorso = degrees(-2, 0, 0), UpperTorso = degrees(-8, 0, 0), Head = degrees(4, 0, 0),
			RightUpperArm = degrees(165, 0, 6), RightLowerArm = degrees(8, 0, 0),
			LeftUpperArm = degrees(32, 0, -45), LeftLowerArm = degrees(20, 0, 0),
			RightUpperLeg = degrees(30, 0, 4), RightLowerLeg = degrees(-45, 0, 0),
			LeftUpperLeg = degrees(30, 0, -4), LeftLowerLeg = degrees(-45, 0, 0),
		}),
		frame(0.92, {
			UpperTorso = degrees(-6, 0, 0),
			RightUpperArm = degrees(168, 0, 4),
		}),
	},
}
