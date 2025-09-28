-- don't load if class is wrong
local _, class = UnitClass("player")
if class ~= "DEATHKNIGHT" then return end

local _, xmod = ...

xmod.frostdeathknightmodule = {}
xmod = xmod.frostdeathknightmodule

local qTaint = true -- will force queue check

-- 
local GetTime, GetSpellCooldown, UnitBuff, UnitAura, UnitPower, UnitSpellHaste, UnitHealth, UnitHealthMax, GetActiveSpecGroup, GetTalentInfoByID, GetGlyphSocketInfo, IsUsableSpell, GetShapeshiftForm, max, min =
GetTime, GetSpellCooldown, UnitBuff, UnitAura, UnitPower, UnitSpellHaste, UnitHealth, UnitHealthMax, GetActiveSpecGroup, GetTalentInfoByID, GetGlyphSocketInfo, IsUsableSpell, GetShapeshiftForm, max, min
local db


xmod.version = 9000001
xmod.defaults = {
	version = xmod.version,
	frostdkprio = "sac rd bos emp ff pof rm ob_ex sr_ros rw hb ob_ia fb ob_km2 hb_r sr fs ob_km ob bag",
	rangeCheckSkill = "_rangeoff",
	bossMode = false,
	deathCoilMode = false,
	pofMode = false,
	
}

-- @defines
--------------------------------------------------------------------------------
local idGCD = 47541 -- death coil for gcd

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

-- racials
local idArcaneTorrent = 50613
local idBagOfTricks = 312411

-- spells

local idEmpowerRuneWeapon = 47568
local idDeathCoil = 47541
local idDeathStrike = 49998
local idBreathOfSindragosa = 1249658
local idReapersMark = 439843
local idSoulReaper = 343294
local idObliterate = 49020
local idSacrificialPact = 327574

local idDeathAndDecay = 43265
local idHowlingBlast = 49184
local idFrostStrike = 49143

-- talents
local idFrostbane = 1228433
local idFrostwyrmsFury = 279302
local idPillarOfFrost = 51271
local idRemorselessWinter = 196770
local idRaiseDead = 46585
local idFrozenDominion = 377226 -- checks for actual talent

-- AOE mode spells
local idFrostscythe = 207230
local idGlacialAdvance = 194913

-- buffs
local idRime = 59052
local idKillingMachine = 51124
local idInexorableAssault = 253595
local idIcyOnslaught = 1230273

local idReaperOfSouls = 469172
local idExterminate = 441416

-- debuffs
local idFrostFever = 55095
local idSoulReaper = 343294
local idFrostreaper = 1233351

-- status vars
local s1, s2
local s_ctime, s_otime, s_gcd, s_hp, s_dp, s_aw, s_ss, s_dc, s_fv, s_bc, s_haste, s_in_execute_range

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
	
	-- Death coil if no other spell is in range
	dc = {
		id = idDeathCoil,
		GetCD = function()
			if (s1 ~= idDeathCoil) and (s_rp > 30) then
				return GetCooldown(idDeathCoil)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Death Coil at ranged distance",
	},

	-- Death strike
	ds = {
		id = idDeathStrike,
		GetCD = function()
			if (s1 ~= idDeathStrike) and s_rp > 34 then
				return GetCooldown(idDeathStrike)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Death Strike",
	},

}

-- actions ---------------------------------------------------------------------
local actions = {
		
	--Arcane Torrent
	arc = {
		id = idArcane,
		GetCD = function()
			if (s1 ~= idArcane) and (IsSpellKnown(155145)) then
				return GetCooldown(idArcane)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Arcane Torrent",
	},

	-- Bag o tricks
	bag = {
		id = idBagOfTricks,
		GetCD = function()
			if (s1 ~= idBagOfTricks) and (IsSpellKnown(312411))then
				return GetCooldown(idBagOfTricks)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Bag Of Tricks",
	},

	-- --------------------------------------

	-- emp rune wep with sub 90 runic power
	emp = {
		id = idEmpowerRuneWeapon,
		GetCD = function()
			if (s1 ~= idEmpowerRuneWeapon) and C_SpellBook.IsSpellInSpellBook(idEmpowerRuneWeapon) then
				return GetCooldown(idEmpowerRuneWeapon)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Empower Rune Weapon",
	},

	-- Raise Dead
	rd = {
		id = idRaiseDead,
		GetCD = function()
		
			level = UnitLevel("target")
			bossModeCheck = (db.bossMode and (level < 0)) or not(db.bossMode)

			if (s1 ~= idRaiseDead) and bossModeCheck and C_SpellBook.IsSpellInSpellBook(idRaiseDead) then
				return GetCooldown(idRaiseDead)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Raise Dead",
	},

	-- Sacrificial Pact
	sac = {
		id = idSacrificialPact,
		GetCD = function()
		
			seconds = GetTotemTimeLeft(1)
			
			if (s1 ~= idSacrificialPact) and (s_rp > 20) and (GetCooldown(idRaiseDead) > 60) and (seconds > 1) and (seconds < 5) and C_SpellBook.IsSpellInSpellBook(idSacrificialPact) then
				return GetCooldown(idSacrificialPact)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Sacririficial Pact with < 5 seconds remaining",
	},

	-- pillar of frost
	pof = {
		id = idPillarOfFrost,
		GetCD = function()

			if (s1 ~= idPillarOfFrost) and C_SpellBook.IsSpellInSpellBook(idPillarOfFrost) then
				return GetCooldown(idPillarOfFrost)
			end
			
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Pillar Of Frost",
	},

	-- remorseless winter
	rw = {
		id = idRemorselessWinter,
		GetCD = function()
		
			rwCheck = C_SpellBook.IsSpellKnown(idRemorselessWinter) and not C_SpellBook.IsSpellKnown(idFrozenDominion)
		
			if (s1 ~= idRemorselessWinter) and rwCheck then
				return GetCooldown(idRemorselessWinter)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Remorseless Winter",
	},

	-- dnd
	dnd = {
		id = idDeathAndDecay,
		GetCD = function()
			if (s1 ~= idDeathAndDecay) and (s_rune >= 1) then
				return GetCooldown(idDeathAndDecay)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Death and Decay",
	},

	-- frostwyrms fury
	ff = {
		id = idFrostwyrmsFury,
		GetCD = function()
			
			level = UnitLevel("target")
			bossModeCheck = (db.bossMode and (level < 0)) or not(db.bossMode)
			
			if (s1 ~= idFrostwyrmsFury) and bossModeCheck and C_SpellBook.IsSpellInSpellBook(279302) then
				return GetCooldown(idFrostwyrmsFury)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Frostwyrm's Fury (Boss Fights)",
	},

	-- howling blast
	hb = {
		id = idHowlingBlast,
		GetCD = function()
			if (s_rune >= 1) and (s1 ~= idHowlingBlast) and not s_debuff_FrostFever and C_SpellBook.IsSpellInSpellBook(idHowlingBlast) then
				return 0
			end
			
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Howling Blast to apply Frost Fever",
	},

	-- howling blast w/rime proc
	hb_r = {
		id = idHowlingBlast,
		GetCD = function()
			if (s1 ~= idHowlingBlast) and s_buff_Rime and C_SpellBook.IsSpellInSpellBook(idHowlingBlast) then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Howling Blast w/ Rime proc",
	},
	
	-- frostbane
	fb = {
		id = idFrostbane,
		GetCD = function()
		
			if s_buff_IcyOnslaught then 
				icyOnslaughtStacks = s_buff_IcyOnslaught.applications
			else
				icyOnslaughtStacks = 0
			end
			
			fsVariableCost = ((icyOnslaughtStacks * 5) + 35)
			
			if (s1 ~= idFrostbane) and ((s_rp > 35) or (s_buff_IcyOnslaught and (s_rp > fsVariableCost))) and C_SpellBook.IsSpellInSpellBook(idFrostbane) then
				return 0
			end

			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Frostbane",
	},
	
	-- frost strike
	fs = {
		id = idFrostStrike,
		GetCD = function()
		
			if s_buff_IcyOnslaught then 
				icyOnslaughtStacks = s_buff_IcyOnslaught.applications
			else
				icyOnslaughtStacks = 0
			end
			
			fsVariableCost = ((icyOnslaughtStacks * 5) + 35)
			
			if (s1 ~= idFrostStrike) and ((s_rp > 35) or (s_buff_IcyOnslaught and (s_rp > fsVariableCost))) then
				return 0
			end

			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Frost Strike",
	},
	
	-- frost strike with frost reaper debuff
	fs_fr = {
		id = idFrostStrike,
		GetCD = function()
			if (s1 ~= idFrostStrike) and (s_rp > 35) and s_debuff_Frostreaper then
				return 0
			end

			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Frost Strike w/Frostreaper on target",
	},

	-- obliterate
	ob = {
		id = idObliterate,
		GetCD = function()
		
			if (s1 ~= idObliterate) and (s_rune > 2) and C_SpellBook.IsSpellInSpellBook(idObliterate) then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Obliterate",
	},
	
	-- obliterate w/ killing machine
	ob_km = {
		id = idObliterate,
		GetCD = function()
			
			local reaperCD = C_Spell.GetSpellCooldown(idReapersMark)
			local ReapersMarkCD = reaperCD.duration
			local variantCheckDeath = C_SpellBook.IsSpellInSpellBook(idReapersMark) and ReapersMarkCD > 3
			local variantCheckNotDeath = not C_SpellBook.IsSpellInSpellBook(idReapersMark)
			local variantCheckOb = ((db.pofMode and variantCheckDeath and s_buff_PillarOfFrost) or not(db.pofMode))
			
			local wtf1 = (db.pofMode and variantCheckDeath and s_buff_PillarOfFrost) or (not(db.pofMode) and variantCheckDeath)
			local wtf2 = (db.pofMode and variantCheckDeath and s_buff_PillarOfFrost) or (not(db.pofMode) and variantCheckNotDeath)
			local wtf3 = (db.pofMode and variantCheckNotDeath and s_buff_PillarOfFrost) or (not(db.pofMode) and variantCheckDeath) 
			local wtf4 = (db.pofMode and variantCheckNotDeath and s_buff_PillarOfFrost) or (not(db.pofMode) and variantCheckNotDeath)
			
			local variationsWTF = wtf1 or wtf2 or wtf3 or wtf4
		
			if (s1 ~= idObliterate) and C_SpellBook.IsSpellInSpellBook(idObliterate) and (s_rune > 1) and s_buff_KillingMachine and variationsWTF then
				return 0
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Obliterate w/Killing Machine",
	},

	-- obliterate w/2 killing machine
	ob_km2 = {
		id = idObliterate,
		GetCD = function()
			
			if s_buff_KillingMachine then 
				killingMachineStacks = s_buff_KillingMachine.applications
			else
				killingMachineStacks = 0
			end
			
			local killingMachineCheck = (s_buff_KillingMachine and killingMachineStacks > 1) and (s_rune > 1)
			local killingMachineRunes = (s_buff_KillingMachine and killingMachineStacks == 1) and (s_rune > 2)
			
			local reaperCD = C_Spell.GetSpellCooldown(idReapersMark)
			local ReapersMarkCD = reaperCD.duration
			local variantCheckDeath = C_SpellBook.IsSpellInSpellBook(idReapersMark) and ReapersMarkCD > 3
			local variantCheckNotDeath = not C_SpellBook.IsSpellInSpellBook(idReapersMark)
			local variantCheckOb = ((db.pofMode and variantCheckDeath and s_buff_PillarOfFrost) or not(db.pofMode))
			
			local wtf1 = (db.pofMode and variantCheckDeath and s_buff_PillarOfFrost) or (not(db.pofMode) and variantCheckDeath)
			local wtf2 = (db.pofMode and variantCheckDeath and s_buff_PillarOfFrost) or (not(db.pofMode) and variantCheckNotDeath)
			local wtf3 = (db.pofMode and variantCheckNotDeath and s_buff_PillarOfFrost) or (not(db.pofMode) and variantCheckDeath) 
			local wtf4 = (db.pofMode and variantCheckNotDeath and s_buff_PillarOfFrost) or (not(db.pofMode) and variantCheckNotDeath)
			
			local variationsWTF = wtf1 or wtf2 or wtf3 or wtf4
			
			if (s1 ~= idObliterate) and C_SpellBook.IsSpellInSpellBook(idObliterate) and (killingMachineCheck or killingMachineRunes) and variationsWTF then
				return 0
			end
			
			return 100
		end,
	
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Obliterate w/Killing Machine x2 -OR- x1 w/3+ runes",
	},
	
	-- obliterate inexorable assault
	ob_ia = {
		id = idObliterate,
		GetCD = function()

			if s_buff_InexorableAssault then 
				inexorableAssaultStacks = s_buff_InexorableAssault.applications
			else
				inexorableAssaultStacks = 0
			end
			
			local inexorableAssaultCheck = (s_buff_InexorableAssault and inexorableAssaultStacks > 2)
			
			if (s1 ~= idObliterate) and (s_rune > 2) and C_SpellBook.IsSpellInSpellBook(idObliterate) and inexorableAssaultCheck then
				return 0
			end
			
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Obliterate w/Inexorable Assault sttacks x3",
	},
	
	-- obliterate extermination
	ob_ex = {
		id = idObliterate,
		GetCD = function()

			if (s1 ~= idObliterate) and (s_rune > 0) and C_SpellBook.IsSpellInSpellBook(idObliterate) and s_buff_Exterminate then
				return 0
			end
			
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Obliterate w/Exterminate (Hero Talent) proc",
	},
	
	-- Reapers mark hero talent
	rm = {
		id = idReapersMark,
		GetCD = function()
		
			if (s1 ~= idReapersMark) and C_SpellBook.IsSpellInSpellBook(idReapersMark) and (s_rune > 1) then
				return GetCooldown(idReapersMark)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Reaper's Mark (Hero Talent)",
	},

	-- Sindragosa's breath
	bos = {
		id = idBreathOfSindragosa,
		GetCD = function()
		
			level = UnitLevel("target")
			bossModeCheck = (db.bossMode and (level < 0)) or not(db.bossMode)
		
			if (s1 ~= idBreathOfSindragosa) and (s_rp > 59) and bossModeCheck and C_SpellBook.IsSpellInSpellBook(idBreathOfSindragosa) then
				return GetCooldown(idBreathOfSindragosa)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Breath Of Sindragosa",
	},
	
	-- Soul Reaper
	sr = {
		id = idSoulReaper,
		GetCD = function()
			if (s1 ~= idSoulReaper) and (((UnitHealth("target") / (UnitHealthMax("target") + 1) * 100)) < 36) and (C_SpellBook.IsSpellInSpellBook(idSoulReaper)) then
				return GetCooldown(idSoulReaper)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		info = "Soul Reaper with Target Below 35% Health",
	},

	sr_ros = {
		id = idSoulReaper,
		GetCD = function()
			if (s1 ~= idSoulReaper) and (C_SpellBook.IsSpellInSpellBook(idSoulReaper)) and s_buff_ReaperOfSouls then
				return GetCooldown(idSoulReaper)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		info = "Soul Reaper w/Reaper of Souls (Hero Talent) proc",
	},




}
--------------------------------------------------------------------------------

local function UpdateQueue()
	-- normal queue
	qn = {}
	for v in string.gmatch(db.frostdkprio, "[^ ]+") do
		if actions[v] then
			table.insert(qn, v)
		else
			print("Frost - invalid action:", v)
		end
	end
	db.frostdkprio = table.concat(qn, " ")

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
	s_buff_Rime = C_UnitAuras.GetPlayerAuraBySpellID(idRime)
	s_buff_KillingMachine = C_UnitAuras.GetPlayerAuraBySpellID(idKillingMachine)
	s_buff_RemorselessWinter = C_UnitAuras.GetPlayerAuraBySpellID(idRemorselessWinter)
	s_buff_PillarOfFrost = C_UnitAuras.GetPlayerAuraBySpellID(idPillarOfFrost)
	s_buff_InexorableAssault = C_UnitAuras.GetPlayerAuraBySpellID(idInexorableAssault)
	s_buff_IcyOnslaught = C_UnitAuras.GetPlayerAuraBySpellID(idIcyOnslaught)
	s_buff_ReaperOfSouls = C_UnitAuras.GetPlayerAuraBySpellID(idReaperOfSouls)
	s_buff_Exterminate = C_UnitAuras.GetPlayerAuraBySpellID(idExterminate)
	
	-- retrieves localized debuff spell name
	local spellInfoFrostFever = C_Spell.GetSpellInfo(idFrostFever)
	local debuffFrostFever = spellInfoFrostFever.name
	
	local spellInfoSoulReaper = C_Spell.GetSpellInfo(idSoulReaper)
	local debuffSoulReaper = spellInfoSoulReaper.name

	local spellInfoFrostreaper = C_Spell.GetSpellInfo(idFrostreaper)
	local debuffFrostreaper = spellInfoFrostreaper.name
	
	-- the debuffs
	s_debuff_FrostFever = AuraUtil.FindAuraByName(debuffFrostFever, "target", "HARMFUL")
	s_debuff_SoulReaper = AuraUtil.FindAuraByName(debuffSoulReaper, "target", "HARMFUL")
	s_debuff_Frostreaper = AuraUtil.FindAuraByName(debuffFrostreaper, "target", "HARMFUL")
		
	-- client runic power, runes, and haste
	s_rp = UnitPower("player", 6)
	s_rune = UnitPower("player", Enum.PowerType.Runes)
	s_haste = 1 + UnitSpellHaste("player") / 100
	
	-- local total = 0
	-- for i=1,6 do
		-- total = total + GetRuneCount(i)
	-- end
	
	-- local s_rune = total
	
	
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

	local action
	s1, action = GetNextAction()

	-- 
	s_otime = s_ctime -- save it so we adjust buffs for next
	actions[action].UpdateStatus()

	s_otime = s_ctime - s_otime

	-- -----------
	-- AOE Mode --
	-- -----------

	local AssistedDS = select(1, C_AssistedCombat.GetNextCastSpell())
	local level = UnitLevel("target")
	local className = UnitClass("target")
	local SoulHunterCheck = ((className == "Adarus Duskblaze") or (className == "Velaryn Bloodwrath") or (className == "Ilyssa Darksorrow"))
	local SoulbinderCheck = ((className == "Shadowguard Mage") or (className == "Shadowguard Assassin") or (className == "Shadowguard Phaseblade") or (className == "Soulbinder Naazindhri"))
	local ForgeweaverCheck = ((className == "Forgeweaver Araz") or (className == "Arcane Echo") or (className == "Arcane Manifestation"))
	
	if ((AssistedDS == 207230) and db.aoeMode and ((level > 0) and (level < 82))) or ((SoulHunterCheck or SoulbinderCheck or ForgeweaverCheck) and (s1 == idTemplarsVerdict) and (AssistedDS == 207230)) then
		s1 = idFrostscythe
	end
	
	if ((AssistedDS == 194913) and db.aoeMode and ((level > 0) and (level < 82))) or ((SoulHunterCheck or SoulbinderCheck or ForgeweaverCheck) and (s1 == idTemplarsVerdict) and (AssistedDS == 194913)) then
		s1 = idGlacialAdvance
	end
	
	-- Death strike on low health
	if db.healthToggle and s_rp > 35 and (((UnitHealth("player") / (UnitHealthMax("player") + 1) * 100)) < db.healthValue) then 
		s1 = overrideActions.ds.id
	end
	
	-- Death coil out of melee
	if db.deathCoilMode and s_rp > 29 and C_SpellBook.IsSpellInSpellBook(idFrostStrike) and not C_Spell.IsSpellInRange(idFrostStrike) then 
		s1 = overrideActions.dc.id
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
	
	-- Blizz assisted combat api
	local specID = C_SpecializationInfo.GetSpecialization()
	local blizzEnabled = clcret.db.profile.rotation.specBlizzMode[specID] or false
	local idBlizz = GetBlizzID()
	if blizzEnabled and s1 ~= idHammerOfLight and s1~= overrideActions.trink1.GetID() and s1 ~= overrideActions.trink2.GetID()then
		s1 = idBlizz
	end
	-- --------------
	
	s2, action = GetNextAction()

	return s1, s2
end

-- event frame
local ef = CreateFrame("Frame", "frostdkModuleEventFrame") -- event frame
ef:Hide()
local function OnEvent()
	qTaint = true


end
ef:SetScript("OnEvent", OnEvent)
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("PLAYER_TALENT_UPDATE")
ef:RegisterEvent("PLAYER_LEVEL_UP")
