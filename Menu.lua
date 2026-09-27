local MainModule = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local DATASTORE_NAME = "MyRPGData_V1"

local ATTACK_COOLDOWN = 0.35
local ATTACK_RANGE = 12

local NPC_DATA = {
	Bandit = {
		Health = 100,
		EXP = 50,
		Beli = 25,
		Respawn = 5,
		Spawn = "BanditSpawn"
	},

	BanditBoss = {
		Health = 500,
		EXP = 250,
		Beli = 150,
		Respawn = 15,
		Spawn = "BossSpawn"
	}
}

local DataStore = DataStoreService:GetDataStore(DATASTORE_NAME)

local cooldowns = {}

--------------------------------------------------
-- UTILITY
--------------------------------------------------

local function createValue(className, name, value, parent)
	local object = Instance.new(className)
	object.Name = name
	object.Value = value
	object.Parent = parent

	return object
end

local function getExpNeeded(level)
	return 100 + ((level - 1) * 50)
end

--------------------------------------------------
-- REMOTES
--------------------------------------------------

local function createRemotes()

	local folder = ReplicatedStorage:FindFirstChild("Remotes")

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

	local names = {
		"Attack",
		"Quest",
		"Teleport",
		"AddStat"
	}

	for _, name in pairs(names) do

		if not folder:FindFirstChild(name) then

			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder

		end

	end

	return folder
end

--------------------------------------------------
-- PLAYER
--------------------------------------------------

local function setupPlayer(player)

	if player:FindFirstChild("leaderstats") then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local level = createValue(
		"IntValue",
		"Level",
		1,
		leaderstats
	)

	local beli = createValue(
		"IntValue",
		"Beli",
		0,
		leaderstats
	)

	local exp = createValue(
		"IntValue",
		"EXP",
		0,
		player
	)

	local statPoints = createValue(
		"IntValue",
		"StatPoints",
		0,
		player
	)

	local melee = createValue(
		"IntValue",
		"Melee",
		1,
		player
	)

	local defense = createValue(
		"IntValue",
		"Defense",
		1,
		player
	)

	local quest = createValue(
		"StringValue",
		"Quest",
		"",
		player
	)

	local questKills = createValue(
		"IntValue",
		"QuestKills",
		0,
		player
	)

	local questMax = createValue(
		"IntValue",
		"QuestMax",
		0,
		player
	)

	------------------------------------------------
	-- LOAD
	------------------------------------------------

	local success, data = pcall(function()
		return DataStore:GetAsync(
			"Player_" .. player.UserId
		)
	end)

	if success and type(data) == "table" then

		level.Value = data.Level or 1
		beli.Value = data.Beli or 0
		exp.Value = data.EXP or 0
		statPoints.Value = data.StatPoints or 0
		melee.Value = data.Melee or 1
		defense.Value = data.Defense or 1

	end

end

--------------------------------------------------
-- SAVE
--------------------------------------------------

local function savePlayer(player)

	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		return
	end

	local data = {
		Level = leaderstats.Level.Value,
		Beli = leaderstats.Beli.Value,
		EXP = player.EXP.Value,
		StatPoints = player.StatPoints.Value,
		Melee = player.Melee.Value,
		Defense = player.Defense.Value
	}

	pcall(function()

		DataStore:SetAsync(
			"Player_" .. player.UserId,
			data
		)

	end)

end

--------------------------------------------------
-- EXP
--------------------------------------------------

local function addEXP(player, amount)

	local exp = player:FindFirstChild("EXP")
	local statPoints = player:FindFirstChild("StatPoints")
	local leaderstats = player:FindFirstChild("leaderstats")

	if not exp or not statPoints or not leaderstats then
		return
	end

	local level = leaderstats.Level

	exp.Value += amount

	while exp.Value >= getExpNeeded(level.Value) do

		exp.Value -= getExpNeeded(level.Value)

		level.Value += 1

		statPoints.Value += 3

	end

end

--------------------------------------------------
-- FIND NPC
--------------------------------------------------

local function getNearestNPC(player)

	local character = player.Character

	if not character then
		return nil
	end

	local root =
		character:FindFirstChild("HumanoidRootPart")

	if not root then
		return nil
	end

	local npcs = workspace:FindFirstChild("NPCs")

	if not npcs then
		return nil
	end

	local nearest = nil
	local nearestDistance = ATTACK_RANGE

	for _, npc in pairs(npcs:GetChildren()) do

		local humanoid =
			npc:FindFirstChildOfClass("Humanoid")

		local npcRoot =
			npc:FindFirstChild("HumanoidRootPart")

		if humanoid and npcRoot and humanoid.Health > 0 then

			local distance =
				(root.Position - npcRoot.Position).Magnitude

			if distance <= nearestDistance then

				nearestDistance = distance
				nearest = npc

			end

		end

	end

	return nearest
end

--------------------------------------------------
-- NPC SETUP
--------------------------------------------------

local function setupNPC(npc)

	local humanoid =
		npc:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return
	end

	if npc:GetAttribute("RPGConnected") then
		return
	end

	npc:SetAttribute("RPGConnected", true)

	humanoid.Died:Connect(function()

		local attacker =
			npc:FindFirstChild("LastAttacker")

		local player = nil

		if attacker and attacker.Value then

			if attacker.Value:IsA("Player") then
				player = attacker.Value
			end

		end

		local data = NPC_DATA[npc.Name]

		if data and player then

			local leaderstats =
				player:FindFirstChild("leaderstats")

			if leaderstats then

				local beli =
					leaderstats:FindFirstChild("Beli")

				if beli then
					beli.Value += data.Beli
				end

			end

			addEXP(player, data.EXP)

			------------------------------------------------
			-- QUEST
			------------------------------------------------

			local quest =
				player:FindFirstChild("Quest")

			local kills =
				player:FindFirstChild("QuestKills")

			local max =
				player:FindFirstChild("QuestMax")

			if quest and kills and max then

				if quest.Value == "Bandit"
					and npc.Name == "Bandit" then

					kills.Value += 1

					if kills.Value >= max.Value then

						if leaderstats then

							leaderstats.Beli.Value += 100

						end

						addEXP(player, 100)

						quest.Value = ""
						kills.Value = 0
						max.Value = 0

					end

				end

			end

		end

		------------------------------------------------
		-- RESPAWN
		------------------------------------------------

		if data then

			local spawnFolder =
				workspace:FindFirstChild("SpawnPoints")

			local spawnPart =
				spawnFolder
				and spawnFolder:FindFirstChild(data.Spawn)

			local oldNPC = npc

			task.delay(data.Respawn, function()

				if not spawnPart then
					return
				end

				local newNPC =
					oldNPC:Clone()

				newNPC:SetAttribute(
					"RPGConnected",
					nil
				)

				newNPC.Parent =
					workspace:FindFirstChild("NPCs")

				local root =
					newNPC:FindFirstChild("HumanoidRootPart")

				if root then

					newNPC:PivotTo(
						spawnPart.CFrame
						+ Vector3.new(0, 3, 0)
					)

				end

				local newHumanoid =
					newNPC:FindFirstChildOfClass("Humanoid")

				if newHumanoid then

					newHumanoid.MaxHealth =
						data.Health

					newHumanoid.Health =
						data.Health

				end

				setupNPC(newNPC)

			end)

		end

		task.wait(0.1)

		if npc then
			npc:Destroy()
		end

	end)

end

--------------------------------------------------
-- REMOTE SYSTEM
--------------------------------------------------

local function setupRemotes(Remotes)

	------------------------------------------------
	-- ATTACK
	------------------------------------------------

	Remotes.Attack.OnServerEvent:Connect(function(player)

		if cooldowns[player] then
			return
		end

		cooldowns[player] = true

		task.delay(
			ATTACK_COOLDOWN,
			function()
				cooldowns[player] = nil
			end
		)

		local npc =
			getNearestNPC(player)

		if not npc then
			return
		end

		local humanoid =
			npc:FindFirstChildOfClass("Humanoid")

		local melee =
			player:FindFirstChild("Melee")

		if not humanoid or not melee then
			return
		end

		local damage =
			20 + melee.Value * 2

		local tag =
			npc:FindFirstChild("LastAttacker")

		if not tag then

			tag = Instance.new("ObjectValue")
			tag.Name = "LastAttacker"
			tag.Parent = npc

		end

		tag.Value = player

		humanoid:TakeDamage(damage)

	end)

	------------------------------------------------
	-- QUEST
	------------------------------------------------

	Remotes.Quest.OnServerEvent:Connect(
		function(player, questName)

			if questName ~= "BanditQuest" then
				return
			end

			local quest =
				player:FindFirstChild("Quest")

			local kills =
				player:FindFirstChild("QuestKills")

			local max =
				player:FindFirstChild("QuestMax")

			if not quest or not kills or not max then
				return
			end

			quest.Value = "Bandit"
			kills.Value = 0
			max.Value = 5

		end
	)

	------------------------------------------------
	-- STAT
	------------------------------------------------

	Remotes.AddStat.OnServerEvent:Connect(
		function(player, statName)

			local points =
				player:FindFirstChild("StatPoints")

			if not points or points.Value <= 0 then
				return
			end

			if statName == "Melee" then

				local melee =
					player:FindFirstChild("Melee")

				if melee then
					melee.Value += 1
					points.Value -= 1
				end

			elseif statName == "Defense" then

				local defense =
					player:FindFirstChild("Defense")

				if defense then
					defense.Value += 1
					points.Value -= 1
				end

			end

		end
	)

	------------------------------------------------
	-- TELEPORT
	------------------------------------------------

	Remotes.Teleport.OnServerEvent:Connect(
		function(player, destination)

			if destination ~= "BanditSpawn"
				and destination ~= "BossSpawn" then
				return
			end

			local character =
				player.Character

			if not character then
				return
			end

			local folder =
				workspace:FindFirstChild("SpawnPoints")

			if not folder then
				return
			end

			local spawnPart =
				folder:FindFirstChild(destination)

			if not spawnPart then
				return
			end

			character:PivotTo(
				spawnPart.CFrame
				+ Vector3.new(0, 4, 0)
			)

		end
	)

end

--------------------------------------------------
-- INITIALIZE
--------------------------------------------------

function MainModule.Start()

	------------------------------------------------
	-- REMOTES
	------------------------------------------------

	local Remotes = createRemotes()

	------------------------------------------------
	-- PLAYER
	------------------------------------------------

	Players.PlayerAdded:Connect(setupPlayer)

	Players.PlayerRemoving:Connect(savePlayer)

	for _, player in pairs(Players:GetPlayers()) do
		setupPlayer(player)
	end

	------------------------------------------------
	-- REMOTES
	------------------------------------------------

	setupRemotes(Remotes)

	------------------------------------------------
	-- NPC
	------------------------------------------------

	local NPCs = workspace:FindFirstChild("NPCs")

	if NPCs then

		for _, npc in pairs(NPCs:GetChildren()) do
			setupNPC(npc)
		end

		NPCs.ChildAdded:Connect(function(npc)
			task.wait()
			setupNPC(npc)
		end)

	end

	------------------------------------------------
	-- CLOSE
	------------------------------------------------

	game:BindToClose(function()

		for _, player in pairs(
			Players:GetPlayers()
		) do

			savePlayer(player)

		end

	end)

	print("================================")
	print("       MY RPG LOADED")
	print("================================")

end

return MainModule
