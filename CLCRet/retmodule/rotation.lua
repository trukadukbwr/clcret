-- Pulls back the Addon-Local Variables and store them locally.
local addonName, addonTable = ...;
local addon = _G[addonName];

-- Store local copies of Blizzard API and other addon global functions and variables
local GetBuildInfo = GetBuildInfo;
local select, setmetatable, table, type, unpack = select, setmetatable, table, type, unpack;

addonTable.CURRENT_WOW_VERSION = select(4, GetBuildInfo());

local Prototype = {


	-- API Version History
	-- 8.0 - Dropped second parameter (nameSubtext).
	--     - Also, no longer supports querying by spell name.
	UnitBuff = function(...)
		if addonTable.CURRENT_WOW_VERSION >= 80000 then
			local unitID, ID = ...;

			if type(ID) == "string" then
				for counter = 1, 40 do
					local auraName = UnitBuff(unitID, counter);

					if ID == auraName then
						return UnitBuff(unitID, counter);
					end
				end
			end
		else
			local parameters = { UnitBuff(...) };

			table.insert(parameters, 2, "dummyReturn");

			return unpack(parameters);
		end
	end,

	-- API Version History
	-- 8.0 - Dropped second parameter (nameSubtext).
	--     - Also, no longer supports querying by spell name.
	UnitDebuff = function(...)
		if addonTable.CURRENT_WOW_VERSION >= 80000 then
			local unitID, ID = ...;

			if type(ID) == "string" then
				for counter = 1, 40 do
					local auraName = UnitDebuff(unitID, counter);

					if ID == auraName then
						return UnitDebuff(unitID, counter);
					end
				end
			end
		else
			local parameters = { UnitDebuff(...) };

			table.insert(parameters, 2, "dummyReturn");

			return unpack(parameters);
		end
	end,

};

local MT = {
	__index = function(table, key)
		local classPrototype = Prototype[key];

		if classPrototype then
			if type(classPrototype) == "function" then
				return function(...)
					return classPrototype(...);
				end
			else
				return classPrototype;
			end
		else
			return function(...)
				return _G[key](...);
			end
		end
	end,
};

APIWrapper = setmetatable({}, MT);


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
	prio = "es tv5 ds_s tvdp woa fr ts2 how_aw tv boj_aow dt ds boj2 j boj ts1 cs2 cs cons",
	rangePerSkill = false,
	howclash = 0, -- priority time for hammer of wrath
	csclash = 0, -- priority time for cs
}

-- @defines
--------------------------------------------------------------------------------
local idGCD = 85256 -- tv for gcd

-- spells
local idTemplarsVerdict = 85256
local idCrusaderStrike = 35395
local idJudgment = 20271
local idConsecration = 26573
local idJusticarsVengeance = 215661
local idWakeOfAshes = 255937
local idExecutionSentence = 343527
local idHammerOfJustice = 853
local idDivineStorm = 53385
local idArcaneTorrent = 155145
local idHoW = 24275
local idBladeOfJustice = 184575
local idDivineStorm = 53385
local idAvengingWrath = 31884
local idFinalReckoning = 343721
local idJusticarsVengeance = 215661
local idSanctify = 382536

-- talents, Generate 2 Holy Power
local idBoJ2 = 383342
local idJudgment2 = 405278
local idHoW2 = 383314
local idTemplarSlash = 406647
local idDivineHammer = 198034

-- talents, makes passive
local idCrusadingStrikes = 404542
local idConsecratedBlade = 404834

-- talents, Holy Power Costs
local idDivineAuxiliary = 406158
local idVanguard = 406545
local idDivinePurpose = 408459

-- ------------------------
-- ---Covenant Abilities---
-- ------------------------
local idToll = 375576

-- ------
-- buffs
-- ------
local ln_buff_aow = GetSpellInfo(281178)
local ln_buff_DivinePurpose = GetSpellInfo(223819)
local ln_buff_ds2 = GetSpellInfo(326733)
local ln_buff_aw = GetSpellInfo(31884)
local ln_buff_FinalVerdict = GetSpellInfo(383329)
local ln_buff_ds = GetSpellInfo(387178)
local ln_buff_Crusade = GetSpellInfo(231895)

-- debuffs
local ln_debuff_Judgment = GetSpellInfo(197277)
local ln_debuff_Exec = GetSpellInfo(343527)
local ln_debuff_FinalReckoning = GetSpellInfo(343721)
local ln_debuff_Sanctify = GetSpellInfo(382538)
local ln_debuff_Expurgation = GetSpellInfo(383346)

-- buffs/debuffs
local s_buff_aow, s_buff_DivinePurpose, s_buff_ds2, s_buff_aw, s_buff_FinalVerdict, s_buff_ds, s_buff_Crusade
local s_debuff_Judgment, s_debuff_ExecutionSentence, s_debuff_FinalReckoning, s_debuff_Sanctify, s_debuff_Expurgation

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
	local start, duration = GetSpellCooldown(id)
	if start == nil then return 100 end
	local cd = start + duration - s_ctime - s_gcd
	if cd < 0 then return 0 end
	return cd
end


-- ----------------
-- Spell Charges --
-- ----------------

local function GetCSData()
	local charges, maxCharges, start, duration = GetSpellCharges(idCrusaderStrike)
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
	local charges, maxCharges, start, duration = GetSpellCharges(idHoW)
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
	local charges, maxCharges, start, duration = GetSpellCharges(idBladeOfJustice)
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
	local charges, maxCharges, start, duration = GetSpellCharges(idJudgment)
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
-- /dump UnitBuff("Player", 1)
-- /dump UnitDebuff("Target", 1)
-- IsSpellKnownOrOverridesKnown()
-- (not(IsUsableSpell(id )))
-- IsPlayerSpell  -- to check for talent
-- IsUsableSpell(383469) wont return true unless theres holy power
-- costs = GetSpellPowerCost(255937)	
-- -------------------------------------------------------------------------------

-- actions ---------------------------------------------------------------------
local actions = {

	--Arcane Torrent
	arc = {
		id = idArcaneTorrent,
		GetCD = function()
			if (s1 ~= idArcaneTorrent) and (s_hp <= 2) and IsSpellKnownOrOverridesKnown(idArcaneTorrent) then
				return GetCooldown(idArcaneTorrent)
			end
			return 100
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			
					s_hp = min(3, s_hp + 1)

		end,
		info = "Arcane Torrent",
	},

	--Consecration
	cons = {
		id = idConsecration,
		GetCD = function()
			if (s1 ~= idConsecration) and IsSpellKnownOrOverridesKnown(idConsecration) and (not(IsUsableSpell(idTemplarsVerdict))) and (not(IsPlayerSpell(idConsecratedBlade))) and (not(IsPlayerSpell(idDivineHammer))) then
				return GetCooldown(idConsecration)
			end
			
			if (s1 ~= idConsecration) and IsSpellKnownOrOverridesKnown(idConsecration) and (not(IsUsableSpell(idTemplarsVerdict))) and (not(IsPlayerSpell(idConsecratedBlade))) and IsPlayerSpell(idDivineHammer) then
				return GetCooldown(idDivineHammer)
			end
			
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste

		end,
		info = "Consecration",
	},

	-- ----------------------------------
	-- Holy Power Generators
	-- ----------------------------------
	
	woa = {
		id = idWakeOfAshes,
		GetCD = function()
			if (s1 ~= idWakeOfAshes) and IsSpellKnownOrOverridesKnown(idWakeOfAshes) and (s_hp < 4) and IsUsableSpell(idWakeOfAshes) then
					return GetCooldown(idWakeOfAshes)
			end
			return 100
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			
			-- we need to trick the addon so it doesn't suggest a 3HoPo fr and wake and overcap us
				if IsPlayerSpell(idDivineAuxiliary) then
					s_hp = max(3, s_hp + 3)
				else
					s_hp = min(3, s_hp + 2)
				end
				
		end,
		info = "Wake Of Ashes",
	},

	--Judgment
	j = {
		id = idJudgment,
		GetCD = function()
			if (s1 ~= idJudgment) and ((s_JudgmentCharges == 1) or (s_JudgmentCharges == 2)) and IsSpellKnownOrOverridesKnown(idJudgment) and (s_debuff_Judgment < 2) then
				return GetCooldown(idJudgment)
			end
			return 100 -- lazy stuff
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_debuff_Judgment = 8
				
				if IsPlayerSpell(idJudgment2) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end
				
				s_JudgmentCharges = max(0, s_JudgmentCharges - 1)

		end,
		info = "Judgment",
	},

	--Judgment
	j2 = {
		id = idJudgment,
		GetCD = function()
			if (s1 ~= idJudgment) and (s_JudgmentCharges == 2) and IsSpellKnownOrOverridesKnown(idJudgment) and (s_debuff_Judgment < 2) then
				return GetCooldown(idJudgment)
			end
			return 100 -- lazy stuff
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_debuff_Judgment = 8
				
				if IsPlayerSpell(idJudgment2) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end
				
				s_JudgmentCharges = max(0, s_JudgmentCharges - 1)

		end,
		info = "Judgment at 2 Stacks (TALENT)",
	},

	--Crusader Strike; templar strike 1st part combo
	ts1 = {
		id = idCrusaderStrike,
		GetCD = function()
			local cd, charges = GetCSData()
			
			if (s1 ~= idCrusaderStrike) and IsPlayerSpell(idCrusadingStrikes) then
				return 100
			end
			
			if (s1 ~= idCrusaderStrike) and (s_hp < 5) and (not(IsPlayerSpell(idCrusadingStrikes))) and IsPlayerSpell(406646) and (not(IsSpellKnownOrOverridesKnown(idTemplarSlash))) then
				return 0
			end
			return cd + 0.5
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

			s_hp = min(3, s_hp + 1)
			
			s_CrusaderStrikeCharges = max(0, s_CrusaderStrikeCharges - 1)
			
		end,
		info = "Templar Strike (1st Part of Crusader Strike Combo)(TALENT)",
	},

	--Crusader Strike; templar strike 2nd part combo
	ts2 = {
		id = idCrusaderStrike,
		GetCD = function()
			local cd, charges = GetCSData()
			
			if (s1 ~= idCrusaderStrike) and IsPlayerSpell(idCrusadingStrikes) then
				return 100
			end
			
			if (s1 ~= idCrusaderStrike) and (s_hp < 5) and (not(IsPlayerSpell(idCrusadingStrikes))) and IsSpellKnownOrOverridesKnown(idTemplarSlash) then
				return 0
			end
			return cd + 0.5
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

			s_hp = min(3, s_hp + 1)
			
			s_CrusaderStrikeCharges = max(0, s_CrusaderStrikeCharges - 1)
			
		end,
		info = "Templar Slash (2nd Part of Crusader Strike Combo)(TALENT)",
	},

	--Crusader Strike
	cs = {
		id = idCrusaderStrike,
		GetCD = function()
			local cd, charges = GetCSData()
			
			if (s1 ~= idCrusaderStrike) and IsPlayerSpell(idCrusadingStrikes) then
				return 100
			end
			
			if (s1 ~= idCrusaderStrike) and ((s_CrusaderStrikeCharges == 1) or (s_CrusaderStrikeCharges == 2)) and (s_hp < 3) and (not(IsUsableSpell(idTemplarsVerdict))) and (not(IsPlayerSpell(idCrusadingStrikes))) then
				return 0
			end
			return cd + 0.5
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

			s_hp = min(3, s_hp + 1)
			
			s_CrusaderStrikeCharges = max(0, s_CrusaderStrikeCharges - 1)
			
		end,
		info = "Crusader Strike",
	},

	--Crusader Strike @ 2 charges
	cs2 = {
		id = idCrusaderStrike,
		GetCD = function()
		
			if (s1 ~= idCrusaderStrike) and IsPlayerSpell(idCrusadingStrikes) then
				return 100		
			end
			
			if (s1 ~= idCrusaderStrike) and (s_CrusaderStrikeCharges == 2) and (s_hp < 3) and (not(IsUsableSpell(idTemplarsVerdict))) and (not(IsPlayerSpell(idCrusadingStrikes))) then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

			s_hp = max(3, s_hp + 1)
			
			s_CrusaderStrikeCharges = max(0, s_CrusaderStrikeCharges - 1)

		end,
		info = "Crusader Strike at 2 Stacks",
	},
	
	--Hammer of Wrath
	how = {
		id = idHoW,
		GetCD = function()
		local cd, charges = GetHoWData()
			if (s1 ~= idHoW) and ((s_HoWCharges == 1) or (s_HoWCharges == 2)) and IsUsableSpell(idHoW) and IsSpellKnownOrOverridesKnown(idHoW) and (not(IsUsableSpell(idTemplarsVerdict))) then
				return GetCooldown(idHoW)
			end
			return 100
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if IsPlayerSpell(idHoW2) and (((UnitHealth("target") / (UnitHealthMax("target") + 1) * 100)) < 20) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end	
			
			s_HoWCharges = max(0, s_HoWCharges - 1)

		end,
		info = "Hammer of Wrath",
	},

	--Hammer of Wrath
	how2 = {
		id = idHoW,
		GetCD = function()
		local cd, charges = GetHoWData()
			if (s1 ~= idHoW) and (s_HoWCharges == 2) and IsUsableSpell(idHoW) and IsSpellKnownOrOverridesKnown(idHoW) and (not(IsUsableSpell(idTemplarsVerdict))) then
				return GetCooldown(idHoW)
			end
			return 100
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if IsPlayerSpell(idHoW2) and (((UnitHealth("target") / (UnitHealthMax("target") + 1) * 100)) < 20) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end
			
			s_HoWCharges = max(0, s_HoWCharges - 1)

		end,
		info = "Hammer of Wrath at 2 Stacks (TALENT)",
	},

	--Hammer of Wrath w/ Avenging Wrath
	how_aw = {
		id = idHoW,
		GetCD = function()
			if (s1 ~= idHoW) and IsUsableSpell(idHoW) and (((s_buff_aw > 1) or (s_buff_Crusade > 1)) or (s_buff_FinalVerdict > 1)) and IsSpellKnownOrOverridesKnown(idHoW) then
				return GetCooldown(idHoW)
			end
			return 100
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if IsPlayerSpell(idHoW2) and (((UnitHealth("target") / (UnitHealthMax("target") + 1) * 100)) < 20) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end
			
			s_HoWCharges = max(0, s_HoWCharges - 1)
			
		end,
		info = "Hammer of Wrath during Avenging Wrath",
	},

	--Blade of Justice
	boj = {
		id = idBladeOfJustice,
		GetCD = function()
			if (s1 ~= idBladeOfJustice) and ((s_BoJCharges == 1) or (s_BoJCharges == 2)) and (s_hp <= 3) and IsSpellKnownOrOverridesKnown(idBladeOfJustice) and (not(IsUsableSpell(idTemplarsVerdict))) then
				return GetCooldown(idBladeOfJustice)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if IsPlayerSpell(idBoJ2) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end

			s_BoJCharges = max(0, s_BoJCharges - 1)

		end,
		info = "Blade of Justice",
	},

	--Blade of Justice
	boj2 = {
		id = idBladeOfJustice,
		GetCD = function()
			if (s1 ~= idBladeOfJustice) and (s_BoJCharges == 2) and (s_hp <= 3) and IsSpellKnownOrOverridesKnown(idBladeOfJustice) and (not(IsUsableSpell(idTemplarsVerdict))) then
				return GetCooldown(idBladeOfJustice)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if IsPlayerSpell(idBoJ2) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end

			s_BoJCharges = max(0, s_BoJCharges - 1)

		end,
		info = "Blade of Justice at 2 Stacks (TALENT)",
	},

	--Blade of Justice w/ Art of War proc
	boj_aow = {
		id = idBladeOfJustice,
		GetCD = function()
			if (s1 ~= idBladeOfJustice) and (s_hp <= 3) and IsSpellKnownOrOverridesKnown(idBladeOfJustice) and (s_buff_aow > 1) and (not(IsUsableSpell(idTemplarsVerdict))) then
				return GetCooldown(idBladeOfJustice)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if IsPlayerSpell(idBoJ2) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end

			s_BoJCharges = max(0, s_BoJCharges - 1)

		end,
		info = "Blade of Justice w/ Art of War Proc",
	},

	-- ----------------------------------
	-- Holy Power Consumers
	-- ----------------------------------

	--Divine Storm Proc
	ds = {
		id = idDivineStorm,
		GetCD = function()
			if (s1 ~= idDivineStorm) and (s_buff_ds2 > 1) then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(3, s_hp - 0)
		end,
		info = "Divine Storm w/ Empyrean Power Proc",
	},

	--Divine Storm no sanctify buff (used to apply sanctify talent buff)
	ds_s = {
		id = idDivineStorm,
		GetCD = function()
			if (s1 ~= idDivineStorm) and (((IsPlayerSpell(idVanguard) and (s_hp > 3)) or ((not(IsPlayerSpell(idVanguard))) and (s_hp > 2))) or (s_buff_DivinePurpose > 0)) and (not(s_debuff_Sanctify > 1)) and IsPlayerSpell(idSanctify) and (s_buff_ds < 1) then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(3, s_hp - 3)
		end,
		info = "Divine Storm to apply Sanctify debuff",
	},


	-- ----------------------------------
	-- Templar's Verdict
	-- ----------------------------------
	--
	-- ((IsPlayerSpell(idVanguard) and (s_hp > 3)) or ((not(IsPlayerSpell(idVanguard))) and (s_hp > 2)))
	--
	-------------------------------------


	--Templar's Verdict no j
	tv = {
		id = idTemplarsVerdict,
		GetCD = function()
			if (s1 ~= idTemplarsVerdict) and (((s_debuff_Sanctify < 1) and IsPlayerSpell(idSanctify) and (s_buff_ds > 1)) or (((s_debuff_Sanctify > 1) and IsPlayerSpell(idSanctify)) or (not(IsPlayerSpell(idSanctify))))) and ((IsPlayerSpell(idVanguard) and (s_hp > 3)) or ((not(IsPlayerSpell(idVanguard))) and (s_hp > 2))) then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if IsPlayerSpell(idVanguard) then
					s_hp = min(4, s_hp - 4)
				else
					s_hp = min(3, s_hp - 3)
				end

		end,
		info = "Templar's Verdict",
	},

	--Templar's Verdic 5 HoPo
	tv5 = {
		id = idTemplarsVerdict,
		GetCD = function()
			if (s1 ~= idTemplarsVerdict) and (s_hp > 4) then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

				if IsPlayerSpell(idVanguard) then
					s_hp = min(4, s_hp - 4)
				else
					s_hp = min(3, s_hp - 3)
				end

		end,
		info = "Templar's Verdict at 5 Holy Power",
	},

	--Templar's Verdict w/ Empyrean Legacy proc
	tv_ds = {
		id = idTemplarsVerdict,
		GetCD = function()
			if (s1 ~= idTemplarsVerdict) and ((IsPlayerSpell(idVanguard) and (s_hp > 3)) or ((not(IsPlayerSpell(idVanguard))) and (s_hp > 2))) and (s_buff_ds > 1) then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(3, s_hp - 3)
		end,
		info = "Templar's Verdict with Empyrean Legacy Proc",
	},

	-- ----------------------------------
	-- Talents (Execution Sentence, etc)
	-- ----------------------------------

	--Final Reckoning
	fr = {
		id = idFinalReckoning,
		GetCD = function()
			if (s1 ~= idFinalReckoning) and IsSpellKnownOrOverridesKnown(idFinalReckoning) and (((not(IsPlayerSpell(idDivineAuxiliary))) and (s_hp > 2)) or (IsPlayerSpell(idDivineAuxiliary) and (s_hp < 1))) and (GetCooldown(idFinalReckoning) < 3) then
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
	},

	--Execution Sentence 
	es = {
		id = idExecutionSentence,
		GetCD = function()
			if (s1 ~= idExecutionSentence) and IsUsableSpell(idExecutionSentence) and IsSpellKnownOrOverridesKnown(idExecutionSentence) and ((not(IsPlayerSpell(idDivineAuxiliary))) or (IsPlayerSpell(idDivineAuxiliary) and (s_hp < 5))) and (GetCooldown(idExecutionSentence) < 2) then
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
	},

	-- --------------------------------------------
	-- Divine Purpose Procs
	-- --------------------------------------------

	--Templar's Verdict with Divine Purpose
	tvdp = {
		id = idTemplarsVerdict,
		GetCD = function()
			if (s1 ~= idTemplarsVerdict) and (s_buff_DivinePurpose > 0) then
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

	--Divine Toll 
	dt = {
		id = idToll,
		GetCD = function()

			if (s1 ~= idToll) and IsPlayerSpell(idToll) then
				return GetCooldown(idToll)	
			end

			return 100 -- lazy stuff
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			--s_debuff_Judgment = 8
			
					s_hp = min(3, s_hp + 1)

		end,
		info = "Divine Toll",
	},

}

--------------------------------------------------------------------------------



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

local function GetBuff(buff)

	local left = 0
	local _, expires
	_, _, _, _, _, expires = APIWrapper.UnitBuff("player", buff, nil, "PLAYER")
	if expires then
		left = max(0, expires - s_ctime - s_gcd)
	end
	return left
end

local function GetDebuff(debuff)
	local left = 0
	local _, expires
	_, _, _, _, _, expires = APIWrapper.UnitDebuff("target", debuff, nil, "PLAYER")
	if expires then
		left = max(0, expires - s_ctime - s_gcd)
	end
	return left
end


-- reads all the interesting data // List of Buffs
local function GetStatus()
	-- current time
	s_ctime = GetTime()

	-- gcd value
	local start, duration = GetSpellCooldown(idGCD)
	s_gcd = start + duration - s_ctime
	if s_gcd < 0 then s_gcd = 0 end


	-- the buffs
	if (talent_DivinePurpose) then
		s_buff_DivinePurpose = GetBuff(ln_buff_DivinePurpose)
	else
		s_buff_DivinePurpose = 0
	end
	
	s_buff_aow = GetBuff(ln_buff_aow)
	s_buff_DivinePurpose = GetBuff(ln_buff_DivinePurpose)
	s_buff_ds2 = GetBuff(ln_buff_ds2)
	s_buff_aw = GetBuff(ln_buff_aw)
	s_buff_FinalVerdict = GetBuff(ln_buff_FinalVerdict)
	s_buff_ds = GetBuff(ln_buff_ds)
	s_buff_Crusade = GetBuff(ln_buff_Crusade)

	-- the debuffs
	s_debuff_Judgment = GetDebuff(ln_debuff_Judgment)
	s_debuff_ExecutionSentence = GetDebuff(ln_debuff_Exec)
	s_debuff_FinalReckoning = GetDebuff(ln_debuff_FinalReckoning)
	s_debuff_Sanctify = GetDebuff(ln_debuff_Sanctify)
	s_debuff_Expurgation = GetDebuff(ln_debuff_Expurgation)

	-------------------
	-- Spell Charges --
	-------------------
	
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
	
	-------------------------
	-- client hp and haste --
	-------------------------
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
			_, name, _, selected, available = GetTalentInfoByID(actions[v].reqTalent, GetActiveSpecGroup())
			if name and selected and available then
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

	-- adjust buffs
	s_buff_aow = max(0, s_buff_aow - s_otime)
	s_buff_DivinePurpose = max(0, s_buff_DivinePurpose - s_otime)	
	s_buff_ds2 = max(0, s_buff_ds2 - s_otime)
	s_buff_aw = max(0, s_buff_aw - s_otime)
	s_buff_FinalVerdict = max(0, s_buff_FinalVerdict - s_otime)
	s_buff_ds = max(0, s_buff_ds - s_otime)
	s_buff_Crusade = max(0, s_buff_Crusade - s_otime)

	-- the debuffs
	s_debuff_Judgment = max(0, s_debuff_Judgment - s_otime)
	s_debuff_ExecutionSentence = max(0, s_debuff_ExecutionSentence - s_otime)
	s_debuff_FinalReckoning = max(0, s_debuff_FinalReckoning - s_otime)
	s_debuff_Sanctify = max(0, s_debuff_Sanctify - s_otime)
	s_debuff_Expurgation = max(0, s_debuff_Expurgation - s_otime)

	-------------------
	-- Spell Charges --
	-------------------
	
	-- crusader strike stacks
	local cd, charges = GetCSData()
	s_CrusaderStrikeCharges = charges
	
	if (s1 == idCrusaderStrike) then
		s_CrusaderStrikeCharges = s_CrusaderStrikeCharges - 1

	end

	-- HoW Charges
	local cd, charges = GetHoWData()
	s_HoWCharges = charges
	
	if (s1 == idHoW) then
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
	sJudgmentCharges = charges
	
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
	-- local _, name, _, selected, available = GetTalentInfoByID(22215, GetActiveSpecGroup())
	-- if name and selected and available then
		-- talent_DivinePurpose = selected
	-- end
	
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
