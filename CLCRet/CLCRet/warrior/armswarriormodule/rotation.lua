-- don't load if class is wrong
local _, class = UnitClass("player")
if class ~= "WARRIOR" then return end

local _, xmod = ...

xmod.armswarriormodule = {}
xmod = xmod.armswarriormodule

local qTaint = true -- will force queue check

-- 
local GetTime, GetSpellCooldown, UnitBuff, UnitAura, UnitPower, UnitSpellHaste, UnitHealth, UnitHealthMax, GetActiveSpecGroup, GetTalentInfoByID, GetGlyphSocketInfo, IsUsableSpell, GetShapeshiftForm, max, min =
GetTime, GetSpellCooldown, UnitBuff, UnitAura, UnitPower, UnitSpellHaste, UnitHealth, UnitHealthMax, GetActiveSpecGroup, GetTalentInfoByID, GetGlyphSocketInfo, IsUsableSpell, GetShapeshiftForm, max, min
local db


xmod.version = 9000001
xmod.defaults = {
	version = xmod.version,
	armsprio = "cru2 cru bs opx skull cs ex ms r s",
	rangeCheckSkill = "_rangeoff",
}

-- @defines
--------------------------------------------------------------------------------
local idGCD = 1464 -- slam for gcd

-- spells
local idSlam = 1464
local idSkullsplitter = 260643
local idMortalStrike = 12294
local idVictoryRush = 34428
local idRend = 772
local idExecute = 163201
local idBladestorm = 446035
local idBladeDummy = 227847
local idColossusSmash = 167105
local idWarbreaker = 262161
local idOverpower = 7384
local idHeroicThrow = 57755
local idArcane = 69179
local idCharge = 100
local idRavager = 152277
local idStormBolt = 107570
local idWhirlwind = 1680
local idDragonRoar = 384318
local idSpearOfBastion = 376079
local idThunderclap = 396719
local idShockwave = 46968
local idTestOfMightTalent = 385008
local idSweepingStrikes = 260708
local idDemolish = 436358

-- buffs
local idDeadlyCalm = 262228
local idCrush = 278826
local idTestOfMight = 385013
local idSuddenDeath = 52437

-- debuffs
local idDeepWounds = 262115
local idColossus = 208086
local idExecutioner = 386633

-- status vars
local s1, s2
local s_ctime, s_otime, s_gcd, s_hp, s_dp, s_aw, s_ss, s_dc, s_fv, s_bc, s_haste, s_in_execute_range

local s_OverpowerCharges = 0

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

local function GetOPData()
	local chargeInfo = C_Spell.GetSpellCharges(idOverpower)
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
	--Arcane Torrent
	arc = {
		id = idArcane,
		GetCD = function()
			if (s1 ~= idArcane) and (s_hp < 10) and (IsSpellKnownOrOverridesKnown(idArcane)) then
				return GetCooldown(idArcane)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
				s_hp = max(100, s_hp + 15)

		end,
		info = "Arcane Torrent",
	},

	--Sweeping Strikes
	sweep = {
		id = idSweepingStrikes,
		GetCD = function()
		
		-- code for in range
		inRange = 0
			for i = 1, 40 do
				if UnitExists('nameplate' .. i) and C_Spell.IsSpellInRange('Slam', 'nameplate' .. i) == 1 then 
				inRange = inRange + 1
			end
		end
		-- ------
		
			if (s1 ~= idSweepingStrikes) and (inRange > 2) then
				return GetCooldown(idSweepingStrikes)
			end
			
			if (s1 ~= idSweepingStrikes) and (inRange < 2) then
				return 100
			end
			
			if (s2 ~= idSweepingStrikes) and (inRange < 2) then
				return 100
			end
			
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
		end,
		info = "Sweeping Strikes",
	},

	--Colossus Smash
	cs = {
		id = idColossusSmash,
		GetCD = function()
		
			ColossusCheck = (not(IsPlayerSpell(262161)) and (GetCooldown(idColossusSmash) < 1))
			WarCheck = (IsPlayerSpell(262161) and (GetCooldown(idWarbreaker) < 1))
		
			if (s1 ~= idColossusSmash) and (ColossusCheck or WarCheck) then
				return 0 --GetCooldown(idColossusSmash)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_debuff_Colossus = 10
			s_hp = max(100, s_hp + 30)
		end,
		info = "Colossus Smash",

	},

	--Rend
	r = {
		id = idRend,
		GetCD = function()
			if (s1 ~= idRend) and not(s_debuff_Rend) and (IsSpellKnownOrOverridesKnown(idRend)) then
				return GetCooldown(idRend)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = min(100, s_hp - 30)
		end,
		info = "Rend",
	},

	--Rend on boss targets
	r_boss = {
		id = idRend,
		GetCD = function()
		
			level = UnitLevel("target")
			Boss = ((level < 0) or (level > 82))
			
			if (s1 ~= idRend) and not(s_debuff_Rend) and (IsPlayerSpell(idRend)) and Boss then
				return GetCooldown(idRend)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = min(100, s_hp - 30)
		end,
		info = "Rend on boss targets",
	},

	--Thunderclap
	tc = {
			id = idThunderclap,
		GetCD = function()
			if (s1 ~= idThunderclap) and IsPlayerSpell(idThunderclap) and (s_hp > 29) then
				return GetCooldown(idThunderclap)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp - 40)
		end,
		info = "Thunder Clap",
	},

	--Thunderclap to apply rend
	tc_rend = {
			id = idThunderclap,
		GetCD = function()
			if (s1 ~= idThunderclap) and IsPlayerSpell(idThunderclap) and (s_hp > 29) and (s_debuff_Rend < 1) and IsPlayerSpell(idRend) then
				return GetCooldown(idThunderclap)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp - 40)
		end,
		info = "Thunder Clap to apply Rend (Blood and Thunder talent)",
	},

	--Slam
	s = {
		id = idSlam,
		GetCD = function()
			if (s1 ~= idSlam) then
				return GetCooldown(idSlam)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = min(100, s_hp - 20)

		end,
		info = "Slam",

	},

	--Whirlwind w/Storm of Swords talent
	ww_sos = {
		id = idWhirlwind,
		GetCD = function()
			if (s1 ~= idWhirlwind) and (s_hp > 49) and (IsPlayerSpell(385512)) then
				return GetCooldown(idWhirlwind)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = min(100, s_hp - 50)

		end,
		info = "Whirlwind w/Storm of Swords talent",

	},

	--Whirlwind
	ww = {
		id = idWhirlwind,
		GetCD = function()
		
		-- code for in range
		inRange = 0
			for i = 1, 40 do
				if UnitExists('nameplate' .. i) and C_Spell.IsSpellInRange('Slam', 'nameplate' .. i) == 1 then 
				inRange = inRange + 1
			end
		end
		-- ------
		
			if (s1 ~= idWhirlwind) and (s_hp > 50) and (inRange > 2) then
				return GetCooldown(idWhirlwind)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = min(100, s_hp - 40)

		end,
		info = "Whirlwind",

	},

	--Skullsplitter
	skull = {
		id = idSkullsplitter,
		GetCD = function()
		
			TestOfMightCheck = (not(IsPlayerSpell(idTestOfMightTalent)) or (IsPlayerSpell(idTestOfMightTalent) and not(s_debuff_Colossus)))
		
			if (s1 ~= idSkullsplitter) and IsSpellKnownOrOverridesKnown(idSkullsplitter) and TestOfMightCheck then
				return GetCooldown(idSkullsplitter)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp + 15)

		end,
		info = "Skullsplitter",
	},

	--thunderous roar
	tr_tom = {
		id = idDragonRoar,
		GetCD = function()
		
			TestOfMightCheckX = (not(IsPlayerSpell(idTestOfMightTalent)) or (IsPlayerSpell(idTestOfMightTalent) and (s_buff_TestOfMight)))
		
			if (s1 ~= idDragonRoar) and IsSpellKnownOrOverridesKnown(idDragonRoar) and TestOfMightCheckX then
				return GetCooldown(idDragonRoar)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp + 10)

		end,
		info = "Thunderous Roar with Test of Might up",
	},

	--thunderous roar
	tr = {
		id = idDragonRoar,
		GetCD = function()
		
			if (s1 ~= idDragonRoar) and IsSpellKnownOrOverridesKnown(idDragonRoar) then
				return GetCooldown(idDragonRoar)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp + 10)

		end,
		info = "Thunderous Roar",
	},

	--Mortal Strike
	ms = {
		id = idMortalStrike,
		GetCD = function()
			if (s1 ~= idMortalStrike) and s_hp > 30 then
				return GetCooldown(idMortalStrike)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = min(100, s_hp - 30)

		end,
		info = "Mortal Strike",
	},

	--Mortal Strike w/Executioner's Precision (talent) @ 2 stacks
	ms_exec = {
		id = idMortalStrike,
		GetCD = function()
		
			name, _, count, _, duration, _, _, _, _, spellId, _, _, _, _, _ = APIWrapper.UnitDebuff  ("target", ln_debuff_Executioner)
		
			if (s1 ~= idMortalStrike) and (count == 2) and s_hp > 30 then
				return GetCooldown(idMortalStrike)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = min(100, s_hp - 30)

		end,
		info = "Mortal Strike w/Executioner's Precision (talent) @ 2 stacks",
	},

	--Mortal Strike w/Overpower Buff (Martial Prowless talent)
	ms_op = {
		id = idMortalStrike,
		GetCD = function()
		
			name, _, count, _, duration, _, _, _, _, spellId, _, _, _, _, _ = APIWrapper.UnitBuff  ("player", ln_debuff_Overpower)
		
			if (s1 ~= idMortalStrike) and s_buff_Overpower and (count == 2) and s_hp > 30 then
				return GetCooldown(idMortalStrike)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = min(100, s_hp - 30)

		end,
		info = "Mortal Strike w/Overpower Buff (Martial Prowless talent) @ 2 stacks",
	},

	--Execute
	ex = {
		id = idExecute,
		GetCD = function()
			if (s1 ~= idExecute) and C_Spell.IsSpellUsable(idExecute) and (s_hp > 20) then
				return GetCooldown(idExecute)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Execute",
	},
	
	--Execute w/Sudden Death proc
	ex_sd = {
		id = idExecute,
		GetCD = function()
			if (s1 ~= idExecute) and C_Spell.IsSpellUsable(idExecute) and s_buff_SuddenDeath then
				return GetCooldown(idExecute)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Execute w/Sudden Death proc",
	},

	--Demolish (hero talent)
	dem = {
		id = idDemolish,
		GetCD = function()
			if (s1 ~= idDemolish) and IsPlayerSpell(idDemolish) and GetCooldown(idDemolish) < 1 then
				return GetCooldown(idDemolish)
			end
			return 100
		end,
		UpdateStatus = function()
			-- s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Demolish",
	},
	

	--Overpower
	op = {
		id = idOverpower,
		GetCD = function()
		
			TestOfMightCheck = (not(IsPlayerSpell(idTestOfMightTalent)) or (IsPlayerSpell(idTestOfMightTalent) and not(s_debuff_Colossus)))
			
			if (s1 ~= idOverpower) and TestOfMightCheck then
				return GetCooldown(idOverpower)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp + 25)
			s_OverpowerCharges = max(0, s_OverpowerCharges - 1)
		end,
		info = "Overpower",
	},

	--Spear of Bastion 
	sob = {
		id = idSpearOfBastion,
		GetCD = function()
			if (s1 ~= idSpearOfBastion) and IsPlayerSpell(idSpearOfBastion) then
				return GetCooldown(idSpearOfBastion)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp + 20)
		end,
		info = "Spear of Bastion",
	},
	
	--Shockwave 
	sw = {
		id = idShockwave,
		GetCD = function()
			if (s1 ~= idShockwave) and IsPlayerSpell(idShockwave) then
				return GetCooldown(idShockwave)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp + 10)
		end,
		info = "Shockwave",
	},

	--Bladestorm
	bs = {
		id = idBladestorm,
		GetCD = function()
			level = UnitLevel("target")
			-- if (s1 ~= idBladestorm) and ((level < 0) or (level > 82)) then
			if (s1 ~= idBladestorm) and ((level < 0) or (level > 82)) and IsPlayerSpell(idBladeDummy) and GetCooldown(idBladestorm) < 0.1 then
				return 0
			end
			return 0.5
		end,
		UpdateStatus = function()
			-- s_ctime = s_ctime + s_gcd + 1.5
			-- s_hp = max(100, s_hp + 50)

		end,
		info = "Bladestorm",
	},

}
--------------------------------------------------------------------------------

	local function UpdateQueue()
	-- normal queue
	qn = {}
		for v in string.gmatch(db.armsprio, "[^ ]+") do
			if actions[v] then
				table.insert(qn, v)
			else
				print("Arms - invalid action:", v)
			end
		end
		db.armsprio = table.concat(qn, " ")

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

	s_buff_DeadlyCalm = C_UnitAuras.GetPlayerAuraBySpellID(idDeadlyCalm)
	s_buff_Crush = C_UnitAuras.GetPlayerAuraBySpellID(idCrush)
	s_buff_Overpower = C_UnitAuras.GetPlayerAuraBySpellID(idOverpower)
	s_buff_TestOfMight = C_UnitAuras.GetPlayerAuraBySpellID(idTestOfMight)
	s_buff_SuddenDeath = C_UnitAuras.GetPlayerAuraBySpellID(idSuddenDeath)
	s_buff_SweepingStrikes = C_UnitAuras.GetPlayerAuraBySpellID(idSweepingStrikes)
	
	-- retrieves localized debuff spell name
	local spellInfoDeepWounds = C_Spell.GetSpellInfo(idDeepWounds)
	local debuffDeepWounds = spellInfoDeepWounds.name
	
	local spellInfoColossus = C_Spell.GetSpellInfo(idColossus)
	local debuffColossus = spellInfoColossus.name
	
	local spellInfoRend = C_Spell.GetSpellInfo(idRend)
	local debuffRend = spellInfoRend.name
	
	local spellInfoExecutioner = C_Spell.GetSpellInfo(idExecutioner)
	local debuffExecutioner = spellInfoExecutioner.name
	
	-- the debuffs
	s_debuff_DeepWounds = AuraUtil.FindAuraByName(debuffDeepWounds, "target", "HARMFUL")
	s_debuff_Colossus = AuraUtil.FindAuraByName(debuffColossus, "target", "HARMFUL")
	s_debuff_Rend = AuraUtil.FindAuraByName(debuffRend, "target", "HARMFUL")
	s_debuff_Executioner = AuraUtil.FindAuraByName(debuffExecutioner, "target", "HARMFUL")
	
	-- ----------------------------------------
	-- Spell Charges for GetStatus Function --
	-- ----------------------------------------

	-- Overpower stacks
	local cd, charges = GetOPData()
	s_OverpowerCharges = charges


	-- client rage and haste
	s_hp = UnitPower("player", 1)
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

	-- Overpower stacks
	local cd, charges = GetOPData()
		s_OverpowerCharges = charges
	
	if (s1 == idOverpower) then
		s_OverpowerCharges = s_OverpowerCharges - 1
	end

	if debug and debug.enabled then
		debug:AddBoth("opc", s_OverpowerCharges)
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
local ef = CreateFrame("Frame", "ArmsModuleEventFrame") -- event frame
ef:Hide()
local function OnEvent()
	qTaint = true


-- Tells addon to use WW in place of slam with fervor talent

	-- _, name, _, selected, available = GetTalentInfoByID(22489, GetActiveSpecGroup())
	-- if name and selected and available then
		-- idSlam = 1680
	-- end

	-- actions['s'].id = idSlam

	-- _, name, _, selected, available = GetTalentInfoByID(22380, GetActiveSpecGroup())
	-- if name and selected and available then
		-- idSlam = 1464
	-- end

	-- actions['s'].id = idSlam

	-- _, name, _, selected, available = GetTalentInfoByID(19138, GetActiveSpecGroup())
	-- if name and selected and available then
		-- idSlam = 1464
	-- end

	-- actions['s'].id = idSlam

-- Tells addon to use WW in place of slam with fervor talent w/ crushing assault azerite trait procced

	-- _, name, _, selected, available = GetTalentInfoByID(22489, GetActiveSpecGroup())
	-- if name and selected and available then
		-- idSlam = 1680
	-- end

	-- actions['sca'].id = idSlam

	-- _, name, _, selected, available = GetTalentInfoByID(22380, GetActiveSpecGroup())
	-- if name and selected and available then
		-- idSlam = 1464
	-- end

	-- actions['sca'].id = idSlam

	-- _, name, _, selected, available = GetTalentInfoByID(19138, GetActiveSpecGroup())
	-- if name and selected and available then
		-- idSlam = 1464
	-- end

	-- actions['sca'].id = idSlam

-- Tells addon to use Warbreaker in place of Colossus Smash

	-- _, name, _, selected, available = GetTalentInfoByID(22391, GetActiveSpecGroup())
	-- if name and selected and available then
		-- idColossusSmash = 262161
	-- end

	-- actions['cs'].id = idColossusSmash

	-- _, name, _, selected, available = GetTalentInfoByID(22392, GetActiveSpecGroup())
	-- if name and selected and available then
		-- idColossusSmash = 167105
	-- end

	-- actions['cs'].id = idColossusSmash

	-- _, name, _, selected, available = GetTalentInfoByID(22362, GetActiveSpecGroup())
	-- if name and selected and available then
		-- idColossusSmash = 167105
	-- end

	-- actions['cs'].id = idColossusSmash

-- Tells addon to use Ravager in place of Bladestorm

	-- _, name, _, selected, available = GetTalentInfoByID(21667, GetActiveSpecGroup())
	-- if name and selected and available then
		-- idBladestorm = 152277
	-- end

	-- actions['bs'].id = idBladestorm

	-- _, name, _, selected, available = GetTalentInfoByID(21204, GetActiveSpecGroup())
	-- if name and selected and available then
		-- idBladestorm = 227847
	-- end

	-- actions['bs'].id = idBladestorm
	-- _, name, _, selected, available = GetTalentInfoByID(21667, GetActiveSpecGroup())
	-- if name and selected and available then
		-- idBladestorm = 227847
	-- end

	-- actions['bs'].id = idBladestorm


end
ef:SetScript("OnEvent", OnEvent)
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("PLAYER_TALENT_UPDATE")
ef:RegisterEvent("PLAYER_LEVEL_UP")
