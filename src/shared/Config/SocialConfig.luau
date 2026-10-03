-- Friends and invites: the INVITE button, the friends-in-server Cash bonus and the
-- one-time referral rewards. Everything is checked and paid on the server (InviteService).
local SocialConfig = {
	-- Dunk and air-trick Cash bonus for each Roblox friend in the same server.
	FriendBonusPerFriend = 0.1,
	MaxFriendBonus = 0.3, -- +30% at most (3 friends)
	-- Who invited a player comes from Roblox's referral system first
	-- (Player:GetJoinData().ReferredByPlayerId, set by Roblox for every kind of invite: the
	-- INVITE button, Roblox's own invite menu, share links and the Referral Rewards banner).
	-- Older INVITE-button invites also carry "ref:<inviter UserId>" as launch data (Roblox
	-- allows 200 characters), used when ReferredByPlayerId is missing.
	LaunchPrefix = "ref:",
	PromptMessage = "Invite friends to dunk with you! You both get a 2x Cash Boost when they join.",
	-- A friend who joins through your invite for the first time (a fresh player who hasn't
	-- dunked or Rebirthed yet) gets a Cash Boost; you get Cash worth this many dunks at your
	-- current Vertical plus a Cash Boost. Paid right away if you're in the same server,
	-- otherwise the next time you join.
	InviteeBoostMinutes = 15,
	InviterRewardDunks = 20,
	InviterBoostMinutes = 15,
	-- Referral rewards an inviter can earn per UTC day.
	MaxInviterRewardsPerDay = 5,
	-- Accounts younger than this (days) can't credit an inviter, whichever way they were
	-- invited. Anyone can craft a join link with "ref:" launch data, so those invites also
	-- need the invitee to be the inviter's Roblox friend; ReferredByPlayerId is set by Roblox
	-- itself and can't be faked, so it skips the friend check (share links reach non-friends).
	MinAccountAgeDays = 7,
	-- Community group: members earn GroupBonus extra dunk and air-trick Cash. The HUD button
	-- opens Roblox's join prompt. 0 = no group yet (button hidden, no bonus).
	GroupId = 292818851, -- Dunk Simulator Official
	GroupBonus = 0.1,
	-- Roblox Premium members earn this much extra dunk and air-trick Cash (PremiumService).
	-- Roblox also pays the game more the longer Premium members play (Premium Payouts).
	PremiumBonus = 0.1,
	GroupRecheckSeconds = 10,
	-- Launch data can take a few seconds to arrive after a player joins.
	LaunchDataAttempts = 5,
	LaunchDataRetrySeconds = 2,
	-- Studio only (ignored on live servers), for testing without real friends or invites:
	-- pretend this many friends are online, and/or pretend this player joined with this launch
	-- data (e.g. "ref:123") or this ReferredByPlayerId (e.g. 123); the friend and account-age
	-- checks are skipped for both. Keep them all off when done.
	StudioPretendFriendsOnline = 0,
	-- Studio only: treat the player as a group member (needs a GroupId set).
	StudioPretendInGroup = false,
	-- Studio only: treat the player as a Roblox Premium member.
	StudioPretendPremium = false,
	StudioLaunchData = nil,
	StudioReferredBy = nil,
}

function SocialConfig.FriendMultiplier(friendsOnline: number): number
	return 1 + math.min(math.max(friendsOnline, 0) * SocialConfig.FriendBonusPerFriend, SocialConfig.MaxFriendBonus)
end

return SocialConfig
