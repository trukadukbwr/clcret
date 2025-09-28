-- don't load if class is wrong
local _, class = UnitClass("player")
if class ~= "WARRIOR" then return end

local _, xmod = ...

xmod.furymodule = {}
xmod = xmod.furymodule

local qTaint = true -- will force queue check

-- 
local GetTime, GetSpellCooldown, UnitBuff, UnitAura, UnitPower, UnitSpellHaste, UnitHealth, UnitHealthMax, GetActiveSpecGroup, GetTalentInfoByID, GetGlyphSocketInfo, IsUsableSpell, GetShapeshiftForm, max, min =
GetTime, GetSpellCooldown, UnitBuff, UnitAura, UnitPower, UnitSpellHaste, UnitHealth, UnitHealthMax, GetActiveSpecGroup, GetTalentInfoByID, GetGlyphSocketInfo, IsUsableSpell, GetShapeshiftForm, max, min
local db


xmod.version = 9000001
xmod.defaults = {
	version = xmod.version,
	furyprio = "r ex3 bs tr rb_ss r_100 bt_bc4 rb bt ex s",
	rangeCheckSkill = _rangeoff,
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
local idBladestorm = 227847
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
local idChampionsSpear = 376079
local idThunderclap = 6343
local idShockwave = 46968
local idTestOfMightTalent = 385008
local idSweepingStrikes = 260708
local idDemolish = 436358
local idRampage = 184367
local idRagingBlow = 85288
local idBloodthirst = 23881
local idOdynsFury = 385059

-- buffs
local idDeadlyCalm = 262228
local idCrush = 278826
local idTestOfMight = 385013
local idSuddenDeath = 52437
local idEnrage = 184362
local idSlaughteringStrikes = 388004
local idBrutalFinish = 446085
local idBloodcraze = 393951
local idThunderBlast = 435615

-- debuffs
local idDeepWounds = 262115
local idColossus = 208086
local idExecutioner = 386633
local idMarkedForExecution = 445584

-- status vars
local s1, s2
local s_ctime, s_otime, s_gcd, s_hp, s_dp, s_aw, s_ss, s_dc, s_fv, s_bc, s_haste, s_in_execute_range

local s_RagingBlowCharges = 0

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

local function GetRBData()
	local chargeInfo = C_Spell.GetSpellCharges(idRagingBlow)
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

	--Rampage
	r = {
		id = idRampage,
		GetCD = function()
			if (s1 ~= idRampage) and (s_hp > 80) then
				return GetCooldown(idRampage)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp - 80)

		end,
		info = "Rampage if not Enraged",
	},
	
	--Rampage at over 100 rage
	r_100 = {
		id = idRampage,
		GetCD = function()
			if (s1 ~= idRampage) and (s_hp > 100) then
				return GetCooldown(idRampage)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp - 80)

		end,
		info = "Rampage with over 100 Rage",
	},

	--Raging Blow ignoring stacks
	rb = {
		id = idRagingBlow,
		GetCD = function()
		
			local cd, charges = GetRBData()
		
			if (s1 ~= idRagingBlow) and ((s_RagingBlowCharges == 1) or (s_RagingBlowCharges == 2)) then
				return GetCooldown(idRagingBlow)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp + 14)
			s_RagingBlowCharges = max(2, s_RagingBlowCharges - 1)	

		end,
		info = "Raging Blow @ any stacks",
	},

	--Raging Blow @ 2 stacks
	rb2 = {
		id = idRagingBlow,
		GetCD = function()
		
			local cd, charges = GetRBData()
		
			if (s1 ~= idRagingBlow) and (s_RagingBlowCharges == 2) then
				return GetCooldown(idRagingBlow)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp + 14)
			s_RagingBlowCharges = max(2, s_RagingBlowCharges - 1)	

		end,
		info = "Raging Blow @ 2 Charges",
	},

	--Raging Blow to build slaughtering strikes
	rb_ss = {
		id = idRagingBlow,
		GetCD = function()
		
			SlaughteringStrikesStacks = select(3, AuraUtil.FindAuraByName("Slaughtering Strikes", "player", "HELPFUL"))
			s_stacks = not(s_buff_SlaugteringStrikes) or (s_buff_SlaugteringStrikes and SlaughteringStrikesStacks < 5)
			
			if (s1 ~= idRagingBlow) and s_stacks and s_buff_BrutalFinish then
				return GetCooldown(idRagingBlow)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp + 14)


		end,
		info = "Raging Blow to build Slaughtering Strikes",
	},

	--Bloodthirst
	bt = {
		id = idBloodthirst,
		GetCD = function()
			if (s1 ~= idBloodthirst) then
				return GetCooldown(idBloodthirst)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp + 10)

		end,
		info = "Bloodthirst",
	},
	
	--Bloodthirst  at 3 or more stacks of bloodcraze crit
	bt_bc4 = {
		id = idBloodthirst,
		GetCD = function()
		
			BloodcrazeStacks = select(3, AuraUtil.FindAuraByName("Bloodcraze", "player", "HELPFUL"))
		
			if (s1 ~= idBloodthirst) and (s_buff_Bloodcraze and BloodcrazeStacks > 2) then
				return GetCooldown(idBloodthirst)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp + 10)

		end,
		info = "Bloodthirst with 3 or more Bloodcraze stacks",
	},

	--Champions spear
	cs = {
		id = idChampionsSpear,
		GetCD = function()
			if (s1 ~= idChampionsSpear) and IsPlayerSpell(idChampionsSpear) then
				return GetCooldown(idChampionsSpear)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp + 10)

		end,
		info = "Champion's Spear",
	},
	
	--odyns fury onlyfans
	of = {
		id = idOdynsFury,
		GetCD = function()
			if (s1 ~= idOdynsFury) and IsPlayerSpell(idOdynsFury) then
				return GetCooldown(idOdynsFury)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5
			s_hp = max(100, s_hp + 10)

		end,
		info = "Odyn's Fury",
	},

	--Thunderclap
	tc = {
			id = idThunderclap,
		GetCD = function()
			if (s1 ~= idThunderclap) and IsPlayerSpell(idThunderclap) and s_buff_ThunderBlast then
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

		end,
		info = "Slam",

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

		end,
		info = "Whirlwind",

	},

	--thunderous roar
	tr = {
		id = idDragonRoar,
		GetCD = function()
		
			if (s1 ~= idDragonRoar) and IsSpellKnownOrOverridesKnown(idDragonRoar) and s_buff_Enrage then
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

	--Execute w/Marked for execution debuff @ 3
	ex3 = {
		id = idExecute,
		GetCD = function()
	
			ExecStacks = select(3, AuraUtil.FindAuraByName("Marked for Execution", "target", "HARMFUL"))
	
			if (s1 ~= idExecute) and C_Spell.IsSpellUsable(idExecute) and (s_hp > 20) and ExecStacks == 3 then
				return GetCooldown(idExecute)
			end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + 1.5

		end,
		info = "Execute w/3 stacks of Marked for Execution",
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
			if (s1 ~= idBladestorm) and IsPlayerSpell(idBladeDummy) and GetCooldown(idBladestorm) < 0.1 and s_buff_Enrage then
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
		for v in string.gmatch(db.furyprio, "[^ ]+") do
			if actions[v] then
				table.insert(qn, v)
			else
				print("Fury - invalid action:", v)
			end
		end
		db.furyprio = table.concat(qn, " ")

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
	s_buff_Enrage = C_UnitAuras.GetPlayerAuraBySpellID(idEnrage)
	s_buff_SlaugteringStrikes = C_UnitAuras.GetPlayerAuraBySpellID(idSlaughteringStrikes)
	s_buff_BrutalFinish = C_UnitAuras.GetPlayerAuraBySpellID(idBrutalFinish)
	s_buff_Bloodcraze = C_UnitAuras.GetPlayerAuraBySpellID(idBloodcraze)
	s_buff_ThunderBlast = C_UnitAuras.GetPlayerAuraBySpellID(idThunderBlast)
	
	-- retrieves localized debuff spell name
	local spellInfoDeepWounds = C_Spell.GetSpellInfo(idDeepWounds)
	local debuffDeepWounds = spellInfoDeepWounds.name
	
	local spellInfoColossus = C_Spell.GetSpellInfo(idColossus)
	local debuffColossus = spellInfoColossus.name
	
	local spellInfoRend = C_Spell.GetSpellInfo(idRend)
	local debuffRend = spellInfoRend.name
	
	local spellInfoExecutioner = C_Spell.GetSpellInfo(idExecutioner)
	local debuffExecutioner = spellInfoExecutioner.name
	
	local spellInfoMarkedForExecution = C_Spell.GetSpellInfo(idMarkedForExecution)
	local debuffMarkedForExecution = spellInfoMarkedForExecution.name
	
	-- the debuffs
	s_debuff_DeepWounds = AuraUtil.FindAuraByName(debuffDeepWounds, "target", "HARMFUL")
	s_debuff_Colossus = AuraUtil.FindAuraByName(debuffColossus, "target", "HARMFUL")
	s_debuff_Rend = AuraUtil.FindAuraByName(debuffRend, "target", "HARMFUL")
	s_debuff_Executioner = AuraUtil.FindAuraByName(debuffExecutioner, "target", "HARMFUL")
	s_debuff_MarkedForExecution = AuraUtil.FindAuraByName(debuffMarkedForExecution, "target", "HARMFUL")
	
	-- ----------------------------------------
	-- Spell Charges for GetStatus Function --
	-- ----------------------------------------

	-- Raging Blow stacks
	local cd, charges = GetRBData()
	s_RagingBlowCharges = charges


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

	-- Raging Blow stacks
	local cd, charges = GetRBData()
		s_RagingBlowCharges = charges
	
	if (s1 == idRagingBlow) then
		s_RagingBlowCharges = s_RagingBlowCharges - 1
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
local ef = CreateFrame("Frame", "FuryModuleEventFrame") -- event frame
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
