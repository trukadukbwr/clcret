-- don't load if class is wrong
local _, class = UnitClass("player")
if class ~= "EVOKER" then return end

local _, xmod = ...

xmod.devastationevokermodule = {}
xmod = xmod.devastationevokermodule

local qTaint = true -- will force queue check

-- 
local GetTime, GetSpellCooldown, UnitBuff, UnitAura, UnitPower, UnitSpellHaste, UnitHealth, UnitHealthMax, GetActiveSpecGroup, GetTalentInfoByID, GetGlyphSocketInfo, IsUsableSpell, GetShapeshiftForm, max, min =
GetTime, GetSpellCooldown, UnitBuff, UnitAura, UnitPower, UnitSpellHaste, UnitHealth, UnitHealthMax, GetActiveSpecGroup, GetTalentInfoByID, GetGlyphSocketInfo, IsUsableSpell, GetShapeshiftForm, max, min
local db


xmod.version = 8000001
xmod.defaults = {
	version = xmod.version,
	devastationprio = "ss d_dr deep_ir fb lf_bo fs d6 deep d lf",
	rangeCheckSkill = "_rangeoff",
	BlizzMode = false,
	trinketMode = false,
}

-- @defines
-- ------------------------------------------------------------------------------
local idGCD = 362969 -- azure strike for gcd

-- override functions
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
local idAzureStrike = 362969
local idDeepBreath = 357210
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
local idBreathOfEons = 403631
local idEruption = 395160

-- Talent spells (for checking if talented)
local idIridescence = 370867
local idShatteringStar = 370452
local idFirestorm = 368847

-- Hero talents
local idEngulf = 443328
local idDeepBreathHero = 433874

-- buffs
local idEssenceBurst = 359618
local idIridescenceRed = 386353
local idIridescenceBlue = 386399
local idDragonrage = 375087
local idSnapfire = 370818
local idBurnout = 375802
local idScales = 370553

-- debuffs
local idShatteringStar = 370452
local idFireBreathDebuff = 357209
local idLivingFlameDebuff = 361500

-- status vars
local s1, s2
local s_ctime, s_otime, s_gcd, s_hp, s_dp, s_aw, s_ss, s_dc, s_fv, s_bc, s_haste, s_in_execute_range

local s_EngulfCharges = 0

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

local function GetEngulfData()
	local chargeInfo = C_Spell.GetSpellCharges(idEngulf)
	local charges, maxCharges = chargeInfo.currentCharges, chargeInfo.maxCharges;
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

-- IsSpellOverlayed() -- used to check if it's glowing overlay is active
-- IsSpellKnownOrOverridesKnown()
-- C_Spell.IsSpellUsable()
-- C_Spell.GetSpellCooldown()
-- IsPlayerSpell() -- use this one to check for talent spells in the tree

-- costs = GetSpellPowerCost()	

-- (OLD) Do NOT put a check for "GetSpellCooldown(SpellID or Addon Shorthand)" in code, it will cause issues with GCD and displaying it as current recommendation
-- -------------------

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
	
	--	Deep Breath
	deep = {
		id = idDeepBreath,
		GetCD = function()
		
			spec = GetSpecialization()
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII) or C_Spell.IsCurrentSpell(idEternitySurge) or C_Spell.IsCurrentSpell(idEternitySurgeII) or C_Spell.IsCurrentSpell(idDisintegrate))
			
			if (s1 ~= idDeepBreath) and spec == 1 and EmpowerCheck and IsPlayerSpell(idDeepBreath) and not IsSpellKnownOrOverridesKnown(idDeepBreathHero) then
				return GetCooldown(idDeepBreath)
			end
			
			if (s1 ~= idDeepBreath) and spec == 1 and EmpowerCheck and IsSpellKnownOrOverridesKnown(idDeepBreathHero) then
				return GetCooldown(idDeepBreathHero)
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		
		info = "Deep Breath",
	},

-- -----------------------------------------------------------------------------
-- -- Living Flame -------------------------------------------------------------
-- -----------------------------------------------------------------------------

	--	Living Flame
	lf = {
		id = idLivingFlame,
		GetCD = function()
		
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII) or C_Spell.IsCurrentSpell(idEternitySurge) or C_Spell.IsCurrentSpell(idEternitySurgeII) or C_Spell.IsCurrentSpell(idDisintegrate))
		
			if (s1 ~= idLivingFlame) and EmpowerCheck then
				return GetCooldown(idLivingFlame)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		
		info = "Living Flame",
	},

	--	Living Flame w/ dragonrage up
	lf_dr = {
		id = idLivingFlame,
		GetCD = function()
		
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII) or C_Spell.IsCurrentSpell(idEternitySurge) or C_Spell.IsCurrentSpell(idEternitySurgeII) or C_Spell.IsCurrentSpell(idDisintegrate))
		
			if (s1 ~= idLivingFlame) and s_buff_Dragonrage and not s_buff_EssenceBurst then
				return GetCooldown(idLivingFlame)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		
		info = "Living Flame w/ Dragonrage buff (Talent) up",
	},

	--	Living Flame with Burnout up (Instant and free)
	lf_bo = {
		id = idLivingFlame,
		GetCD = function()
		
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII) or C_Spell.IsCurrentSpell(idEternitySurge) or C_Spell.IsCurrentSpell(idEternitySurgeII) or C_Spell.IsCurrentSpell(idDisintegrate))
		
			if (s1 ~= idLivingFlame) and s_buff_Burnout then
				return GetCooldown(idLivingFlame)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		
		info = "Living Flame w/Burnout buff (Talent) up",
	},

-- -----------------------------------------------------------------------------
-- -- Empowered ----------------------------------------------------------------
-- -----------------------------------------------------------------------------

	--	Fire Breath
	fb = {
		id = idFireBreath,
		GetCD = function()		
		
			if ((s1 ~= idFireBreath) and IsPlayerSpell(411212)) or (C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII)) then
				return GetCooldown(idFireBreathII)
			end
			
			if (s1 ~= idFireBreath) or (C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII)) then
				return GetCooldown(idFireBreath)
			end			
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		
		info = "Fire Breath",
	},

	--	Fire Breath w/ tip the scales buff (talent)
	fb_tts = {
		id = idFireBreath,
		GetCD = function()
		
			if (s1 ~= idFireBreath) and s_buff_Scales and IsPlayerSpell(411212) then
				return GetCooldown(idFireBreathII)
			end
			
			if (s1 ~= idFireBreath) and s_buff_Scales then
				return GetCooldown(idFireBreath)
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		
		info = "Fire Breath w/Tip the Scales buff (Talent) up",
	},
	
	--	Eternity Surge
	es = {
		id = idEternitySurge,
		GetCD = function()
		
			spec = GetSpecialization()		
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII))
			
			if (s1 ~= idEternitySurge) and spec == 1 and EmpowerCheck and IsPlayerSpell(411212) then
				return GetCooldown(idEternitySurgeII)
			end
			
			if (s1 ~= idEternitySurge) and spec == 1 and EmpowerCheck then
				return GetCooldown(idEternitySurge)
			end	
			
			return 100			
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		
		info = "Eternity Surge",
	},

-- -----------------------------------------------------------------------------
-- -- Disintegrate -------------------------------------------------------------
-- -----------------------------------------------------------------------------

	--Disintegrate @ 6 Essence
	d6 = {
		id = idDisintegrate,
		GetCD = function()
		
			spec = GetSpecialization()
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII))
			
			if ((s1 ~= idDisintegrate) and (s_es > 5) and spec == 1 and EmpowerCheck) or C_Spell.IsCurrentSpell(idDisintegrate) then
				return 0
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_es = max(5, s_es - 3)
		end,
		
		info = "Disintegrate at 6 Essence",
	},

	--Disintegrate @ 3 or more Essence
	d = {
		id = idDisintegrate,
		GetCD = function()
		
			spec = GetSpecialization()
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII))
			
			if ((s1 ~= idDisintegrate) and (s_es > 2) and spec == 1 and EmpowerCheck) or C_Spell.IsCurrentSpell(idDisintegrate) then
				return 0
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_es = max(5, s_es - 3)
		end,
		
		info = "Disintegrate at 3 or more Essence",
	},

	--Disintegrate w/Essence Burst up (free)
	d_eb = {
		id = idDisintegrate,
		GetCD = function()
		
			spec = GetSpecialization()
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII))
			
			if ((s1 ~= idDisintegrate) and s_buff_EssenceBurst and spec == 1 and EmpowerCheck) or C_Spell.IsCurrentSpell(idDisintegrate) then
				return 0
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		
		info = "Disintegrate w/ Essence Burst up (Free)",
	},

	--Disintegrate w/Iridescence: Blue
	d_ib = {
		id = idDisintegrate,
		GetCD = function()
		
			spec = GetSpecialization()
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII))
			
			if ((s1 ~= idDisintegrate) and (s_es > 2) and IsPlayerSpell(idIridescence) and s_buff_IridescenceBlue and spec == 1) or C_Spell.IsCurrentSpell(idDisintegrate) then
				return 0
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_es = max(5, s_es - 3)
		end,
		
		info = "Disintegrate w/ Iridescence: Blue up.",
	},

-- -----------------------------------------------------------------------------
-- -- Talents ------------------------------------------------------------------
-- -----------------------------------------------------------------------------

	--Shattering Star
	ss = {
		id = idShatteringStar,
		GetCD = function()
		
			spec = GetSpecialization()	
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII) or C_Spell.IsCurrentSpell(idEternitySurge) or C_Spell.IsCurrentSpell(idEternitySurgeII) or C_Spell.IsCurrentSpell(idDisintegrate))
			
			if (s1 ~= idShatteringStar) and IsSpellKnown(idShatteringStar) and spec == 1 and EmpowerCheck then
				return GetCooldown(idShatteringStar)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		
		info = "Shattering Star (Talent)",
	},

	--Firestorm
	fs = {
		id = idFirestorm,
		GetCD = function()
		
			spec = GetSpecialization()	
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII) or C_Spell.IsCurrentSpell(idEternitySurge) or C_Spell.IsCurrentSpell(idEternitySurgeII) or C_Spell.IsCurrentSpell(idDisintegrate))
			
			if (s1 ~= idFirestorm) and IsSpellKnown(idFirestorm) and spec == 1 and EmpowerCheck then
				return GetCooldown(idFirestorm)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		
		info = "Firestorm (Talent)",
	},

	--Firestorm w/snapfire up
	fs_sf = {
		id = idFirestorm,
		GetCD = function()
		
			spec = GetSpecialization()	
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII) or C_Spell.IsCurrentSpell(idEternitySurge) or C_Spell.IsCurrentSpell(idEternitySurgeII) or C_Spell.IsCurrentSpell(idDisintegrate))
			
			if (s1 ~= idFirestorm) and IsSpellKnown(idFirestorm) and s_buff_Snapfire and spec == 1 and EmpowerCheck then
				return GetCooldown(idFirestorm)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		
		info = "Firestorm(Talent) w/ Snapfire buff (Talent)",
	},

-- -----------------------------------------------------------------------------
-- -- Hero Talents -------------------------------------------------------------
-- -----------------------------------------------------------------------------
	
	--	Engulf
	eg = {
		id = idEngulf,
		GetCD = function()
		
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII) or C_Spell.IsCurrentSpell(idEternitySurge) or C_Spell.IsCurrentSpell(idEternitySurgeII) or C_Spell.IsCurrentSpell(idDisintegrate))
			
			-- local cd, charges = GetEngulfData()
			
			if (s1 ~= idEngulf) and EmpowerCheck then
				return GetCooldown(idEngulf)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			-- s_EngulfCharges = max(2, s_EngulfCharges - 1)	
		end,
		
		info = "Engulf, regardless of DoTs on target",
	},
	
	--	Engulf fire breath and living flame dot
	eg_fb_lf = {
		id = idEngulf,
		GetCD = function()
		
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII) or C_Spell.IsCurrentSpell(idEternitySurge) or C_Spell.IsCurrentSpell(idEternitySurgeII) or C_Spell.IsCurrentSpell(idDisintegrate))
			
			-- local cd, charges = GetEngulfData()
			
			if (s1 ~= idEngulf) and EmpowerCheck and s_debuff_FireBreath and s_debuff_LivingFlame then
				return GetCooldown(idEngulf)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			-- s_EngulfCharges = max(2, s_EngulfCharges - 1)	
		end,
		
		info = "Engulf with Fire Breath and Living Flame DoT up",
	},
	
	--	Engulf fire breath dot
	eg_fb = {
		id = idEngulf,
		GetCD = function()
		
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII) or C_Spell.IsCurrentSpell(idEternitySurge) or C_Spell.IsCurrentSpell(idEternitySurgeII) or C_Spell.IsCurrentSpell(idDisintegrate))
			
			-- local cd, charges = GetEngulfData()
			
			if (s1 ~= idEngulf) and EmpowerCheck and s_debuff_FireBreath then
				return GetCooldown(idEngulf)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			-- s_EngulfCharges = max(2, s_EngulfCharges - 1)	
		end,
		
		info = "Engulf with just Fire Breath DoT up",
	},
	
	--	Engulf living flame dot
	eg_lf = {
		id = idEngulf,
		GetCD = function()
		
			EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII) or C_Spell.IsCurrentSpell(idEternitySurge) or C_Spell.IsCurrentSpell(idEternitySurgeII) or C_Spell.IsCurrentSpell(idDisintegrate))
			
			-- local cd, charges = GetEngulfData()
			
			if (s1 ~= idEngulf) and EmpowerCheck and s_debuff_LivingFlame then
				return GetCooldown(idEngulf)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			-- s_EngulfCharges = max(2, s_EngulfCharges - 1)	
		end,
		
		info = "Engulf with just Living Flame DoT up.",
	},
	
	--	Engulf @ 1 stack
	-- eg1 = {
		-- id = idEngulf,
		-- GetCD = function()
		
			-- EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII) or C_Spell.IsCurrentSpell(idEternitySurge) or C_Spell.IsCurrentSpell(idEternitySurgeII) or C_Spell.IsCurrentSpell(idDisintegrate))
			
			-- local cd, charges = GetEngulfData()
			
			-- if (s1 ~= idEngulf) and EmpowerCheck and (s_EngulfCharges == 1)then
				-- return GetCooldown(idEngulf)
			-- end
			-- return 100
		-- end,
		
		-- UpdateStatus = function()
			-- s_ctime = s_ctime + s_gcd + 1.5
			-- s_EngulfCharges = max(2, s_EngulfCharges - 1)	
		-- end,
		
		-- info = "Engulf @ 1 charge, no DoTs up",
	-- },
	
	--	Engulf @ 2 stacks
	-- eg2 = {
		-- id = idEngulf,
		-- GetCD = function()
		
			-- EmpowerCheck = not(C_Spell.IsCurrentSpell(idFireBreath) or C_Spell.IsCurrentSpell(idFireBreathII) or C_Spell.IsCurrentSpell(idEternitySurge) or C_Spell.IsCurrentSpell(idEternitySurgeII) or C_Spell.IsCurrentSpell(idDisintegrate))
			
			-- local cd, charges = GetEngulfData()
			
			-- if (s1 ~= idEngulf) and EmpowerCheck and (s_EngulfCharges == 2)then
				-- return GetCooldown(idEngulf)
			-- end
			-- return 100
		-- end,
		
		-- UpdateStatus = function()
			-- s_ctime = s_ctime + s_gcd + 1.5
			-- s_EngulfCharges = max(2, s_EngulfCharges - 1)	
		-- end,
		
		-- info = "Engulf @ 2 charges, no DoTs up",
	-- },
	
}
--------------------------------------------------------------------------------

local function UpdateQueue()
	-- normal queue
	qn = {}
	for v in string.gmatch(db.devastationprio, "[^ ]+") do
		if actions[v] then
			table.insert(qn, v)
		else
			print("Devastation - invalid action:", v)
		end
	end
	db.devastationprio = table.concat(qn, " ")

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

	-- retrieves localized debuff spell name
	local spellInfoShatteringStar = C_Spell.GetSpellInfo(idShatteringStar)
	local debuffShatteringStar = spellInfoShatteringStar.name
	
	local spellInfoLivingFlame = C_Spell.GetSpellInfo(idLivingFlameDebuff)
	local debuffLivingFlame = spellInfoLivingFlame.name
	
	local spellInfoFireBreath = C_Spell.GetSpellInfo(idFireBreathDebuff)
	local debuffFireBreath = spellInfoFireBreath.name

	-- the debuffs
	s_debuff_ShatteringStar = AuraUtil.FindAuraByName(debuffShatteringStar, "target", "HARMFUL")
	s_debuff_LivingFlame = AuraUtil.FindAuraByName(debuffLivingFlame, "target", "HARMFUL")
	s_debuff_FireBreath = AuraUtil.FindAuraByName(debuffFireBreath, "target", "HARMFUL")

	-- Spell Charges for GetStatus Function
	-- engulf stacks
	local cd, charges = GetEngulfData()
	s_EngulfCharges = charges

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
			table.insert(q, v)
	end
end

local function GetNextAction()
	-- check if working queue needs updated due to glyph talent changes
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

	s_otime = s_ctime -- save it so we adjust buffs for next
	actions[action].UpdateStatus()

	s_otime = s_ctime - s_otime

	-- Spell Charges for xmod.rotation
	
	-- engulf charges
	local cd, charges = GetEngulfData()
	s_EngulfCharges = charges
	
	if (s1 == idEngulf) then
	s_EngulfCharges = s_EngulfCharges - 1
	end

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
	
	-- Blizz assisted combat api (for non generic modules only)
	local specID = C_SpecializationInfo.GetSpecialization()
	local blizzEnabled = clcret.db.profile.rotation.specBlizzMode[specID] or false
	local idBlizz = GetBlizzID()
	if blizzEnabled and s1 ~= idHammerOfLight and s1~= overrideActions.trink1.GetID() and s1 ~= overrideActions.trink2.GetID()then
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
	return s1, s2
end

-- event frame
local ef = CreateFrame("Frame", "EvokerModuleEventFrame") -- event frame
ef:Hide()

local function OnEvent()
	qTaint = true
		
	if not IsPlayerSpell(411212) then
		idFireBreath = 357208
	end
	
	if IsPlayerSpell(411212) then
		idFireBreath = 382266
	end
	
	actions['fb'].id = idFireBreath
	actions['fb_tts'].id = idFireBreath
	
end
ef:SetScript("OnEvent", OnEvent)
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("PLAYER_TALENT_UPDATE")
ef:RegisterEvent("PLAYER_LEVEL_UP")
