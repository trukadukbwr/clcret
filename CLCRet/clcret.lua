local _, playerClass = UnitClass("player")
local _, xmod = ...

local GetTime = GetTime

clcret = LibStub("AceAddon-3.0"):NewAddon("clcret", "AceEvent-3.0", "AceConsole-3.0")

local MAX_AURAS = 10

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

-- spellInfo = C_Spell.GetSpellInfo

nq[1] = C_Spell.GetSpellInfo(85256)
nq[2] = C_Spell.GetSpellInfo(85256)

-- local csname = C_Spell.GetSpellInfo(35395)

-- main and secondary skill buttons
local buttons = {}
-- configurable buttons
local auraButtons = {}
local enabledAuraButtons
local numEnabledAuraButtons 
local auraIndex

-- local icd = {}
-- local playerName

-- addon status
local addonEnabled = false			-- enabled
local addonInit = false				-- init completed
clcret.locked = true				-- main frame locked

-- shortcut for db options
local db

-- check if addon should load for current spec
local function IsCurrentSpecEnabled()

	local spec = GetSpecialization()
	
	if not spec then 
		return false 
	end
	
	local enabled = db["spec"..spec.."Enable"]
	return enabled ~= false
	
end


local MeleeCheckSpells = {

	-- activate/input spell ids as modules are added; only for melee capable classes
	PALADIN = {
		-- crusader strike for all 3 specs
		[65] = 35395, -- holy
		[66] = 35395, -- prot
		[70] = 35395, -- ret
	},
	DEATHKNIGHT = {
		[250] = 206930, -- blood
		[251] = 49143, -- frost
		[252] = 85948, -- unholy
	},
	-- WARRIOR = { 
		-- [71] = 00000, -- arms
		-- [72] = 00000, -- fury
		-- [73] = 00000, -- prot
	-- },
	-- DEMONHUNTER = { 
		-- [577] = 00000, -- havoc
		-- [581] = 00000, -- veng
		-- [000] = 00000, -- dev
	-- },
	-- DRUID = { 
		-- [102] = 00000, -- balance
		-- [103] = 00000, -- feral
		-- [104] = 00000,-- guardian
		-- [105] = 00000, -- resto
	-- },
	-- HUNTER = { 
		-- [253] = 00000, -- bm
		-- [254] = 00000, -- mm
		-- [255] = 00000, -- surv
	-- },
	-- MONK = { 
		-- yes, the spec ids are out of order, this is because the spec # (1,2,3) are out of order vs spec ids on Blizz's end
		-- [268] = 00000, -- brew
		-- [270] = 00000, -- mist
		-- [269] = 00000, -- ww
	-- },
	-- ROGUE = { 
		-- [259] = 00000, -- assass
		-- [260] = 00000, -- outlaw
		-- [261] = 00000, -- sub
	-- },
	-- SHAMAN = { 
		-- [262] = 00000, -- ele
		-- [263] = 00000, -- enh
		-- [264] = 00000, -- resto
	-- },
}

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
		zoomIcons = false,
		noBorder = true,
		borderColor = {0, 0, 0, 1},
		borderType = 2,
		x = 880,
		y = 269,
		scale = 1,
		alpha = 1,
		show = "always",
		fullDisable = false,
		strata = 3,
		spec1Enable = true,
		spec2Enable = true, 
		spec3Enable = true,
		spec4Enable = true,
		
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
				size = 65,
				alpha = 1,
				x = 0,
				y = 0,
				point = "CENTER",
				pointParent = "CENTER",
			},
			button2 = {
				size = 45,
				alpha = 1,
				x = 0,
				y = 8,
				point = "BOTTOMLEFT",
				pointParent = "BOTTOMRIGHT",
			},
		},
		
		-- aura buttons
		auras = {},
		
	}
}

-- blank rest of the auras buttons in default options
for i = 1, MAX_AURAS + 2 do 
	defaults.profile.auras[i] = {
		enabled = false,
		data = {
			exec = "AuraButtonExecNone",
			spell = "",

		},
		layout = {
			size = 30,
			x = 0,
			y = 0,
			alpha = 1,
			point = "BOTTOM",
			pointParent = "TOP",
			
			procFlipbook = false, 
	procFlipbookWidth = 4,
	procFlipbookColor = {1, 0.84, 0, 1},
			
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
			auraIndex = enabledAuraButtons[i]
			clcret[db.auras[auraIndex].data.exec]()
		end
	end
end

-- ---------------------------------------------------------------------------------------------------------------------
-- ROTATION MODULE INITIALIZATION
-- ---------------------------------------------------------------------------------------------------------------------
-- Only set default values if not present/empty
	local function EnsureDefaults(db_rotation, defaults)
		for k, v in pairs(defaults) do
			if db_rotation[k] == nil or db_rotation[k] == "" then
				db_rotation[k] = v
			end
		end
	end

-- Avoid errors before init
clcret.RR_UpdateQueue = function() end
clcret.Rotation = function() end
clcret.RR_BuildOptions = function() end

local function clcInit()
	
	local spec = C_SpecializationInfo.GetSpecialization()	
	if not spec or spec == 0 then
		-- Wait for spec to load if not available yet
		C_Timer.After(0.5, clcInit)
		return
	end
	
	local activeModule = xmod.genericmodule
	
	if not clcret.db.profile.rotation then
		clcret.db.profile.rotation = {}
	end
		clcret.db.profile.rotation.specBlizzMode = clcret.db.profile.rotation.specBlizzMode or {}

	-- Get current spec ID
	local specID = C_SpecializationInfo.GetSpecialization()

	-- Set default for new spec
	if clcret.db.profile.rotation.specBlizzMode[specID] == nil then
		clcret.db.profile.rotation.specBlizzMode[specID] = true -- or true if you want default ON
	end


	-- Ensure the profile rotation table exists
	clcret.db.profile.rotation = clcret.db.profile.rotation or {}

	-- Only set defaults for missing/empty rotation values
	EnsureDefaults(clcret.db.profile.rotation, activeModule.defaults)

	-- Actions table from current module
	clcret.RR_actions = activeModule.GetActions()

	-- Functions for updating the queue, performing rotation, and building options
	function clcret.RR_UpdateQueue()
		activeModule.db = clcret.db.profile.rotation
		if activeModule.Init then activeModule.Init() end
	end

	function clcret.Rotation()
		if activeModule.Rotation then
			return activeModule.Rotation()
		end
	end

	function clcret.RR_BuildOptions()
		if activeModule.BuildOptions then
			return activeModule.BuildOptions()
		end
	end
	
end

-- Frame for events
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event)
	clcInit()
	self:UnregisterEvent(event)
end)


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
	
	if C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel then
        LibStub("AceConfigDialog-3.0"):Open("CLCRet");
        return;
    end
	
end

function clcret:ACTIVE_PLAYER_SPECIALIZATION_CHANGED()

	if db.fullDisable or not IsCurrentSpecEnabled() then
		self:CLCRETDisable()
	else
		self:CLCRETEnable()
	end

end

function clcret:OnInitialize()
	-- SAVEDVARS
	self.db = LibStub("AceDB-3.0"):New("clcretDB", defaults)
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfileChanged")
	db = self.db.profile

	-- check if addon should be enabled for spec
    if not IsCurrentSpecEnabled() or db.fullDisable then
        self:CLCRETDisable()
    else
        self:CLCRETEnable()
    end
	
	-- Welcome message
	-- print "|cffF58CBAclcRet|r: To turn on AOE mode; Type |cff55ff84/clcret|r go to |cff55ff84Rotation|r > |cff55ff84Setting & AOE Mode|r > |cff55ff84Check the box|r."

	-- this would give a proper init
	self:RegisterEvent("QUEST_LOG_UPDATE")	
	self:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
end

function clcret:QUEST_LOG_UPDATE()
	self:UnregisterEvent("QUEST_LOG_UPDATE")
	
	-- test if it's a paladin or not -- Obsolete?? !!!
	self.CheckQueue = self.DoNothing
	
	self.LBF = LibStub('LibButtonFacade', true)
	
	-- update rates
	self.scanFrequency = 1 / db.updatesPerSecond
	self.scanFrequencyAuras = 1 / db.updatesPerSecondAuras
	
	-- blank options page for title
	optionFrame = CreateFrame("Frame", nil, UIParent)
	optionFrame.name = "CLCRet"
	optionFrame.button = CreateFrame("Button", nil, optionFrame, "UIPanelButtonTemplate")
	optionFrame.button:SetText("Open Config Panel")
	optionFrame.button:SetWidth(150)
	optionFrame.button:SetHeight(22)
	optionFrame.button:SetScript("OnClick", ShowOptions)
	optionFrame.button:SetPoint("TOPLEFT", optionFrame, "TOPLEFT", 20, -20)
	
	if Settings then
		local category = Settings.RegisterCanvasLayoutCategory(optionFrame, "CLCRet")
		Settings.RegisterAddOnCategory(category)
	end

	-- chat command that points to our category
	self:RegisterChatCommand("clcret", ShowOptions)
	-- self:RegisterChatCommand("clcretlp", CmdLinePrio)
	self:RegisterChatCommand("rl", ReloadUI)
	self:UpdateEnabledAuraButtons()
	
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
	self:UnregisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")

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
	
	self:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
	
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
-- NOTE: Disable/enable portion is obsolete, but the whole function is needed to detect if you change a talent
-- leave in whole function to prevent errors
function clcret:PLAYER_TALENT_UPDATE()
		self.CheckQueue = self.CheckQueueRotation
		self:CLCRETEnable()
		self:UpdateShowMethod()
end

-- ---------------------------------------------------------------------------------------------------------------------
-- UPDATE FUNCTIONS
-- ---------------------------------------------------------------------------------------------------------------------


function clcret:PLAYER_EQUIPMENT_CHANGED()
	if not addonEnabled then return end
	
	-- Check both trinket slots
	for trinketSlot = 1, 2 do
		local trinketIndex = MAX_AURAS + trinketSlot
		
		-- Only update if the trinket is enabled
		if db.auras[trinketIndex].enabled then
			local slotNum = trinketSlot == 1 and 13 or 14
			local newTrinketID = GetInventoryItemID("player", slotNum)
			local currentTrinketID = tonumber(db.auras[trinketIndex].data.spell)
			
			-- If trinket changed, update it
			if newTrinketID and newTrinketID ~= currentTrinketID then
				db.auras[trinketIndex].data.spell = tostring(newTrinketID)
				clcret:UpdateAuraButtonLayout(trinketIndex)
				clcret:AuraButtonResetTexture(trinketIndex)
			end
		end
	end
end


-- just show the button for positioning
function clcret:AuraButtonExecaNone(index)
	auraButtons[auraIndex]:Show()
end

-- shows a usable item always and with a visible cooldown when needed
function clcret:AuraButtonExecItemVisible1Always()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data

	-- fix the texture once
	if not button.hasTexture then
		button.hasTexture = true
		button.texture:SetTexture(C_Item.GetItemIconByID(data.spell))
	end
	
	button:Show()
	
	-- Show the flipbook effect if enabled
	local start, duration = C_Item.GetItemCooldown(data.spell)
	if db.auras[index].layout.procFlipbook and C_Item.IsUsableItem(data.spell) and not (duration and duration > 0) then
		button.procFlipbook:Show()
		button.procFlipbookAnimGroup:Play()
	else
		button.procFlipbook:Hide()
		button.procFlipbookAnimGroup:Stop()
	end
	-- -----
	
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
function clcret:AuraButtonExecItemVisible2NoCooldown()
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
	
		-- Show the flipbook effect if enabled
	local start, duration = C_Item.GetItemCooldown(data.spell)
	if db.auras[index].layout.procFlipbook and C_Item.IsUsableItem(data.spell) and not (duration and duration > 0) then
		button.procFlipbook:Show()
		button.procFlipbookAnimGroup:Play()
	else
		button.procFlipbook:Hide()
		button.procFlipbookAnimGroup:Stop()
	end
	-- -----
	
end
-- shows shows an Equipped usable item only when off cooldown
function clcret:AuraButtonExecItemVisible4NoCooldownEquip()
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
	
	
		-- Show the flipbook effect if enabled
	local start, duration = C_Item.GetItemCooldown(data.spell)
	if db.auras[index].layout.procFlipbook and C_Item.IsUsableItem(data.spell) and not (duration and duration > 0) then
		button.procFlipbook:Show()
		button.procFlipbookAnimGroup:Play()
	else
		button.procFlipbook:Hide()
		button.procFlipbookAnimGroup:Stop()
	end
	-- -----
	
	
	if not C_Item.IsEquippedItem(data.spell) then
		button:Hide()
	end
end

-- shows shows an Equipped usable item , always visible
function clcret:AuraButtonExecItemVisible3AlwaysEquip()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data

	-- fix the texture once
	if not button.hasTexture then
		button.hasTexture = true
		button.texture:SetTexture(C_Item.GetItemIconByID(data.spell))
	end
	
	button:Show()
	
	
		-- Show the flipbook effect if enabled
	local start, duration = C_Item.GetItemCooldown(data.spell)
	if db.auras[index].layout.procFlipbook and C_Item.IsUsableItem(data.spell) and not (duration and duration > 0) then
		button.procFlipbook:Show()
		button.procFlipbookAnimGroup:Play()
	else
		button.procFlipbook:Hide()
		button.procFlipbookAnimGroup:Stop()
	end
	-- -----
	
	
	if C_Item.IsUsableItem(data.spell) and C_Item.IsEquippedItem(data.spell) then
		button.texture:SetVertexColor(1, 1, 1, 1)
	else
		button.texture:SetVertexColor(0.3, 0.3, 0.3, 1)
	end
	
	local start, duration = C_Item.GetItemCooldown(data.spell)
	if duration and duration > 0 then
		button.cooldown:SetCooldown(start, duration)
	end
	
	if not C_Item.IsEquippedItem(data.spell) then
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
		local button = buttons[1]
		local spellInfo = C_Spell.GetSpellInfo
		local texture = C_Spell.GetSpellTexture(dq[1])
		button.texture:SetTexture(texture)
		
		local spellCooldownInfo = C_Spell.GetSpellCooldown(61304)
		local start, duration = spellCooldownInfo.startTime, spellCooldownInfo.duration
		
		if duration and duration > 0 then
			button.cooldown:Show()
			button.cooldown:SetCooldown(start, duration)
		else
			button.cooldown:Hide()
		end
end

-- gets the spell to use as a melee range check for each melee class
local function GetMeleeRangeCheckSpell()
	local specID = GetSpecialization() and GetSpecializationInfo(GetSpecialization())
	
	if MeleeCheckSpells[playerClass] and MeleeCheckSpells[playerClass][specID] then
		return MeleeCheckSpells[playerClass][specID]
	end
	-- fallback spell
	return 35395	
end

-- Range Check Settings !!!!
function clcret:CheckRange()

	if db.rotation.rangeCheckSkill == "_rangeoff" then
		-- for i = 1, 2 do
			buttons[1].texture:SetVertexColor(1, 1, 1)
		-- end
		return
	end
	
	if db.rotation.rangeCheckSkill == "rangeperability" then
		-- each skill shows the range of the ability
		for i = 1, 2 do
			local inRange = C_Spell.IsSpellInRange(dq[1], "target")
			if inRange then
				buttons[i].texture:SetVertexColor(1, 1, 1)
			else
				buttons[i].texture:SetVertexColor(0.8, 0.1, 0.1)
			end
		end	
		
	elseif db.rotation.rangeCheckSkill == "rangemelee" then
		-- each skill show melee range
		local spellID = GetMeleeRangeCheckSpell()
		local inRange
		-- for ret only; checks if crusading strikes(404542) is known and to use BoJ as fallback check instead
		if C_SpellBook.IsSpellInSpellBook(404542) then 
			inRange = C_Spell.IsSpellInRange(184575)
		else
			inRange = C_Spell.IsSpellInRange(spellID)
		end
		
		-- for all others
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

function clcret:CheckQueueRotation()
	dq[1], dq[2] = clcret.Rotation()
	
	spellInfo = C_Spell.GetSpellInfo
	
	-- Only get spell info if dq values are valid
	if dq[1] then
		nq[1] = spellInfo(dq[1])
	else
		nq[1] = nil
	end
	
	if dq[2] then
		nq[2] = spellInfo(dq[2])
	else
		nq[2] = nil
	end
	
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
-- update aura for a single button
function clcret:UpdateAuraButtonLayout(index)
	self:UpdateButtonLayout(auraButtons[index], db.auras[index].layout)
end

-- update a given button
function clcret:UpdateButtonLayout(button, opt)
	if not button then return end
	
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
	
	-- Handle procFlipbook visibility
	if opt.procFlipbook then
		button.procFlipbook:Show()
	else
		button.procFlipbook:Hide()
	end
	
	if button.procFlipbookTop then
		local width = opt.procFlipbookWidth or 4
		local color = opt.procFlipbookColor or {1, 0.84, 0, 1}
		
		button.procFlipbookTop:SetHeight(width)
		button.procFlipbookTop:SetVertexColor(unpack(color))
		
		button.procFlipbookBottom:SetHeight(width)
		button.procFlipbookBottom:SetVertexColor(unpack(color))
		
		button.procFlipbookLeft:SetWidth(width)
		button.procFlipbookLeft:SetVertexColor(unpack(color))
		
		button.procFlipbookRight:SetWidth(width)
		button.procFlipbookRight:SetVertexColor(unpack(color))
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
	
	-- aura buttons
	self:InitAuraButtons()
	
	-- set scale, alpha, position
	self:UpdateFrameSettings()
	
	addonInit = true
	self:CLCRETDisable()
	self.frame:SetScript("OnUpdate", OnUpdate)
end

-- Auto-detect trinket in slot 13/14
function clcret:AutoDetectTrinket(trinketSlot)
	local slotNum = trinketSlot == 1 and 13 or 14
	local trinketID = GetInventoryItemID("player", slotNum)
	
	if trinketID then
		local trinketIndex = MAX_AURAS + trinketSlot
		db.auras[trinketIndex].data.spell = tostring(trinketID)
		
		-- Only set exec type if it's not already set (preserve user's choice)
		if db.auras[trinketIndex].data.exec == "AuraButtonExecaNone" then
			db.auras[trinketIndex].data.exec = "AuraButtonExecItemVisible2NoCooldown"
		end
		
		clcret:UpdateAuraButtonLayout(trinketIndex)
		clcret:UpdateEnabledAuraButtons()
		
		return trinketID
	end
	
	return nil
end


-- initialize aura buttons
function clcret:InitAuraButtons()
	local data, layout
	for i = 1, MAX_AURAS + 2 do
		data = db.auras[i].data
		layout = db.auras[i].layout
		auraButtons[i] = self:CreateButton("aura"..i, layout.size, layout.point, clcretFrame, layout.pointParent, layout.x, layout.y, "Auras", nil, layout.procFlipbookColor)
		auraButtons[i].start = 0
		auraButtons[i].duration = 0
		auraButtons[i].expirationTime = 0
		auraButtons[i].hasTexture = false
	end
end


-- create button
function clcret:CreateButton(name, size, point, parent, pointParent, offsetx, offsety, bfGroup, isChecked, glowColor)
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
	
	local color = glowColor or {1, 0.84, 0, 1}
	
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
	
	-- Create border glow frame
	button.procFlipbook = CreateFrame("Frame", "$parentProcFlipbook", button)
	button.procFlipbook:SetAllPoints(button)
	button.procFlipbook:SetFrameLevel(button:GetFrameLevel() + 2)
	
	-- Create 4 border textures (top, bottom, left, right)
	-- Top border
	button.procFlipbookTop = button.procFlipbook:CreateTexture("$parentBorderTop", "OVERLAY")
	button.procFlipbookTop:SetHeight(7)
	button.procFlipbookTop:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	button.procFlipbookTop:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
	button.procFlipbookTop:SetTexture("Interface\\Cooldown\\starburst")
	button.procFlipbookTop:SetBlendMode("ADD")
button.procFlipbookTop:SetVertexColor(unpack(color))
	
	-- Bottom border
	button.procFlipbookBottom = button.procFlipbook:CreateTexture("$parentBorderBottom", "OVERLAY")
	button.procFlipbookBottom:SetHeight(7)
	button.procFlipbookBottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
	button.procFlipbookBottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
	button.procFlipbookBottom:SetTexture("Interface\\Cooldown\\starburst")
	button.procFlipbookBottom:SetBlendMode("ADD")
	button.procFlipbookBottom:SetVertexColor(unpack(color))
	
	-- Left border
	button.procFlipbookLeft = button.procFlipbook:CreateTexture("$parentBorderLeft", "OVERLAY")
	button.procFlipbookLeft:SetWidth(7)
	button.procFlipbookLeft:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	button.procFlipbookLeft:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
	button.procFlipbookLeft:SetTexture("Interface\\Cooldown\\starburst")
	button.procFlipbookLeft:SetBlendMode("ADD")
	button.procFlipbookLeft:SetVertexColor(unpack(color))
	
	-- Right border
	button.procFlipbookRight = button.procFlipbook:CreateTexture("$parentBorderRight", "OVERLAY")
	button.procFlipbookRight:SetWidth(7)
	button.procFlipbookRight:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
	button.procFlipbookRight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
	button.procFlipbookRight:SetTexture("Interface\\Cooldown\\starburst")
	button.procFlipbookRight:SetBlendMode("ADD")
	button.procFlipbookRight:SetVertexColor(unpack(color))
	
	-- Create animation group for pulsing effect
	local animGroup = button.procFlipbook:CreateAnimationGroup()
	
	-- Alpha animation (pulsing brightness)
	local alpha = animGroup:CreateAnimation("Alpha")
	alpha:SetDuration(0.6)
	alpha:SetFromAlpha(0.3)
	alpha:SetToAlpha(1)
	alpha:SetSmoothing("OUT")
	
	-- Scale animation (pulsing size)
local scale = animGroup:CreateAnimation("Scale")
scale:SetDuration(0.6)
scale:SetScale(1.05, 1.05)  -- Grows to 105% size
scale:SetSmoothing("OUT")
	
	animGroup:SetLooping("REPEAT")
	button.procFlipbookAnimGroup = animGroup
	
	button.procFlipbook:Hide()
	
	-- ----

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

-- --------------
-- FULL DISABLE
-- --------------
function clcret:FullDisableToggle()
	if db.fullDisable then
		-- enabled
		db.fullDisable = false
		
		-- register events
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
		self:RegisterCLEU()
		
		-- do the normal load routine
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
		
		self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
		
		-- disable
		self:CLCRETDisable()
	end
end

-- ------------------
-- HELPER FUNCTIONS
-- ------------------
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
	for i = 1, MAX_AURAS + 2 do
		if db.auras[i].enabled then
			numEnabledAuraButtons = numEnabledAuraButtons + 1
			enabledAuraButtons[numEnabledAuraButtons] = i
		end
	end
end