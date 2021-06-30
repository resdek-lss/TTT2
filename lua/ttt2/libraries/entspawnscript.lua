---
-- A load of function handling the weapon spawn scripts
-- @author Mineotopia
-- @module entspawnscript

if SERVER then
	AddCSLuaFile()
end

local fileExists = file.Exists
local fileCreateDir = file.CreateDir
local fileWrite = file.Write
local gameGetMap = game.GetMap
local stringFormat = string.format
local pairs = pairs
local tableRemove = table.remove

local spawnEntList = {}

local spawnColors = {
	[SPAWN_TYPE_WEAPON] = Color(0, 175, 175, 255),
	[SPAWN_TYPE_AMMO] = Color(175, 75, 75, 255),
	[SPAWN_TYPE_PLAYER] = Color(75, 175, 50, 255)
}

local spawnData = {
	[SPAWN_TYPE_WEAPON] = {
		[WEAPON_TYPE_RANDOM] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_random"),
			name = "spawn_weapon_random"
		},
		[WEAPON_TYPE_MELEE] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_melee"),
			name = "spawn_weapon_melee"
		},
		[WEAPON_TYPE_NADE] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_nade"),
			name = "spawn_weapon_nade"
		},
		[WEAPON_TYPE_SHOTGUN] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_shotgun"),
			name = "spawn_weapon_shotgun"
		},
		[WEAPON_TYPE_ASSAULT] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_assault"),
			name = "spawn_weapon_assault"
		},
		[WEAPON_TYPE_SNIPER] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_sniper"),
			name = "spawn_weapon_sniper"
		},
		[WEAPON_TYPE_PISTOL] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_pistol"),
			name = "spawn_weapon_pistol"
		},
		[WEAPON_TYPE_SPECIAL] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_special"),
			name = "spawn_weapon_special"
		}
	},
	[SPAWN_TYPE_AMMO] = {
		[AMMO_TYPE_RANDOM] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_random"),
			name = "ammo_type_random"
		},
		[AMMO_TYPE_DEAGLE] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_random"),
			name = "ammo_type_deagle"
		},
		[AMMO_TYPE_PISTOL] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_random"),
			name = "ammo_type_pistol"
		},
		[AMMO_TYPE_MAC10] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_random"),
			name = "ammo_type_mac10"
		},
		[AMMO_TYPE_RIFLE] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_random"),
			name = "ammo_type_rifle"
		},
		[AMMO_TYPE_SHOTGUN] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_random"),
			name = "ammo_type_shotgun"
		}
	},
	[SPAWN_TYPE_PLAYER] = {
		[PLAYER_TYPE_RANDOM] = {
			material = Material("vgui/ttt/tid/tid_big_weapon_random"),
			name = "player_type_random"
		}
	}
}

entspawnscript = entspawnscript or {}

if SERVER then
	util.AddNetworkString("ttt2_remove_spawn_ent")
	util.AddNetworkString("ttt2_add_spawn_ent")
	util.AddNetworkString("ttt2_update_spawn_ent")
	util.AddNetworkString("ttt2_toggle_entspawn_editing")
	util.AddNetworkString("ttt2_entspawn_init")

	local spawndir = "ttt/weaponspawnscripts/"

	function entspawnscript.Exists()
		local mapname = gameGetMap()

		return fileExists(spawndir .. mapname .. ".txt", "DATA")
	end

	function entspawnscript.InitMap()
		local content = ""
		local mapname = gameGetMap()
		local weaponspawns = map.GetWeaponSpawnEntities()
		local ammospawns = map.GetAmmoSpawnEntities()

		fileCreateDir(spawndir)

		content = content .. "\n# weapons\n\n"

		for entType, spawns in pairs(weaponspawns) do
			for i = 1, #spawns do
				local spawn = spawns[i]

				local pos = spawn.pos
				local ang = spawn.ang

				content = content .. stringFormat("%d\t%f %f %f\t%f %f %f", entType, pos.x, pos.y, pos.z, ang.p, ang.y, ang.r) .. "\n"
			end
		end

		content = content .. "\n# ammo\n\n"

		for entType, spawns in pairs(ammospawns) do
			for i = 1, #spawns do
				local spawn = spawns[i]

				local pos = spawn.pos
				local ang = spawn.ang

				content = content .. stringFormat("%d\t%f %f %f\t%f %f %f", entType, pos.x, pos.y, pos.z, ang.p, ang.y, ang.r) .. "\n"
			end
		end

		fileWrite(spawndir .. mapname .. ".txt", content)

		return {
			[SPAWN_TYPE_WEAPON] = weaponspawns,
			[SPAWN_TYPE_AMMO] = ammospawns
		}
	end

	function entspawnscript.SetEditing(ply, state)
		ply:SetNWBool("is_spawn_editing", state)
	end

	function entspawnscript.StreamToClient(ply)
		net.SendStream("TTT2_WeaponSpawnEntities", spawnEntList, ply)
	end

	net.Receive("ttt2_remove_spawn_ent", function(_, ply)
		if not IsValid(ply) or not ply:IsAdmin() then return end

		entspawnscript.RemoveSpawnById(net.ReadUInt(4), net.ReadUInt(4), net.ReadUInt(32))
	end)

	net.Receive("ttt2_add_spawn_ent", function(_, ply)
		if not IsValid(ply) or not ply:IsAdmin() then return end

		entspawnscript.AddSpawn(net.ReadUInt(4), net.ReadUInt(4), net.ReadVector(), net.ReadAngle(), net.ReadUInt(8))
	end)

	net.Receive("ttt2_update_spawn_ent", function(_, ply)
		if not IsValid(ply) or not ply:IsAdmin() then return end

		entspawnscript.UpdateSpawn(net.ReadUInt(4), net.ReadUInt(4), net.ReadUInt(32), net.ReadVector(), net.ReadAngle(), net.ReadUInt(8))
	end)

	net.Receive("ttt2_entspawn_init", function(_, ply)
		if not IsValid(ply) or not ply:IsAdmin() then return end

		entspawnscript.Init(net.ReadBool())
	end)

	net.Receive("ttt2_toggle_entspawn_editing", function(_, ply)
		if not IsValid(ply) or not ply:IsAdmin() then return end

		if net.ReadBool() then
			entspawnscript.StartEditing(ply)
		else
			entspawnscript.StopEditing(ply)
		end
	end)
end

if CLIENT then
	local isEditing = false
	local focusedSpawn = nil
	local spawnInfoEnt = nil

	function entspawnscript.SetFocusedSpawn(spawnType, entType, id, spawn)
		if not spawnType then
			focusedSpawn = nil
		else
			focusedSpawn = {
				spawnType = spawnType,
				entType = entType,
				id = id,
				spawn = spawn
			}
		end
	end

	function entspawnscript.GetFocusedSpawn()
		return focusedSpawn
	end

	function entspawnscript.SetSpawnInfoEntity(ent)
		spawnInfoEnt = ent
	end

	function entspawnscript.GetSpawnInfoEntity()
		return spawnInfoEnt
	end

	net.ReceiveStream("TTT2_WeaponSpawnEntities", function(spawnEnts)
		spawnEntList = spawnEnts
	end)
end

function entspawnscript.IsEditing(ply)
	return ply:GetNWBool("is_spawn_editing", false)
end

function entspawnscript.GetLangIdentifierFromSpawnType(spawnType, entType)
	return spawnData[spawnType][entType].name
end

function entspawnscript.GetColorFromSpawnType(spawnType)
	return spawnColors[spawnType]
end

function entspawnscript.GetIconFromSpawnType(spawnType, entType)
	return spawnData[spawnType][entType].material
end

function entspawnscript.GetSpawnTypeList()
	local indexedTable = {}

	for spawnType, spawns in pairs(spawnData) do
		for entType in pairs(spawns) do
			indexedTable[#indexedTable + 1] = {
				spawnType = spawnType,
				entType = entType
			}
		end
	end

	return indexedTable
end

function entspawnscript.GetSpawnEntities()
	return spawnEntList
end

function entspawnscript.RemoveSpawnById(spawnType, entType, id)
	if not spawnEntList or not spawnEntList[spawnType] or not spawnEntList[spawnType][entType] then return end

	local list = spawnEntList[spawnType][entType]

	tableRemove(list, id)

	if CLIENT then
		net.Start("ttt2_remove_spawn_ent")
		net.WriteUInt(spawnType, 4)
		net.WriteUInt(entType, 4)
		net.WriteUInt(id, 32)
		net.SendToServer()
	end
end

function entspawnscript.AddSpawn(spawnType, entType, pos, ang, ammo)
	spawnEntList = spawnEntList or {}
	spawnEntList[spawnType] = spawnEntList[spawnType] or {}
	spawnEntList[spawnType][entType] = spawnEntList[spawnType][entType] or {}

	local list = spawnEntList[spawnType][entType]

	list[#list + 1] = {
		pos = pos,
		ang = ang,
		ammo = ammo
	}

	if CLIENT then
		net.Start("ttt2_add_spawn_ent")
		net.WriteUInt(spawnType, 4)
		net.WriteUInt(entType, 4)
		net.WriteVector(pos)
		net.WriteAngle(ang)
		net.WriteUInt(ammo, 8)
		net.SendToServer()
	end
end

function entspawnscript.UpdateSpawn(spawnType, entType, id, pos, ang, ammo)
	if not spawnEntList or not spawnEntList[spawnType] or not spawnEntList[spawnType][entType] then return end

	local listEntry = spawnEntList[spawnType][entType]

	if not listEntry[id] then return end

	pos = pos or listEntry[id].pos
	ang = ang or listEntry[id].ang
	ammo = ammo or listEntry[id].ammo

	listEntry[id] = {
		pos = pos,
		ang = ang,
		ammo = ammo
	}

	if CLIENT then
		net.Start("ttt2_update_spawn_ent")
		net.WriteUInt(spawnType, 4)
		net.WriteUInt(entType, 4)
		net.WriteUInt(id, 32)
		net.WriteVector(pos)
		net.WriteAngle(ang)
		net.WriteUInt(ammo, 8)
		net.SendToServer()
	end
end

function entspawnscript.StartEditing(ply)
	if CLIENT then
		net.Start("ttt2_toggle_entspawn_editing")
		net.WriteBool(true)
		net.SendToServer()
	else
		if entspawnscript.IsEditing(ply) then return end

		ply:CacheAndStipWeapons()
		local wep = ply:Give("weapon_ttt_spawneditor")

		wep:Equip()

		entspawnscript.SetEditing(ply, true)
	end
end

function entspawnscript.StopEditing(ply)
	if CLIENT then
		net.Start("ttt2_toggle_entspawn_editing")
		net.WriteBool(false)
		net.SendToServer()
	else
		if not entspawnscript.IsEditing(ply) then return end

		ply:RestoreCachedWeapons()
		ply:StripWeapon("weapon_ttt_spawneditor")

		entspawnscript.SetEditing(ply, false)
	end
end

function entspawnscript.Init(forceReinit)
	if CLIENT then
		net.Start("ttt2_entspawn_init")
		net.WriteBool(forceReinit or false)
		net.SendToServer()
	else
		if forceReinit or not entspawnscript.Exists() then
			spawnEntList = entspawnscript.InitMap()
		else
			spawnEntList = entspawnscript.ReadFile()
		end
	end
end
