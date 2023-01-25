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
	prio = "s5 tv5 fr how_aw tv woa ds s tvdp exo cons boj_aow j dt how boj cs2 cs",
	rangePerSkill = false,
	howclash = 0, -- priority time for hammer of wrath
	csclash = 0, -- priority time for cs
	exoclash = 0, -- priority time for exorcism
	ssduration = 0, -- minimum duration on ss buff before suggesting refresh
}

-- @defines
--------------------------------------------------------------------------------
local idGCD = 85256 -- tv for gcd

-- spells
local idTemplarsVerdict = 85256
local idCrusaderStrike = 35395
local idJudgement = 20271
local idConsecration = 26573
local idJusticarsVengeance = 215661
local idWakeOfAshes = 255937
local idExecutionSentence = 343527
local idHammerOfJustice = 853
local idDivineStorm = 53385
local idArcaneTorrent = 155145
local idHoW = 24275
local idSer = 152262
local idBladeOfJustice = 184575
local idDivineStorm = 53385
local idAvengingWrath = 31884
local idWord = 85673
local idFinal = 343721
local idHolyAvenger = 105809
local idJusticarsVengeance = 215661
local idExorcism = 383185
local idRadiantDecree = 383469

-- ------------------------
-- ---Covenant Abilities---
-- ------------------------
local idToll = 375576
local idTollOld = 304971

-- ------
-- buffs. Removed Lights Champion Buff (tier 1 DF set buff)
-- ------
local ln_buff_RighteousVerdict = GetSpellInfo(267611)
local ln_buff_TheFiresOfJustice = GetSpellInfo(209785)
local ln_buff_DivinePurpose = GetSpellInfo(223819)
local ln_buff_aow = GetSpellInfo(281178)
local ln_buff_ds2 = GetSpellInfo(326733)
local ln_buff_aw = GetSpellInfo(31884)
local ln_buff_Crusade = GetSpellInfo(231895)
local ln_buff_ha = GetSpellInfo(105809)
local ln_buff_FinalVerdict = GetSpellInfo(383329)
local ln_buff_Seraphim = GetSpellInfo(152262)
local ln_buff_SealedVerdict = GetSpellInfo(387643)
local ln_buff_Dawn = GetSpellInfo(385127)
local ln_buff_Dusk = GetSpellInfo(385126)
local ln_buff_Woa = GetSpellInfo(267344)
local ln_buff_CrusadersStrength = GetSpellInfo(394673)
local ln_buff_ds = GetSpellInfo(387178)

-- debuffs
local ln_debuff_Judgement = GetSpellInfo(197277)
local ln_debuff_Exec = GetSpellInfo(343527)
local ln_debuff_FinalReckoning50 = GetSpellInfo(343721)
local ln_debuff_FinalReckoning10 = GetSpellInfo(343724)
local ln_debuff_Sanctify = GetSpellInfo(382538)

-- status vars
local s1, s2
local s_ctime, s_otime, s_gcd, s_hp, s_dp, s_aw, s_ss, s_dc, s_fv, s_bc, s_haste, s_in_execute_range
local s_CrusaderStrikeCharges = 0
local s_HoWCharges = 0
local s_buff_DivinePurpose, s_buff_TheFiresOfJustice, s_buff_ds2, s_buff_aw, s_buff_ha, s_buff_FinalVerdict, s_buff_RighteousVerdict, s_buff_Seraphim, s_buff_SealedVerdict, s_buff_Dawn, s_buff_Dusk, s_buff_Woa, s_buff_CrusadersStrength, s_buff_ds, s_buff_Crusade
local s_debuff_Judgement, s_debuff_Exec, s_debuff_FinalReckoning50, s_debuff_FinalReckoning10, s_debuff_Sanctify

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


-- -------------------
-- /dump GetTalentInfo(row, column, 1)
-- s_hp = min(3, s_hp + 2) is telling the addon what hp you need to reach for tv
-- /dump UnitBuff("Player", 1)
-- /dump UnitDebuff("Target", 1)
-- IsSpellKnown(155145)
-- -------------------
-- code to check buff count (cons 2 set bonus as example)
--	cons_2p = {
--		id = idConsecration,
--		GetCD = function()
--		
--			name, _, count, _, duration, _, _, _, _, spellId, _, _, _, _, _ = APIWrapper.UnitBuff  ("player", ln_buff_CrusadersStrength)
--		
--			if (s1 ~= idConsecration) and (count == 2) and (IsSpellKnown(26573)) and (s_buff_CrusadersStrength > 1) then
--				return GetCooldown(idConsecration)
--
-- -------------------------------------------------------------------------------

-- actions ---------------------------------------------------------------------
local actions = {

	--Arcane Torrent
	arc = {
		id = idArcaneTorrent,
		GetCD = function()
			if ((s1 ~= idArcaneTorrent) and (s_hp <= 2) and (IsSpellKnown(155145))) then
				return GetCooldown(idArcaneTorrent)
			end
			return 100
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				if (s_buff_ha > 0) then
					s_hp = min(3, s_hp + 3)
				else
					s_hp = min(3, s_hp + 1)
				end
		end,
		info = "Arcane Torrent",
	},

	--Consecration
	cons = {
		id = idConsecration,
		GetCD = function()
			if (s1 ~= idConsecration) and (IsSpellKnown(26573)) and (not(IsUsableSpell(idTemplarsVerdict))) then
				return GetCooldown(idConsecration)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste

		end,
		info = "Consecration",
	},

	--Consecration DF 2set before they changed it on beta. Keep in code in case they bring back ability.
	-- cons_2p = {
		-- id = idConsecration,
		-- GetCD = function()
		
			-- name, _, count, _, duration, _, _, _, _, spellId, _, _, _, _, _ = APIWrapper.UnitBuff  ("player", ln_buff_CrusadersStrength)
		
			-- if (s1 ~= idConsecration) and (count == 2) and (IsSpellKnown(26573)) and (s_buff_CrusadersStrength > 1) then
				-- return GetCooldown(idConsecration)
			-- end
			-- return 100
		-- end,
		-- UpdateStatus = function()
			-- s_ctime = s_ctime + s_gcd + 1.5 / s_haste

		-- end,
		-- info = "Consecration w/ 2 Stacks of Crusader's Strength (2 Set)",
	-- },

	--exorcism dont worry about dot, exo cd longer then dot
	exo = {
		id = idExorcism,
		GetCD = function()
			if (s1 ~= idExorcism) and (IsSpellKnown(383185)) and (not(IsUsableSpell(idTemplarsVerdict))) then
				return GetCooldown(idExorcism)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste

		end,
		info = "Exorcism",
	},


	-- ----------------------------------
	-- Holy Power Generators
	-- ----------------------------------
	
	-- Wake of Ashes
	-- IsSpellKnownOrOverridesKnown(255937) will check for Wake of Ashes or any spell that replaces it.

	-- For Radiant Decree Talent;
	-- IsSpellKnownOrOverridesKnown(383469) is to check if radiant decree is talented
	-- IsUsableSpell(383469) wont return true unless theres holy power, use this to check for enough holy power for RD
	-- IsPlayerSpell(384052) will check if the player knows the talent. 383469 will not return true, even if they know the talent
	woa = {
		id = idWakeOfAshes,
		GetCD = function()
			costs = GetSpellPowerCost(255937)
			if (s1 ~= idWakeOfAshes) and IsSpellKnownOrOverridesKnown(255937) and ((s_hp <= 1) and (IsUsableSpell(255937))) or ((IsUsableSpell(383469) and IsPlayerSpell(384052)) and (GetCooldown(idRadiantDecree) < 1) and (((s_hp > 2) or (s_buff_DivinePurpose > 1)) or ((s_hp > 1) and (s_buff_TheFiresOfJustice > 0)))) then
				if IsSpellKnownOrOverridesKnown(383469) then
					return GetCooldown(idRadiantDecree)
				else
					return GetCooldown(idWakeOfAshes)
				end	
			end
			return 100
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				if IsSpellKnownOrOverridesKnown(383469) then
					s_hp = max(3, s_hp - 3)
				else
					s_hp = min(3, s_hp + 3)
				end
		end,
		info = "Wake Of Ashes",
	},

	--Radiant decree
	rd = {
		id = idRadiantDecree,
		GetCD = function()
			if (IsUsableSpell(383469) and IsPlayerSpell(384052) and IsSpellKnownOrOverridesKnown(383469)) and ((((s_debuff_Sanctify < 1) and IsPlayerSpell(382536) and (s_buff_ds > 1)) or (((s_debuff_Sanctify > 1) and IsPlayerSpell(382536)) or (not(IsPlayerSpell(382536))))) and (IsSpellKnown(385125) and (((s_buff_Dawn < 2) and (s_hp > 4)) or ((s_buff_Dawn > 1) and (s_hp > 2) or ((s_hp > 1) and (s_buff_TheFiresOfJustice > 0)) or (s_buff_DivinePurpose > 0)))) or ((not(IsSpellKnown(385125))) and ((s_hp > 2) or ((s_hp > 1) and (s_buff_TheFiresOfJustice > 0)) or (s_buff_DivinePurpose > 0)))) then
				return GetCooldown(idRadiantDecree)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(3, s_hp - 3)
		end,
		info = "Radiant Decree (Talent)",
	},

	--Wake of Ashes
	-- woa_4p = {
		-- id = idWakeOfAshes,
		-- GetCD = function()
			-- if ((s1 ~= idWakeOfAshes) and (s_buff_Woa > 0)) and (IsSpellKnown(255937)) then
				-- return GetCooldown(idWakeOfAshes)
			-- end
			-- return 100
		-- end,
			-- UpdateStatus = function()
			-- s_ctime = s_ctime + s_gcd + 1.5
				-- if (s_buff_ha > 0) then
					-- s_hp = max(5, s_hp + 5)
				-- else
					-- s_hp = min(3, s_hp + 3)
				-- end
		-- end,
		-- info = "Wake Of Ashes w/ Art of War (Ashes to Dust Talent)",
	-- },

	--Wake of Ashes
	w1m= {
		id = idWakeOfAshes,
		GetCD = function()
			if ((s1 ~= idWakeOfAshes) and (s_hp <= 1)) and (IsSpellKnown(255937)) and ((((IsSpellKnown(343527)) and (GetCooldown(idExecutionSentence) < 5)) or ((IsSpellKnown(343721)) and (GetCooldown(idFinal) < 5)) or ((IsSpellKnown(343527)) and (IsSpellKnown(343721)) and (GetCooldown(idFinal) < 5) and (GetCooldown(idExecutionSentence) < 5))) or ((not(IsSpellKnown(343527))) and (not(IsSpellKnown(343721))))) then
				return GetCooldown(idWakeOfAshes)
			end
			return 100
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				if (s_buff_ha > 0) then
					s_hp = max(5, s_hp + 5)
				else
					s_hp = min(3, s_hp + 3)
				end
		end,
		info = "Wake Of Ashes for 1 min build",
	},

	--Judgment
	j = {
		id = idJudgement,
		GetCD = function()
			if s1 ~= idJudgement and (IsSpellKnown(20271)) and (s_debuff_Judgement < 2) then
				return GetCooldown(idJudgement)
			end
			return 100 -- lazy stuff
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_debuff_Judgement = 8
				if (s_buff_ha > 0) then
					s_hp = min(3, s_hp + 3)
				else
					s_hp = min(3, s_hp + 1)
				end
		end,
		info = "Judgement",
	},

	--Crusader Strike @ 2 charges
	cs2 = {
		id = idCrusaderStrike,
		GetCD = function()
			if (s_CrusaderStrikeCharges == 2) and (s_hp < 3) and (not(IsUsableSpell(idTemplarsVerdict))) then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			if (s_buff_ha > 0) then
				s_hp = max(3, s_hp + 3)
			else
				s_hp = max(3, s_hp + 1)
			s_CrusaderStrikeCharges = max(0, s_CrusaderStrikeCharges - 1)
			end
		end,
		info = "Crusader Strike stacks = 2",
	},
	
	--Crusader Strike
	cs = {
		id = idCrusaderStrike,
		GetCD = function()
			local cd, charges = GetCSData()
			if (s_CrusaderStrikeCharges == 1) and (s_hp < 3) and (not(IsUsableSpell(idTemplarsVerdict))) then
				return 0
			end
			return cd + 0.5
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			if (s_buff_ha > 0) then
				s_hp = min(3, s_hp + 3)
			else
				s_hp = min(3, s_hp + 1)
			s_CrusaderStrikeCharges = max(0, s_CrusaderStrikeCharges - 1)
			end
		end,
		info = "Crusader Strike",
	},

	--Hammer of Wrath
	how = {
		id = idHoW,
		GetCD = function()
		local cd, charges = GetHoWData()
			if ((s_HoWCharges == 1) or (s_HoWCharges == 2)) and IsUsableSpell(idHoW) and (IsSpellKnown(24275)) and (not(IsUsableSpell(idTemplarsVerdict))) then
				return GetCooldown(idHoW)
			end
			return 100
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				if (s_buff_ha > 0) then
					s_hp = min(3, s_hp + 3)
				else
					s_hp = min(3, s_hp + 1)
			s_HoWCharges = max(0, s_HoWCharges - 1)
				end
		end,
		info = "Hammer of Wrath",
	},

	--Hammer of Wrath w/ Avenging Wrath
	how_aw = {
		id = idHoW,
		GetCD = function()
			if (s1 ~= idHoW) and IsUsableSpell(idHoW) and (((s_buff_aw > 1) or (s_buff_Crusade > 1)) or (s_buff_FinalVerdict > 1)) and (IsSpellKnown(24275)) then
				return GetCooldown(idHoW)
			end
			return 100
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				if (s_buff_ha > 0) then
					s_hp = min(3, s_hp + 3)
				else
					s_hp = min(3, s_hp + 1)
				end
		end,
		info = "Hammer of Wrath during Avenging Wrath",
	},

	--Blade of Justice
	boj = {
		id = idBladeOfJustice,
		GetCD = function()
			-- check if dawn buff is about to expire so we can build to 5 hp if needed
			if (s1 ~= idBladeOfJustice) and (IsSpellKnown(184575)) and (((IsSpellKnown(385125) and (s_buff_Dawn < 1) and (s_hp < 5) and (not(IsUsableSpell(idTemplarsVerdict)))) or (IsSpellKnown(385125) and (s_buff_Dawn > 1) and (s_hp < 2) and (not(IsUsableSpell(idTemplarsVerdict))))) or ((not(IsSpellKnown(385125))) and (s_hp <= 3) and (not(IsUsableSpell(idTemplarsVerdict))))) then
				return GetCooldown(idBladeOfJustice)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			if (s_buff_ha > 0) then
				s_hp = min(3, s_hp + 4)
			else
				s_hp = min(3, s_hp + 2)
			end
		end,
		info = "Blade of Justice",
	},

	--Blade of Justice w/ Art of War proc
	boj_aow = {
		id = idBladeOfJustice,
		GetCD = function()
				-- check if dawn buff is about to expire so we can build to 5 hp if needed
			if (s1 ~= idBladeOfJustice) and (IsSpellKnown(184575)) and ((s_buff_aow > 2) or (s_buff_SealedVerdict > 1)) and (((IsSpellKnown(385125) and (s_buff_Dawn < 1) and (s_hp < 5) and (not(IsUsableSpell(idTemplarsVerdict)))) or (IsSpellKnown(385125) and (s_buff_Dawn > 1) and (s_hp < 2) and (not(IsUsableSpell(idTemplarsVerdict))))) or ((not(IsSpellKnown(385125))) and (s_hp <= 3) and (not(IsUsableSpell(idTemplarsVerdict))))) then
				return GetCooldown(idBladeOfJustice)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			if (s_buff_ha > 0) then
				s_hp = min(3, s_hp + 4)
			else
				s_hp = min(3, s_hp + 2)
			end
		end,
		info = "Blade of Justice w/ Art of War OR Sealed Verdict Proc",
	},

	-- ----------------------------------
    -- Boj with vault 4 set bonus
    -- ----------------------------------
 
 	-- Blade of Justice vault 4 set buff
	-- boj_4p = {
		-- id = idBladeOfJustice,
		-- GetCD = function()
			-- check if dawn buff is about to expire so we can build to 5 hp if needed
			-- if (s1 ~= idBladeOfJustice) and (s_buff_LightChampion > 0) and (IsSpellKnown(184575)) and (((IsSpellKnown(385125) and (s_buff_Dawn < 1) and (s_hp < 5) and (not(IsUsableSpell(idTemplarsVerdict)))) or (IsSpellKnown(385125) and (s_buff_Dawn > 1) and (s_hp < 2) and (not(IsUsableSpell(idTemplarsVerdict))))) or ((not(IsSpellKnown(385125))) and (s_hp <= 3) and (not(IsUsableSpell(idTemplarsVerdict))))) then
				-- return GetCooldown(idBladeOfJustice)
			-- end
			-- return 100
		-- end,
		-- UpdateStatus = function()
			-- s_ctime = s_ctime + s_gcd + 1.5
			-- if (s_buff_ha > 0) then
				-- s_hp = min(3, s_hp + 4)
			-- else
				-- s_hp = min(3, s_hp + 2)
			-- end
		-- end,
		-- info = "Blade of Justice w/ Light's Champion (4 set) Buff",
	-- },

 
	-- ----------------------------------
	-- Holy Power Consumers
	-- ----------------------------------

	--Divine Storm Proc
	ds = {
		id = idDivineStorm,
		GetCD = function()
			if (s_buff_ds2 > 1) then
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
			if ((s_hp > 2) or ((s_hp > 1) and (s_buff_TheFiresOfJustice > 0)) or (s_buff_DivinePurpose > 0)) and (not(s_debuff_Sanctify > 1)) and (IsPlayerSpell(382536)) and (s_buff_ds < 1) then
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

	--Templar's Verdict dynamic no j, Will detect Dusk and Dawn, Smart Templar's Verdict (Will detect buffs and Holy Power Costs), Removed Smart description to reduce confusion for DF launch
	tv = {
		id = idTemplarsVerdict,
		GetCD = function()
			if (((s_debuff_Sanctify < 1) and IsPlayerSpell(382536) and (s_buff_ds > 1)) or (((s_debuff_Sanctify > 1) and IsPlayerSpell(382536)) or (not(IsPlayerSpell(382536))))) and ((IsSpellKnown(385125)) and (((s_buff_Dawn < 2) and (s_hp > 4)) or ((s_buff_Dawn > 1) and (s_hp > 2) or ((s_hp > 1) and (s_buff_TheFiresOfJustice > 0)) or (s_buff_DivinePurpose > 0)))) or ((not(IsSpellKnown(385125))) and ((s_hp > 2) or ((s_hp > 1) and (s_buff_TheFiresOfJustice > 0)) or (s_buff_DivinePurpose > 0))) then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(3, s_hp - 3)
		end,
		info = "Templar's Verdict. Will Detect Dusk n Dawn Talents.",
	},

	--Templar's Verdict dynamic 5 HoPo, cast at 5 no matter what, dont need smart string
	tv5 = {
		id = idTemplarsVerdict,
		GetCD = function()
			if (s_hp > 4) then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(5, s_hp - 3)
		end,
		info = "Templar's Verdict at 5 Holy Power",
	},

-- ---
	--jv
--	jv = {
--		id = idJusticarsVengeance,
--		GetCD = function()
--			if (s_hp > 2) or ((s_hp > 1) and (s_buff_TheFiresOfJustice > 0)) or (s_buff_DivinePurpose > 0) then
--				return 0
--			end
--			return 100
--		end,
--		UpdateStatus = function()
--			s_ctime = s_ctime + s_gcd + 1.5
--				s_hp = max(5, s_hp - 3)
--		end,
--		info = "Justicars Vengeance",
--	},

-- ------

	-- ----------------------------------
	-- Talents (Execution Sentence, etc)
	-- ----------------------------------

	--Final Reckoning
	fr = {
		id = idFinal,
		GetCD = function()
			if (s1 ~= idFinal) and IsSpellKnown(343721) and (s_hp > 2) and (((IsSpellKnown(343527)) and (GetCooldown(idExecutionSentence) < 5)) or ((not(IsSpellKnown(343527))) and (GetCooldown(idFinal) < 5))) then
				return GetCooldown(idFinal)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste

		end,
		info = "Final Reckoning",
	},

	--Execution Sentence 
	es = {
		id = idExecutionSentence,
		GetCD = function()
			if ((IsSpellKnown(385125)) and (((s_buff_Dawn < 2) and (s_hp > 4)) or ((s_buff_Dawn > 1) and (s_hp > 2) or ((s_hp > 1) and (s_buff_TheFiresOfJustice > 0)) or (s_buff_DivinePurpose > 0)))) or ((not(IsSpellKnown(385125))) and ((s_hp > 2) or ((s_hp > 1) and (s_buff_TheFiresOfJustice > 0)) or (s_buff_DivinePurpose > 0))) and (IsUsableSpell(idExecutionSentence) and (IsSpellKnown(343527))) then
				return GetCooldown(idExecutionSentence)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = min(3, s_hp - 3)

		end,
		info = "Execution Sentence",
	},

	--Execution Sentence 5 hopo
	es5 = {
		id = idExecutionSentence,
		GetCD = function()
			if (s_hp > 4) and IsUsableSpell(idExecutionSentence) and (IsSpellKnown(343527)) then
				return GetCooldown(idExecutionSentence)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = min(3, s_hp - 3)

		end,
		info = "Execution Sentence",
	},

	--Holy Avenger
	ha = {
		id = idHolyAvenger,
		GetCD = function()
			if s1 ~= idHolyAvenger then
				return GetCooldown(idHolyAvenger)
			end
			return 100
	
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5 / s_haste
		end,
		info = "Holy Avenger",
		},


	-- -------------------------------
	-- Holy Power Consumers (Buffs)
	-- -------------------------------

	--Seraphim
	s = {
		id = idSer,
		GetCD = function()
			if (((IsSpellKnown(385125)) and (((s_buff_Dawn < 2) and (s_hp > 4)) or ((s_buff_Dawn > 1) and (s_hp > 2) or ((s_hp > 1) and (s_buff_TheFiresOfJustice > 0)) or (s_buff_DivinePurpose > 0)))) or ((not(IsSpellKnown(385125))) and ((s_hp > 2) or ((s_hp > 1) and (s_buff_TheFiresOfJustice > 0)) or (s_buff_DivinePurpose > 0)))) and ((IsUsableSpell(idSer)) and (IsSpellKnown(152262))) then
				return GetCooldown(idSer)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(3, s_hp - 3)
		end,
		info = "Seraphim",
	},

	--Smart Seraphim
	s1m = {
		id = idSer,
		GetCD = function()
			if ((s_hp >= 3) or ((s_hp >= 2) and (s_buff_TheFiresOfJustice > 0)) or (s_buff_DivinePurpose > 0)) and ((((IsSpellKnown(343527)) and (GetCooldown(idExecutionSentence) < 5)) or ((IsSpellKnown(343721)) and (GetCooldown(idFinal) < 5)) or ((IsSpellKnown(343527)) and (IsSpellKnown(343721)) and (GetCooldown(idFinal) < 5) and (GetCooldown(idExecutionSentence) < 5))) or ((not(IsSpellKnown(343527))) and (not(IsSpellKnown(343721))))) and ((IsUsableSpell(idSer)) and (IsSpellKnown(152262))) then
				return GetCooldown(idSer)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(3, s_hp - 3)
		end,
		info = "Seraphim for 1m Build (Tries to Sync Seraphim w/ other 1m CDs)",

	},

	--Seraphim w/5 HoPo, removed boss target level which was included for unknown reasons
	s5 = {
		id = idSer,
		GetCD = function()
			if (s_hp >= 5) and (IsUsableSpell(idSer)) and (IsSpellKnown(152262)) then
				return GetCooldown(idSer)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(5, s_hp - 3)
		end,
		info = "Seraphim at 5 Holy Power",

	},
	
	--Seraphim dusk n dawn
	-- s_dnd = {
		-- id = idSer,
		-- GetCD = function()
			-- if (IsUsableSpell(idSer)) and (IsSpellKnown(152262)) and ((s_buff_Dawn < 2) and (s_hp > 4)) or ((s_buff_Dawn > 1) and (s_hp > 2) or ((s_hp > 1) and (s_buff_TheFiresOfJustice > 0)) or (s_buff_DivinePurpose > 0)) then
				-- return GetCooldown(idSer)
			-- end
			-- return 100
		-- end,
		-- UpdateStatus = function()
			-- s_ctime = s_ctime + s_gcd + 1.5
				-- s_hp = max(3, s_hp - 3)
		-- end,
		-- info = "Seraphim",
	-- },

	-- --------------------------------------------
	-- Divine Purpose Procs
	-- --------------------------------------------

	--Templar's Verdict with Divine Purpose
	tvdp = {
		id = idTemplarsVerdict,
		GetCD = function()
			if (s_buff_DivinePurpose > 0) then
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

			if (s1 ~= idToll) and not(IsPlayerSpell(375576)) and IsUsableSpell(304971) then
				return GetCooldown(idTollOld)	
			end

			if (s1 ~= idToll) and IsPlayerSpell(375576) then
				return GetCooldown(idToll)	
			end

			return 100 -- lazy stuff
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			--s_debuff_Judgement = 8
				if (s_buff_ha > 0) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end
		end,
		info = "Divine Toll",
	},

	--Divine Toll 
	dt1m = {
		id = idToll,
		GetCD = function()
			if (s1 ~= idToll) and (s_buff_Seraphim > 1) and (IsUsableSpell(375576)) then
				return GetCooldown(idToll)
			end
			return 100 -- lazy stuff
		end,
			UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			--s_debuff_Judgement = 8
				if (s_buff_ha > 0) then
					s_hp = min(3, s_hp + 2)
				else
					s_hp = min(3, s_hp + 1)
				end
		end,
		info = "Divine Toll for 1 min build. (Tries to sync DT w/ other 1m CDs)",
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
	s_buff_TheFiresOfJustice = GetBuff(ln_buff_TheFiresOfJustice)
	s_buff_DivinePurpose = GetBuff(ln_buff_DivinePurpose)
	s_buff_aow = GetBuff(ln_buff_aow)
	s_buff_ds2 = GetBuff(ln_buff_ds2)
	s_buff_aw = GetBuff(ln_buff_aw)
	s_buff_ha = GetBuff(ln_buff_ha)
	s_buff_FinalVerdict = GetBuff(ln_buff_FinalVerdict)
	s_buff_RighteousVerdict = GetBuff(ln_buff_RighteousVerdict)
	s_buff_Seraphim = GetBuff(ln_buff_Seraphim)
	s_buff_SealedVerdict = GetBuff(ln_buff_SealedVerdict)
	s_buff_Dawn = GetBuff(ln_buff_Dawn)
	s_buff_Dusk = GetBuff(ln_buff_Dusk)
	s_buff_Woa = GetBuff(ln_buff_Woa)
	s_buff_CrusadersStrength = GetBuff(ln_buff_CrusadersStrength)
	s_buff_ds = GetBuff(ln_buff_ds)
	s_buff_Crusade = GetBuff(ln_buff_Crusade)

	-- the debuffs
	s_debuff_Judgement = GetDebuff(ln_debuff_Judgement)
	s_debuff_Exec = GetDebuff(ln_debuff_Exec)
	s_debuff_FinalReckoning50 = GetDebuff(ln_debuff_FinalReckoning50)
	s_debuff_FinalReckoning10 = GetDebuff(ln_debuff_FinalReckoning10)
	s_debuff_Sanctify = GetDebuff(ln_debuff_Sanctify)

	-- crusader strike stacks
	local cd, charges = GetCSData()
	s_CrusaderStrikeCharges = charges

	-- HoW stacks
	local cd, charges = GetHoWData()
	s_HoWCharges = charges

	-- client hp and haste
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

		debug:AddBoth("dJudgement", s_debuff_Judgement)
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
	s_buff_RighteousVerdict = max(0, s_buff_RighteousVerdict - s_otime)
	s_buff_TheFiresOfJustice = max(0, s_buff_TheFiresOfJustice - s_otime)
	s_buff_DivinePurpose = max(0, s_buff_DivinePurpose - s_otime)	
	s_buff_ds2 = max(0, s_buff_ds2 - s_otime)
	s_buff_aw = max(0, s_buff_aw - s_otime)
	s_buff_ha = max(0, s_buff_ha - s_otime)
	s_buff_FinalVerdict = max(0, s_buff_FinalVerdict - s_otime)
	s_buff_Seraphim = max(0, s_buff_Seraphim - s_otime)
	s_buff_SealedVerdict = max(0, s_buff_SealedVerdict - s_otime)
	s_buff_Dawn = max(0, s_buff_Dawn - s_otime)
	s_buff_Dusk = max(0, s_buff_Dusk - s_otime)
	s_buff_Woa = max(0, s_buff_Woa - s_otime)
	s_buff_CrusadersStrength = max(0, s_buff_CrusadersStrength - s_otime)	
	s_buff_ds = max(0, s_buff_ds - s_otime)
	s_buff_Crusade = max(0, s_buff_Crusade - s_otime)

	-- the debuffs
	s_debuff_Judgement = max(0, s_debuff_Judgement - s_otime)
	s_debuff_Exec = max(0, s_debuff_Exec - s_otime)
	s_debuff_FinalReckoning10 = max(0, s_debuff_FinalReckoning10 - s_otime)
	s_debuff_FinalReckoning50 = max(0, s_debuff_FinalReckoning50 - s_otime)
	s_debuff_Sanctify = max(0, s_debuff_Sanctify - s_otime)

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


	if debug and debug.enabled then
		debug:AddBoth("csc", s_CrusaderStrikeCharges)
	end

	if debug and debug.enabled then
		debug:AddBoth("ctime", s_ctime)
		debug:AddBoth("otime", s_otime)
		debug:AddBoth("gcd", s_gcd)
		debug:AddBoth("hp", s_hp)
		debug:AddBoth("haste", s_haste)
		debug:AddBoth("dJudgement", s_debuff_Judgement)
		debug:AddBoth("bDivinePurpose", s_buff_DivinePurpose)
		debug:AddBoth("bTFOJ", s_buff_TheFiresOfJustice)
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
	local _, name, _, selected, available = GetTalentInfoByID(22215, GetActiveSpecGroup())
	if name and selected and available then
		talent_DivinePurpose = selected
	end




end
ef:SetScript("OnEvent", OnEvent)
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("PLAYER_TALENT_UPDATE")
ef:RegisterEvent("PLAYER_LEVEL_UP")