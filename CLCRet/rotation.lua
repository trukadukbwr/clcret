
local _, class = UnitClass("player")
local _, xmod = ...

xmod.rotationAssist = {}
xmod = xmod.rotationAssist

local qTaint = true -- will force queue check

local db

xmod.version = 9000001
xmod.defaults = {
	version = xmod.version,
	rangeCheckSkill = "_rangeoff",
	trinketMode = false,
}

-- ------------------------------------------------------------------------------

-- local idGCD = 61304

local db

-- Get trinket spell id
-- local function GetTrinketSpellID(slot)
    -- local itemID = GetInventoryItemID("player", slot)
    -- if itemID then
        -- local _, spellID = C_Item.GetItemSpell(itemID)
        -- return spellID
    -- end
    -- return nil
-- end

-- status vars
-- local s1

-- local overrideActions = {

	-- trink1 = {
		-- GetID = function()
			-- return GetTrinketSpellID(13)
		-- end,
		
		-- GetCD = function()
		
			-- local id = GetTrinketSpellID(13)
			
			-- if id and (s1 ~= id) and GetInventoryItemCooldown("player", 13) < 1 then
				-- return GetInventoryItemCooldown("player", 13)
			-- end			
			-- return 100
		-- end,
		
			-- UpdateStatus = function()
		-- end,
		
		-- info = "",
	-- },

	-- trink2 = {
		-- GetID = function()
			-- return GetTrinketSpellID(14)
		-- end,
		
		-- GetCD = function()
		
			-- local id = GetTrinketSpellID(14)
			
			-- if id and (s1 ~= id) and GetInventoryItemCooldown("player", 14) < 1 then
				-- return GetInventoryItemCooldown("player", 14)
			-- end			
			-- return 100
		-- end,
		
		-- UpdateStatus = function()
		-- end,
		-- info = "",
	-- },

-- }

-- this function should be called from addons
function xmod.Init()
	db = xmod.db
	-- print "|cffF58CBAclcRet|r: A module is not yet available for this spec. |cff33E8CDGeneric Module|r Loaded"
end

-- function xmod.Rotation()

	-- Trinket Override
	-- if db.trinketMode then
		-- local cd1 = overrideActions.trink1.GetCD()
		-- if cd1 == 0 then
			-- s1 = overrideActions.trink1.GetID()
			-- overrideActions.trink1.UpdateStatus()
		-- end
	-- end
	
	-- if db.trinketMode then
		-- local cd2 = overrideActions.trink2.GetCD()
		-- if cd2 == 0 and s1 ~= overrideActions.trink1.GetID() then
			-- s1 = overrideActions.trink2.GetID()
			-- overrideActions.trink2.UpdateStatus()
		-- end
	-- end

	-- return s1
-- end

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