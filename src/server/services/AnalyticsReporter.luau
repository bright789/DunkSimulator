-- Sends gameplay analytics (Creator Hub -> Analytics) through AnalyticsService: Cash
-- sources and sinks (economy), the new-player onboarding funnel, the progression funnel and
-- a few custom events. Server only. Every call is protected, so analytics can never break
-- gameplay, and nothing here changes player data.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.Config.AnalyticsConfig)

local AnalyticsReporter = {}
local isStudio = RunService:IsStudio()
local initialized = false
-- Batched frequent sources: [player] = { [sku] = { Amount = n, TransactionType = name } }
local pending: { [Player]: { [string]: { Amount: number, TransactionType: string } } } = {}
local lastBalance: { [Player]: number } = {}

local function send(label: string, method: string, ...)
	if isStudio then
		if Config.StudioPrint then print("[Analytics] " .. label) end
		return
	end
	local ok, problem = pcall(AnalyticsService[method], AnalyticsService, ...)
	if not ok then warn("[Analytics] " .. method .. " failed: " .. tostring(problem)) end
end

local function economy(player: Player, flow: Enum.AnalyticsEconomyFlowType, amount: number, endingBalance: number,
	transactionType: string, sku: string)
	send(string.format("%s %s %s $%d (balance $%d) %s", player.Name, flow.Name, transactionType, amount, endingBalance, sku),
		"LogEconomyEvent", player, flow, Config.CurrencyName, amount, endingBalance, transactionType, sku)
end

local function validAmount(amount): boolean
	return type(amount) == "number" and amount == amount and amount > 0 and amount < math.huge
end

-- Cash gained. `transactionType` is an Enum.AnalyticsEconomyTransactionType name ("Gameplay",
-- "TimedReward", "Shop", "Onboarding", ...). `batch` adds it to the player's running total for
-- `sku` instead of sending it now (use for dunks and air tricks).
function AnalyticsReporter.CashEarned(player: Player, amount: number, endingBalance: number, transactionType: string,
	sku: string, batch: boolean?)
	if not validAmount(amount) then return end
	lastBalance[player] = endingBalance
	if batch then
		local totals = pending[player]
		if not totals then
			totals = {}
			pending[player] = totals
		end
		local entry = totals[sku]
		if entry then
			entry.Amount += amount
		else
			totals[sku] = { Amount = amount, TransactionType = transactionType }
		end
		return
	end
	economy(player, Enum.AnalyticsEconomyFlowType.Source, amount, endingBalance, transactionType, sku)
end

-- Cash spent (courts, upgrades, Locker items, Rebirth).
function AnalyticsReporter.CashSpent(player: Player, amount: number, endingBalance: number, transactionType: string, sku: string)
	if not validAmount(amount) then return end
	lastBalance[player] = endingBalance
	economy(player, Enum.AnalyticsEconomyFlowType.Sink, amount, endingBalance, transactionType, sku)
end

-- Sends the player's batched totals (one event per sku).
function AnalyticsReporter.Flush(player: Player)
	local totals = pending[player]
	pending[player] = nil
	if not totals then return end
	local balance = lastBalance[player] or 0
	for sku, entry in totals do
		economy(player, Enum.AnalyticsEconomyFlowType.Source, math.floor(entry.Amount), balance, entry.TransactionType, sku)
	end
end

-- One-time new-player funnel. Repeated steps are ignored by Roblox, and a later step also
-- counts the earlier ones as reached.
function AnalyticsReporter.OnboardingStep(player: Player, step: number, stepName: string)
	send(string.format("%s onboarding step %d %s", player.Name, step, stepName),
		"LogOnboardingFunnelStepEvent", player, step, stepName)
end

-- One-time progression funnel (MilestoneConfig.Progression).
function AnalyticsReporter.ProgressionStep(player: Player, step: number, stepName: string)
	send(string.format("%s progression step %d %s", player.Name, step, stepName),
		"LogFunnelStepEvent", player, Config.ProgressionFunnel, nil, step, stepName)
end

function AnalyticsReporter.Custom(player: Player, eventName: string, value: number?)
	send(string.format("%s custom %s %s", player.Name, eventName, tostring(value or 1)),
		"LogCustomEvent", player, eventName, value or 1)
end

function AnalyticsReporter.Init()
	if initialized then return end
	initialized = true
	Players.PlayerRemoving:Connect(function(player)
		AnalyticsReporter.Flush(player)
		lastBalance[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.BatchFlushSeconds)
			for player in pending do
				AnalyticsReporter.Flush(player)
			end
		end
	end)
end

return AnalyticsReporter
