-- New-player tutorial: grab a ball, dunk (new players start at dunk height), train, then
-- buy the first training upgrade (steps in MilestoneConfig.Tutorial). It reads progress the
-- server already replicates (leaderstats and player attributes), so it needs no saved data
-- of its own: players who finished the steps, or have Rebirthed, never see it. SKIP hides it
-- for the session. Display only; the server logs the matching analytics funnel.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Milestones = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MilestoneConfig"))
local Monetization = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local TutorialView = require(script.Parent:WaitForChild("ui"):WaitForChild("TutorialView"))

local player = Players.LocalPlayer
local view = TutorialView.new(player:WaitForChild("PlayerGui"))

local UPDATE_SECONDS = 0.25
-- How often to look the target up again (it can stream in or the player can change court).
local RETARGET_SECONDS = 2

local skipped = false
local offering = false
-- Seconds after "TUTORIAL COMPLETE!" before the one-time Starter Pack offer (if it's on sale).
local OFFER_DELAY_SECONDS = 6
local OFFER_SECONDS = 14
local wasActive = false
local shownStep = 0
local target: BasePart? = nil
local targetName: string? = nil
local nextRetarget = 0

-- Same fields MilestoneConfig expects, read from what the server replicates. nil until the
-- player's data has loaded.
local function snapshot()
	local leaderstats = player:FindFirstChild("leaderstats")
	local vertical = leaderstats and leaderstats:FindFirstChild("Vertical")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	local trainingLevel = player:GetAttribute("TrainingLevel")
	local totalDunks = player:GetAttribute("TotalDunks")
	if not vertical or not cash or trainingLevel == nil or totalDunks == nil then return nil end
	return {
		Vertical = vertical.Value,
		BestVertical = math.max(player:GetAttribute("BestVertical") or 0, vertical.Value),
		TotalDunks = totalDunks,
		TrainingLevel = trainingLevel,
		Rebirths = player:GetAttribute("Rebirths") or 0,
		ContestWins = player:GetAttribute("ContestWins") or 0,
		Cash = cash.Value,
		HasBall = player:GetAttribute("HasBasketball") == true,
		UnlockedCourts = {},
	}
end

-- Nearest map part with this name (every court has its own stations and hoop).
local function findTarget(name: string, root: BasePart): BasePart?
	local gameplay = Workspace:FindFirstChild("Gameplay")
	if not gameplay then return nil end
	local best, bestDistance = nil, math.huge
	for _, descendant in gameplay:GetDescendants() do
		if descendant.Name == name and descendant:IsA("BasePart") then
			local distance = (descendant.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = descendant, distance
			end
		end
	end
	return best
end

local function clearGuide()
	target, targetName = nil, nil
	view.SetGuide(nil, nil)
end

local function update()
	local state = snapshot()
	local active = state ~= nil and not skipped and Milestones.TutorialActive(state)
	if not active then
		if wasActive and state and not skipped and Milestones.TutorialStepsDone(state) == #Milestones.Tutorial then
			view.ShowComplete()
			local pass = Monetization.GetPass("StarterPack")
			if pass and pass.Id ~= 0 then
				task.delay(OFFER_DELAY_SECONDS, function()
					if player:GetAttribute("Pass_StarterPack") == true then return end
					offering = true
					local contents = pass.Contents
					view.ShowOffer("SPECIAL OFFER", "STARTER PACK", string.format("$%d Cash, 2x Cash for %d min and Sky Risers shoes",
						contents.Cash, contents.BoostMinutes))
					task.delay(OFFER_SECONDS, function()
						if offering then
							offering = false
							view.Hide()
						end
					end)
				end)
			end
		elseif wasActive then
			view.Hide()
		end
		if wasActive then clearGuide() end
		wasActive = false
		shownStep = 0
		return
	end
	wasActive = true
	local index = Milestones.TutorialStepsDone(state) + 1
	local step = Milestones.Tutorial[index]
	local current, goal = nil, nil
	if step.Progress then current, goal = step.Progress(state) end
	view.ShowStep(index, #Milestones.Tutorial, step, current, goal)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		clearGuide()
		return
	end
	local now = os.clock()
	if index ~= shownStep or targetName ~= step.Target or now >= nextRetarget then
		shownStep = index
		nextRetarget = now + RETARGET_SECONDS
		local found = findTarget(step.Target, root)
		if found ~= target or targetName ~= step.Target then
			target, targetName = found, step.Target
			view.SetGuide(root, found, step.Marker)
		end
	end
end

view.SkipButton.Activated:Connect(function()
	if offering then
		offering = false
		view.Hide()
		return
	end
	skipped = true
	view.Hide()
	clearGuide()
end)

view.BuyButton.Activated:Connect(function()
	local pass = Monetization.GetPass("StarterPack")
	offering = false
	view.Hide()
	if pass and pass.Id ~= 0 then MarketplaceService:PromptGamePassPurchase(player, pass.Id) end
end)

player.CharacterAdded:Connect(function()
	-- The guide line is attached to the old character; rebuild it on the next update.
	clearGuide()
end)

while true do
	local ok, problem = pcall(update)
	if not ok then warn("[Tutorial] " .. tostring(problem)) end
	task.wait(UPDATE_SECONDS)
end
