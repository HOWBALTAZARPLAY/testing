-- PATCH v2 (palitan nito ang v1 kung nailagay mo na)

-- PART 1: ilagay SA ITAAS ng `local function Fish(Active)`

local ConfigWarned = false

local function DumpTable(Value, Depth, Prefix)
	for Key, Item in Value do
		if type(Item) == "table" and Depth > 0 then
			print(`{Prefix}{Key} = table`)
			DumpTable(Item, Depth - 1, Prefix .. "  ")
		else
			print(`{Prefix}{Key} = {tostring(Item)}`)
		end
	end
end

-- Hinahanap ang minigame config (yung may barHeightRatio, treasure, progressLossPerSecond, durationSeconds)
local function FindMinigameConfig(State, Runtime)
	for _, Source in {State, Runtime} do
		if type(Source) == "table" then
			if type(Source.barHeightRatio) == "number" then
				return Source
			end

			for _, Value in Source do
				if type(Value) == "table" and type(Value.barHeightRatio) == "number" then
					return Value
				end
			end
		end
	end
end

-- Returns: target position (0-1), at kung treasure ang hinahabol
local function GetMinigameTarget(State, Runtime, Simulation)
	local FishTarget = Simulation.fish.center + Simulation.fish.velocity * 0.1
	local Config = FindMinigameConfig(State, Runtime)

	if not Config then
		if not ConfigWarned then
			ConfigWarned = true
			warn("[Fishing] Hindi nahanap ang minigame config. Ipadala ang output sa baba:")
			print("=== ATOM ===")
			DumpTable(State, 1, "")
			print("=== RUNTIME ===")
			DumpTable(Runtime, 1, "")
		end

		return FishTarget, false
	end

	local Treasure = Config.treasure
	local Tuning = Fishing.Data.OCEAN_FISHING_TREASURE_TUNING

	-- Walang treasure sa catch na ito, o nakuha na, o hindi pa lumalabas
	if not Treasure or not Tuning or Simulation.treasureCaught or Simulation.elapsedSeconds < Treasure.appearAtSeconds then
		return FishTarget, false
	end

	local Needed = (1 - Simulation.treasureProgress) * Tuning.fillSeconds
	local TimeLeft = Config.durationSeconds and (Config.durationSeconds - Simulation.elapsedSeconds) or math.huge

	-- Kulang na ang oras para mapuno
	if TimeLeft < Needed + 0.3 then
		return FishTarget, false
	end

	-- Safe lang umalis sa isda kung kaya ng progress bar na tumagal habang pinupuno ang treasure
	local Loss = Config.progressLossPerSecond
	local Safe

	if Loss and Loss > 0 then
		Safe = Simulation.progress / Loss > Needed + 0.8
	else
		Safe = Simulation.progress > 0.35
	end

	if Safe then
		return Treasure.center, true
	end

	return FishTarget, false
end

-- PART 2: palitan ang `elseif State.phase == "minigame" then ...` block sa loob ng Fish() nito:

		elseif State.phase == "minigame" then
			local Runtime = Fishing.Runtime()
			local Simulation = Runtime.state

			if Simulation then
				local Target, ChasingTreasure = GetMinigameTarget(State, Runtime, Simulation)
				local PredictedBar = Simulation.barCenter + Simulation.barVelocity * 0.12

				Fishing.Runner.setFishingMinigameUseHeld(PredictedBar > Target)
				Fishing.Status = `{ChasingTreasure and "Treasure" or "Reeling"}: fish {math.floor(Simulation.progress * 100)}% | chest {math.floor(Simulation.treasureProgress * 100)}%`
			end
