-- DUNK PASS logic on the client. Everything shown comes from the server's attributes
-- (PassSeason, PassXp, PassFree, PassPremium, Pass_DunkPass); claims are SeasonRequest calls
-- the server checks. Also: "+N PASS XP" in the action feed, tier-up announcements and the
-- claimable count on the HUD button.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Season = require(ReplicatedStorage.Shared.Config.SeasonConfig)
local Daily = require(ReplicatedStorage.Shared.Config.DailyConfig)
local Crew = require(ReplicatedStorage.Shared.Config.CrewConfig)
local Locker = require(ReplicatedStorage.Shared.Config.LockerConfig)
local Monetization = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local HUDConfig = require(ReplicatedStorage.Shared.Config.HUDConfig)
local View = require(script.Parent.ui:WaitForChild("SeasonView"))
local UI = require(script.Parent.ui:WaitForChild("UIComponents"))
local ActionFeed = require(script.Parent:WaitForChild("ActionFeed"))
local Feedback = require(script.Parent:WaitForChild("FeedbackController"))

local SeasonController = {}

local PASS_XP_COLOR = Color3.fromRGB(255, 170, 60)

local function span(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days, hours, minutes = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
	if days > 0 then return string.format("%dd %dh", days, hours) end
	if hours > 0 then return string.format("%dh %dm", hours, minutes) end
	return string.format("%dm", minutes)
end

local function tierSet(text): { [number]: boolean }
	local set = {}
	for tier in string.gmatch(tostring(text or ""), "%d+") do set[tonumber(tier)] = true end
	return set
end

function SeasonController.new(player: Player, hud)
	local request = ReplicatedStorage.Remotes:WaitForChild("SeasonRequest")
	local view = View.new(player:WaitForChild("PlayerGui"))
	local connections = {}
	local stats = player:WaitForChild("leaderstats")
	local verticalValue = stats:WaitForChild("Vertical") :: IntValue
	local lastXp = tonumber(player:GetAttribute("PassXp"))

	local function season()
		return Season.Get(player:GetAttribute("PassSeason")) or Season.Current(Workspace:GetServerTimeNow())
	end

	local function hasPass(current): boolean
		return current ~= nil and player:GetAttribute("Pass_" .. current.PassKey) == true
	end

	-- Icon, text and colour for a reward.
	local function describe(reward)
		if reward.Cash then
			return "💵", "$" .. UI.Number(reward.Cash * Daily.DunkValue(verticalValue.Value)), HUDConfig.Colors.Gain
		elseif reward.Boost then
			return "⚡", string.format("2x CASH %dm", reward.Boost), HUDConfig.Colors.Gold
		elseif reward.Pack then
			return "🎴", "CREW PACK", Color3.fromRGB(255, 120, 220)
		elseif reward.Shoe then
			local item = Locker.Get("Shoes", reward.Shoe)
			return "👟", item and string.upper(item.Name) or "SHOES", Color3.fromRGB(255, 170, 60)
		elseif reward.Ball then
			local item = Locker.Get("Balls", reward.Ball)
			return "🏀", item and string.upper(item.Name) or "BALL", Color3.fromRGB(255, 170, 60)
		elseif reward.Crew then
			local member = Crew.GetMember(reward.Crew)
			return member and member.Icon or "❔", member and string.upper(member.Name) or "CREW",
				member and Crew.Rarities[member.Rarity].Color or HUDConfig.Colors.Text
		end
		return "❔", "", HUDConfig.Colors.Text
	end

	local function render()
		local current = season()
		local xp = tonumber(player:GetAttribute("PassXp")) or 0
		local reached, into, need = Season.TierForXp(xp)
		local free, premium = tierSet(player:GetAttribute("PassFree")), tierSet(player:GetAttribute("PassPremium"))
		local owned = hasPass(current)
		local claimable = 0
		for tier = 1, Season.MaxTiers do
			local isReached = current ~= nil and tier <= reached
			view.SetTierReached(tier, isReached, tier == reached + 1)
			for _, track in { "Free", "Premium" } do
				local reward = current and current[track][tier] or {}
				local icon, text, color = describe(reward)
				local claimed = (track == "Free" and free or premium)[tier] == true
				local status = claimed and "Claimed" or (not isReached and "Locked") or (track == "Premium" and not owned and "Pass")
					or "Claim"
				if status == "Claim" then claimable += 1 end
				view.SetReward(tier, track, { Icon = icon, Text = text, TextColor = color, Status = status, Reached = isReached })
			end
		end
		local passInfo = current and Monetization.GetPass(current.PassKey)
		local passText = not current and "NO SEASON" or owned and "PREMIUM ✓"
			or ((passInfo and passInfo.Id ~= 0) and "GET DUNK PASS" or "PASS COMING SOON")
		view.SetButtons(claimable, passText, current ~= nil and not owned and passInfo ~= nil and passInfo.Id ~= 0)
		local seasonText = current and string.format("SEASON %s: %s   •   ENDS IN %s", string.sub(current.Id, 2), current.Name,
			span(current.Ends - Workspace:GetServerTimeNow())) or "No season is running. The next one starts soon!"
		view.SetHeader(seasonText, reached, into, need)
		hud.SetPassBadge(claimable)
	end

	for tier, card in view.Cards do
		for _, track in { "Free", "Premium" } do
			table.insert(connections, card[track].Action.Activated:Connect(function()
				if card[track].Action.Active then request:FireServer("Claim", tier, track) end
			end))
		end
	end
	table.insert(connections, view.ClaimAll.Activated:Connect(function()
		if view.ClaimAll.Active then request:FireServer("ClaimAll") end
	end))
	table.insert(connections, view.PassButton.Activated:Connect(function()
		local current = season()
		local passInfo = current and Monetization.GetPass(current.PassKey)
		if view.PassButton.Active and passInfo and passInfo.Id ~= 0 then
			pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, passInfo.Id)
		end
	end))
	table.insert(connections, view.Close.Activated:Connect(function() view.Panel.Visible = false end))
	table.insert(connections, hud.PassButton.Activated:Connect(function()
		view.Panel.Visible = not view.Panel.Visible
		if view.Panel.Visible then
			view.ShowResult(true, "")
			render()
			view.ScrollTo(Season.TierForXp(tonumber(player:GetAttribute("PassXp")) or 0) + 1)
		end
	end))
	table.insert(connections, request.OnClientEvent:Connect(function(kind, a, b)
		if kind == "Claimed" and type(a) == "table" then
			Feedback.ChallengeClaim()
			for _, text in a do
				if type(text) == "string" then ActionFeed.Push("DUNK PASS: " .. text, PASS_XP_COLOR) end
			end
			if view.Panel.Visible then view.ShowResult(true, string.format("Claimed %d reward%s!", #a, #a == 1 and "" or "s")) end
		elseif kind == "Result" and type(b) == "string" then
			if view.Panel.Visible then view.ShowResult(a == true, b) else ActionFeed.Push(b, HUDConfig.Colors.Warning) end
		elseif kind == "TierUp" and type(a) == "number" then
			ActionFeed.Announce(string.format("DUNK PASS TIER %d!", a), PASS_XP_COLOR)
			Feedback.DunkUnlock()
		end
		render()
	end))
	for _, attribute in { "PassSeason", "PassXp", "PassFree", "PassPremium", "Pass_DunkPass" } do
		table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(function()
			if attribute == "PassXp" then
				local xp = tonumber(player:GetAttribute("PassXp")) or 0
				if lastXp and xp > lastXp then
					ActionFeed.Add("passxp", xp - lastXp, function(amount) return "+" .. UI.Number(amount) .. " PASS XP" end, PASS_XP_COLOR)
				end
				lastXp = xp
			end
			render()
		end))
	end
	-- Keep the countdown fresh while the screen is open.
	local ticker = task.spawn(function()
		while true do
			task.wait(30)
			if view.Panel.Visible then render() end
		end
	end)
	render()

	local controller = {}
	function controller.Destroy()
		task.cancel(ticker)
		for _, connection in connections do connection:Disconnect() end
		view.Destroy()
	end
	return controller
end

return SeasonController
