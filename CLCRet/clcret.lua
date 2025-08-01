local _, trueclass = UnitClass("player")
if trueclass ~= "PALADIN" then return end

local GetTime = GetTime

clcret = LibStub("AceAddon-3.0"):NewAddon("clcret", "AceEvent-3.0", "AceConsole-3.0")

local MAX_AURAS = 20
local BGTEX = "Interface\\AddOns\\clcret\\textures\\minimalist"
local BORDERTEX = "Interface\\AddOns\\clcret\\textures\\border"
local borderType = {
	"Interface\\AddOns\\clcret\\textures\\border",					-- light
	"Interface\\AddOns\\clcret\\textures\\border_medium",			-- medium
	"Interface\\AddOns\\clcret\\textures\\border_heavy"				-- heavy
}

local spellInfo = C_Spell.GetSpellInfo
local dq = { 85256, 85256 }
local nq = {}

spellInfo = C_Spell.GetSpellInfo

nq[1] = C_Spell.GetSpellInfo(85256)
nq[2] = C_Spell.GetSpellInfo(85256)

local csname = C_Spell.GetSpellInfo(35395)

-- main and secondary skill buttons
local buttons = {}
-- configurable buttons
local auraButtons = {}
local enabledAuraButtons
local numEnabledAuraButtons 
local auraIndex

local icd = {}
local playerName

-- addon status
local addonEnabled = false			-- enabled
local addonInit = false				-- init completed
clcret.locked = true				-- main frame locked

-- shortcut for db options
local db

local strataLevels = {
	"BACKGROUND",
	"LOW",
	"MEDIUM",
	"HIGH",
	"DIALOG",
	"FULLSCREEN",
	"FULLSCREEN_DIALOG",
	"TOOLTIP",
}

-- ---------------------------------------------------------------------------------------------------------------------
-- DEFAULT VALUES
-- ---------------------------------------------------------------------------------------------------------------------
local defaults = {
	profile = {
		version = 6,
		
		-- layout settings for the main frame (the black box you toggle on and off)\
		zoomIcons = true,
		noBorder = false,
		borderColor = {0, 0, 0, 1},
		borderType = 2,
		x = 500,
		y = 300,
		scale = 1,
		alpha = 1,
		show = "always",
		fullDisable = false,
		strata = 3,
		grayOOM = false,
		
		-- icd
		icd = {
			visibility = {
				ready = 1,
				cd = 3,
			},
		},
		
		-- behavior
		updatesPerSecond = 10,
		updatesPerSecondAuras = 5,

		-- layout of the 2 skill buttons
		layout = {
			button1 = {
				size = 70,
				alpha = 1,
				x = 0,
				y = 0,
				point = "CENTER",
				pointParent = "CENTER",
			},
			button2 = {
				size = 40,
				alpha = 1,
				x = 50,
				y = 0,
				point = "BOTTOMLEFT",
				pointParent = "BOTTOMRIGHT",
			},
		},
		
		-- aura buttons
		-- 4 examples, rest init to "blank" later
		auras = {},
	}
}
-- blank rest of the auras buttons in default options
for i = 1, MAX_AURAS do 
	defaults.profile.auras[i] = {
		enabled = false,
		data = {
			exec = "AuraButtonExecNone",
			spell = "",
			unit = "",
			byPlayer = true,
		},
		layout = {
			size = 30,
			x = 0,
			y = 0,
			alpha = 1,
			point = "BOTTOM",
			pointParent = "TOP",
		},
	}
end

clcret.db_defaults = defaults

-- ---------------------------------------------------------------------------------------------------------------------
-- MAIN UPDATE FUNCTION
-- ---------------------------------------------------------------------------------------------------------------------
local throttle = 0
local throttleAuras = 0

local function OnUpdate(self, elapsed)
	throttle = throttle + elapsed
	if throttle > clcret.scanFrequency then
		throttle = 0
		clcret:CheckQueue()
		clcret:CheckRange()
	end
	
	throttleAuras = throttleAuras + elapsed
	if throttleAuras > clcret.scanFrequencyAuras then
		throttleAuras = 0
		for i = 1, numEnabledAuraButtons do
			-- TODO: check docs to see how it's done properly
			auraIndex = enabledAuraButtons[i]
			clcret[db.auras[auraIndex].data.exec]()
		end
	end

end

-- ---------------------------------------------------------------------------------------------------------------------
-- INIT
-- ---------------------------------------------------------------------------------------------------------------------
function clcret:ProfileChanged(db, sourceProfile)
	-- relink 
	ReloadUI()
end

-- load if needed and show options
local function ShowOptions()

	if not clcret.optionsLoaded then 
		C_AddOns.LoadAddOn("CLCRet_Options") 
	end
	
	Settings.OpenToCategory("CLCRet")

end

local function CmdLinePrio(args)
	clcret.db.profile.rotation.prio = args
	clcret.RR_UpdateQueue()
end

function clcret:OnInitialize()
	-- SAVEDVARS
	self.db = LibStub("AceDB-3.0"):New("clcretDB", defaults)
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfileChanged")
	db = self.db.profile
	
	-- Welcome message
	print "|cffF58CBAclcRet|r: To turn on the |cffec0000Experimental|r AOE mode; Type |cff55ff84/clcret|r go to |cff55ff84Rotation|r > |cff55ff84Setting & AOE Mode|r > |cff55ff84Check the box|r."

	-- this would give a proper init
	self:RegisterEvent("QUEST_LOG_UPDATE")
end

function clcret:QUEST_LOG_UPDATE()
	self:UnregisterEvent("QUEST_LOG_UPDATE")
	
	-- test if it's a paladin or not

	self.CheckQueue = self.DoNothing
	
	self.LBF = LibStub('LibButtonFacade', true)
	
	-- update rates
	self.scanFrequency = 1 / db.updatesPerSecond
	self.scanFrequencyAuras = 1 / db.updatesPerSecondAuras
	
	-- blank options page for title
	local optionFrame = CreateFrame("Frame", nil, UIParent)
	optionFrame.name = "CLCRet"
	local optionFrameLoad = CreateFrame("Button", nil, optionFrame, "UIPanelButtonTemplate")
	optionFrameLoad:SetWidth(150)
	optionFrameLoad:SetHeight(22)
	optionFrameLoad:SetText("Load Options")
	optionFrameLoad:SetPoint("TOPLEFT", 20, -20)
	optionFrameLoad:SetScript("OnClick", ShowOptions)

	-- chat command that points to our category
	self:RegisterChatCommand("clcret", ShowOptions)
	self:RegisterChatCommand("clcretlp", CmdLinePrio)
	self:RegisterChatCommand("rl", ReloadUI)
	
	self:UpdateEnabledAuraButtons()
	
	-- create the power bar

	self:RR_UpdateQueue()
	self:InitUI()
	self:UpdateAuraButtonsCooldown()
	self:PLAYER_TALENT_UPDATE()
	
	if self.LBF then
		self.LBF:RegisterSkinCallback("clcret", self.OnSkin, self)
		self.LBF:Group("clcret", "Skills"):Skin(unpack(db.lbf.Skills))
		self.LBF:Group("clcret", "Auras"):Skin(unpack(db.lbf.Auras))
	end
	
	if not db.fullDisable then
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
	end

	-- icd stuff
	self:AuraButtonUpdateICD()
	
	--[[ DEBUG
	self:InitDebugFrame()
	--]]
end

function clcret:OnSkin(skin, glossAlpha, gloss, group, _, colors)
	local styleDB
	if group == 'Skills' then
		styleDB = db.lbf.Skills
	elseif group == 'Auras' then
		styleDB = db.lbf.Auras
	end

	if styleDB then
		styleDB[1] = skin
		styleDB[2] = glossAlpha
		styleDB[3] = gloss
		styleDB[4] = colors
	end
	
	self:UpdateAuraButtonsLayout()
	self:UpdateSkillButtonsLayout()
end

-- ---------------------------------------------------------------------------------------------------------------------
-- SHOW WHEN SETTINGS
-- ---------------------------------------------------------------------------------------------------------------------

-- updates the settings from db and register/unregisters the needed events
function clcret:UpdateShowMethod()
	-- unregister all events first
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	self:UnregisterEvent("PLAYER_REGEN_DISABLED")
	self:UnregisterEvent("PLAYER_TARGET_CHANGED")
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("UNIT_FACTION")

	if db.show == "combat" then
		if addonEnabled then
			if UnitAffectingCombat("player") then
				self.frame:Show()
			else
				self.frame:Hide()
			end
		end
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		
	elseif db.show == "valid" or db.show == "boss" then
		self:PLAYER_TARGET_CHANGED()
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED")
		self:RegisterEvent("UNIT_FACTION")
	else
		if addonEnabled then
			self.frame:Show()
		end
	end
end

-- out of combat
function clcret:PLAYER_REGEN_ENABLED()
	if not addonEnabled then return end
	self.frame:Hide()
end

-- in combat
function clcret:PLAYER_REGEN_DISABLED()
	if not addonEnabled then return end
	self.frame:Show()
end

-- target change
function clcret:PLAYER_TARGET_CHANGED()
	if not addonEnabled then return end
	
	if db.show == "boss" then
		if UnitClassification("target") ~= "worldboss" then
			self.frame:Hide()
			return
		end
	end
	
	if UnitExists("target") and UnitCanAttack("player", "target") and (not UnitIsDead("target")) then
		self.frame:Show()
	else
		self.frame:Hide()
	end
end

-- unit faction changed - test if it gets fired everytime a target switches friend -> enemy
function clcret:UNIT_FACTION(event, unit)
	if unit == "target" then
		self:PLAYER_TARGET_CHANGED()
	end
end

-- disable/enable according to spec
function clcret:PLAYER_TALENT_UPDATE()
	if db.fullDisable then
		self:CLCRETDisable()
		return
	end
	
	-- check specialization
	-- 3 = retribution
	local spec = GetSpecialization()
	
	if spec == 3 then
		self.CheckQueue = self.CheckQueueRet
		dq[1], dq[2] = 85256, 85256
		self:CLCRETEnable()
		self:UpdateShowMethod()
	else
		self.CheckQueue = self.DoNothing
		self:CLCRETDisable()
	end
end

-- ---------------------------------------------------------------------------------------------------------------------
-- UPDATE FUNCTIONS
-- ---------------------------------------------------------------------------------------------------------------------
-- just show the button for positioning
function clcret:AuraButtonExecaNone(index)
	auraButtons[auraIndex]:Show()
end

-- shows a skill always with a visible cooldown when needed
function clcret:AuraButtonExecSkillVisibleAlways()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	-- fix the texture once
	if not button.hasTexture then
		button.hasTexture = true
		button.texture:SetTexture(GetSpellTexture(data.spell))
	end
	
	button:Show()
	
	if IsUsableSpell(data.spell) then
		button.texture:SetVertexColor(1, 1, 1, 1)
	else
		button.texture:SetVertexColor(0.3, 0.3, 0.3, 1)
	end
	
	local start, duration = C_Spell.GetSpellCooldown(data.spell)
	if duration and duration > 0 then
		button.cooldown:SetCooldown(start, duration)
	end
end

-- shows a skill only when off cd
function clcret:AuraButtonExecSkillVisibleNoCooldown()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	-- fix the texture once
	if not button.hasTexture then
		button.hasTexture = true
		button.texture:SetTexture(GetSpellTexture(data.spell))
	end

	local start, duration = C_Spell.GetSpellCooldown(data.spell)
	
	-- if IsUsableSpell(data.spell) then --changed oct 6th 2024
	if C_Spell.IsSpellUsable(data.spell) then
		button.texture:SetVertexColor(1, 1, 1, 1)
	else
		button.texture:SetVertexColor(0.3, 0.3, 0.3, 1)
	end
	
	if duration and duration > 1.5 then
		button:Hide()
	else
		button:Show()
	end
end

-- shows a skill only when on cd
function clcret:AuraButtonExecSkillVisibleOnCooldown()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	-- fix the texture once
	if not button.hasTexture then
		button.hasTexture = true
		button.texture:SetTexture(GetSpellTexture(data.spell))
	end

	local start, duration = C_Spell.GetSpellCooldown(data.spell)
	
	if duration and duration > 1.5 then
		button:Show()
		button.cooldown:SetCooldown(start, duration)
	else
		button:Hide()
	end
end

-- shows a usable item always and with a visible cooldown when needed
function clcret:AuraButtonExecItemVisibleAlways()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data

	-- fix the texture once
	if not button.hasTexture then
		button.hasTexture = true
		button.texture:SetTexture(C_Item.GetItemIconByID(data.spell))
	end
	
	button:Show()
	
	if C_Item.IsUsableItem(data.spell) and C_Item.IsEquippedItem(data.spell) then
		button.texture:SetVertexColor(1, 1, 1, 1)
	else
		button.texture:SetVertexColor(0.3, 0.3, 0.3, 1)
	end
	
	local start, duration = C_Item.GetItemCooldown(data.spell)
	if duration and duration > 0 then
		button.cooldown:SetCooldown(start, duration)
	end
	
end

-- shows shows a usable item only when out of cooldown
function clcret:AuraButtonExecItemVisibleNoCooldown()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data

	-- fix the texture once
	if not button.hasTexture then
		button.hasTexture = true
		button.texture:SetTexture(C_Item.GetItemIconByID(data.spell))
	end

	local start, duration = C_Item.GetItemCooldown(data.spell)
	
	if C_Item.IsUsableItem(data.spell) and C_Item.IsEquippedItem(data.spell) then
		button.texture:SetVertexColor(1, 1, 1, 1)
	else
		button.texture:SetVertexColor(0.3, 0.3, 0.3, 1)
	end
	
	if duration and duration > 1.5 then
		button:Hide()
	else
		button:Show()
	end
	
end

-- shows shows an Equipped usable item only when off cooldown
function clcret:AuraButtonExecItemVisibleNoCooldownEquip()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data

	-- fix the texture once
	if not button.hasTexture then
		button.hasTexture = true
		button.texture:SetTexture(C_Item.GetItemIconByID(data.spell))
	end

	local start, duration = C_Item.GetItemCooldown(data.spell)
	
	if C_Item.IsUsableItem(data.spell) and C_Item.IsEquippedItem(data.spell) then
		button.texture:SetVertexColor(1, 1, 1, 1)
	else
		button.texture:SetVertexColor(0.3, 0.3, 0.3, 1)
	end
	
	if duration and duration > 1.5 then
		button:Hide()
	else
		button:Show()
	end
	
	if not C_Item.IsEquippedItem(data.spell) then
		button:Hide()
	end
end

-- displayed when a specific spell isn't active on player
function clcret:AuraButtonExecPlayerMissingBuff()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	if not button.hasTexture then
		button.texture:SetTexture(GetSpellTexture(data.spell))
		button.hasTexture = true
	end
	
	local aura = C_UnitAuras.GetAuraDataBySpellName("player", data.spell)
	if not aura then
		button:Show()
	else
		button:Hide()
	end
end

-- resets the vertex color when grayOOM option changes
function clcret:ResetButtonVertexColor()
	buttons[1].texture:SetVertexColor(1, 1, 1, 1)
	buttons[2].texture:SetVertexColor(1, 1, 1, 1)
end

-- updates the 2 skill buttons
function clcret:UpdateUI()
	-- queue
	for i = 1, 2 do
		local button = buttons[i]
		local spellInfo = C_Spell.GetSpellInfo
		local texture = C_Spell.GetSpellTexture(dq[i])
		button.texture:SetTexture(texture)
		
		local spellCooldownInfo = C_Spell.GetSpellCooldown(dq[i])
		local start, duration = spellCooldownInfo.startTime, spellCooldownInfo.duration
		
		if duration and duration > 0 then
			button.cooldown:Show()
			button.cooldown:SetCooldown(start, duration)
		else
			button.cooldown:Hide()
		end
		
		if db.grayOOM then
			local _, nomana = C_Spell.IsSpellUsable(213644)
			if nomana then 
				button.texture:SetVertexColor(0.3, 0.3, 0.3, 0.3)
			else
				button.texture:SetVertexColor(1, 1, 1, 1)
			end
		end
		
	end
end

-- melee range check
function clcret:CheckRange()

	local inRange
	
	if db.rotation.rangePerSkill then
		-- each skill shows the range of the ability
		for i = 1, 2 do
				inRange = C_Spell.IsSpellInRange(dq[1], "target")
			if inRange then
				buttons[i].texture:SetVertexColor(1, 1, 1)
			else
				buttons[i].texture:SetVertexColor(0.8, 0.1, 0.1)
			end
		end
	else
		-- both skills show melee range
		-- inRange = C_Spell.IsSpellInRange(96231)	
		
		-- checks if crusading strikes(404542) is known and to use BoJ as the check instead
		if IsPlayerSpell(404542) then 
			inRange = C_Spell.IsSpellInRange(184575)
		else
			inRange = C_Spell.IsSpellInRange(35395)
		end
		
		if inRange then
			for i = 1, 2 do
				buttons[i].texture:SetVertexColor(1, 1, 1)
			end
		else
			for i = 1, 2 do
				buttons[i].texture:SetVertexColor(0.8, 0.1, 0.1)
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------------------------------------
-- QUEUE LOGIC
-- ---------------------------------------------------------------------------------------------------------------------
function clcret:DoNothing()
	self:CLCRETDisable()
end

function clcret:CheckQueueRet()
	dq[1], dq[2] = clcret.RetRotation()
	
	spellInfo = C_Spell.GetSpellInfo
	
	nq[1] = spellInfo(dq[1])
	nq[2] = spellInfo(dq[2])
	self:UpdateUI()
end

-- ---------------------------------------------------------------------------------------------------------------------
-- ENABLE/DISABLE
-- ---------------------------------------------------------------------------------------------------------------------
function clcret:CLCRETEnable()
	if addonInit then
		addonEnabled = true
		self.frame:Show()
	end
end

function clcret:CLCRETDisable()
	if addonInit then
		addonEnabled = false
		self.frame:Hide()
	end
end

-- ---------------------------------------------------------------------------------------------------------------------
-- UPDATE LAYOUT
-- ---------------------------------------------------------------------------------------------------------------------

-- toggle main frame for drag
function clcret:ToggleLock()
	if self.locked then
		self.locked = false
		self.frame:EnableMouse(true)
		self.frame.texture:Show()
	else
		self.locked = true
		self.frame:EnableMouse(false)
		self.frame.texture:Hide()
	end
end

-- center the main frame
function clcret:CenterHorizontally()
	db.x = (UIParent:GetWidth() - clcretFrame:GetWidth() * db.scale) / 2 / db.scale
	self:UpdateFrameSettings()
end

-- update for aura buttons 
function clcret:UpdateSkillButtonsLayout()
	clcretFrame:SetWidth(db.layout.button1.size + 10)
	clcretFrame:SetHeight(db.layout.button1.size + 10)
	
	for i = 1, 2 do
		self:UpdateButtonLayout(buttons[i], db.layout["button" .. i])
	end
end
-- update aura buttons 
function clcret:UpdateAuraButtonsLayout()
	for i = 1, MAX_AURAS do
		self:UpdateButtonLayout(auraButtons[i], db.auras[i].layout)
	end
end
-- update aura for a single button (tmp use in options)
function clcret:UpdateAuraButtonLayout(index)
	self:UpdateButtonLayout(auraButtons[index], db.auras[index].layout)
end
-- update a given button
function clcret:UpdateButtonLayout(button, opt)
	local scale = opt.size / button.defaultSize
	button:SetScale(scale)
	button:ClearAllPoints()
	button:SetPoint(opt.point, clcretFrame, opt.pointParent, opt.x / scale, opt.y / scale)
	button:SetAlpha(opt.alpha)
	button.border:SetVertexColor(unpack(db.borderColor))
	button.border:SetTexture(borderType[db.borderType])
	
	button.stack:ClearAllPoints()
	button.stack:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, 0)
	
	if db.zoomIcons then
		button.texture:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	else
		button.texture:SetTexCoord(0, 1, 0, 1)
	end
	
	if db.noBorder then
		button.border:Hide()
	else
		button.border:Show()
	end
end

-- update scale, alpha, position for main frame
function clcret:UpdateFrameSettings()
	self.frame:SetScale(max(db.scale, 0.01))
	self.frame:SetAlpha(db.alpha)
	self.frame:SetPoint("BOTTOMLEFT", db.x, db.y)
end

-- ---------------------------------------------------------------------------------------------------------------------
-- INIT LAYOUT
-- ---------------------------------------------------------------------------------------------------------------------

-- initialize main frame and all the buttons
function clcret:InitUI()
	local frame = CreateFrame("Frame", "clcretFrame", UIParent)
	frame.unit = "player"
	frame:SetFrameStrata(strataLevels[db.strata])
	frame:SetWidth(db.layout.button1.size + 10)
	frame:SetHeight(db.layout.button1.size + 10)
	frame:SetPoint("BOTTOMLEFT", db.x, db.y)
	
	frame:EnableMouse(false)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		db.x = clcretFrame:GetLeft()
		db.y = clcretFrame:GetBottom()
	end)
	
	local texture = frame:CreateTexture(nil, "BACKGROUND")
	texture:SetAllPoints()
	texture:SetTexture(BGTEX)
	texture:SetVertexColor(0, 0, 0, 1)
	texture:Hide()
	frame.texture = texture

	self.frame = frame
	
	-- init main skill button
	local opt
	opt = db.layout["button1"]
	buttons[1] = self:CreateButton("SB1", opt.size, opt.point, clcretFrame, opt.pointParent, opt.x, opt.y, "Skills", true)
	buttons[1]:SetAlpha(opt.alpha)
	buttons[1]:Show()
	
	-- init secondary skill button
	opt = db.layout["button2"]
	buttons[2] = self:CreateButton("SB2", opt.size, opt.point, clcretFrame, opt.pointParent, opt.x, opt.y, "Skills")
	buttons[2]:SetAlpha(opt.alpha)
	buttons[2]:Show()
	
	-- aura buttons
	self:InitAuraButtons()
	
	-- set scale, alpha, position
	self:UpdateFrameSettings()
	
	addonInit = true
	self:CLCRETDisable()
	self.frame:SetScript("OnUpdate", OnUpdate)
end

-- initialize aura buttons
function clcret:InitAuraButtons()
	local data, layout
	for i = 1, MAX_AURAS do
		data = db.auras[i].data
		layout = db.auras[i].layout
		auraButtons[i] = self:CreateButton("aura"..i, layout.size, layout.point, clcretFrame, layout.pointParent, layout.x, layout.y, "Auras")
		auraButtons[i].start = 0
		auraButtons[i].duration = 0
		auraButtons[i].expirationTime = 0
		auraButtons[i].hasTexture = false
	end
end

-- create button
function clcret:CreateButton(name, size, point, parent, pointParent, offsetx, offsety, bfGroup, isChecked)
	name = "clcret" .. name
	local button
	if isChecked then
		button = CreateFrame("CheckButton", name , parent)
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
	else
		button = CreateFrame("Button", name , parent)
	end
	button:EnableMouse(false)
	
	button:SetWidth(64)
	button:SetHeight(64)
	
	button.texture = button:CreateTexture("$parentIcon", "BACKGROUND")
	button.texture:SetAllPoints()
	button.texture:SetTexture(BGTEX)
	
	button.border = button:CreateTexture(nil, "BORDER") -- not $parentBorder so it can work when bf is enabled
	button.border:SetAllPoints()
	button.border:SetTexture(BORDERTEX)
	button.border:SetVertexColor(unpack(db.borderColor))
	button.border:SetTexture(borderType[db.borderType])
	
	button.cooldown = CreateFrame("Cooldown", "$parentCooldown", button, "CooldownFrameTemplate")
	button.cooldown:SetAllPoints(button)
	
	button.stack = button:CreateFontString("$parentCount", "OVERLAY", "TextStatusBarText")
	local fontFace, _, fontFlags = button.stack:GetFont()
	button.stack:SetFont(fontFace, 30, fontFlags)
	button.stack:SetJustifyH("RIGHT")
	button.stack:ClearAllPoints()
	button.stack:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, 0)
	
	button.defaultSize = button:GetWidth()
	local scale = size / button.defaultSize
	button:SetScale(scale)
	button:ClearAllPoints()
	button:SetPoint(point, parent, pointParent, offsetx / scale, offsety / scale)
	
	if self.LBF then
		self.LBF:Group("clcret", bfGroup):AddButton(button)
	end
	
	if db.zoomIcons then
		button.texture:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	end
	
	if db.noBorder then
		button.border:Hide()
	end
	
	button:Hide()
	return button
end

-- ---------------------------------------------------------------------------------------------------------------------
-- FULL DISABLE
-- ---------------------------------------------------------------------------------------------------------------------
function clcret:FullDisableToggle()
	if db.fullDisable then
		-- enabled
		db.fullDisable = false
		
		-- register events
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
		self:RegisterCLEU()
		
		-- do the normal load rutine
		self:PLAYER_TALENT_UPDATE()
	else
		-- disabled
		db.fullDisable = true
		
		-- unregister events
		self:UnregisterEvent("PLAYER_TALENT_UPDATE")
		
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		self:UnregisterEvent("PLAYER_REGEN_DISABLED")
		self:UnregisterEvent("PLAYER_TARGET_CHANGED")
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		self:UnregisterEvent("UNIT_FACTION")
		
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		
		-- disable
		self:CLCRETDisable()
	end
end

function clcret:AoeModeToggle()
	if db.aoeMode then
		-- enabled
		db.aoeMode = false
		
		-- register events
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
		self:RegisterCLEU()
		
		-- do the normal load rutine
		self:PLAYER_TALENT_UPDATE()
	else
		-- disabled
		db.aoeMode = true
		

	end
end

-- ---------------------------------------------------------------------------------------------------------------------
-- HELPER FUNCTIONS
-- ---------------------------------------------------------------------------------------------------------------------
function clcret:AuraButtonResetTextures()
	for i = 1, MAX_AURAS do
		auraButtons[i].hasTexture = false
	end
end

function clcret:AuraButtonResetTexture(index)
	auraButtons[index].hasTexture = false
end

function clcret:AuraButtonHide(index)
	auraButtons[index]:Hide()
end

-- reversed and edged cooldown look for buffs and debuffs
function clcret:UpdateAuraButtonsCooldown()
	for i = 1, MAX_AURAS do
		if (db.auras[i].data.exec == "AuraButtonExecGenericBuff") or (db.auras[i].data.exec == "AuraButtonExecGenericDebuff") then
			auraButtons[i].cooldown:SetReverse(true)
		else
			auraButtons[i].cooldown:SetReverse(false)
		end
	end
end

-- update the used aura buttons to shorten the for
function clcret:UpdateEnabledAuraButtons()
	numEnabledAuraButtons = 0
	enabledAuraButtons = {}
	for i = 1, MAX_AURAS do
		if db.auras[i].enabled then
			numEnabledAuraButtons = numEnabledAuraButtons + 1
			enabledAuraButtons[numEnabledAuraButtons] = i
		end
	end
end


local ceAuraApplied = {
	["SPELL_AURA_APPLIED"] = true,
	["SPELL_AURA_REFRESH"] = true,
	["SPELL_AURA_APPLIED_DOSE"] = true,
}

local ceAuraRemoved = {
	["SPELL_AURA_REMOVED"] = true,
	["SPELL_AURA_REMOVED_DOSE"] = true,
}

-- reports min icd for a specified aura button
function clcret:ICDReportMinCd(args)
	local id = tonumber(args)
	if icd.data[id] then
		print("clcret:", icd.data[id].mincd)
	else
		print("clcret:", "No data found")
	end
end

-- check the aura list and enables cleu if needed, also resets all data
function clcret:AuraButtonUpdateICD()
	icd.spells = {}
	icd.data = {}
	icd.cleu = false

	for i = 1, MAX_AURAS do
		if db.auras[i].data.exec == "AuraButtonExecICDItem" and db.auras[i].data.spell ~= "" and db.auras[i].enabled then
			local id = tonumber(db.auras[i].data.spell)
			local durationICD, durationBuff = strsplit(":", db.auras[i].data.unit)
			durationICD = tonumber(durationICD) or 0
			durationBuff = tonumber(durationBuff) or 0
			
			icd.cleu = true
			icd.spells[id] = i
			icd.data[i] = { id = db.auras[i].data.spell, durationICD = durationICD, durationBuff = durationBuff, start = 0, enabled = false, active = false, last = 0, mincd = 10000 }
		end
	end
	
	-- register/unregister combat log proccessing
	self:RegisterCLEU()
end

function clcret:RegisterCLEU()
	if icd.cleu then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	else
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end

-- cleu dispatcher wannabe
function clcret:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, combatEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, spellType, dose, ...)

	-- return if no icd
	if not icd.cleu then return end
	
	-- icd logic
	if destName == playerName and icd.spells[spellId] then
		local i = icd.spells[spellId]
			spellInfo = C_Spell.GetSpellInfo
		if ceAuraApplied[combatEvent] then
			icd.data[i].start = GetTime()
			icd.data[i].cd = floor(icd.data[i].start - icd.data[i].last + 0.5)
			icd.data[i].last = icd.data[i].start
			-- check if it's a smaller cd than the one used
			if icd.data[i].start > 0 and icd.data[i].cd < icd.data[i].durationICD then
				print("clcret:", "Warning: " .. spellId .. "(" .. spellInfo(spellId) .. ") activated after " .. icd.data[i].cd .. " seconds and specified ICD is " .. icd.data[i].durationICD .. " seconds.")
			end
			-- save min cd
			if icd.data[i].cd < icd.data[i].mincd then icd.data[i].mincd = icd.data[i].cd end
			icd.data[i].enabled = true
			icd.data[i].active = true
		end
	end
end