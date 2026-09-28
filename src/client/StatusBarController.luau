-- Top status stack: the NEXT goal bar and the HEAT pill (see ui/StatusBarView).
-- The goal is worked out from your replicated stats, in this order:
--   1. the next dunk style you can reach on this court ("NEXT DUNK: TOMAHAWK 62 / 75 VERT"),
--   2. if you're maxed here but have a higher court, go train there,
--   3. the next court to unlock (its Vertical, then its Cash),
--   4. the next Rebirth.
-- At HEAT 5 your court's rim burns (local only). While the new-player tutorial panel is up
-- (it sits in the same spot and shows its own goal) the stack stays hidden. Display only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Styles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local Rebirths = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local Heat = require(ReplicatedStorage.Shared.Config.HeatConfig)
local View = require(script.Parent.ui:WaitForChild("StatusBarView"))
local UI = require(script.Parent.ui:WaitForChild("UIComponents"))
local DunkVFX = require(script.Parent:WaitForChild("DunkVFX"))

local StatusBarController = {}

local function orderedCourts()
	local list = {}
	for _, court in Courts.Definitions do table.insert(list, court) end
	table.sort(list, function(a, b) return a.Order < b.Order end)
	return list
end

function StatusBarController.new(player: Player)
	local view = View.new(player:WaitForChild("PlayerGui"))
	local stats = player:WaitForChild("leaderstats")
	local verticalValue = stats:WaitForChild("Vertical") :: IntValue
	local cashValue = stats:WaitForChild("Cash") :: IntValue
	local courts = orderedCourts()
	local heatFire: Fire? = nil

	local function unlockedCourts(): { [string]: boolean }
		local set = {}
		for courtId in string.gmatch(tostring(player:GetAttribute("UnlockedCourts") or ""), "[^,]+") do set[courtId] = true end
		return set
	end

	local function verticalGoal(title: string, vertical: number, target: number)
		return title, string.format("%s / %s VERT", UI.Number(vertical), UI.Number(target)), vertical / target
	end

	local function cashGoal(title: string, cash: number, target: number)
		return title, string.format("$%s / $%s", UI.Number(cash), UI.Number(target)), cash / target
	end

	local function nextGoal(): (string, string, number)
		local vertical, cash = verticalValue.Value, cashValue.Value
		local here = Courts.Get(player:GetAttribute("CurrentCourt"))
		local cap = here and here.TrainingVerticalCap or math.huge
		local unlocked = unlockedCourts()
		for _, styleId in Styles.OrderedIds() do
			local style = Styles.Get(styleId)
			if vertical < style.RequiredVertical then
				if style.RequiredVertical <= cap then
					return verticalGoal("NEXT DUNK: " .. string.upper(style.DisplayName), vertical, style.RequiredVertical)
				end
				break
			end
		end
		if vertical >= cap then
			for _, court in courts do
				if unlocked[court.Id] and court.TrainingVerticalCap > cap then
					return "MAXED HERE! TRAIN AT " .. string.upper(court.DisplayName), "", 1
				end
			end
		end
		for _, court in courts do
			if not unlocked[court.Id] then
				local title = "UNLOCK " .. string.upper(court.DisplayName)
				if vertical < court.Requirements.Vertical then
					return verticalGoal(title, vertical, court.Requirements.Vertical)
				end
				return cashGoal(title, cash, court.Requirements.Cash)
			end
		end
		local requirement = Rebirths.Requirement(tonumber(player:GetAttribute("Rebirths")) or 0)
		if vertical < requirement.Vertical then return verticalGoal("NEXT: REBIRTH", vertical, requirement.Vertical) end
		return cashGoal("NEXT: REBIRTH", cash, requirement.Cash)
	end

	local function setHoopFire(on: boolean)
		local rim = on and DunkVFX.FindRim(player) or nil
		if heatFire and (not rim or heatFire.Parent ~= rim) then
			heatFire:Destroy()
			heatFire = nil
		end
		if rim and not heatFire then
			local fire = Instance.new("Fire")
			fire.Name = "LocalHeatFire"
			fire.Size = 6
			fire.Heat = 9
			fire.Color = Heat.Colors[#Heat.Colors]
			fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
			fire.Parent = rim
			heatFire = fire
		end
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local function tutorialShowing(): boolean
		local tutorial = playerGui:FindFirstChild("Tutorial")
		local step = tutorial and tutorial:FindFirstChild("Step")
		return tutorial ~= nil and tutorial:IsA("ScreenGui") and tutorial.Enabled
			and step ~= nil and step:IsA("GuiObject") and step.Visible
	end

	local ticker = task.spawn(function()
		while true do
			local hidden = tutorialShowing()
			local dunking = player:GetAttribute("DunkState") == "Executing"
			local ok, title, progress, fraction = pcall(nextGoal)
			view.SetGoal(ok and not dunking and not hidden, title, progress, fraction)
			local level = tonumber(player:GetAttribute("Heat"))
			local untilTime = tonumber(player:GetAttribute("HeatUntil"))
			if level and untilTime and not hidden then
				local left = math.max(0, untilTime - Workspace:GetServerTimeNow())
				view.SetHeat(level, Heat.Names[level], Heat.Multipliers[level], left / Heat.WindowSeconds, Heat.Colors[level])
			else
				view.SetHeat(nil)
			end
			setHoopFire(level == #Heat.Multipliers)
			task.wait(0.1)
		end
	end)

	local controller = {}
	function controller.Destroy()
		task.cancel(ticker)
		setHoopFire(false)
		view.Destroy()
	end
	return controller
end

return StatusBarController
