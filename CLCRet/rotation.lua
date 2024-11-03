-- don't load if class is wrong
local _, class = UnitClass("player")
if class ~= "PALADIN" then return end

local _, xmod = ...

xmod.retmodule = {}
xmod = xmod.retmodule

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
	prio = "es dh hol ds ts2_exp fr tv5 ds_s woa tv how_aw bojx dtx boj2 jx cs2 cs ts2 ts1 boj how j cons",
	rangePerSkill = false,
	howclash = 0, -- priority time for hammer of wrath
	csclash = 0, -- priority time for cs
}

-- @defines
--------------------------------------------------------------------------------
local idGCD = 85256 -- tv for gcd

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

-- racials
local idArcaneTorrent = 155145
local idLightsJudgment = 255647

-- Talents
-- ids for talent spells (the actual talent in the tree, not the spell in the spellbook)
local idExecutionSentence = 343527
local idFinalReckoning = 343721
local idTemplarStrike = 407480
local idTemplarSlash = 406647
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
local idHammerOfLightDummy = 429826
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
local idDivinePurpose = 408459

-- dummy spells to get fake cd for Hammer of Light
local idFlashOfLightDummy = 19750

-- buffs
-- /dump C_UnitAuras.GetBuffDataByIndex("Player", 1)
-- /dump C_UnitAuras.GetDebuffDataByIndex("Target", 1)
-- /etrace for combat log search/pause

local idAvengingWrath = 31884
local idCrusade = 231895
local idArtOfWar = 281178
local idDivinePurpose = 408458
local idFinalVerdictHOW = 383329
local idEmpyreanLegacyTV = 387178
local idEmpyreanPowerDS = 326733
local idBlessingOfAnshe = 445206
local idForWhomTheBellTolls = 433618
local idEchoesOfWrath = 423590
local idLightsDeliverance = 433674
local idShakeTheHeavens = 431536

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

-- IsSpellOverlayed() -- used to check if it's glowing overlay is active
-- IsSpellKnownOrOverridesKnown()
-- C_Spell.IsSpellUsable()
-- C_Spell.GetSpellCooldown()
-- IsPlayerSpell() -- use this one to check for talent spells in the tree
-- Dummy spell for GCD = 61304

-- costs = GetSpellPowerCost(255937)	

-- (OLD) Do NOT put a check for "GetSpellCooldown(SpellID or Addon Shorthand)" in code, it will cause issues with GCD and displaying it as current recommendation
-- -------------------

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
		
		info = "Arcane Torrent (Blood Elf)",
		
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
		
		info = "Light's Judgment (Lightforged Draenei)",
		
		reqTalent = idLightsJudgment,
	},
	
	-- Consecration
	-- cons = {
		-- id = idConsecration,
		-- GetCD = function()
		
			-- local strings for less confusing code
			-- usableTV = C_Spell.IsSpellUsable(idTemplarsVerdict)
			-- playerSpellConsecratedBlade = IsPlayerSpell(idConsecratedBlade)
			-- playerSpellDivineHammer = IsPlayerSpell(idDivineHammer)
		
			-- if (s1 ~= idConsecration) and knownCONS and (not(usableTV)) and (not(playerSpellConsecratedBlade)) and (not(playerSpellDivineHammer)) then
				-- return GetCooldown(idConsecration)
			-- end
			
			-- if (s1 ~= idConsecration) and knownCONS and (not(usableTV)) and (not(playerSpellConsecratedBlade)) and playerSpellDivineHammer then
				-- return GetCooldown(idDivineHammer)
			-- end			
				-- return 100
		-- end,
		
		-- UpdateStatus = function()
			-- s_ctime = s_ctime + s_gcd + 1.5 / s_haste
		-- end,
		
		-- info = "Consecration",
	-- },

	-- ----------------------------------
	-- Holy Power Generators
	-- ----------------------------------
	
	-- Wake of Ashes
	woa = {
		id = idWakeOfAshes,
		GetCD = function()

			-- local strings for less confusing code
			knownWOA = IsSpellKnownOrOverridesKnown(idWakeOfAshes)
			usableWOA = C_Spell.IsSpellUsable(idWakeOfAshes)
			knownDivineHammer = IsPlayerSpell(idDivineHammer)
			
			s_cd_DH = GetCooldown(idDivineHammer)
			inactive_DH = ((s_cd_DH < 105))  -- divine hammer WAS up, on CD, NOT spinning
			active_DH = (s_cd_DH > 105) -- divine hammer is UP, on CD, Spinning
			DivineHammerCheck3 = ((knownDivineHammer and inactive_DH and (s_cd_DH > 1)) or (not(knownDivineHammer)))
			DivineHammerCheck4 = (knownDivineHammer and active_DH) and (s_cd_DH > 1) and (s_cd_DH < 109)
			TemplarCheck = ((IsPlayerSpell(idLightsGuidance) and s_hp >= 2) or (not(IsPlayerSpell(idLightsGuidance)) and s_hp >= 0))
			
			if (s1 ~= idWakeOfAshes) and usableWOA and (DivineHammerCheck3 or DivineHammerCheck4) and TemplarCheck then
					return GetCooldown(idWakeOfAshes)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			
			-- we need to trick the addon so it doesn't suggest a 3HoPo fr along with WoA and overcap HoPo
				if IsPlayerSpell(idDivineAuxiliary) then
					s_hp = max(3, s_hp + 3)
				else
					s_hp = min(3, s_hp + 3)
				end				
		end,
		
		info = "Wake Of Ashes",
		
		reqTalent = idWakeOfAshes,
	},

	-- Judgment
	j = {
		id = idJudgment,
		GetCD = function()
		
			-- local strings for less confusing code
			knownJ = IsSpellKnownOrOverridesKnown(idJudgment)
			usableHOL = C_Spell.IsSpellUsable(idHammerOfLight)
		
			local cd, charges = GetJudgmentData()
			
			if (s1 ~= idJudgment) and knownJ and not(usableHOL) then
				return GetCooldown(idJudgment)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				
				if IsPlayerSpell(idJudgment2) then
					s_hp = max(3, s_hp + 2)
				else
					s_hp = max(3, s_hp + 1)
				end
				
				s_JudgmentCharges = max(0, s_JudgmentCharges - 1)
		end,
		
		info = "Judgment",
	},

	-- Judgment 2 charges
	j2 = {
		id = idJudgment,
		GetCD = function()
		
			-- local strings for less confusing code
			knownJ = IsSpellKnownOrOverridesKnown(idJudgment)
			usableHOL = C_Spell.IsSpellUsable(idHammerOfLight)
		
			local cd, charges = GetJudgmentData()
		
			if (s1 ~= idJudgment) and (s_JudgmentCharges == 2) and knownJ and not(usableHOL) then
				return GetCooldown(idJudgment)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				
				if IsPlayerSpell(idJudgment2) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end
				
				s_JudgmentCharges = max(2, s_JudgmentCharges - 1)
		end,
		
		info = "Judgment at 2 Stacks (TALENT)",
		
		reqTalent = idImprovedJudgment,
	},

	-- Judgment w/whom the bell tolls hero talent proc
	j_bell = {
		id = idJudgment,
		GetCD = function()
		
			-- local strings for less confusing code
			knownJ = IsSpellKnownOrOverridesKnown(idJudgment)
			usableHOL = C_Spell.IsSpellUsable(idHammerOfLight)
		
			local cd, charges = GetJudgmentData()
			
			if (s1 ~= idJudgment) and knownJ and not(usableHOL) and s_buff_ForWhomTheBellTolls then
				return GetCooldown(idJudgment)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				
				if IsPlayerSpell(idJudgment2) then
					s_hp = max(3, s_hp + 2)
				else
					s_hp = max(3, s_hp + 1)
				end
				
				s_JudgmentCharges = max(0, s_JudgmentCharges - 1)
		end,
		
		info = "Judgment w/ For Whom The Bell Tolls up (Templar HERO TALENT)",
	},

	-- Judgment
	-- j_0sth = {
		-- id = idJudgment,
		-- GetCD = function()
		
			-- local strings for less confusing code
			-- knownJ = IsSpellKnownOrOverridesKnown(idJudgment)
			-- usableHOL = C_Spell.IsSpellUsable(idHammerOfLight)
		
			-- local cd, charges = GetJudgmentData()
			
			-- if (s1 ~= idJudgment) and knownJ and not(usableHOL) and not s_debuff_Judgment then
				-- return GetCooldown(idJudgment)
			-- end
			-- return 100
		-- end,
		
		-- UpdateStatus = function()
			-- s_ctime = s_ctime + s_gcd + 1.5
				
				-- if IsPlayerSpell(idJudgment2) then
					-- s_hp = max(3, s_hp + 2)
				-- else
					-- s_hp = max(3, s_hp + 1)
				-- end
				
				-- s_JudgmentCharges = max(0, s_JudgmentCharges - 1)
		-- end,
		
		-- info = "Judgment w/o Shake The Heavens up (TEMPLAR HERO TALENT BUFF)",
	-- },

	-- Crusader Strike
	cs = {
		id = idCrusaderStrike,
		GetCD = function()
		
			-- local strings for less confusing code
			CrusadingStrikes = IsPlayerSpell(idCrusadingStrikes)
			TemplarStrikesTalent = IsPlayerSpell(406646)
			usableTV = C_Spell.IsSpellUsable(idTemplarsVerdict)
			
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
		
		info = "Crusader Strike",
	},

	-- Crusader Strike @ 2 charges
	cs2 = {
		id = idCrusaderStrike,
		GetCD = function()
		
			-- local strings for less confusing code
			CrusadingStrikes = IsPlayerSpell(idCrusadingStrikes)
			TemplarStrikesTalent = IsPlayerSpell(406646)
			usableTV = C_Spell.IsSpellUsable(idTemplarsVerdict)
		
			local cd, charges = GetCSData()
		
			if (s1 ~= idCrusaderStrike) and CrusadingStrikes then
				return 100		
			end
			
			if (s1 ~= idCrusaderStrike) and (s_hp < 3) and (s_CrusaderStrikeCharges == 2) and not(CrusadingStrikes) and not(TemplarStrikesTalent) then
				return 0
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

			s_hp = max(3, s_hp + 1)
			
			s_CrusaderStrikeCharges = max(2, s_CrusaderStrikeCharges - 1)
		end,
		
		info = "Crusader Strike at 2 Stacks",
	},
	
	-- Templar strike 1st part combo
	ts1 = {
		id = idCrusaderStrike,
		GetCD = function()
			
			-- local strings for less confusing code
			CrusadingStrikes = IsPlayerSpell(idCrusadingStrikes)
			TemplarStrikesTalent = IsPlayerSpell(406646)
			usableTV = C_Spell.IsSpellUsable(idTemplarsVerdict)
			
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
		
		info = "Templar Strike (1st Part of Crusader Strike Combo)(TALENT)",
		
		reqTalent = 406646,
	},
	
	-- Templar slash 2nd part combo
	ts2 = {
		id = idTemplarSlash,
		GetCD = function()
		
			-- local strings for less confusing code
			CrusadingStrikes = IsPlayerSpell(idCrusadingStrikes)
			TemplarStrikesTalent = IsPlayerSpell(406646)
			knownTSlash = IsSpellKnownOrOverridesKnown(idTemplarSlash)
		
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
		
		info = "Templar Slash (2nd Part of Crusader Strike Combo)(TALENT)",
		
		reqTalent = 406646,
	},

	-- Templar slash 2nd part combo, about to expire
	ts2_exp = {
		id = idTemplarSlash,
		GetCD = function()
		
			-- local strings for less confusing code
			CrusadingStrikes = IsPlayerSpell(idCrusadingStrikes)
			TemplarStrikesTalent = IsPlayerSpell(406646)
			knownTSlash = IsSpellKnownOrOverridesKnown(idTemplarSlash)
		
			local chargeInfo = C_Spell.GetSpellCharges(407480)
			local charges, maxCharges, StartTime = chargeInfo.currentCharges, chargeInfo.maxCharges, chargeInfo.cooldownStartTime;
			local tscdexpiring = ((GetTime() > ((StartTime) + 3)) and (GetTime() < ((StartTime) + 5)))
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
		
		info = "Templar Slash Combo(TALENT) about to expire",
		
		reqTalent = 406646,
	},
	
	-- Hammer of Wrath
	how = {
		id = idHammerOfWrath,
		GetCD = function()
		
			-- local strings for less confusing code
			usableHOW = C_Spell.IsSpellUsable(idHammerOfWrath)
			usableTV = C_Spell.IsSpellUsable(idTemplarsVerdict)
			knownHOW = IsSpellKnownOrOverridesKnown(idHammerOfWrath)
		
		local cd, charges = GetHoWData()
			if (s1 ~= idHammerOfWrath) and ((s_HoWCharges == 1) or (s_HoWCharges == 2)) and usableHOW and knownHOW then
				return GetCooldown(idHammerOfWrath)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if IsPlayerSpell(idHammerOfWrath2) and (((UnitHealth("target") / (UnitHealthMax("target") + 1) * 100)) < 20) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end	
			
			s_HoWCharges = max(0, s_HoWCharges - 1)
		end,
		
		info = "Hammer of Wrath",
	},

	-- Hammer of Wrath 2 charges (talent)
	how2 = {
		id = idHammerOfWrath,
		GetCD = function()

			-- local strings for less confusing code
			usableHOW = C_Spell.IsSpellUsable(idHammerOfWrath)
			knownHOW = IsSpellKnownOrOverridesKnown(idHammerOfWrath)

		-- we don't use usableTV string since we want to HoW2 to go on cd and start recharging while we use TV
		local cd, charges = GetHoWData()
			if (s1 ~= idHammerOfWrath) and (s_HoWCharges == 2) and usableHOW and knownHOW then
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
			
			s_HoWCharges = max(2, s_HoWCharges - 1)
		end,
		
		info = "Hammer of Wrath at 2 Stacks (TALENT)",
		
		reqTalent = idVanguardsMomentum,
	},

	-- Hammer of Wrath w/ Avenging Wrath
	how_anshe = {
		id = idHammerOfWrath,
		GetCD = function()
			local cd, charges = GetHoWData()
		
			-- local strings for less confusing code
			knownHOW = IsSpellKnownOrOverridesKnown(idHammerOfWrath)
			usableTV = C_Spell.IsSpellUsable(idTemplarsVerdict)
		
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
		
		info = "Hammer of Wrath with Blessing Of Anshe (Herald of the Sun HERO TALENT)",
	},

	-- Hammer of Wrath w/ Avenging Wrath
	how_aw = {
		id = idHammerOfWrath,
		GetCD = function()
			local cd, charges = GetHoWData()
		
			-- local strings for less confusing code
			awCheck = (s_buff_AvengingWrath or s_buff_Crusade)
			knownHOW = IsSpellKnownOrOverridesKnown(idHammerOfWrath)
			usableTV = C_Spell.IsSpellUsable(idTemplarsVerdict)
		
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
		
		info = "Hammer of Wrath during Avenging Wrath",
	},
	
	-- Hammer of Wrath (2 charge talent) w/ Avenging Wrath 
	how2_aw = {
		id = idHammerOfWrath,
		GetCD = function()
		
			-- local strings for less confusing code
			awCheck = (s_buff_AvengingWrath or s_buff_Crusade)
			knownHOW = IsSpellKnownOrOverridesKnown(idHammerOfWrath)
		
		-- we don't need usableHOW strings since HoW is always usable during AW
		-- we don't use usableTV string since we want to HoW2 to go on cd and start recharging while we use TV
		local cd, charges = GetHoWData()
			if (s1 ~= idHammerOfWrath) and (s_HoWCharges == 2) and awCheck and knownHOW then
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
		
		info = "Hammer of Wrath (2 charges) during Avenging Wrath",
		
		reqTalent = idVanguardsMomentum,
	},

	-- Blade of Justice
	boj = {
		id = idBladeOfJustice,
		GetCD = function()
		
			-- local strings for less confusing code
			knownBOJ = IsSpellKnownOrOverridesKnown(idBladeOfJustice)
			usableTV = C_Spell.IsSpellUsable(idTemplarsVerdict)
		
		local cd, charges = GetBoJData()

			if (s1 ~= idBladeOfJustice) and knownBOJ and (GetCooldown(idBladeOfJustice) < 1) then
				return GetCooldown(idBladeOfJustice)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if IsPlayerSpell(idBladeOfJustice2) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end

			s_BoJCharges = max(0, s_BoJCharges - 1)
		end,
		
		info = "Blade of Justice",
	},

	-- Blade of Justice 2 stacks
	boj2 = {
		id = idBladeOfJustice,
		GetCD = function()
		
			-- local strings for less confusing code
			knownBOJ = IsSpellKnownOrOverridesKnown(idBladeOfJustice)
			usableTV = C_Spell.IsSpellUsable(idTemplarsVerdict)
		
		local cd, charges = GetBoJData()
			
			if (s1 ~= idBladeOfJustice) and (s_BoJCharges == 2) and (s_hp <= 3) and knownBOJ and (GetCooldown(idBladeOfJustice) < 1) then
				return GetCooldown(idBladeOfJustice)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if IsPlayerSpell(idBladeOfJustice2) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end

			s_BoJCharges = max(0, s_BoJCharges - 1)
		end,
		
		info = "Blade of Justice at 2 Stacks (TALENT)",
		
		reqTalent = idImprovedBladeOfJustice,
	},

	-- ----------------------------------
	-- Holy Power Consumers
	-- ----------------------------------

	-- Divine Storm Proc
	ds = {
		id = idDivineStorm,
		GetCD = function()
			if (s1 ~= idDivineStorm) and s_buff_EmpyreanPowerDS then
				return 0
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(3, s_hp - 0)
		end,
		
		info = "Divine Storm w/ Empyrean Power Proc",
		
		reqTalent = idEmpyreanPower,
	},

	-- Divine Storm no sanctify buff (used to apply sanctify talent buff)
	ds_s = {
		id = idDivineStorm,
		GetCD = function()
		
			-- local strings for less confusing code
			SanctifyTalent = IsPlayerSpell(idSanctify)
		
			if (s1 ~= idDivineStorm) and (s_buff_DivinePurpose or (s_hp > 2)) and not(s_debuff_Sanctify) and SanctifyTalent and s_buff_EmpyreanPowerDS then
				return 0
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(3, s_hp - 3)
		end,
		
		info = "Divine Storm to apply Sanctify debuff",
		
		reqTalent = idSanctify,
	},


	-- ----------------------------------
	-- Templar's Verdict
	-- ----------------------------------

	-- Templar's Verdict 
	tv = {
		id = idTemplarsVerdict,
		GetCD = function()

			-- Keeping for possible later use
			-- JudgmentCheck = ((C_Spell.GetSpellCooldown(idJudgment) > 2) or (IsPlayerSpell(idDivineToll) and (C_Spell.GetSpellCooldown(idDivineToll) > 2)))
	
			-- local strings for less confusing code
			knownHOL = IsSpellKnownOrOverridesKnown(idHammerOfLight)
			knownDivineHammer = IsPlayerSpell(idDivineHammer)
			
			s_cd_DH = GetCooldown(idDivineHammer)
			inactive_DH = ((s_cd_DH < 105))  -- divine hammer is NOT up
			active_DH = (s_cd_DH > 105) -- divine hammer is UP
			DivineHammerCheck1 = (((s_hp > 2) or s_buff_DivinePurpose) and ((knownDivineHammer and inactive_DH) or (not(knownDivineHammer))))
			DivineHammerCheck2 = (((s_hp > 4) or s_buff_DivinePurpose) and knownDivineHammer and active_DH) and (s_cd_DH > 1) and (s_cd_DH < 105)
			
			if (s1 ~= idTemplarsVerdict) and not(knownHOL) and (DivineHammerCheck1 or DivineHammerCheck2) then
				return 0
			end
			
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		
		info = "Templar's Verdict",
	},

	-- Templar's Verdic 5 HoPo
	tv5 = {
		id = idTemplarsVerdict,
		GetCD = function()
			
			-- local strings for less confusing code
			knownHOL = IsSpellKnownOrOverridesKnown(idHammerOfLight)
			knownDivineHammer = IsPlayerSpell(idDivineHammer)
			
			s_cd_DH = GetCooldown(idDivineHammer)
			inactive_DH = ((s_cd_DH < 105))  -- divine hammer is NOT up
			active_DH = (s_cd_DH > 105) -- divine hammer is UP
			DivineHammerCheck1 = (((s_hp > 4) or s_buff_DivinePurpose) and ((knownDivineHammer and inactive_DH) or (not(knownDivineHammer))))
			DivineHammerCheck2 = (((s_hp > 4) or s_buff_DivinePurpose) and knownDivineHammer and active_DH) and (s_cd_DH > 1) and (s_cd_DH < 105)
			
			if (s1 ~= idTemplarsVerdict) and not(knownHOL) and (DivineHammerCheck1 or DivineHammerCheck2) then
				return 0
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		
		info = "Templar's Verdict at 5 Holy Power",
	},

	-- Templar's Verdict w/ Empyrean Legacy proc
	tv_ds = {
		id = idTemplarsVerdict,
		GetCD = function()
			
			-- local strings for less confusing code
			knownTV = IsSpellKnownOrOverridesKnown(idTemplarsVerdict)
			knownHOL = IsSpellKnownOrOverridesKnown(idHammerOfLight)
			
			if (s1 ~= idTemplarsVerdict) and knownTV and ((s_hp > 2) or s_buff_DivinePurpose) and s_buff_EmpyreanLegacyTV and not(knownHOL) then
				return 0
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(3, s_hp - 3)
		end,
		
		info = "Templar's Verdict with Empyrean Legacy (Divine Storm) Proc",
	},

	-- ----------------------------------
	-- Talents/Hero Talents (Execution Sentence, etc)
	-- ----------------------------------
	
	-- Hammer of light
		hol = {
		id = idHammerOfLightDummy,
		GetCD = function()
			
			-- local strings for less confusing code
			usableWOA = C_Spell.IsSpellUsable(idWakeOfAshes)
			usableHOL = C_Spell.IsSpellUsable(idHammerOfLight)
			knownHOL = IsSpellKnownOrOverridesKnown(idHammerOfLight)
			knownDivineHammer = IsPlayerSpell(idDivineHammer)
			
			s_cd_DH = GetCooldown(idDivineHammer)
			inactive_DH = ((s_cd_DH < 105))  -- divine hammer is NOT up
			active_DH = (s_cd_DH > 105) -- divine hammer is UP
			LightsDeliverance = (IsSpellOverlayed(idHammerOfLight) and IsPlayerSpell(idLightsGuidance) and s_buff_LightsDeliverance)
			DivineHammerCheck1 = (((s_hp > 4) or s_buff_DivinePurpose or LightsDeliverance) and ((knownDivineHammer and inactive_DH) or (not(knownDivineHammer))))
			DivineHammerCheck2 = (((s_hp > 4) or s_buff_DivinePurpose or LightsDeliverance) and knownDivineHammer and active_DH) and (s_cd_DH > 1) and (s_cd_DH < 105)
			
			if (s1 ~= idHammerOfLightDummy) and usableHOL and IsSpellOverlayed(idHammerOfLight) then
				return 0
			end
			return 100
		end,
		
		UpdateStatus = function()
			-- s_ctime = s_gcd + 1.5 -- HoL gcd string causes bug where it displays first, second, or third in line for rotation on GCD, regardless if known or not
		end,
		
		info = "Hammer of Light (Templar HERO TALENT)",
	},

	-- Final Reckoning
	fr = {
		id = idFinalReckoning,
		GetCD = function()
		
		-- Redundancy to make sure FR is known and off cd
		frCheck = (IsSpellKnownOrOverridesKnown(343721) and (GetCooldown(343721) < 3))
		
		--Checks to make sure Divine Auxillary talent will not over cap Holy Power if specced with Vanguard
		AuxHPcapCheck = ((not(IsPlayerSpell(406158)) and (s_hp > 2)) or (IsPlayerSpell(406158) and (s_hp < 4)))
			
			if (s1 ~= idFinalReckoning) and frCheck and AuxHPcapCheck then
				return GetCooldown(idFinalReckoning)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste

				if IsPlayerSpell(idDivineAuxiliary) then
					s_hp = max(3, s_hp + 3)
				else
					s_hp = min(3, s_hp + 0)
				end
		end,
		
		info = "Final Reckoning",
		-- reqTalent = 343721,
	},

	-- Divine Hammers 
	dh = {
		id = idDivineHammer,
		GetCD = function()
		
			-- local strings for less confusing code
			knownDH = IsSpellKnownOrOverridesKnown(idDivineHammer)
			
			if (s1 ~= idDivineHammer) and knownDH and (s_hp > 2) then
				return GetCooldown(idDivineHammer)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		
		info = "Divine Hammer",
		
		reqTalent = 198034,
	},

	-- Execution Sentence Boss only
	es_boss = {
		id = idExecutionSentence,
		GetCD = function()
		
			-- local strings for less confusing code
			knownES = IsSpellKnownOrOverridesKnown(idExecutionSentence)
			usableES = C_Spell.IsSpellUsable(idExecutionSentence)
			
			-- checks target level 
			level = UnitLevel("target")
			
			-- makes sure you dont overcap holy power too much
			AuxHPcapCheck = ((not(IsPlayerSpell(406158)) and (s_hp > 2)) or (IsPlayerSpell(406158) and (s_hp < 4)))
					
			if (s1 ~= idExecutionSentence) and knownES and usableES and AuxHPcapCheck and ((level < 0) or (level > 81)) then
				return GetCooldown(idExecutionSentence)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if IsPlayerSpell(idDivineAuxiliary) then
					s_hp = max(3, s_hp + 3)
				else
					s_hp = min(3, s_hp + 0)
				end
		end,
		
		info = "Execution Sentence on Boss level mobs only",
		
		-- reqTalent = 343527,
	},

	-- Execution Sentence  
	es = {
		id = idExecutionSentence,
		GetCD = function()
		
			-- local strings for less confusing code
			knownES = IsSpellKnownOrOverridesKnown(idExecutionSentence)
			usableES = C_Spell.IsSpellUsable(idExecutionSentence)
			
			-- checks target level 
			level = UnitLevel("target")
			
			-- makes sure you dont overcap holy power too much
			AuxHPcapCheck = ((not(IsPlayerSpell(406158)) ) or (IsPlayerSpell(406158) and (s_hp < 4)))
			
			if (s1 ~= idExecutionSentence) and knownES and usableES and AuxHPcapCheck then
				return GetCooldown(idExecutionSentence)
			end
			return 100
		end,
		
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if IsPlayerSpell(idDivineAuxiliary) then
					s_hp = max(3, s_hp + 3)
				else
					s_hp = min(3, s_hp + 0)
				end
		end,
		
		info = "Execution Sentence",
		
		-- reqTalent = 343527,
	},

	-- --------------------------------------------
	-- Divine Purpose Procs
	-- --------------------------------------------

	-- Templar's Verdict with Divine Purpose
	tvdp = {
		id = idTemplarsVerdict,
		GetCD = function()
		
			-- local strings for less confusing code
			knownHOL = IsSpellKnownOrOverridesKnown(idHammerOfLight)
		
			if (s1 ~= idTemplarsVerdict) and s_buff_DivinePurpose and not(knownHOL) then
				return 0
			end
			return 100
		end,
		
		UpdateStatus = function()
		end,
		
		info = "Templar's Verdict w/ DP Proc",
	},

	-- ----------------------------------
	-- (Ex)Covenant Abilities
	-- ----------------------------------

	-- Divine Toll 
	dt = {
		id = idDivineToll,
		GetCD = function()

			if (s1 ~= idDivineToll) and IsPlayerSpell(idDivineToll) and (GetCooldown(idDivineToll) < 1) then
				return GetCooldown(idDivineToll)
			end
			return 100
		end,
		
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			
					s_hp = min(3, s_hp + 1)
		end,
		
		info = "Divine Toll",
		
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
			print("clcretmodule - invalid action:", v)
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
		debug:AddBoth("hp", s_hp)
		debug:AddBoth("haste", s_haste)

		debug:AddBoth("dJudgment", s_debuff_Judgment)
		debug:AddBoth("bDivinePurpose", s_buff_DivinePurpose)
		debug:AddBoth("bTFOJ", s_buff_TheFiresOfJustice)
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

	---------------

	if debug and debug.enabled then
		debug:AddBoth("csc", s_CrusaderStrikeCharges)
	end

	if debug and debug.enabled then
		debug:AddBoth("ctime", s_ctime)
		debug:AddBoth("otime", s_otime)
		debug:AddBoth("gcd", s_gcd)
		debug:AddBoth("hp", s_hp)
		debug:AddBoth("haste", s_haste)
		debug:AddBoth("dJudgment", s_debuff_Judgment)
		debug:AddBoth("bDivinePurpose", s_buff_DivinePurpose)
	end
	
	s2, action = GetNextAction()
	if debug and debug.enabled then
		debug:AddBoth("s2", action)
	end

	return s1, s2
end

-- event frame
local ef = CreateFrame("Frame", "clcRetModuleEventFrame") -- event frame
ef:Hide()
local function OnEvent()
	qTaint = true

	-- DivinePurpose talent
	local isKnown = IsPlayerSpell(idDivinePurpose)
	if isKnown then
		talent_DivinePurpose = selected
	end



end
ef:SetScript("OnEvent", OnEvent)
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("PLAYER_TALENT_UPDATE")
ef:RegisterEvent("PLAYER_LEVEL_UP")
