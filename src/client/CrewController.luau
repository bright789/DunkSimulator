-- HYPE CREW menu logic. Everything shown comes from the server's attributes (CrewOwned,
-- CrewEquipped, CrewSlots, CrewCash, CrewTrain, UnlockedCourts, Pass_CrewTriple) and every
-- action is a CrewRequest the server checks. Pack results play as flip reveals, one at a time.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crew = require(ReplicatedStorage.Shared.Config.CrewConfig)
local Courts = require(ReplicatedStorage.Shared.Config.CourtConfig)
local HUDConfig = require(ReplicatedStorage.Shared.Config.HUDConfig)
local View = require(script.Parent.ui:WaitForChild("CrewView"))
local Feedback = require(script.Parent:WaitForChild("FeedbackController"))
local ActionFeed = require(script.Parent:WaitForChild("ActionFeed"))

local CrewController = {}

function CrewController.new(player: Player, hud)
	local request = ReplicatedStorage.Remotes:WaitForChild("CrewRequest")
	local view = View.new(player:WaitForChild("PlayerGui"))
	local connections = {}
	local page = "Packs"
	local reveals = {}
	local revealing = false
	local revealStep: (() -> ())? = nil

	local function owned(): { [string]: number }
		local map = {}
		for memberId, stars in string.gmatch(tostring(player:GetAttribute("CrewOwned") or ""), "([%w_]+):(%d+)") do
			map[memberId] = tonumber(stars)
		end
		return map
	end

	local function equipped(): { string }
		local list = {}
		for memberId in string.gmatch(tostring(player:GetAttribute("CrewEquipped") or ""), "[^,]+") do table.insert(list, memberId) end
		return list
	end

	local function cash(): number
		local stats = player:FindFirstChild("leaderstats")
		local value = stats and stats:FindFirstChild("Cash")
		return value and value.Value or 0
	end

	local function render()
		local mine, wearing = owned(), equipped()
		local slots = tonumber(player:GetAttribute("CrewSlots")) or Crew.Slots
		local count, total = 0, 0
		for memberId in Crew.Members do
			total += 1
			if mine[memberId] then count += 1 end
		end
		view.SetHeader(string.format("CREW BONUS:  +%d%% CASH   +%d%% TRAINING   (%d/%d SLOTS)",
			tonumber(player:GetAttribute("CrewCash")) or 0, tonumber(player:GetAttribute("CrewTrain")) or 0, #wearing, slots),
			string.format("MY CREW  %d/%d", count, total))
		local unlocked = {}
		for courtId in string.gmatch(tostring(player:GetAttribute("UnlockedCourts") or ""), "[^,]+") do unlocked[courtId] = true end
		local money = cash()
		local triple = player:GetAttribute("Pass_CrewTriple") == true
		for packId, pack in Crew.Packs do
			local court = Courts.Get(pack.Court)
			view.SetPack(packId, {
				Unlocked = unlocked[pack.Court] == true or pack.Court == Courts.StartingId,
				CanAfford = money >= pack.Price,
				CanAffordThree = money >= pack.Price * 3,
				HasTriple = triple,
				CourtName = court and court.DisplayName or pack.Court,
			})
		end
		for memberId in Crew.Members do
			local isOn = table.find(wearing, memberId) ~= nil
			view.SetMember(memberId, { Stars = mine[memberId], Equipped = isOn, CanEquip = #wearing < slots })
		end
	end

	local function nextReveal()
		local item = table.remove(reveals, 1)
		if not item then
			revealing = false
			view.HideReveal()
			render()
			return
		end
		revealing = true
		local member = Crew.Members[item.Result.Id]
		view.RevealCard(Crew.Packs[item.Pack].Color, item.Result.Id, item.Result)
		task.delay(0.6, function()
			if member.Rarity == "Legendary" then
				Feedback.Rebirth()
				ActionFeed.Announce("LEGENDARY: " .. string.upper(member.Name) .. "!", Crew.Rarities.Legendary.Color)
			elseif member.Rarity == "Epic" then
				Feedback.DunkUnlock()
			else
				Feedback.ChallengeClaim()
			end
			ActionFeed.Push(string.format("%s %s (%s)", item.Result.New and "NEW!" or "STAR UP!", member.Name, member.Rarity),
				Crew.Rarities[member.Rarity].Color)
		end)
	end
	revealStep = nextReveal

	local function open(packId: string, count: number)
		if revealing then return end
		request:FireServer("Buy", packId, count)
	end

	for packId, card in view.PackCards do
		table.insert(connections, card.Open.Activated:Connect(function() if card.Open.Active then open(packId, 1) end end))
		table.insert(connections, card.OpenThree.Activated:Connect(function() if card.OpenThree.Active then open(packId, 3) end end))
	end
	for memberId, card in view.CrewCards do
		table.insert(connections, card.Action.Activated:Connect(function()
			if not card.Action.Active then return end
			local isOn = table.find(equipped(), memberId) ~= nil
			request:FireServer(isOn and "Unequip" or "Equip", memberId)
		end))
	end
	table.insert(connections, request.OnClientEvent:Connect(function(kind, a, b)
		if kind == "Opened" and type(a) == "string" and type(b) == "table" and Crew.Packs[a] then
			for _, resultInfo in b do
				if type(resultInfo) == "table" and Crew.Members[resultInfo.Id] then
					table.insert(reveals, { Pack = a, Result = resultInfo })
				end
			end
			if not revealing then nextReveal() end
		elseif kind == "Result" and type(b) == "string" then
			if view.Panel.Visible then view.ShowResult(a == true, b) else ActionFeed.Push(b, a == true and HUDConfig.Colors.Gain or HUDConfig.Colors.Warning) end
		end
	end))
	table.insert(connections, view.Reveal.Activated:Connect(function() if revealStep then revealStep() end end))
	table.insert(connections, view.PacksTab.Activated:Connect(function() page = "Packs" view.ShowPage(page) end))
	table.insert(connections, view.CrewTab.Activated:Connect(function() page = "Crew" view.ShowPage(page) end))
	table.insert(connections, view.Close.Activated:Connect(function() view.Panel.Visible = false end))
	table.insert(connections, hud.CrewButton.Activated:Connect(function()
		view.Panel.Visible = not view.Panel.Visible
		if view.Panel.Visible then
			view.ShowResult(true, "")
			render()
		end
	end))
	for _, attribute in { "CrewOwned", "CrewEquipped", "CrewSlots", "CrewCash", "CrewTrain", "UnlockedCourts", "Pass_CrewTriple" } do
		table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(function()
			if view.Panel.Visible and not revealing then render() end
		end))
	end
	local stats = player:WaitForChild("leaderstats")
	table.insert(connections, stats:WaitForChild("Cash").Changed:Connect(function()
		if view.Panel.Visible and not revealing then render() end
	end))
	render()

	local controller = {}
	function controller.Destroy()
		for _, connection in connections do connection:Disconnect() end
		view.Destroy()
	end
	return controller
end

return CrewController
