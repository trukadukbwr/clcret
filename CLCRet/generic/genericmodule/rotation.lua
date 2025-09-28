	-- FOR REFERENCE ONLY!! USED TO DETERMINE WHAT TO RENAME "genericprio"!! Feel free to delete after customizing!!
	-- PALADIN = {
		-- [1] = "hpalprio", 
		-- [2] = "protpallyprio", 
		-- [3] = "prio",      -- Ret
	-- },
	
	-- WARRIOR = {
		-- [1] = "armsprio",
		-- [2] = "furyprio",
		-- [3] = "protwarrprio",
	-- },
	
	-- DEATHKNIGHT = {
		-- [1] = "blooddkprio",
		-- [2] = "frostdkprio",
		-- [3] = "unholydkprio",
	-- },
	
	-- DEMONHUNTER = {
		-- [1] = "havocprio",
		-- [2] = "vengeanceprio",
		-- [3] = "annihilatorprio", -- (Midnight) (Placeholder)
	-- },
	
	-- DRUID = {
		-- [1] = "balanceprio",
		-- [2] = "feralprio",
		-- [3] = "guardianprio",
		-- [4] = "restorationprio"
	-- },
	
	-- EVOKER = {
		-- [1] = "devastationprio",
		-- [2] = "preservationprio",
		-- [3] = "augmentationprio",
	-- },
	
	-- HUNTER = {
		-- [1] = "beastmasteryprio",
		-- [2] = "marksmanshipprio",
		-- [3] = "survivalprio",
	-- },
	
	-- MAGE = {
		-- [1] = "arcaneprio",
		-- [2] = "fireprio",
		-- [3] = "frostprio",
	-- },
	
	-- MONK = {
		-- [1] = "brewmasterprio",
		-- [2] = "mistweaverprio",
		-- [3] = "windwalkerprio",
	-- },
	
	-- PRIEST = {
		-- [1] = "disciplineprio",
		-- [2] = "holyprio",
		-- [3] = "shadowprio",
	-- },
	
	-- ROGUE = {
		-- [1] = "assassinationprio",
		-- [2] = "outlawprio",
		-- [3] = "subtletyprio",
	-- },
	
	-- SHAMAN = {
		-- [1] = "elementalprio",
		-- [2] = "enhancementprio",
		-- [3] = "restorationprio",
	-- },
	
	-- WARLOCK = {
		-- [1] = "afflictionprio",
		-- [2] = "demonologyprio",
		-- [3] = "destructionprio",
	-- },

local _, class = UnitClass("player")
local _, xmod = ...

xmod.genericmodule = {} -- change these two lines to correct spec module!!!
xmod = xmod.genericmodule

local qTaint = true -- will force queue check

local GetTime, GetSpellCooldown, UnitBuff, UnitAura, UnitPower, UnitSpellHaste, UnitHealth, UnitHealthMax, GetActiveSpecGroup, GetTalentInfoByID, GetGlyphSocketInfo, IsUsableSpell, GetShapeshiftForm, max, min, SPELL_POWER_HOLY_POWER =
GetTime, GetSpellCooldown, UnitBuff, UnitAura, UnitPower, UnitSpellHaste, UnitHealth, UnitHealthMax, GetActiveSpecGroup, GetTalentInfoByID, GetGlyphSocketInfo, IsUsableSpell, GetShapeshiftForm, max, min, SPELL_POWER_HOLY_POWER
local db

xmod.version = 9000001
xmod.defaults = {
	version = xmod.version,
	genericprio = "blizz druid warrior hunter mage rogue priest warlock paladin monk demonhunter deathknight evoker shaman", -- change to specprio and default rotation!!!
	rangeCheckSkill = "_rangeoff",
	BlizzMode = true,
	classIconToggle = true, 
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

-- spells
-- local idJudgment = 20271
local idBlizzRotation = 1229376 -- The actual id for the one button helper spell, saved for reference
local idDruid = 190888
local idWarrior = 143420
local idHunter = 401125
local idMage = 401130
local idRogue = 401126
local idPriest = 401127
local idWarlock = 401131
local idPaladin = 401124
local idShaman = 402814
local idMonk = 401132
local idDemonHunter = 401134
local idDeathKnight = 401128
local idEvoker = 401135

-- racials
local idArcaneTorrent = 155145
local idLightsJudgment = 255647

-- Talents
-- ids for talent spells (the actual talent in the tree, not the spell in the spellbook)
-- local idExecutionSentence = 343527

-- Hero Talents
-- local idHammerOfLight = 427453

-- adds charges to spells; ids for actual talents
-- local idJudgment2 = 405278

-- makes passive
-- local idCrusadingStrikes = 404542

-- modify power costs
-- local idDivineAuxiliary = 406158

-- buffs
-- local idAvengingWrath = 31884

-- status vars
local s1, s2
local s_ctime, s_otime, s_gcd, s_haste, s_in_execute_range

-- local s_JudgmentCharges = 0 -- spell charges function !!!

-- the queue
local qn = {} -- normal queue
local q -- working queue

local function GetCooldown(id)
	local spellCooldownInfo = C_Spell.GetSpellCooldown(id)
	local start, duration = spellCooldownInfo.startTime, spellCooldownInfo.duration
	
	if start == nil then return 100 end
	local cd = start + duration - s_ctime - s_gcd
	if cd < 0 then return 0 end
	return cd
end

-- ----------------
-- Spell Charges --
-- ----------------
-- activate as needed per spec with spell charges !!!
-- local function GetJudgmentData()
	-- local chargeInfo = C_Spell.GetSpellCharges(idJudgment)
	-- local charges, maxCharges = chargeInfo.currentCharges, chargeInfo.maxCharges;
	-- if (charges >= 2) then
		-- return 0, 2
	-- end

	-- if start == nil then
		-- return 100, charges
	-- end
	-- local cd = start + duration - s_ctime - s_gcd
	-- if cd < 0 then
		-- return 0, min(2, charges + 1)
	-- end

	-- return cd, charges
-- end

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
				return GetCooldown(id)
			end			
			return 100
		end,
		
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
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
				return GetCooldown(id)
			end			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			
		end,
		info = "",
	},

}

-- actions ---------------------------------------------------------------------
local actions = {

	-- --------
	-- Racials
	-- --------
		
	-- Light's Judgment 
	lj = {
		id = idLightsJudgment,
		GetCD = function()
		
			if (s1 ~= idLightsJudgment) and GetCooldown(idLightsJudgment) < 1 then
				return GetCooldown(idLightsJudgment)
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		
		info = "|cffe7e303Light's Judgment|r (Lightforged Draenei)",
		
		reqTalent = idLightsJudgment,
	},

	-- ---------------------------
	-- Blizzard Assisted Rotation
	-- ---------------------------
	
	blizz = {
		id = GetBlizzID,
		GetCD = function()
		
			-- add checker functions here
			 local idBlizz = GetBlizzID()
			 
			if idBlizz and  (s1 ~= idBlizz) and GetCooldown(idBlizz) < 1 then
					return 100
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			-- s_hp = max(3, s_hp + 3) -- example secondary power function

		end,
		
		info = "|cfffe8a00Blizz Suggested Rotation|r",
		
		-- reqTalent = idBlizz, -- required talent function
	},
	druid = {
		id = idDruid,
		GetCD = function() 
		local _, class = UnitClass("player")
		
		if class ~= "DRUID" and db.classIconToggle then
			return 100
		end
		
			return 0 
		end, 
		
		UpdateStatus = function() 
		
		end,
		
		info = "Class Icon",
	},
	warrior= {
		id = idWarrior,
		GetCD = function() 
		local _, class = UnitClass("player")
		if class ~= "WARRIOR" and db.classIconToggle then
			return 100
		end
			return 0 
		end, 
		
		UpdateStatus = function() 
		
		end,
		
		info = "Class Icon",
	},
	hunter = {
		id = idHunter,
		GetCD = function() 
		local _, class = UnitClass("player")
		if class ~= "HUNTER" and db.classIconToggle then
			return 100
		end
			return 0 
		end, 
		
		UpdateStatus = function() 
		
		end,
		
		info = "Class Icon",
	},
	mage = {
		id = idMage,
		GetCD = function() 
		local _, class = UnitClass("player")
		if class ~= "MAGE" and db.classIconToggle then
			return 100
		end
			return 0 
		end, 
		
		UpdateStatus = function() 
		
		end,
		
		info = "Class Icon",
	},
	rogue = {
		id = idRogue,
		GetCD = function() 
		local _, class = UnitClass("player")
		if class ~= "ROGUE" and db.classIconToggle then
			return 100
		end
			return 0 
		end, 
		
		UpdateStatus = function() 
		
		end,
		
		info = "Class Icon",
	},
	priest = {
		id = idPriest,
		GetCD = function() 
		local _, class = UnitClass("player")
		if class ~= "PRIEST" and db.classIconToggle then
			return 100
		end
			return 0 
		end, 
		
		UpdateStatus = function() 
		
		end,
		
		info = "Class Icon",
	},
	warlock = {
		id = idWarlock,
		GetCD = function() 
		local _, class = UnitClass("player")
		if class ~= "WARLOCK" and db.classIconToggle then
			return 100
		end
			return 0 
		end, 
		
		UpdateStatus = function() 
		
		end,
		
		info = "Class Icon",
	},
	paladin = {
		id = idPaladin,
		GetCD = function() 
		local _, class = UnitClass("player")
		if class ~= "PALADIN" and db.classIconToggle then
			return 100
		end
			return 0 
		end, 
		
		UpdateStatus = function() 
		
		end,
		
		info = "Class Icon",
	},
	shaman = {
		id = idShaman,
		GetCD = function() 
		local _, class = UnitClass("player")
		if class ~= "SHAMAN" and db.classIconToggle then
			return 100
		end
			return 0 
		end, 
		
		UpdateStatus = function() 
		
		end,
		
		info = "Class Icon",
	},
	monk = {
		id = idMonk,
		GetCD = function() 
		local _, class = UnitClass("player")
		if class ~= "MONK" and db.classIconToggle then
			return 100
		end
			return 0 
		end, 
		
		UpdateStatus = function() 
		
		end,
		
		info = "Class Icon",
	},
	demonhunter = {
		id = idDemonHunter,
		GetCD = function() 
		local _, class = UnitClass("player")
		if class ~= "DEMONHUNTER" and db.classIconToggle then
			return 100
		end
			return 0 
		end, 
		
		UpdateStatus = function() 
		
		end,
		
		info = "Class Icon",
	},
	deathknight = {
		id = idDeathKnight,
		GetCD = function() 
		local _, class = UnitClass("player")
		if class ~= "DEATHKNIGHT" and db.classIconToggle then
			return 100
		end
			return 0 
		end, 
		
		UpdateStatus = function() 
		
		end,
		
		info = "Class Icon",
	},
	evoker = {
		id = idEvoker,
		GetCD = function() 
		local _, class = UnitClass("player")
		if class ~= "EVOKER" and db.classIconToggle then
			return 100
		end
			return 0 
		end, 
		
		UpdateStatus = function() 
		
		end,
		
		info = "Class Icon",
	},
}
-- -----------------------------------------------------------------------------

local function UpdateQueue()
	-- normal queue -- change genericprio to specprio !!!
	qn = {}
	for v in string.gmatch(db.genericprio, "[^ ]+") do 
		if actions[v] then
			table.insert(qn, v)
		else
			print("Generic Module - invalid action:", v)
		end
	end
	db.genericprio = table.concat(qn, " ") 

	-- force reconstruction for q
	qTaint = true
end

	-- reads all the interesting data // List of Buffs
local function GetStatus()
	-- current time
	s_ctime = GetTime()

	-- gcd value
	local spellCooldownInfo = C_Spell.GetSpellCooldown(idGCD)
	local start, duration = spellCooldownInfo.startTime, spellCooldownInfo.duration
	
	s_gcd = start + duration - s_ctime
	if s_gcd < 0 then s_gcd = 0 end
		
	-- the buffs !!!
	-- s_buff_AvengingWrath = C_UnitAuras.GetPlayerAuraBySpellID(idAvengingWrath)

	-- retrieves localized debuff spell name !!!
	-- local spellInfoJudgment = C_Spell.GetSpellInfo(idJudgment)
	-- local debuffJudgment = spellInfoJudgment.name
	
	-- the debuffs !!!
	-- s_debuff_Judgment = AuraUtil.FindAuraByName(debuffJudgment, "target", "HARMFUL")

	-- ----------------------------------------
	-- Spell Charges for GetStatus Function --
	-- ----------------------------------------

	-- crusader strike stacks. Change/activate per spec if needed (per spell)!!!
	-- local cd, charges = GetCSData()
	-- s_CrusaderStrikeCharges = charges

	-- -----------------------
	-- client secondary power and haste --
	-- -----------------------
	-- s_hp = UnitPower("player", 9) --change to spec secondary power (holy power, arcane charges, etc)!!!
	s_haste = 1 + UnitSpellHaste("player") / 100
	
end

-- remove all talents not available and present in rotation
-- adjust for modified skills present in rotation
local function GetWorkingQueue()
	q = {}
	local name, selected, available
	for k, v in pairs(qn) do
		-- see if it has a talent requirement
		if actions[v].reqTalent then
			-- see if the talent is activated
			isKnown = C_SpellBook.IsSpellInSpellBook(actions[v].reqTalent)
			if isKnown then
				table.insert(q, v)
			end
		else
			table.insert(q, v)
		end				
	end
end

local function GetNextAction()

	-- Forces assisted combat spell check each rotational change
	actions.blizz.id = GetBlizzID()
	C_AssistedCombat.GetNextCastSpell()
	
	-- check if working queue needs updated due to talent changes
	if qTaint then
		GetWorkingQueue()
		qTaint = false
	end

	local n = #q

	-- Shortcuts, DO NOT PUT "level = UnitLevel" stuff here, leave that in each string
	-- It's ok if its "playerLevel = UnitLevel", but it cannot just be "level = UnitLevel"
	targetLevel = UnitLevel("target")
	playerLevel = UnitLevel("player")
	-- AssistedDS = select(1, C_AssistedCombat.GetNextCastSpell()) -- assistedDS = need aoe / db.aoemode = suggest aoe. Activate AOE mode per spec!!!

	-- Checker strings. Change to list of needed checks for spec!!!
	-- awCheck = (s_buff_AvengingWrath or s_buff_Crusade)

	-- Spell known checks. !!!
	-- knownSBA = C_SpellBook.IsSpellInSpellBook(idBlizz)

	-- Spell usable checks !!!
	-- usableTV = C_Spell.IsSpellUsable(idTemplarsVerdict)

	-- Talent checks !!!
	-- CrusadingStrikes = C_SpellBook.IsSpellInSpellBook(idCrusadingStrikes)

	-- parse once, get cooldowns, return first 0
	for i = 1, n do
		local action = actions[q[i]]
		local cd = action.GetCD()
		if debug and debug.enabled then
			debug:AddBoth(q[i], cd)
		end
		if cd == 0 then
			return action.id, q[i]
		end
		action.cd = cd
	end

	-- parse again, return min cooldown
	local minQ = 1
	local minCd = actions[q[1]].cd
	for i = 2, n do
		local action = actions[q[i]]
		if minCd > action.cd then
			minCd = action.cd
			minQ = i
		end
	end
	return actions[q[minQ]].id, q[minQ]
end

-- exposed functions

-- this function should be called from addons
function xmod.Init()
	db = xmod.db
	local specID = C_SpecializationInfo.GetSpecialization()
	clcret.db.profile.rotation.specBlizzMode = clcret.db.profile.rotation.specBlizzMode or {}
	clcret.db.profile.rotation.specBlizzMode[specID] = true
	UpdateQueue()
	print "|cffF58CBAclcRet|r: A module is not yet available for this spec. |cff33E8CDGeneric Module|r Loaded"
end

function xmod.GetActions() -- This is the actions list
	return actions
end

local function SafeInit()
    if xmod and xmod.GetActions then
		-- Do your normal initialization
		local actions = xmod.GetActions()
	else
		C_Timer.After(0.5, SafeInit)
	end
end

-- Call SafeInit() instead of directly calling xmod.GetActions() in your OnInitialize or at login
function xmod.Update()
	UpdateQueue()
end

function xmod.Rotation()
	s1 = nil
	GetStatus()
	db.BlizzMode = true

	local action
	s1, action = GetNextAction()

	-- 
	s_otime = s_ctime -- save it so we adjust buffs for next
	actions[action].UpdateStatus()

	s_otime = s_ctime - s_otime

	-- -----------------------------------
	-- Spell Charges for xmod.rotation --
	-- -----------------------------------
	
	-- spell charges
	-- local cd, charges = GetCSData()
		-- s_CrusaderStrikeCharges = charges
	
	-- if (s1 == idCrusaderStrike) then
		-- s_CrusaderStrikeCharges = s_CrusaderStrikeCharges - 1

	-- end

	-- -----------
	-- AOE Mode --
	-- -----------

	-- local AssistedDS = select(1, C_AssistedCombat.GetNextCastSpell())
	-- local level = UnitLevel("target")
	-- local className = UnitClass("target")
	-- local SoulHunterCheck = ((className == "Adarus Duskblaze") or (className == "Velaryn Bloodwrath") or (className == "Ilyssa Darksorrow"))
	-- local SoulbinderCheck = ((className == "Shadowguard Mage") or (className == "Shadowguard Assassin") or (className == "Shadowguard Phaseblade") or (className == "Soulbinder Naazindhri"))
	-- local ForgeweaverCheck = ((className == "Forgeweaver Araz") or (className == "Arcane Echo") or (className == "Arcane Manifestation"))
	
	-- if ((AssistedDS == 53385) and db.aoeMode and ((level > 0) and (level < 82))) or ((SoulHunterCheck or SoulbinderCheck or ForgeweaverCheck) and (s1 == idTemplarsVerdict) and (AssistedDS == 53385)) then
		-- s1 = idDivineStorm
	-- end

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
	
	-- Blizz assisted combat api
	local specID = C_SpecializationInfo.GetSpecialization()
	local blizzEnabled = clcret.db.profile.rotation.specBlizzMode[specID] or false
	local idBlizz = GetBlizzID()
	
	if blizzEnabled and s1~= overrideActions.trink1.GetID() and s1 ~= overrideActions.trink2.GetID()then
		s1 = idBlizz
	end

	if debug and debug.enabled then
		debug:AddBoth("ctime", s_ctime)
		debug:AddBoth("otime", s_otime)
		debug:AddBoth("gcd", s_gcd)
		debug:AddBoth("haste", s_haste)
	end
	
	s2, action = GetNextAction()
	if debug and debug.enabled then
		debug:AddBoth("s2", action)
	end

	-- Class icon Override
	if not db.classIconToggle then 
		s2 = s1
	end

	return s1, s2
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