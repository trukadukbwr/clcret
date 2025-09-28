-- don't load if class is wrong
local _, class = UnitClass("player")
if class ~= "PALADIN" then return end

local _, xmod = ...

xmod.retributionpaladinmodule = {}
xmod = xmod.retributionpaladinmodule

local qTaint = true -- will force queue check

-- thanks cremor
local GetTime, GetSpellCooldown, UnitBuff, UnitAura, UnitPower, UnitSpellHaste, UnitHealth, UnitHealthMax, GetActiveSpecGroup, GetTalentInfoByID, GetGlyphSocketInfo, IsUsableSpell, GetShapeshiftForm, max, min, SPELL_POWER_HOLY_POWER =
GetTime, GetSpellCooldown, UnitBuff, UnitAura, UnitPower, UnitSpellHaste, UnitHealth, UnitHealthMax, GetActiveSpecGroup, GetTalentInfoByID, GetGlyphSocketInfo, IsUsableSpell, GetShapeshiftForm, max, min, SPELL_POWER_HOLY_POWER
local db

-- debug if clcInfo detected
local debug
if clcInfo then debug = clcInfo.debug end

xmod.version = 9000001
xmod.defaults = {
	version = xmod.version,
	prio = "dh fr tv_dh_2 hol es woa ds tv_4pc tv5 tvdp ts2_exp tv ts1 how_anshe dt boj j how ts2 cs",
	rangeCheckSkill = "_rangeoff",
	aoeMode = true,
	BlizzMode = false,
	trinketMode = false,
	howclash = 0, -- priority time for hammer of wrath
	csclash = 0, -- priority time for cs
}

-- @defines
-- ------------------------------------------------------------------------------
local playerLevel = UnitLevel("Player")
local idGCD = 85256 -- tv for gcd

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
local idTemplarsVerdict = 85256
local idJusticarsVengeance = 215661
local idWakeOfAshes = 255937
local idCrusaderStrike = 35395
local idJudgment = 20271
local idConsecration = 26573
local idDivineStorm = 53385
local idHammerOfWrath = 24275
local idBladeOfJustice = 184575
local idBlizzRotation = 1229376

-- racials
local idArcaneTorrent = 155145
local idLightsJudgment = 255647

-- Talents
-- ids for talent spells (the actual talent in the tree, not the spell in the spellbook)
local idExecutionSentence = 343527
local idFinalReckoning = 343721
local idTemplarStrike = 407480
local idTemplarSlash = 406647
local idTemplarStrikesTalent = 406646
local idDivineHammer = 198034
local idSanctify = 382536
local idDivineToll = 375576
local idExpurgation = 383344
local idImprovedJudgment = 405461
local idVanguardsMomentum = 383314
local idImprovedBladeOfJustice = 403745
local idEmpyreanPower = 326732 --id for Empyrean Power Talent

-- Hero Talents
local idHammerOfLight = 427453
local idLightsGuidance = 427445

-- adds charges to spells; ids for actual talents
local idBladeOfJustice2 = 383342
local idJudgment2 = 405278
local idHammerOfWrath2 = 383314

-- makes passive
local idCrusadingStrikes = 404542
local idConsecratedBlade = 404834

-- modify holy power costs
local idDivineAuxiliary = 406158
local idDivinePurposeTalent = 408459 -- The actual talent spell

-- dummy spells to get fake cd
local idFlashOfLightDummy = 19750
local idHammerOfLightDummy = 429826

-- buffs
-- /dump C_UnitAuras.GetBuffDataByIndex("Player", 1)
-- /dump C_UnitAuras.GetDebuffDataByIndex("Target", 1)
-- /etrace for combat log search/pause

local idAvengingWrath = 31884
local idCrusade = 231895
local idArtOfWar = 281178
local idDivinePurpose = 408458 -- The actual buff, not the talent
local idFinalVerdictHOW = 383329
local idEmpyreanLegacyTV = 387178
local idEmpyreanPowerDS = 326733
local idBlessingOfAnshe = 445206
local idForWhomTheBellTolls = 433618
local idEchoesOfWrath = 423590
local idLightsDeliverance = 433674
local idShakeTheHeavens = 431536
local idDivineArbiter = 406975

-- status vars
local s1, s2
local s_ctime, s_otime, s_gcd, s_hp, s_dp, s_aw, s_ss, s_dc, s_fv, s_bc, s_haste, s_in_execute_range

local s_CrusaderStrikeCharges = 0
local s_HoWCharges = 0
local s_BoJCharges = 0
local s_JudgmentCharges = 0

local talent_DivinePurpose = false

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

local function GetCSData()
	local chargeInfo = C_Spell.GetSpellCharges(idCrusaderStrike)
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

local function GetHoWData()
	local chargeInfo = C_Spell.GetSpellCharges(idHammerOfWrath)
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

local function GetBoJData()
	local chargeInfo = C_Spell.GetSpellCharges(idBladeOfJustice)
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

local function GetJudgmentData()
	local chargeInfo = C_Spell.GetSpellCharges(idJudgment)
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
-- s_hp = min(3, s_hp + 2) is telling the addon what hp you need to reach for tv

-- /dump C_UnitAuras.GetBuffDataByIndex("Player", 1)
-- /dump C_UnitAuras.GetDebuffDataByIndex("Target", 1)
-- /dump GetActionInfo(1)

-- C_SpellBook.IsSpellInSpellBook()
-- C_SpellBook.IsSpellKnown() -- Use for passive talent tree spells/checks
-- C_Spell.IsSpellUsable()
-- C_Spell.GetSpellCooldown()
-- Dummy spell for GCD = 61304
-- costs = GetSpellPowerCost(255937)	

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

	-- Arcane Torrent
	arc = {
		id = idArcaneTorrent,
		GetCD = function()
			
			if (s1 ~= idArcaneTorrent) and (s_hp <= 2) then
				return GetCooldown(idArcaneTorrent)
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5			
			s_hp = min(3, s_hp + 1)
		end,
		
		info = "|cffe7e303Arcane Torrent|r (Blood Elf)",
		
		reqTalent = idArcaneTorrent,
	},
	
	-- Light's Judgment 
	lj = {
		id = idLightsJudgment,
		GetCD = function()
		
			if (s1 ~= idLightsJudgment) then
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
	
	-- ----------------------------------
	-- Holy Power Generators
	-- ----------------------------------
	
	-- Wake of Ashes
	woa = {
		id = idWakeOfAshes,
		GetCD = function()
		
			-- Holy power checkers, don't overcap. Don't move to Defines.
			DivineHammerHPCheck = ((not(C_SpellBook.IsSpellInSpellBook(idDivineHammer)) and (s_hp >= 2)) or (C_SpellBook.IsSpellInSpellBook(idDivineHammer) and s_hp >= 3)) 
			-- TemplarCheck = ((C_SpellBook.IsSpellKnown(idLightsGuidance) and DivineHammerHPCheck) or (not(C_SpellBook.IsSpellKnown(idLightsGuidance)) and s_hp >= 0)) -- checks for hp for HOL
			TemplarCheck = ((C_SpellBook.IsSpellKnown(idLightsGuidance) and s_hp >= 2) or (not(C_SpellBook.IsSpellKnown(idLightsGuidance)) and s_hp >= 0)) -- **Old Templar check, keep in case we need to revert
		
			if (s1 ~= idWakeOfAshes) and usableWOA and TemplarCheck then
					return GetCooldown(idWakeOfAshes)
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			
			-- we need to trick the addon so it doesn't suggest a 3HoPo fr along with WoA and overcap HoPo
				if C_SpellBook.IsSpellKnown(idDivineAuxiliary) then
					s_hp = max(3, s_hp + 3)
				else
					s_hp = min(3, s_hp + 3)
				end				
		end,
		
		info = "|cfffe8a00Wake Of Ashes|r",
		
		reqTalent = idWakeOfAshes,
	},

	-- Judgment
	j = {
		id = idJudgment,
		GetCD = function()

			local cd, charges = GetJudgmentData()
			
			-- Do NOT remove the ES or HoL strings, they exist as a failsafe to prevent rotation suggestion errors when these are not talented
			if (s1 ~= idJudgment) and knownJ and not(usableHOL) then
				return GetCooldown(idJudgment)
			end
			
			if (s2 ~= idExecutionSentence) and knownFR then 
				return 0
			end
			
			if (s2 ~= idHammerOfLight) and knownLG then 
				return 0
			end
			
			if (s2 ~= idDivineHammer) and not KnownDH then 
				return 0
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				
				-- if C_SpellBook.IsSpellKnown(idJudgment2) then
					-- s_hp = max(3, s_hp + 2)
				-- else
					-- s_hp = max(3, s_hp + 1)
				-- end
				
				s_JudgmentCharges = max(0, s_JudgmentCharges - 1)
		end,
		
		info = "|cffe7e303Judgment|r",
	},

	-- Judgment w/whom the bell tolls hero talent proc
	j_bell = {
		id = idJudgment,
		GetCD = function()
		
			local cd, charges = GetJudgmentData()
			
			if (s1 ~= idJudgment) and knownJ and not(usableHOL) and s_buff_ForWhomTheBellTolls then
				return GetCooldown(idJudgment)
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				
				if C_SpellBook.IsSpellKnown(idJudgment2) then
					s_hp = max(3, s_hp + 2)
				else
					s_hp = max(3, s_hp + 1)
				end
				
				s_JudgmentCharges = max(0, s_JudgmentCharges - 1)
		end,
		
		info = "|cffe7e303Judgment w/ For Whom The Bell Tolls up|r (Templar HERO TALENT)",
	},

	-- Crusader Strike
	cs = {
		id = idCrusaderStrike,
		GetCD = function()
			
			local cd, charges = GetCSData()
			
			if (s1 ~= idCrusaderStrike) and CrusadingStrikes then
				return 100
			end
			
			if (s1 ~= idCrusaderStrike) and (s_hp < 3) and ((s_CrusaderStrikeCharges == 1) or (s_CrusaderStrikeCharges == 2)) and not(CrusadingStrikes) and not(TemplarStrikesTalent) then
				return 0
			end	
			
			return 100		
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = min(3, s_hp + 1)			
			s_CrusaderStrikeCharges = max(2, s_CrusaderStrikeCharges - 1)		
		end,
		
		info = "|cffe7e303Crusader Strike|r",
	},

	-- Templar strike 1st part combo
	ts1 = {
		id = idCrusaderStrike,
		GetCD = function()
			
			if (s1 ~= idCrusaderStrike) and CrusadingStrikes then
				return 100
			end
			
			if (s1 ~= idCrusaderStrike) and (s_hp < 5) and not(CrusadingStrikes) and TemplarStrikesTalent and (GetCooldown(idTemplarStrike) < 1) then
				return 0
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

			s_hp = min(3, s_hp + 1)				
		end,
		
		info = "|cfffe8a00Templar Strike (1st Part Combo)|r (TALENT)",
		
		reqTalent = 406646,
	},
	
	-- Templar slash 2nd part combo
	ts2 = {
		id = idTemplarSlash,
		GetCD = function()
		
			if (s1 ~= idCrusaderStrike) and CrusadingStrikes then
				return 100
			end
			
			if (s1 ~= idCrusaderStrike) and (s_hp < 5) and not(CrusadingStrikes) and knownTSlash then
				return 0
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 0

			s_hp = min(3, s_hp + 1)			
		end,
		
		info = "|cfffe8a00Templar Slash (2nd Part Combo)|r (TALENT)",
		
		reqTalent = 406646,
	},

	-- Templar slash 2nd part combo, about to expire
	ts2_exp = {
		id = idTemplarSlash,
		GetCD = function()
		
			local chargeInfo = C_Spell.GetSpellCharges(407480)
			local charges, maxCharges, StartTime = chargeInfo.currentCharges, chargeInfo.maxCharges, chargeInfo.cooldownStartTime;
			local tscdexpiring = ((GetTime() > ((StartTime) + 2)) and (GetTime() < ((StartTime) + 4)))
			local cd, charges = GetCSData()
			
			if (s1 ~= idCrusaderStrike) and CrusadingStrikes then
				return 100
			end
			
			if (s1 ~= idCrusaderStrike) and not(CrusadingStrikes) and knownTSlash and tscdexpiring then
				return 0
			end
			
			return 100
		end,

		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 0

			s_hp = min(3, s_hp + 1)
			
		end,
		
		info = "|cfffe8a00Templar Slash Combo about to expire|r (TALENT)",
		
		reqTalent = 406646,
	},
	
	-- Hammer of Wrath
	how = {
		id = idHammerOfWrath,
		GetCD = function()
		
		local cd, charges = GetHoWData()
		
			if (s1 ~= idHammerOfWrath) and ((s_HoWCharges == 1) or (s_HoWCharges == 2)) and usableHOW and knownHOW then
				return GetCooldown(idHammerOfWrath)
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if C_SpellBook.IsSpellKnown(idHammerOfWrath2) and (((UnitHealth("target") / (UnitHealthMax("target") + 1) * 100)) < 20) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end	
			
			s_HoWCharges = max(0, s_HoWCharges - 1)
		end,
		
		info = "|cfffe8a00Hammer of Wrath|r",
	},

	-- Hammer of Wrath w/ Avenging Wrath
	how_anshe = {
		id = idHammerOfWrath,
		GetCD = function() 
			local cd, charges = GetHoWData()
			
			-- we don't need usableHOW strings since HoW is always usable during AW
			if (s1 ~= idHammerOfWrath) and ((s_HoWCharges == 1) or (s_HoWCharges == 2)) and s_buff_BlessingOfAnshe and knownHOW then
				return GetCooldown(idHammerOfWrath)
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				if playerSpellHammerOfWrath2 and (((UnitHealth("target") / (UnitHealthMax("target") + 1) * 100)) < 20) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end
			
			s_HoWCharges = max(0, s_HoWCharges - 1)			
		end,
		
		info = "|cfffe8a00Hammer of Wrath w/Blessing Of Anshe|r (Herald HERO TALENT)",
	},

	-- Hammer of Wrath w/ Avenging Wrath
	how_aw = {
		id = idHammerOfWrath,
		GetCD = function()
			local cd, charges = GetHoWData() 
			
			-- we don't need usableHOW strings since HoW is always usable during AW
			if (s1 ~= idHammerOfWrath) and ((s_HoWCharges == 1) or (s_HoWCharges == 2)) and awCheck and knownHOW then
				return GetCooldown(idHammerOfWrath)
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				if playerSpellHammerOfWrath2 and (((UnitHealth("target") / (UnitHealthMax("target") + 1) * 100)) < 20) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end
			
			s_HoWCharges = max(0, s_HoWCharges - 1)			
		end,
		
		info = "|cfffe8a00Hammer of Wrath during Avenging Wrath|r",
	},
	
	-- Blade of Justice
	boj = {
		id = idBladeOfJustice,
		GetCD = function()
			
		local cd, charges = GetBoJData()

			if (s1 ~= idBladeOfJustice) and knownBOJ and (GetCooldown(idBladeOfJustice) < 1) then
				return GetCooldown(idBladeOfJustice)
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if C_SpellBook.IsSpellKnown(idBladeOfJustice2) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end

			s_BoJCharges = max(0, s_BoJCharges - 1)
		end,
		
		info = "|cfffe8a00Blade of Justice|r",
	},

	-- ----------------------------------
	-- Holy Power Consumers
	-- ----------------------------------
	
	-- Divine Storm Proc
	ds = {
		id = idDivineStorm,
		GetCD = function()
		
			-- keep this check here, not in Defines
			dpCheck = (s_buff_DivinePurpose and db.aoeMode and (AssistedDS == 53385)) -- DO NOT ADD TO DEFINES
		
			if (s1 ~= idDivineStorm) and (s_buff_EmpyreanPowerDS or dpCheck) then
				return 0
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(3, s_hp - 0)
		end,
		
		info = "|cffe7e303Divine Storm w/Empyrean Power Proc|r",
		
		-- reqTalent = idEmpyreanPower,
	},

	-- ----------------------------------
	-- Templar's Verdict
	-- ----------------------------------

	-- Templar's Verdict 
	tv = {
		id = idTemplarsVerdict,
		GetCD = function()
			
			-- aoe checker string
			aoeCheck = (((not(AssistedDS == idDivineStorm) or ((targetLevel < 0) or (targetLevel >= (playerLevel + 2)))) and db.aoeMode) or not db.aoeMode)
			
			if (s1 ~= idTemplarsVerdict) and not(knownHOL) and (s_hp > 2) and aoeCheck then
				return 0
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(3, s_hp - 3)
		end,
		
		info = "|cffe7e303Templar's Verdict|r",
	},

	-- Templar's Verdict w/ DH active
	tv_dh = {
		id = idTemplarsVerdict,
		GetCD = function()

			-- aoe checker string
			aoeCheck = (((not(AssistedDS == idDivineStorm) or ((targetLevel < 0) or (targetLevel >= (playerLevel + 2)))) and db.aoeMode) or not db.aoeMode)
			
			if (s1 ~= idTemplarsVerdict) and not(C_SpellBook.IsSpellInSpellBook(idHammerOfLight)) and (s_hp > 2) and s_buff_DivineHammer and aoeCheck then
				return 0
			end
	
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(3, s_hp - 3)
		end,
		
		info = "|cffe7e303Templar's Verdict w/Divine Hammer active|r",
	},

	-- Templar's Verdict if DH about to fall
	tv_dh_2 = {
		id = idTemplarsVerdict,
		GetCD = function()
			
			-- checks if divine hammer is up and the remaining time, keep these here, not in Defines
			cooldownInfo = C_Spell.GetSpellCooldown(idDivineHammer)
			durationDH = cooldownInfo.duration 
			
			-- aoe checker string
			aoeCheck = (((not(AssistedDS == idDivineStorm) or ((targetLevel < 0) or (targetLevel >= (playerLevel + 2)))) and db.aoeMode) or not db.aoeMode)

			if (s1 ~= idTemplarsVerdict) and (s_hp > 2) and durationDH < 2 and aoeCheck and knownDH then
				return 0
			end

			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(3, s_hp - 3)
		end,
		
		info = "|cffe7e303Templar's Verdict w/< 2 secs left on Divine Hammer|r",
	},

	-- Templar's Verdict 5 HoPo
	tv5 = {
		id = idTemplarsVerdict,		
		GetCD = function()
			
			-- aoe checker string
			aoeCheck = (((not(AssistedDS == idDivineStorm) or ((targetLevel < 0) or (targetLevel >= (playerLevel + 2)))) and db.aoeMode) or not db.aoeMode)
		
			if (s1 ~= idTemplarsVerdict) and not(knownHOL) and (s_hp > 4) and aoeCheck then
				return 0
			end
			
			return 100
			
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(3, s_hp - 3)
		end,
		
		info = "|cffe7e303Templar's Verdict at 5 Holy Power|r",
	},

	-- Templar's Verdict w/ Empyrean Legacy proc
	tv_ds = {
		id = idTemplarsVerdict,
		GetCD = function()
			
			if (s1 ~= idTemplarsVerdict) and knownTV and ((s_hp > 2) or s_buff_DivinePurpose) and s_buff_EmpyreanLegacyTV and not(knownHOL) and not(AssistedDS == idDivineStorm) then
				return 0
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(3, s_hp - 3)
		end,
		
		info = "|cffe7e303Templar's Verdict w/Empyrean Legacy (Divine Storm) Proc|r",
	},

	-- --------------------------------------------
	-- Divine Purpose Procs / Tier Set Procs
	-- --------------------------------------------

	-- Templar's Verdict with Divine Purpose
	tvdp = {
		id = idTemplarsVerdict,
		GetCD = function()
		
			-- aoe checker string
			aoeCheck = (((not(AssistedDS == idDivineStorm) or ((targetLevel < 0) or (targetLevel >= (playerLevel + 2)))) and db.aoeMode) or not db.aoeMode)
			
			if (s1 ~= idTemplarsVerdict) and s_buff_DivinePurpose and not(knownHOL) and aoeCheck then
				return 0
			end
			
			return 100
		end,
		
		UpdateStatus = function()
		end,
		
		info = "|cffe7e303Templar's Verdict w/Divine Purpose Proc|r",
	},

	-- ----------------------------------
	-- Talents/Hero Talents (Execution Sentence, etc)
	-- ----------------------------------
	
	-- Hammer of light
	hol = {
		id = idHammerOfLight,
		GetCD = function()
			
			if (s1 ~= idHammerOfLight) and usableHOL and C_SpellBook.IsSpellInSpellBook(idHammerOfLight) then
				return 0
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			-- s_ctime = s_gcd + 1.5 -- HoL gcd string causes bug where it displays first, second, or third in line for rotation on GCD, regardless if known or not
		end,
		
		info = "|cffe7e303Hammer of Light|r (Templar HERO TALENT)",
	},

	-- Final Reckoning
	fr = {
		id = idFinalReckoning,
		GetCD = function()
		
		-- Failsafe to make sure FR is known and off cd DO NOT ADD TO DEFINES
		frCheck = (C_SpellBook.IsSpellInSpellBook(343721) and (GetCooldown(343721) < 3))
		
		--Failsafe checks to make sure Divine Auxillary talent will not over cap Holy Power if specced with Vanguard DO NOT ADD TO DEFINES
		AuxHPcapCheck = ((not(C_SpellBook.IsSpellKnown(406158)) and (s_hp > 2)) or (C_SpellBook.IsSpellKnown(406158) and (s_hp < 4)))
			
			if (s1 ~= idFinalReckoning) and frCheck and AuxHPcapCheck then
				return GetCooldown(idFinalReckoning)
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste

				if C_SpellBook.IsSpellKnown(idDivineAuxiliary) then
					s_hp = max(3, s_hp + 3)
				else
					s_hp = min(3, s_hp + 0)
				end
		end,
		
		info = "|cfffe8a00Final Reckoning|r",
		-- reqTalent = 343721,
	},

	-- Divine Hammers 
	dh = {
		id = idDivineHammer,
		GetCD = function()
			
			if (s1 ~= idDivineHammer) and knownDH and (s_hp > 2) then
				return GetCooldown(idDivineHammer)
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(3, s_hp - 3)
		end,
		
		info = "|cfffe8a00Divine Hammer|r",
		
	},

	-- Execution Sentence Boss only -- **removed divine aux strings as a redundancy to correct suggestion errors.
	es_boss = {
		id = idExecutionSentence,
		GetCD = function()
		
			-- Failesafe ES Check
			esCheck = (C_SpellBook.IsSpellInSpellBook(343527) and (GetCooldown(343527) < 3)) -- leave this check here, dont move to Defines
			
			-- checks target level DO NOT ADD TO DEFINES
			level = UnitLevel("target")
			Boss = ((targetLevel < 0) or (level > (playerLevel + 3)))
			
			-- makes sure you dont overcap holy power too much
			AuxHPcapCheck = ((not(C_SpellBook.IsSpellKnown(406158)) and (s_hp > 2)) or (C_SpellBook.IsSpellKnown(406158) and (s_hp < 4)))
					
			if (s1 ~= idExecutionSentence) and knownES and AuxHPcapCheck and not knownFR and esCheck and Boss then
				return 0
			end
			
			if (s1 ~= idExecutionSentence) and knownFR then
				return 100
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				-- if C_SpellBook.IsSpellKnown(idDivineAuxiliary) then
					-- s_hp = max(3, s_hp + 3)
				-- else
					-- s_hp = min(3, s_hp + 0)
				-- end
				
		end,
		
		info = "|cffe7e303Execution Sentence on Boss level mobs only|r",
		
		-- reqTalent = 343527,
	},

	-- Execution Sentence -- **removed divine aux strings as a redundancy to correct suggestion errors.
	es = {
		id = idExecutionSentence,
		GetCD = function()
		
			-- Failsafe ES Check
			esCheck = (C_SpellBook.IsSpellInSpellBook(343527) and (GetCooldown(343527) < 3))
			
			-- makes sure you dont overcap holy power too much DO NOT ADD TO DEFINES
			AuxHPcapCheck = ((not(C_SpellBook.IsSpellKnown(406158)) ) or (C_SpellBook.IsSpellKnown(406158) and (s_hp < 4)))
			
			if (s1 ~= idExecutionSentence) and knownES and AuxHPcapCheck and not knownFR and esCheck then
				return 0
			end
			
			if (s1 ~= idExecutionSentence) and knownFR then
				return 100
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				
				-- if C_SpellBook.IsSpellKnown(idDivineAuxiliary) then
					-- s_hp = max(3, s_hp + 3)
				-- else
					-- s_hp = min(3, s_hp + 0)
				-- end
				
		end,
		
		info = "|cffe7e303Execution Sentence|r",
		
		-- reqTalent = 343527,
	},

	-- ----------------------------------
	-- (Ex)Covenant Abilities
	-- ----------------------------------

	-- Divine Toll 
	dt = {
		id = idDivineToll,
		GetCD = function()

			if (s1 ~= idDivineToll) and C_SpellBook.IsSpellInSpellBook(idDivineToll) and (GetCooldown(idDivineToll) < 1) then
				return GetCooldown(idDivineToll)
			end
			return 100
		end,
		
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = min(3, s_hp + 1)
		end,
		
		info = "|cfffe8a00Divine Toll|r",
		
		-- reqTalent = idDivineToll,
	},
	
}
-- -----------------------------------------------------------------------------

local function UpdateQueue()
	-- normal queue
	qn = {}
	for v in string.gmatch(db.prio, "[^ ]+") do
		if actions[v] then
			table.insert(qn, v)
		else
			print("Retribution - invalid action:", v)
		end
	end
	db.prio = table.concat(qn, " ")

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
		
	-- the buffs
	s_buff_AvengingWrath = C_UnitAuras.GetPlayerAuraBySpellID(idAvengingWrath)
	s_buff_Crusade = C_UnitAuras.GetPlayerAuraBySpellID(idCrusade)
	s_buff_ArtOfWar = C_UnitAuras.GetPlayerAuraBySpellID(idArtOfWar)
	s_buff_DivinePurpose = C_UnitAuras.GetPlayerAuraBySpellID(idDivinePurpose)
	s_buff_FinalVerdict = C_UnitAuras.GetPlayerAuraBySpellID(idFinalVerdictHOW)
	s_buff_EmpyreanLegacyTV = C_UnitAuras.GetPlayerAuraBySpellID(idEmpyreanLegacyTV)
	s_buff_EmpyreanPowerDS = C_UnitAuras.GetPlayerAuraBySpellID(idEmpyreanPowerDS)
	s_buff_BlessingOfAnshe = C_UnitAuras.GetPlayerAuraBySpellID(idBlessingOfAnshe)
	s_buff_ForWhomTheBellTolls = C_UnitAuras.GetPlayerAuraBySpellID(idForWhomTheBellTolls)
	s_buff_EchoesOfWrath = C_UnitAuras.GetPlayerAuraBySpellID(idEchoesOfWrath)
	s_buff_LightsDeliverance = C_UnitAuras.GetPlayerAuraBySpellID(idLightsDeliverance)
	s_buff_ShakeTheHeavens = C_UnitAuras.GetPlayerAuraBySpellID(idShakeTheHeavens)
	s_buff_DivineHammer = C_UnitAuras.GetPlayerAuraBySpellID(idDivineHammer)
	s_buff_DivineArbiter = C_UnitAuras.GetPlayerAuraBySpellID(idDivineArbiter)

	-- retrieves localized debuff spell name
	local spellInfoJudgment = C_Spell.GetSpellInfo(idJudgment)
	local debuffJudgment = spellInfoJudgment.name
	
	local spellInfoExecutionSentence = C_Spell.GetSpellInfo(idExecutionSentence)
	local debuffExecutionSentence = spellInfoExecutionSentence.name
	
	local spellInfoFinalReckoning = C_Spell.GetSpellInfo(idFinalReckoning)
	local debuffFinalReckoning = spellInfoFinalReckoning.name
	
	local spellInfoSanctify = C_Spell.GetSpellInfo(idSanctify)
	local debuffSanctify = spellInfoSanctify.name

	local spellInfoExpurgation = C_Spell.GetSpellInfo(idExpurgation)
	local debuffExpurgation = spellInfoExpurgation.name

	-- the debuffs
	s_debuff_Judgment = AuraUtil.FindAuraByName(debuffJudgment, "target", "HARMFUL")
	s_debuff_ExecutionSentence = AuraUtil.FindAuraByName(debuffExecutionSentence, "target", "HARMFUL")
	s_debuff_FinalReckoning = AuraUtil.FindAuraByName(debuffFinalReckoning, "target", "HARMFUL")
	s_debuff_Sanctify = AuraUtil.FindAuraByName(debuffSanctify, "target", "HARMFUL")
	s_debuff_Expurgation = AuraUtil.FindAuraByName(debuffExpurgation, "target", "HARMFUL")

	-- ----------------------------------------
	-- Spell Charges for GetStatus Function --
	-- ----------------------------------------

	-- crusader strike stacks
	local cd, charges = GetCSData()
	s_CrusaderStrikeCharges = charges

	-- HoW stacks
	local cd, charges = GetHoWData()
	s_HoWCharges = charges

	-- BoJ stacks
	local cd, charges = GetBoJData()
	s_BoJCharges = charges

	-- Judgment stacks
	local cd, charges = GetJudgmentData()
	s_JudgmentCharges = charges
	
	-- -----------------------
	-- client hp and haste --
	-- -----------------------
	s_hp = UnitPower("player", 9)
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
			isKnown = C_SpellBook.IsSpellKnown(actions[v].reqTalent)
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

	-- Shortcuts, DO NOT PUT "level = UnitLevel" stuff here, leave that in each string
	-- It's ok if its "playerLevel = UnitLevel", but it cannot just be "level = UnitLevel"
	targetLevel = UnitLevel("target")
	playerLevel = UnitLevel("player")
	AssistedDS = select(1, C_AssistedCombat.GetNextCastSpell()) -- assistedDS = need aoe / db.aoemode = suggest aoe

	-- Checker strings
	awCheck = (s_buff_AvengingWrath or s_buff_Crusade)
	LightsDeliverance = (C_SpellBook.IsSpellInSpellBook(idHammerOfLight) and C_SpellBook.IsSpellKnown(idLightsGuidance) and s_buff_LightsDeliverance)

	-- Spell known checks
	knownTV = C_SpellBook.IsSpellInSpellBook(idTemplarsVerdict)
	knownWOA = C_SpellBook.IsSpellInSpellBook(idWakeOfAshes)
	knownJ = C_SpellBook.IsSpellInSpellBook(idJudgment)
	knownHOW = C_SpellBook.IsSpellInSpellBook(idHammerOfWrath)
	knownBOJ = C_SpellBook.IsSpellInSpellBook(idBladeOfJustice)
	knownHOL = C_SpellBook.IsSpellInSpellBook(idHammerOfLight)
	knownFR = C_SpellBook.IsSpellInSpellBook(idFinalReckoning)
	knownES = C_SpellBook.IsSpellInSpellBook(idExecutionSentence)
	knownDH = C_SpellBook.IsSpellInSpellBook(idDivineHammer)
	knownLG = C_SpellBook.IsSpellInSpellBook(idLightsGuidance)
	knownTSlash = C_SpellBook.IsSpellInSpellBook(idTemplarSlash)
	knownSBA = C_SpellBook.IsSpellInSpellBook(idBlizzRotation)

	-- Spell usable checks
	usableTV = C_Spell.IsSpellUsable(idTemplarsVerdict)
	usableHOW = C_Spell.IsSpellUsable(idHammerOfWrath)
	usableHOL = C_Spell.IsSpellUsable(idHammerOfLight)
	usableWOA = C_Spell.IsSpellUsable(idWakeOfAshes)

	-- Talent checks
	CrusadingStrikes = C_SpellBook.IsSpellKnown(idCrusadingStrikes)
	TemplarStrikesTalent = C_SpellBook.IsSpellKnown(idTemplarStrikesTalent)
	SanctifyTalent = C_SpellBook.IsSpellKnown(idSanctify)

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

function xmod.Update()
	UpdateQueue()
end

function xmod.Rotation()
	s1 = nil
	GetStatus()
	-- if debug and debug.enabled then -- !!!
		-- debug:Clear()
		-- debug:AddBoth("ctime", s_ctime)
		-- debug:AddBoth("gcd", s_gcd)
		-- debug:AddBoth("hp", s_hp)
		-- debug:AddBoth("haste", s_haste)

		-- debug:AddBoth("dJudgment", s_debuff_Judgment)
		-- debug:AddBoth("bDivinePurpose", s_buff_DivinePurpose)
	-- end
	local action
	s1, action = GetNextAction()
	-- if debug and debug.enabled then -- !!!
		-- debug:AddBoth("s1", action)
		-- debug:AddBoth("s1Id", s1)
	-- end
	-- 
	s_otime = s_ctime -- save it so we adjust buffs for next
	actions[action].UpdateStatus()

	s_otime = s_ctime - s_otime

	-- -----------------------------------
	-- Spell Charges for xmod.rotation --
	-- -----------------------------------
	
	-- crusader strike stacks
	local cd, charges = GetCSData()
		s_CrusaderStrikeCharges = charges
	if (s1 == idCrusaderStrike) then
		s_CrusaderStrikeCharges = s_CrusaderStrikeCharges - 1
	end

	-- HoW Charges
	local cd, charges = GetHoWData()
		s_HoWCharges = charges
	if (s1 == idHammerOfWrath) then
		s_HoWCharges = s_HoWCharges - 1
	end

	-- BoJ Charges
	local cd, charges = GetBoJData()
		s_BoJCharges = charges
	if (s1 == idBladeOfJustice) then
		s_BoJCharges = s_BoJCharges - 1
	end

	-- Judgment Charges
	local cd, charges = GetJudgmentData()
		s_JudgmentCharges = charges
	if (s1 == idJudgment) then
		s_JudgmentCharges = s_JudgmentCharges - 1
	end

	-- ---------------
	-- Override Modes
	-- ---------------
	
	-- AOE Mode
	local AssistedDS = select(1, C_AssistedCombat.GetNextCastSpell())
	local level = UnitLevel("target")
	local className = UnitClass("target")
	
	-- Used in force enabling AOE on these mobs
	local SoulHunterCheck = ((className == "Adarus Duskblaze") or (className == "Velaryn Bloodwrath") or (className == "Ilyssa Darksorrow"))
	local SoulbinderCheck = ((className == "Shadowguard Mage") or (className == "Shadowguard Assassin") or (className == "Shadowguard Phaseblade") or (className == "Soulbinder Naazindhri"))
	local ForgeweaverCheck = ((className == "Forgeweaver Araz") or (className == "Arcane Echo") or (className == "Arcane Manifestation") or (className == "Prioress Murrpray"))
	
	-- Used for force Single Targeting on these mobs
	local stCheck = ((className == "Void Emissary") or (className == "Inquisitor Sigar") or (className == "High Adjudicator Aleez"))
	
	if ((AssistedDS == 53385) and db.aoeMode and ((level > 0) and (level < 82))) or ((SoulHunterCheck or SoulbinderCheck or ForgeweaverCheck) and (s1 == idTemplarsVerdict) and (AssistedDS == 53385)) then
		s1 = idDivineStorm
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
	-- --------------

	-- if debug and debug.enabled then -- !!!
		-- debug:AddBoth("csc", s_CrusaderStrikeCharges)
	-- end

	-- if debug and debug.enabled then
		-- debug:AddBoth("ctime", s_ctime)
		-- debug:AddBoth("otime", s_otime)
		-- debug:AddBoth("gcd", s_gcd)
		-- debug:AddBoth("hp", s_hp)
		-- debug:AddBoth("haste", s_haste)
		-- debug:AddBoth("dJudgment", s_debuff_Judgment)
		-- debug:AddBoth("bDivinePurpose", s_buff_DivinePurpose)
	-- end
	
	s2, action = GetNextAction()
	-- if debug and debug.enabled then --!!!
		-- debug:AddBoth("s2", action)
	-- end

	return s1, s2
end

-- event frame
local ef = CreateFrame("Frame", "clcRetModuleEventFrame") -- event frame
ef:Hide()
local function OnEvent()
	qTaint = true

	-- DivinePurpose talent
	local isKnown = C_SpellBook.IsSpellKnown(idDivinePurposeTalent)
	if isKnown then
		talent_DivinePurpose = selected
	end

end
ef:SetScript("OnEvent", OnEvent)
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("PLAYER_TALENT_UPDATE")
ef:RegisterEvent("PLAYER_LEVEL_UP")