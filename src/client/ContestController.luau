-- Dunk Contest on the client: keeps the banner in sync with the round state published on
-- ReplicatedStorage.Contest, plays the judges' scorecard for your dunks, and shows the
-- results podium. The server decides everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Contest = require(ReplicatedStorage.Shared.Config.ContestConfig)
local Feedback = require(script.Parent.FeedbackController)
local View = require(script.Parent.ui:WaitForChild("ContestView"))

local ContestController = {}

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- "3d 4h" / "5h 12m" / "9m" until the weekly reset.
local function span(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days, hours, minutes = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
	if days > 0 then return string.format("%dd %dh", days, hours) end
	if hours > 0 then return string.format("%dh %dm", hours, minutes) end
	return string.format("%dm", minutes)
end

local function decode(raw)
	if typeof(raw) ~= "string" or raw == "" then return nil end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and value or nil
end

function ContestController.new(player: Player)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local folder = ReplicatedStorage:WaitForChild("Contest")
	local view = View.new(player:WaitForChild("PlayerGui"))
	local connections = {}
	local lastPhase = folder:GetAttribute("Phase")
	local controller = {}

	local function refresh()
		local phase = folder:GetAttribute("Phase")
		local now = Workspace:GetServerTimeNow()
		if phase == "Open" then
			local left = (folder:GetAttribute("EndsAt") or now) - now
			local best = player:GetAttribute("ContestBest")
			local leader = decode(folder:GetAttribute("Leader"))
			view.SetBanner("DUNK CONTEST  " .. clock(left), string.format("Your best: %s   |   Leader: %s",
				typeof(best) == "number" and (best .. " pts") or "land a dunk!",
				leader and string.format("%s %d", tostring(leader.Name), leader.Score) or "--"),
				left <= 10 and Color3.fromRGB(255, 120, 80) or nil)
		elseif phase == "Idle" then
			local left = (folder:GetAttribute("StartsAt") or math.huge) - now
			if left <= Contest.AnnounceSeconds then
				view.SetBanner("DUNK CONTEST IN " .. clock(left), "Best dunk in " .. Contest.OpenSeconds
					.. "s wins. Judges love Perfect slams and big combos!")
			else
				-- Between rounds: the weekly champion race.
				local top = decode(folder:GetAttribute("WeeklyTop"))
				local champ = type(top) == "table" and top[1] or nil
				local mine = player:GetAttribute("WeeklyBest")
				local reset = span((folder:GetAttribute("WeekEndsAt") or now) - now)
				view.SetBanner(champ and string.format("👑 WEEKLY CHAMP: %s  %d pts", tostring(champ.Name), champ.Score or 0)
					or "👑 WEEKLY CHAMP: open!",
					string.format("Your best this week: %s   |   Resets in %s   |   Next contest %s",
						typeof(mine) == "number" and (mine .. " pts") or "--", reset, clock(left)))
			end
		elseif phase == "Results" then
			view.SetBanner("CONTEST OVER", "Next contest in a few minutes")
		else
			view.SetBanner(nil)
		end
	end

	table.insert(connections, folder:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = folder:GetAttribute("Phase")
		if phase == "Open" and lastPhase ~= "Open" then
			view.HideResults()
			Feedback.ChallengeReady()
		end
		lastPhase = phase
		refresh()
	end))
	table.insert(connections, remotes:WaitForChild("ContestScore").OnClientEvent:Connect(function(cards, sum, best, newBest)
		if type(cards) ~= "table" or type(sum) ~= "number" then return end
		view.ShowScorecard(cards, sum, typeof(best) == "number" and best or sum, newBest == true, function(index)
			Feedback.AirTrick(index)
		end)
		if sum >= Contest.MaxScore then Feedback.PerfectSlam() end
	end))
	table.insert(connections, remotes:WaitForChild("ContestResult").OnClientEvent:Connect(function(mine)
		if type(mine) ~= "table" then return end
		view.ShowResults(decode(folder:GetAttribute("Results")) or {}, mine)
		if mine.Won then Feedback.Rebirth() elseif (mine.Cash or 0) > 0 then Feedback.ChallengeClaim() end
	end))
	table.insert(connections, view.Close.Activated:Connect(view.HideResults))
	for _, attribute in { "Leader", "EndsAt", "StartsAt", "WeeklyTop" } do
		table.insert(connections, folder:GetAttributeChangedSignal(attribute):Connect(refresh))
	end
	table.insert(connections, player:GetAttributeChangedSignal("ContestBest"):Connect(refresh))
	table.insert(connections, player:GetAttributeChangedSignal("WeeklyBest"):Connect(refresh))

	local ticker = task.spawn(function()
		while true do
			task.wait(0.5)
			refresh()
		end
	end)
	refresh()

	function controller.Destroy()
		for _, connection in connections do connection:Disconnect() end
		task.cancel(ticker)
		view.Destroy()
	end

	return controller
end

return ContestController
