-- don't load if class is wrong
local _, class = UnitClass("player")
if class ~= "EVOKER" then return end

local _, xmod = ...

xmod.augmentationevokermodule = {}
xmod = xmod.augmentationevokermodule

local qTaint = true -- will force queue check

-- 
local GetTime, GetSpellCooldown, UnitBuff, UnitAura, UnitPower, UnitSpellHaste, UnitHealth, UnitHealthMax, GetActiveSpecGroup, GetTalentInfoByID, GetGlyphSocketInfo, IsUsableSpell, GetShapeshiftForm, max, min =
GetTime, GetSpellCooldown, UnitBuff, UnitAura, UnitPower, UnitSpellHaste, UnitHealth, UnitHealthMax, GetActiveSpecGroup, GetTalentInfoByID, GetGlyphSocketInfo, IsUsableSpell, GetShapeshiftForm, max, min
local db


xmod.version = 8000001
xmod.defaults = {
	version = xmod.version,
	augmentationprio = "ps2 em er_eb fb_em up_em ps1 lf",
	rangeCheckSkill = "_rangeoff",
}

-- @defines
-- ------------------------------------------------------------------------------
local idGCD = 362969 -- azure strike for gcd

-- spells
local idAzureStrike = 362969
local idDeepBreath = 433874
local idLivingFlame = 361469
local idDisintegrate = 356995
local idUnravel = 368432

-- empower spells
local idFireBreath = 357208
local idEternitySurge = 359073
local idUpheaval = 396286 -- Aug

-- Font of Magic spells (Upranks Fire Breath and Eternity Surge)
local idFireBreathII = 382266
local idEternitySurgeII = 382411
local idUpheavalII = 408092

-- Augmentation Spells
local idPrescience = 409311
local idEbonMight = 395152
local idBreathOfEons = 442204
local idEruption = 395160

-- Talent spells (for checking if talented)
local idIridescence = 370867
local idShatteringStar = 370452
local idFirestorm = 368847
local idBreathOfEonsTalent = 403631
local idFontOfMagic = 408083

-- buffs
local idEssenceBurst = 392268
local idIridescenceRed = 386353
local idIridescenceBlue = 386399
local idDragonrage = 375087
local idSnapfire = 370818
local idBurnout = 375802
local idScales = 370553
local idEbonMightBuff = 395296

-- debuffs
local idShatteringStar = 370452

-- status vars
local s1, s2
local s_ctime, s_otime, s_gcd, s_hp, s_dp, s_aw, s_ss, s_dc, s_fv, s_bc, s_haste, s_in_execute_range

-- spell charges
local s_PSCharges = 0

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

local function GetPSData()
	local chargeInfo = C_Spell.GetSpellCharges(idPrescience)
	local charges, maxCharges, start, duration = chargeInfo.currentCharges, chargeInfo.maxCharges, chargeInfo.cooldownStart, chargeInfo.cooldownDuration;
	if (charges >= 2) then
		return 0, 2
	end

	if start == nil then
		return 100, charges
	end
	local cd = start + duration - s_ctime - s_gcd
	if cd < 0 then
		return 0, min(2, charges + 1)
	end

	return cd, charges
end

-- -------------------
-- /dump C_UnitAuras.GetBuffDataByIndex("Player", 1)
-- /dump C_UnitAuras.GetDebuffDataByIndex("Target", 1)

-- /dump IsSpellOverlayed() -- used to check if it's glowing overlay is active
-- /dump IsSpellKnownOrOverridesKnown()
-- /dump C_Spell.IsSpellUsable()
-- /dump C_Spell.GetSpellCooldown()
-- /dump IsPlayerSpell() -- use this one to check for talent spells in the tree
-- /dump GetActionInfo(slot)

-- costs = GetSpellPowerCost()	

-- (OLD) Do NOT put a check for "GetSpellCooldown(SpellID or Addon Shorthand)" in code, it will cause issues with GCD and displaying it as current recommendation
-- -------------------

-- actions ---------------------------------------------------------------------
local actions = {	
	
	--	Living Flame
	lf = {
		id = idLivingFlame,
		GetCD = function()
			
			if (s1 ~= idLivingFlame) then
				return GetCooldown(idLivingFlame)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		
		info = "Living Flame (or Chrono Flame)",
	},
	
	-- Empowered ----------------------------------------------------------------

	-- Fire Breath
	fb = {
		id = idFireBreath,
		GetCD = function()		
	
			FontOfMagic = IsPlayerSpell(idFontOfMagic)
	
			if (s1 ~= idFireBreath) and (C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII)) then
				return 0
			end
			
			if (s1 ~= idFireBreath) and FontOfMagic and (GetCooldown(idFireBreathII) < 1) then
				return 0
			end	
			
			if (s1 ~= idFireBreath) and not(FontOfMagic) and (GetCooldown(idFireBreath) < 1) then
				return 0
			end	
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		
		info = "Fire Breath",
	},

	-- Fire Breath w/Ebon Might up
	fb_em = {
		id = idFireBreath,
		GetCD = function()		
	
			FontOfMagic = IsPlayerSpell(idFontOfMagic)
	
			if (s1 ~= idFireBreath) and (C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII)) then
				return 0
			end
			
			if (s1 ~= idFireBreath) and s_buff_EbonMight and FontOfMagic and (GetCooldown(idFireBreathII) < 1) then
				return 0
			end	
			
			if (s1 ~= idFireBreath) and s_buff_EbonMight and not(FontOfMagic) and (GetCooldown(idFireBreath) < 1) then
				return 0
			end	
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		
		info = "Fire Breath w/Ebon Might up",
	},
	
		--	Upheaval w/Ebon Might up
	up = {
		id = idUpheaval,
		GetCD = function()	
		
			FontOfMagic = IsPlayerSpell(idFontOfMagic)
	
			if (s1 ~= idUpheaval) and (C_Spell.IsCurrentSpell(idUpheaval) or C_Spell.IsCurrentSpell(idUpheavalII)) then
				return 0
			end
			
			if (s1 ~= idUpheaval) and FontOfMagic and (GetCooldown(idUpheavalII) < 1) then
				return 0
			end	
			
			if (s1 ~= idUpheaval) and not(FontOfMagic) and (GetCooldown(idUpheaval) < 1) then
				return 0
			end	
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Upheaval w/Ebon Might up",
	},
	
	--	Upheaval w/Ebon Might up
	up_em = {
		id = idUpheaval,
		GetCD = function()	
		
			FontOfMagic = IsPlayerSpell(idFontOfMagic)
	
			if (s1 ~= idUpheaval) and (C_Spell.IsCurrentSpell(idUpheaval) or C_Spell.IsCurrentSpell(idUpheavalII)) then
				return 0
			end
			
			if (s1 ~= idUpheaval) and s_buff_EbonMight and FontOfMagic and (GetCooldown(idUpheavalII) < 1) then
				return 0
			end	
			
			if (s1 ~= idUpheaval) and s_buff_EbonMight and not(FontOfMagic) and (GetCooldown(idUpheaval) < 1) then
				return 0
			end	
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Upheaval w/Ebon Might up",
	},

	-- ----------------------------------------------------------------------------

	-- Prescience 1 stack
	ps1 = {
		id = idPrescience,
		GetCD = function()
		
			local cd, charges = GetPSData()
		
			if (s1 ~= idPrescience) and (s_PSCharges == 1) and IsSpellKnown(idPrescience) then
				return GetCooldown(idPrescience)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_PSCharges = max(0, s_PSCharges - 1)

		end,
		info = "Prescience @ 1 stack",
	},
	
	-- Prescience 2 stacks
	ps2 = {
		id = idPrescience,
		GetCD = function()
		
			local cd, charges = GetPSData()
		
			if (s1 ~= idPrescience) and (s_PSCharges == 2) and IsSpellKnown(idPrescience) then
				return GetCooldown(idPrescience)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_PSCharges = max(0, s_PSCharges - 1)			

		end,
		info = "Prescience @ 2 stacks",
	},
	
	-- Prescience, regardless of stacks
	ps = {
		id = idPrescience,
		GetCD = function()
		
			local cd, charges = GetPSData()
		
			if (s1 ~= idPrescience) and (s_PSCharges == 1) or (s_PSCharges == 2) and IsSpellKnown(idPrescience) then
				return GetCooldown(idPrescience)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_PSCharges = max(0, s_PSCharges - 1)			

		end,
		info = "Prescience, regardless of stacks",
	},
	
	--	Ebon Might
	em = {
		id = idEbonMight,
		GetCD = function()	
			if (s1 ~= idEbonMight) then
				return GetCooldown(idEbonMight)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Ebon Might",
	},
	
	--	Breath of Eons
	boe = {
		id = idBreathOfEons,
		GetCD = function()
			if (s1 ~= idBreathOfEons) and IsPlayerSpell(idBreathOfEonsTalent) then
				return GetCooldown(idBreathOfEons)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Breath of Eons",
	},

	-- Eruption
	er = {
		id = idEruption,
		GetCD = function()
		
			if (s1 ~= idEruption) and ((s_es > 1) or s_buff_EssenceBurst) then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_es = max(5, s_es - 2)
		end,
		info = "Eruption",
	},
	
	-- Eruption
	er_em = {
		id = idEruption,
		GetCD = function()
		
			if (s1 ~= idEruption) and s_buff_EbonMight and ((s_es > 1) or s_buff_EssenceBurst) then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_es = max(5, s_es - 2)
		end,
		info = "Eruption w/Ebon Might up",
	},
	
	-- Eruption w/ Essence Burst
	er_eb = {
		id = idEruption,
		GetCD = function()
		
			if (s1 ~= idEruption) and s_buff_EssenceBurst then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_es = max(5, s_es - 2)
		end,
		info = "Eruption w/Essence Burst up (Doesn't check for Ebon Might)",
	},

}
--------------------------------------------------------------------------------

local function UpdateQueue()
	-- normal queue
	qn = {}
	for v in string.gmatch(db.augmentationprio, "[^ ]+") do
		if actions[v] then
			table.insert(qn, v)
		else
			print("Augmentation - invalid action:", v)
		end
	end
	db.augmentationprio = table.concat(qn, " ")

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
	
	-- ------------

	s_buff_EssenceBurst = C_UnitAuras.GetPlayerAuraBySpellID(idEssenceBurst)
	s_buff_IridescenceRed = C_UnitAuras.GetPlayerAuraBySpellID(idIridescenceRed)
	s_buff_IridescenceBlue = C_UnitAuras.GetPlayerAuraBySpellID(idIridescenceBlue)
	s_buff_Dragonrage = C_UnitAuras.GetPlayerAuraBySpellID(idDragonrage)
	s_buff_Snapfire = C_UnitAuras.GetPlayerAuraBySpellID(idSnapfire)
	s_buff_Burnout = C_UnitAuras.GetPlayerAuraBySpellID(idBurnout)
	s_buff_Scales = C_UnitAuras.GetPlayerAuraBySpellID(idScales)
	s_buff_EbonMight = C_UnitAuras.GetPlayerAuraBySpellID(idEbonMightBuff)

	-- retrieves localized debuff spell name
	local spellInfoShatteringStar = C_Spell.GetSpellInfo(idShatteringStar)
	local debuffShatteringStar = spellInfoShatteringStar.name

	-- the debuffs
	s_debuff_ShatteringStar = AuraUtil.FindAuraByName(debuffShatteringStar, "target", "HARMFUL")

	-- Prescience Charges
	local cd, charges = GetPSData()
	s_PSCharges = charges

	-- client essence and haste
	s_es = UnitPower("player", 19)
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
			isKnown = IsPlayerSpell(actions[v].reqTalent)
			if isKnown then
				table.insert(q, v)
			end
		else
			table.insert(q, v)
		end				
	end
end

local function GetNextAction()
	-- check if working queue needs updated due to talent changes
	if qTaint then
		GetWorkingQueue()
		qTaint = false
	end

	local n = #q

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
	UpdateQueue()
end

function xmod.GetActions()
	return actions
end

function xmod.Update()
	UpdateQueue()
end

function xmod.Rotation()
	s1 = nil
	GetStatus()
	if debug and debug.enabled then
		debug:Clear()
		debug:AddBoth("ctime", s_ctime)
		debug:AddBoth("gcd", s_gcd)
		debug:AddBoth("haste", s_haste)
	end
	
	local action
	s1, action = GetNextAction()
	if debug and debug.enabled then
		debug:AddBoth("s1", action)
		debug:AddBoth("s1Id", s1)
	end
	-- 
	s_otime = s_ctime -- save it so we adjust buffs for next
	actions[action].UpdateStatus()

	s_otime = s_ctime - s_otime

	-- prescience stacks
	local cd, charges = GetPSData()
		s_PSCharges = charges
	
	if (s1 == idPrescience) then
		s_PSCharges = s_PSCharges - 1
	end
	-- ---------
	
	if debug and debug.enabled then
		debug:AddBoth("psc", s_PSCharges)
	end

	if debug and debug.enabled then
		debug:AddBoth("ctime", s_ctime)
		debug:AddBoth("otime", s_otime)
		debug:AddBoth("gcd", s_gcd)
		debug:AddBoth("hp", s_hp)
		debug:AddBoth("haste", s_haste)

	end
	s2, action = GetNextAction()
	if debug and debug.enabled then
		debug:AddBoth("s2", action)
	end

	return s1, s2
end

-- event frame
local ef = CreateFrame("Frame", "AugModuleEventFrame") -- event frame
ef:Hide()
local function OnEvent()
	qTaint = true
end

ef:SetScript("OnEvent", OnEvent)
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("PLAYER_TALENT_UPDATE")
ef:RegisterEvent("PLAYER_LEVEL_UP")