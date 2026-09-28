-- INVITE button: opens Roblox's friend invite prompt with this player's id as launch data,
-- shows the friends-in-server Cash bonus on the button, and pops up referral rewards the
-- server paid (SocialNotice). Display and prompt only; InviteService decides every reward.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local GroupService = game:GetService("GroupService")

local Config = require(ReplicatedStorage.Shared.Config.SocialConfig)
local UI = require(script.Parent.ui:WaitForChild("UIComponents"))
local RewardPresentation = require(script.Parent.ui:WaitForChild("RewardPresentation"))
local Feedback = require(script.Parent.FeedbackController)

local InviteController = {}

function InviteController.new(player: Player, hud)
	local screen = UI.Screen("Social", 9)
	screen.Parent = player:WaitForChild("PlayerGui")
	local popup = RewardPresentation.new(screen)
	local connections = {}
	local prompting = false

	local function refreshBonus()
		hud.SetFriendBonus(player:GetAttribute("FriendBonusPercent") or 0)
	end
	table.insert(connections, player:GetAttributeChangedSignal("FriendBonusPercent"):Connect(refreshBonus))
	refreshBonus()

	-- Community group button (hidden until SocialConfig.GroupId is set).
	local groupPercent = math.floor(Config.GroupBonus * 100 + 0.5)
	local function refreshGroup()
		hud.SetGroup(Config.GroupId ~= 0 and player:GetAttribute("InGroup") ~= nil, player:GetAttribute("InGroup") == true, groupPercent)
	end
	table.insert(connections, player:GetAttributeChangedSignal("InGroup"):Connect(refreshGroup))
	refreshGroup()
	local joining = false
	table.insert(connections, hud.GroupButton.Activated:Connect(function()
		if joining or Config.GroupId == 0 or player:GetAttribute("InGroup") == true then return end
		joining = true
		task.spawn(function()
			local ok, status = pcall(GroupService.PromptJoinAsync, GroupService, Config.GroupId)
			if ok and (status == Enum.GroupMembershipStatus.Joined or status == Enum.GroupMembershipStatus.AlreadyMember) then
				ReplicatedStorage.Remotes.GroupRequest:FireServer("Check")
			elseif ok and status == Enum.GroupMembershipStatus.JoinRequestPending then
				popup.Show("GROUP", "REQUEST SENT", "The bonus starts once your join request is accepted.", false)
			end
			joining = false
		end)
	end))

	table.insert(connections, hud.InviteButton.Activated:Connect(function()
		if prompting then return end
		prompting = true
		task.spawn(function()
			local ok, canSend = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
			if ok and canSend then
				local options = Instance.new("ExperienceInviteOptions")
				options.PromptMessage = Config.PromptMessage
				options.LaunchData = Config.LaunchPrefix .. tostring(player.UserId)
				local shown = pcall(SocialService.PromptGameInvite, SocialService, player, options)
				if not shown then popup.Show("INVITE", "INVITES UNAVAILABLE", "Try again in a moment.", false) end
			else
				popup.Show("INVITE", "INVITES UNAVAILABLE", "Your account can't send invites right now.", false)
			end
			prompting = false
		end)
	end))

	table.insert(connections, ReplicatedStorage.Remotes:WaitForChild("SocialNotice").OnClientEvent:Connect(function(kind, data)
		if type(data) ~= "table" then return end
		if kind == "InviteeReward" and type(data.Minutes) == "number" then
			local who = type(data.Inviter) == "string" and data.Inviter or "A friend"
			popup.Show("FRIEND INVITE", "WELCOME!", string.format("%s invited you: 2x Cash for %d min!", who, data.Minutes), true)
			Feedback.ChallengeReady()
		elseif kind == "InviterReward" and type(data.Cash) == "number" and type(data.Minutes) == "number" then
			local title = type(data.Friend) == "string" and (data.Friend .. " JOINED!")
				or (data.Count == 1 and "A FRIEND JOINED!" or string.format("%d FRIENDS JOINED!", data.Count or 1))
			popup.Show("INVITE REWARD", title, string.format("+$%s and 2x Cash for %d min", UI.Number(data.Cash), data.Minutes), true)
			Feedback.ChallengeReady()
		elseif kind == "WeeklyChampion" and type(data.Cash) == "number" and type(data.Minutes) == "number" then
			-- Sent by WeeklyChampionService: last week's #1 collects their prize.
			popup.Show("WEEKLY CHAMPION", "👑 YOU WON LAST WEEK!", string.format("+$%s and 2x Cash for %d min",
				UI.Number(data.Cash), data.Minutes), true)
			Feedback.Rebirth()
		elseif kind == "WelcomeBack" and type(data.Cash) == "number" and type(data.Seconds) == "number" then
			-- Sent by WelcomeBackService: fans earned Cash while you were away.
			local hours, minutes = data.Seconds // 3600, (data.Seconds % 3600) // 60
			local away = hours > 0 and string.format("%dh %dm", hours, minutes) or string.format("%dm", minutes)
			local note = data.Vip == true and "VIP doubled it!" or "VIP players get 2x!"
			if data.Capped == true then note = "(8 hours max) " .. note end
			popup.Show("WELCOME BACK", "YOUR FANS EARNED $" .. UI.Number(data.Cash),
				string.format("You were away %s. %s", away, note), true, 4.5)
			Feedback.ChallengeClaim()
		elseif kind == "StarterPack" and type(data.Cash) == "number" and type(data.Minutes) == "number" then
			-- Sent by MonetizationService once the Starter Pack is granted.
			popup.Show("STARTER PACK", "UNLOCKED!", string.format("+$%s, 2x Cash for %d min and Sky Risers in your Locker",
				UI.Number(data.Cash), data.Minutes), true)
			Feedback.ChallengeClaim()
		end
	end))

	local controller = {}
	function controller.Destroy()
		for _, connection in connections do connection:Disconnect() end
		popup.Destroy()
		screen:Destroy()
	end
	return controller
end

return InviteController
