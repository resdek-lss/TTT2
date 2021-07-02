---
-- A load of function handling the weapon spawn
-- @author Mineotopia
-- @module entspawn

if CLIENT then return end -- this is a serverside-ony module

---
-- @realm server
local cvSpawnWaveInterval = CreateConVar("ttt_spawn_wave_interval", "0", {FCVAR_NOTIFY, FCVAR_ARCHIVE})

local pairs = pairs
local Vector = Vector
local VectorRand = VectorRand
local mathRand = math.Rand
local tableRemove = table.remove
local timerCreate = timer.Create
local timerRemove = timer.Remove

entspawn = entspawn or {}

local function RemoveEntities(entTable)
	for _, ents in pairs(entTable) do
		for i = 1, #ents do
			ents[i]:Remove()
		end
	end
end

local function GetRandomEntityFromTable(ents)
	if not ents then return end

	return ents[math.random(#ents)]
end

function entspawn.RemoveMapEntities()
	RemoveEntities(map.GetWeaponSpawnEntities())
	RemoveEntities(map.GetAmmoSpawnEntities())
	RemoveEntities(map.GetPlayerSpawnEntities())
end

function entspawn.SpawnEntities(spawns, entsForTypes, entTable, randomType)
	for entType, spawnTable in pairs(spawns) do
		for i = 1, #spawnTable do
			local spawn = spawnTable[i]

			-- if the weapon spawn is a random weapon spawn, select any spawnable weapon
			local selectedEnt
			if entType == randomType then
				selectedEnt = GetRandomEntityFromTable(entTable)
			else
				selectedEnt = GetRandomEntityFromTable(entsForTypes[entType])
			end

			if not selectedEnt then continue end

			-- create the weapon entity
			local spawnedEnt = ents.Create(WEPS.GetClass(selectedEnt))

			if not IsValid(spawnedEnt) then continue end

			-- set the position and angle of the spawned weapon entity
			spawnedEnt:SetPos(spawn.pos)
			spawnedEnt:SetAngles(spawn.ang)
			spawnedEnt:Spawn()
			spawnedEnt:PhysWake()

			-- if the spawn has a defined auto ammo spawn, the ammo should be spawned now
			if spawn.ammo == 0 or not spawnedEnt.AmmoEnt then continue end

			for k = 1, spawn.ammo do
				local ammoEnt = ents.Create(spawnedEnt.AmmoEnt)

				if not IsValid(ammoEnt) then continue end

				local pos = spawn.pos + Vector(mathRand(-35, 35), mathRand(-35, 35), 25)

				ammoEnt:SetPos(pos)
				ammoEnt:SetAngles(VectorRand():Angle())
				ammoEnt:Spawn()
				ammoEnt:PhysWake()
			end
		end
	end
end

function entspawn.SpawnPlayers(deadOnly)
	local waveDelay = cvSpawnWaveInterval:GetFloat()
	local plys = player.GetAll()

	-- simple method, spawn everybody at once
	if waveDelay <= 0 or deadOnly then
		for i = 1, #plys do
			local ply = plys[i]
			local spawnPoint = plyspawn.GetRandomSafePlayerSpawnPoint(ply)

			ply:SpawnForRound(deadOnly, spawnPoint.pos, spawnPoint.ang)
		end
	else
		-- wave method
		local num_spawns = #plyspawn.GetPlayerSpawnPoints()
		local toSpawn = {}

		for _, ply in RandomPairs(plys) do
			if ply:ShouldSpawn() then
				toSpawn[#toSpawn + 1] = ply

				GAMEMODE:PlayerSpawnAsSpectator(ply)
			end
		end

		local sfn = function()
			local c = 0
			-- fill the available spawnpoints with players that need
			-- spawning

			while c < num_spawns and #toSpawn > 0 do
				for k = 1, #toSpawn do
					local ply = toSpawn[k]
					local spawnPoint = plyspawn.GetRandomSafePlayerSpawnPoint(ply, spawnPoint.pos, spawnPoint.ang)

					if IsValid(ply) and ply:SpawnForRound(deadOnly) then
						-- a spawn ent is now occupied
						c = c + 1
					end
					-- Few possible cases:
					-- 1) player has now been spawned
					-- 2) player should remain spectator after all
					-- 3) player has disconnected
					-- In all cases we don't need to spawn them again.
					tableRemove(toSpawn, k)

					-- all spawn ents are occupied, so the rest will have
					-- to wait for next wave
					if c >= num_spawns then break end
				end
			end

			MsgN("Spawned " .. c .. " players in spawn wave.")

			if #toSpawn == 0 then
				timerRemove("spawnwave")

				MsgN("Spawn waves ending, all players spawned.")
			end
		end

		MsgN("Spawn waves starting.")

		timerCreate("spawnwave", wave_delay, 0, sfn)

		-- already run one wave, which may stop the timer if everyone is spawned in one go
		sfn()
	end
end

function entspawn.HandleSpawns()
	-- in a first pass, all weapon entities are removed
	entspawn.RemoveMapEntities()

	-- in the next tick the new entities are spawned
	timer.Simple(0, function()
		-- SPAWN WEAPONS
		local wepSpawns = entspawnscript.GetSpawnEntitiesForSpawnType(SPAWN_TYPE_WEAPON)
		-- This function returns two tables, the first is ordered by weapon spawn types,
		-- the second is just a normal indexed list with all spawnable weapons. This is
		-- done like this to improve the performance for random weapon spawns.
		local wepsForTypes, weps = WEPS.GetWeaponsForSpawnTypes()

		entspawn.SpawnEntities(wepSpawns, wepsForTypes, weps, WEAPON_TYPE_RANDOM)

		-- SPAWN AMMO
		local ammoSpawns = entspawnscript.GetSpawnEntitiesForSpawnType(SPAWN_TYPE_AMMO)
		-- This function returns two tables, the first is ordered by weapon spawn types,
		-- the second is just a normal indexed list with all spawnable weapons. This is
		-- done like this to improve the performance for random weapon spawns.
		local ammoForTypes, ammo = WEPS.GetAmmoForSpawnTypes()

		entspawn.SpawnEntities(ammoSpawns, ammoForTypes, ammo, AMMO_TYPE_RANDOM)

		-- SPAWN PLAYER
		entspawn.SpawnPlayers(false)
	end)
end
