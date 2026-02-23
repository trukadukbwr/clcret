
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


local db



-- this function should be called from addons
function xmod.Init()
	db = xmod.db
	-- print "|cffF58CBAclcRet|r: A module is not yet available for this spec. |cff33E8CDGeneric Module|r Loaded"
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
