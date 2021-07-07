SWEP.Base = "weapon_tttbase"

if CLIENT then
	SWEP.ViewModelFOV = 45
	SWEP.DrawCrosshair = false
	SWEP.ViewModelFlip = false

	SWEP.EquipMenuData = {
		type = "item_weapon",
		name = "xxx",
		desc = "xxx"
	}

	--SWEP.Icon = "vgui/ttt/icon_doorlocker"
end

SWEP.Kind = WEAPON_EQUIP2
SWEP.CanBuy = {}
SWEP.notBuyable = true
SWEP.AutoSpawnable = false

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_toolgun.mdl"
SWEP.WorldModel = "models/weapons/w_toolgun.mdl"

SWEP.AutoSpawnable = false
SWEP.NoSights = true

SWEP.HoldType = "pistol"
SWEP.LimitedStock = true

SWEP.Primary.Recoil = 0
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 0.5
SWEP.Primary.Ammo = "none"

SWEP.Secondary.Recoil = 0
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 0.5

SWEP.lastReload = 0

SWEP.AllowDrop = false

local previewData = {}

if SERVER then
	util.AddNetworkString("weapon_ttt_spawneditor_spawninfo_ent")

	function SWEP:Deploy()
		-- add entity which is used for the targetID integration
		self.entSpawnInfo = ents.Create("ttt_spawninfo_ent")
		self.entSpawnInfo:Spawn()

		timer.Simple(0, function()
			if not IsValid(self) or not IsValid(self.entSpawnInfo) then return end

			net.Start("weapon_ttt_spawneditor_spawninfo_ent")
			net.WriteEntity(self.entSpawnInfo)
			net.Send(self:GetOwner())
		end)

		self.BaseClass.Deploy(self)
	end

	function SWEP:OnRemove()
		-- using the on remove hook to store the updated spawns because it is called in the following scenarios:
		-- * manual stop of the spawn edit process
		-- * stop of the spawn edit process triggered by a death
		-- * stop of the spawn edit process triggered by a new round
		-- * stop of the spawn edit process triggered by a mapchange
		entspawnscript.UpdateSpawnFile()

		-- remove entity which is used for the targetID integration
		if not IsValid(self.entSpawnInfo) then return end

		self.entSpawnInfo:Remove()
	end

	function SWEP:OnDrop()
		self:Remove()
	end
end

local maxEditDistance = 1500

if CLIENT then
	local draw = draw
	local camStart2D = cam.Start2D
	local camEnd2D = cam.End2D
	local camStart3D2D = cam.Start3D2D
	local camEnd3D2D = cam.End3D2D
	local renderPushRenderTarget = render.PushRenderTarget
	local renderSetColorMaterial = render.SetColorMaterial
	local renderDrawSphere = render.DrawSphere
	local camStart3D = cam.Start3D
	local camEnd3D = cam.End3D
	local EyeAngles = EyeAngles
	local Vector = Vector
	local mathPi = math.pi
	local mathTan = math.tan
	local ColorAlpha = ColorAlpha

	local centerX = 0.5 * ScrW()
	local centerY = 0.5 * ScrH()
	local sphereRadius = 10
	local tolerance = 32 * sphereRadius

	local colorPreview = Color(255, 255, 255, 100)

	local function IsHighlighted(pos, scPos)
		local dist3d = LocalPlayer():EyePos():Distance(pos)

		if dist3d > maxEditDistance then
			return false, dist3d
		end

		if math.Distance(scPos.x, scPos.y, centerX, centerY) > tolerance * ScrW() / LocalPlayer():GetFOV() / dist3d then
			return false, dist3d
		end

		return true, dist3d
	end

	local function PaintSpawns(spawnType, entTable, color, proximitySpawns)
		local scPos

		for entType, spawns in pairs(entTable) do
			for i = 1, #spawns do
				local spawn = spawns[i]
				local pos = spawn.pos

				-- the scPos has to be calculatet inside a non modified cam3D space
				-- to yield correct results
				camStart3D()
					scPos = pos:ToScreen()
				camEnd3D()

				local isHighlighted, dist3d = IsHighlighted(pos, scPos)

				if util.IsOffScreen(scPos) or dist3d > maxEditDistance then continue end

				if not isHighlighted then
					renderDrawSphere(pos, 10, 4 + 750 / dist3d, 4 + 750 / dist3d, color)
				else
					proximitySpawns[#proximitySpawns + 1] = {
						entType = entType,
						spawnType = spawnType,
						spawn = spawn,
						dist3d = dist3d,
						scPos = scPos,
						id = i
					}
				end
			end
		end
	end

	local function RenderHook()
		entspawnscript.SetFocusedSpawn(nil)

		local spawnEntList = entspawnscript.GetSpawns()

		if not spawnEntList then return end

		local weps = spawnEntList[SPAWN_TYPE_WEAPON] or {}
		local ammo = spawnEntList[SPAWN_TYPE_AMMO] or {}
		local plys = spawnEntList[SPAWN_TYPE_PLAYER] or {}

		local proximitySpawns = {}

		renderSetColorMaterial()

		local colorWeapon = ColorAlpha(entspawnscript.GetColorFromSpawnType(SPAWN_TYPE_WEAPON), 100)
		local colorAmmo = ColorAlpha(entspawnscript.GetColorFromSpawnType(SPAWN_TYPE_AMMO), 100)
		local colorPlayer = ColorAlpha(entspawnscript.GetColorFromSpawnType(SPAWN_TYPE_PLAYER), 100)

		-- draw spawn bubbles and put bubbles that might be highlighted in
		-- the 'proximitySpawns' table
		PaintSpawns(SPAWN_TYPE_WEAPON, weps, colorWeapon, proximitySpawns)
		PaintSpawns(SPAWN_TYPE_AMMO, ammo, colorAmmo, proximitySpawns)
		PaintSpawns(SPAWN_TYPE_PLAYER, plys, colorPlayer, proximitySpawns)

		-- sort the proximity spawns by distance
		table.sort(proximitySpawns, function(a, b)
			return a.dist3d < b.dist3d
		end)

		-- draw the proximity spawns and highlight teh first one
		for i = 1, #proximitySpawns do
			local proximitySpawn = proximitySpawns[i]
			local spawn = proximitySpawn.spawn
			local spawnType = proximitySpawn.spawnType
			local pos = proximitySpawn.spawn.pos
			local entType = proximitySpawn.entType
			local id = proximitySpawn.id
			local dist3d = proximitySpawn.dist3d
			local color

			scPos = proximitySpawn.scPos

			if spawnType == SPAWN_TYPE_WEAPON then
				color = colorWeapon
			elseif spawnType == SPAWN_TYPE_AMMO then
				color = colorAmmo
			elseif spawnType == SPAWN_TYPE_PLAYER then
				color = colorPlayer
			end

			if i == 1 then
				local client = LocalPlayer()

				-- make sure there is nothingin the way
				local trace = util.TraceLine({
					start = client:EyePos(),
					endpos = pos,
					filter = {client},
					mask = MASK_SOLID
				})

				if not trace.HitWorld then
					entspawnscript.SetFocusedSpawn(spawnType, entType, id, spawn)
				end

				renderDrawSphere(pos, sphereRadius * (trace.HitWorld and 1 or 1.1), 4 + 750 / dist3d, 4 + 750 / dist3d, ColorAlpha(color, 245))
			else
				renderDrawSphere(pos, sphereRadius, 4 + 750 / dist3d, 4 + 750 / dist3d, ColorAlpha(color, 100))
			end
		end

		if not previewData.inRange then return end

		local colorSphere

		if previewData.inPlacement then
			colorSphere = ColorAlpha(entspawnscript.GetColorFromSpawnType(previewData.spawnType), 245)

			-- render circle on ground
			camStart3D2D(
				previewData.posBase + previewData.surfaceNormal * 2,
				previewData.surfaceNormal:Angle() + Angle(90, 0, 0),
				0.25
			)

				draw.Circle(0, 0, 30, colorPreview)

			camEnd3D2D()

			-- render line that shows shift
			camStart3D2D(
				previewData.posBase + previewData.surfaceNormal * 2,
				Angle(0, LocalPlayer():GetAngles().y - 90, 90),
				0.25
			)

				draw.Box(-1, 0, 2, 4 * (previewData.heightShift or 0), colorPreview)

			camEnd3D2D()
		else
			colorSphere = colorPreview
		end

		renderDrawSphere(
			previewData.currentPos,
			sphereRadius,
			4 + 750 / previewData.distance3d,
			4 + 750 / previewData.distance3d,
			colorSphere
		)
	end

	function SWEP:OnRemove()
		hook.Remove("PostDrawTranslucentRenderables", "RenderWeaponSpawnEdit")
	end

	function SWEP:Initialize()
		self.modes = entspawnscript.GetSpawnTypeList()
		self.selectedMode = 1

		self:AddTTT2HUDHelp("spawneditor_place", "spawneditor_remove")
		self:AddHUDHelpLine("spawneditor_change", Key("+reload", "R"))
		self:AddHUDHelpLine("spawneditor_ammo_edit", Key("+walk", "WALK"))

		hook.Add("PostDrawTranslucentRenderables", "RenderWeaponSpawnEdit", RenderHook)
	end

	local matScreen = Material("models/weapons/v_toolgun/screen")
	local screenSize = 256
	local padding = 16
	local iconSize = 64
	local iconX = 0.5 * (screenSize - iconSize)
	local iconY = 2 * padding
	local textX = 0.5 * screenSize
	local textY = iconY + iconSize + padding
	local lineY = screenSize - 48
	local lineW = screenSize - 2 * padding
	local circleS = 6
	local circleY = screenSize - 24

	local RTTexture = GetRenderTarget("TTT2SpawnPlacer", screenSize, screenSize)

	local colorBasic = Color(255, 255, 255, 100)
	local colorSelect = Color(255, 255, 255, 235)

	function SWEP:RenderScreen()
		-- Set the material of the screen to our render target
		matScreen:SetTexture("$basetexture", RTTexture)

		-- Set up our view for drawing to the texture
		renderPushRenderTarget(RTTexture)

		local mode = self.modes[self.selectedMode]

		camStart2D()
			draw.Box(0, 0, screenSize, screenSize, entspawnscript.GetColorFromSpawnType(mode.spawnType))

			draw.ShadowedTexture(iconX, iconY, iconSize, iconSize, entspawnscript.GetIconFromSpawnType(mode.spawnType, mode.entType), 255, COLOR_WHITE)

			draw.ShadowedText(
				LANG.TryTranslation(entspawnscript.GetLangIdentifierFromSpawnType(mode.spawnType, mode.entType)),
				"DermaTTT2SubMenuButtonTitle",
				textX,
				textY,
				COLOR_WHITE,
				TEXT_ALIGN_CENTER,
				TEXT_ALIGN_TOP
			)

			draw.Box(padding, lineY, lineW, 2, colorBasic)

			for i = 1, #self.modes do
				if i == self.selectedMode then
					draw.Circle(i * padding, circleY, circleS, colorSelect)
				else
					draw.Circle(i * padding, circleY, circleS, colorBasic)
				end
			end
		camEnd2D()

		render.PopRenderTarget()
	end

	net.Receive("weapon_ttt_spawneditor_spawninfo_ent", function()
		entspawnscript.SetSpawnInfoEntity(net.ReadEntity())
	end)

	function SWEP:Think()
		local client = LocalPlayer()

		-- Make sure the user is currently not typing anything, to prevent unwanted execution of a placement
		if vgui.GetKeyboardFocus() or client:IsTyping() or gui.IsConsoleVisible() or vguihandler.IsOpen() then return end

		local focusedSpawn = entspawnscript.GetFocusedSpawn()
		local mode = self.modes[self.selectedMode]

		-- always set spawnType
		previewData.spawnType = mode.spawnType

		if input.IsBindingDown("+attack") and not self.wasAttackDown then
			-- first key down of the attack button: get basepos
			self.wasAttackDown = true

			if focusedSpawn then return end

			local trace = client:GetEyeTrace()

			local posEye = client:EyePos()
			local posBase = trace.HitPos
			local distance3d = posEye:Distance(posBase)

			if not trace.Hit or distance3d > maxEditDistance then return end

			previewData.surfaceNormal = trace.HitNormal
			previewData.inPlacement = true
			previewData.posBase = posBase
			previewData.distance3d = distance3d
		elseif input.IsBindingDown("+attack") and previewData.inPlacement then
			-- hold attack key: update preview position
			local posBase = previewData.posBase

			local posEye = client:EyePos()
			local posGround = Vector(posEye.x, posEye.y, posBase.z)

			local distance2d = posGround:Distance(posBase)
			local distance3d = posEye:Distance(posBase)

			local angle = EyeAngles().p / 180 * mathPi -- angle in rad
			local diff = distance2d * mathTan(angle)

			previewData.currentPos = Vector(posBase.x, posBase.y, posEye.z - diff)
			previewData.distance3d = distance3d
			previewData.heightShift = posBase.z - previewData.currentPos.z
		elseif not input.IsBindingDown("+attack") and self.wasAttackDown then
			-- attack key released: set spawn
			self.wasAttackDown = false

			if not previewData.inPlacement or focusedSpawn then return end

			entspawnscript.AddSpawn(mode.spawnType, mode.entType, previewData.currentPos, client:GetAngles(), 0, true)

			previewData.inPlacement = false
			previewData.heightShift = 0
		else
			-- just store current position for rendering of preview
			local trace = client:GetEyeTrace()
			local posEye = client:EyePos()
			local posBase = trace.HitPos
			local distance3d = posEye:Distance(posBase)

			previewData.currentPos = trace.HitPos
			previewData.surfaceNormal = trace.HitNormal
			previewData.distance3d = distance3d
			previewData.inRange = distance3d <= maxEditDistance and not focusedSpawn
		end
	end
end

-- used to place / remove spawns
function SWEP:PrimaryAttack()
	if SERVER or not IsFirstTimePredicted() then return end

	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Primary.Delay)

	local focusedSpawn = entspawnscript.GetFocusedSpawn()

	if input.IsBindingDown("+walk") then
		if not focusedSpawn then return end

		local spawnType = focusedSpawn.spawnType
		local entType = focusedSpawn.entType
		local id = focusedSpawn.id
		local ammo = focusedSpawn.spawn.ammo

		entspawnscript.UpdateSpawn(spawnType, entType, id, nil, nil, ammo + 1, true)
	end
end

function SWEP:SecondaryAttack()
	if SERVER or not IsFirstTimePredicted() then return end

	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Primary.Delay)

	local focusedSpawn = entspawnscript.GetFocusedSpawn()

	if not focusedSpawn then return end

	local spawnType = focusedSpawn.spawnType
	local entType = focusedSpawn.entType
	local id = focusedSpawn.id
	local ammo = focusedSpawn.spawn.ammo

	if input.IsBindingDown("+walk") then
		entspawnscript.UpdateSpawn(spawnType, entType, id, nil, nil, math.max(ammo - 1, 0), true)
	else
		entspawnscript.RemoveSpawnById(focusedSpawn.spawnType, focusedSpawn.entType, focusedSpawn.id, true)
	end
end

function SWEP:Reload()
	if SERVER or not IsFirstTimePredicted() then return end

	if self.lastReload + 0.175 > CurTime() then return end

	self.lastReload = CurTime()

	if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
		if self.selectedMode == 1 then
			self.selectedMode = #self.modes
		else
			self.selectedMode = self.selectedMode - 1
		end
	else
		if self.selectedMode == #self.modes then
			self.selectedMode = 1
		else
			self.selectedMode = self.selectedMode + 1
		end
	end
end
