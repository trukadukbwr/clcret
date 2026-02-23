
local _, class = UnitClass("player")
local _, xmod = ...

xmod.genericmodule = {}
xmod = xmod.genericmodule

local qTaint = true -- will force queue check

local db

xmod.version = 9000001
xmod.defaults = {
	version = xmod.version,
	rangeCheckSkill = "_rangeoff",
	-- updatesPerSecond = 10,
	-- updatesPerSecondAuras = 5,
	trinketMode = false,
}

-- @defines
-- ------------------------------------------------------------------------------
local playerLevel = UnitLevel("Player")
local idGCD = 61304

local db

local function GetBlizzID()
    return select(1, C_AssistedCombat.GetNextCastSpell())
end

local function GetTrinketSpellID(slot)
    local itemID = GetInventoryItemID("player", slot)
    if itemID then
        local _, spellID = C_Item.GetItemSpell(itemID)
        return spellID
    end
    return nil
end

-- status vars
local s1
-- -------------------
-- s_hp = min(3, s_hp + 2) is telling the addon what hp you need to reach for tv

-- /dump C_UnitAuras.GetBuffDataByIndex("Player", 1)
-- /dump C_UnitAuras.GetDebuffDataByIndex("Target", 1)
-- /dump GetActionInfo(1)
--
-- C_SpellBook.IsSpellInSpellBook()
-- C_Spell.IsSpellUsable()
-- C_Spell.GetSpellCooldown()
-- Dummy spell for GCD = 61304
-- costs = GetSpellPowerCost(255937)	
-- -----------------------------------------------------------------------------

local overrideActions = {

	trink1 = {
		GetID = function()
			return GetTrinketSpellID(13)
		end,
		
		GetCD = function()
		
			local id = GetTrinketSpellID(13)
			
			if id and (s1 ~= id) and GetInventoryItemCooldown("player", 13) < 1 then
				return GetInventoryItemCooldown("player", 13)
			end			
			return 100
		end,
		
			UpdateStatus = function()
		end,
		
		info = "",
	},

	trink2 = {
		GetID = function()
			return GetTrinketSpellID(14)
		end,
		
		GetCD = function()
		
			local id = GetTrinketSpellID(14)
			
			if id and (s1 ~= id) and GetInventoryItemCooldown("player", 14) < 1 then
				return GetInventoryItemCooldown("player", 14)
			end			
			return 100
		end,
		
		UpdateStatus = function()
		end,
		info = "",
	},

}

-- actions ---------------------------------------------------------------------
local actions = {

	blizz = {
		id = GetBlizzID,
		GetCD = function()
		
			-- add checker functions here
			 local idBlizz = GetBlizzID()
			 
			if idBlizz and (s1 ~= idBlizz) then
					return 100
			end
			
			return 100
		end,
		
		info = "|cfffe8a00Blizz Suggested Rotation|r",
		
	},

}

-- this function should be called from addons
function xmod.Init()
	db = xmod.db
	-- print "|cffF58CBAclcRet|r: A module is not yet available for this spec. |cff33E8CDGeneric Module|r Loaded"
end

function xmod.GetActions() -- This is the actions list
	return actions
end

function xmod.Rotation()
	local idBlizz = GetBlizzID()
	s1 = idBlizz

	local action
	s1, action = idBlizz

	-- Trinket Override
	if db.trinketMode then
		local cd1 = overrideActions.trink1.GetCD()
		if cd1 == 0 then
			s1 = overrideActions.trink1.GetID()
			overrideActions.trink1.UpdateStatus()
		end
	end
	
	if db.trinketMode then
		local cd2 = overrideActions.trink2.GetCD()
		if cd2 == 0 and s1 ~= overrideActions.trink1.GetID() then
			s1 = overrideActions.trink2.GetID()
			overrideActions.trink2.UpdateStatus()
		end
	end

	-- og with trinket override
	if blizzEnabled and s1~= overrideActions.trink1.GetID() then
		s1 = idBlizz
	end
	
	return s1
end

-- event frame
local ef = CreateFrame("Frame", "clcRetModuleEventFrame") -- event frame
ef:Hide()
local function OnEvent()
	qTaint = true
end
ef:SetScript("OnEvent", OnEvent)
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("PLAYER_TALENT_UPDATE")
ef:RegisterEvent("PLAYER_LEVEL_UP")