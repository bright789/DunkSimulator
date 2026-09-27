-- Friends and invites: the INVITE button, the friends-in-server Cash bonus and the
-- one-time referral rewards. Everything is checked and paid on the server (InviteService).
local SocialConfig = {
	-- Dunk and air-trick Cash bonus for each Roblox friend in the same server.
	FriendBonusPerFriend = 0.1,
	MaxFriendBonus = 0.3, -- +30% at most (3 friends)
	-- Invites carry "ref:<inviter UserId>" as launch data (Roblox allows 200 characters).
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
	-- Accounts younger than this (days) can't credit an inviter. Anyone can craft a join link
	-- with "ref:" launch data, so this (plus the friend check and daily cap) slows alt farming.
	MinAccountAgeDays = 7,
	-- Launch data can take a few seconds to arrive after a player joins.
	LaunchDataAttempts = 5,
	LaunchDataRetrySeconds = 2,
	-- Studio only (ignored on live servers), for testing without real friends or invites:
	-- pretend this many friends are online, and/or pretend this player joined with this launch
	-- data (e.g. "ref:123"; the friend and account-age checks are skipped for it). Keep both
	-- off when done.
	StudioPretendFriendsOnline = 0,
	StudioLaunchData = nil,
}

function SocialConfig.FriendMultiplier(friendsOnline: number): number
	return 1 + math.min(math.max(friendsOnline, 0) * SocialConfig.FriendBonusPerFriend, SocialConfig.MaxFriendBonus)
end

return SocialConfig
