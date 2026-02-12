local _, trueclass = UnitClass("player")

clcret.optionsLoaded = true

local MAX_AURAS = 10

local db = clcret.db.profile
-- local root

local strataLevels = {
	"BACKGROUND",
	"LOW",
	"MEDIUM",
	"HIGH",
	"DIALOG",
	"FULLSCREEN",
	"FULLSCREEN_DIALOG",
	"TOOLTIP",
}

local anchorPoints = {
	CENTER = "CENTER",
	TOP = "TOP",
	BOTTOM = "BOTTOM",
	LEFT = "LEFT",
	RIGHT = "RIGHT",
	TOPLEFT = "TOPLEFT",
	TOPRIGHT = "TOPRIGHT",
	BOTTOMLEFT = "BOTTOMLEFT",
	BOTTOMRIGHT = "BOTTOMRIGHT"
}

-- -------------------
-- Aura Button stuff
-- -------------------
local execList = {
	AuraButtonExecaNone = "None",
	-- AuraButtonExecSkillVisibleAlways = "Skill always visible",
	-- AuraButtonExecSkillVisibleNoCooldown = "Skill visible off CD",
	-- AuraButtonExecSkillVisibleOnCooldown = "Skill visible on CD",
	-- AuraButtonExecSkillVisibleOnCooldown2 = "---",
	AuraButtonExecItemVisible1Always = "Item always visible",
	AuraButtonExecItemVisible2NoCooldown = "Item visible off CD",
	AuraButtonExecItemVisible3AlwaysEquip = "Equipped; always visible",
	AuraButtonExecItemVisible4NoCooldownEquip = "Equipped; visible off CD",
	AuraButtonExecItemVisible5NoCooldownEquip2 = "---",
	
	-- AuraButtonExecPlayerMissingBuff = "Missing player buff",
	-- AuraButtonExecPlayerMissingBuff2 = "---",
}
-- index lookup for aura buttons
local ilt = {}

for i = 1, MAX_AURAS do
	ilt["CD Tracker" .. (i + 2)] = i
end

for i = 1, 2 do
	ilt["Trinket" .. i] = MAX_AURAS + i
end

-- aura buttons get/set functions
local abgs = {}


function abgs:UpdateAll()
	clcret:UpdateEnabledAuraButtons()
	clcret:UpdateAuraButtonsCooldown()
	-- clcret:AuraButtonUpdateICD()
	clcret:AuraButtonResetTextures()
end

-- enabled toggle
function abgs:EnabledGet()
	local i = ilt[self[2]]
	
	return db.auras[i].enabled
end

function abgs:EnabledSet(val)
	local i = ilt[self[2]]
	
	clcret.temp = info
	
	-- Auto-detect trinket if enabling a trinket tracker
	if val and i > MAX_AURAS then
		local trinketSlot = i - MAX_AURAS
		local trinketID = clcret:AutoDetectTrinket(trinketSlot)
		if not trinketID then
			val = false
			print("No trinket equipped in slot " .. (trinketSlot == 1 and "13" or "14"))
		end
		
		
	end
	
	if db.auras[i].data.spell == "" then
		val = false
		print("Not a valid spell name/id or buff name!")
	end
	
	db.auras[i].enabled = val
	if not val then clcret:AuraButtonHide(i) end
	abgs:UpdateAll()
	

	
end

-- function abgs:EnabledSet(val)
	-- local i = ilt[self[2]]
	
	-- clcret.temp = info
	-- if db.auras[i].data.spell == "" then
		-- val = false
		-- print("Not a valid spell name/id or buff name!")
	-- end
	-- db.auras[i].enabled = val
	-- if not val then clcret:AuraButtonHide(i) end
	-- abgs:UpdateAll()
-- end


-- id/name field
function abgs:SpellGet()
	local i = ilt[self[2]]
	
	-- special case for items since link is used instead of name
	if (db.auras[i].data.exec == "AuraButtonExecItemVisible1Always") or (db.auras[i].data.exec == "AuraButtonExecItemVisible2NoCooldown") then
		return db.auras[i].data.spell
	-- elseif db.auras[i].data.exec == "AuraButtonExecICDItem" then
		-- return C_Spell.GetSpellInfo(db.auras[i].data.spell)
	end
	return db.auras[i].data.spell
end
function abgs:SpellSet(val)
	local i = ilt[self[2]]
	
	-- skill
	-- if (db.auras[i].data.exec == "AuraButtonExecSkillVisibleAlways") or (db.auras[i].data.exec == "AuraButtonExecSkillVisibleNoCooldown") or (db.auras[i].data.exec == "AuraButtonExecSkillVisibleOnCooldown") then
		-- local name = C_Spell.GetSpellInfo(val)
		-- if name then
			-- db.auras[i].data.spell = name
		-- else
			-- db.auras[i].data.spell = ""
			-- db.auras[i].enabled = false
			-- clcret:AuraButtonHide(i)
			-- print("Not a valid spell name or id !")
		-- end
	-- item
		if (db.auras[i].data.exec == "AuraButtonExecItemVisible1Always") or (db.auras[i].data.exec == "AuraButtonExecItemVisible2NoCooldown") then
		local name, link = C_Item.GetItemInfo(val)
		if name then
			db.auras[i].data.spell = val
		else
			db.auras[i].data.spell = ""
			db.auras[i].enabled = false
			clcret:AuraButtonHide(i)
			print("Not a valid item name or id !")
		end
	-- icd stuff
	-- elseif (db.auras[i].data.exec == "AuraButtonExecICDItem") then
		-- local tid = tonumber(val)
		-- local name = C_Spell.GetSpellInfo(tid)
		-- if name then
			-- db.auras[i].data.spell = tid
		-- else
			-- db.auras[i].data.spell = ""
			-- db.auras[i].enabled = false
			-- clcret:AuraButtonHide(i)
			-- print("Not a valid spell id!")
		-- end
	else
		db.auras[i].data.spell = val
	end
	
	abgs:UpdateAll()
end


-- ilt copy refera
-- local ilt = {}

-- for i = 1, MAX_AURAS do
	-- ilt["CD Tracker" .. (i + 2)] = i
-- end


-- trinket type select (separate from CD tracker)
function abgs:TrinketExecGet()
	local i = ilt[self[2]]
	
	if i and db.auras[i] then
		return db.auras[i].data.exec
	end
	-- return "AuraButtonExecaNone"
end

function abgs:TrinketExecSet(val)
	local i = ilt[self[2]]
	if not i or not db.auras[i] then return end
	
	local aura = db.auras[i]
	
	if val == "AuraButtonExecaNone" or aura.data.exec == "AuraButtonExecaNone" then
		aura.data.spell = ""
		aura.enabled = false
	end
	
	clcret:AuraButtonHide(i)
	aura.data.exec = val
	abgs:UpdateAll()
end


-- trinket type select
-- function abgs:TrinketExecGet()
	-- local i = ilt[self[2]]
	
	-- return db.auras[i].data.exec
-- end
-- function abgs:TrinketExecSet(val)
	-- local i = ilt[self[2]]
	-- local aura = db.auras[i]
	
	-- if val == "AuraButtonExecaNone" or aura.data.exec == "AuraButtonExecaNone" then
		-- aura.data.spell = ""
	-- end
	
	-- clcret:AuraButtonHide(i)
	
	-- aura.data.exec = val
	
	-- abgs:UpdateAll()
-- end


-- type select
function abgs:ExecGet()
	local i = ilt[self[2]]
	
	return db.auras[i].data.exec
end
function abgs:ExecSet(val)
	local i = ilt[self[2]]
	local aura = db.auras[i]
	
	-- reset every other setting when this is changed
	-- aura.enabled = false
	
	if val == "AuraButtonExecaNone" or aura.data.exec == "AuraButtonExecaNone" then
		aura.data.spell = ""
	end
	
	-- aura.data.spell = ""
	-- aura.data.unit = ""
	-- aura.data.byPlayer = false
	clcret:AuraButtonHide(i)
	
	aura.data.exec = val
	
	abgs:UpdateAll()
end
-- target field
-- function abgs:UnitGet()
	-- local i = ilt[self[2]]
	
	-- return db.auras[i].data.unit
-- end
-- function abgs:UnitSet(val)
	-- local i = ilt[self[2]]
	
	-- db.auras[i].data.unit = val
	-- abgs:UpdateAll()
-- end
-- cast by player toggle
-- function abgs:ByPlayerGet()
	-- local i = ilt[self[2]]
	
	-- return db.auras[i].data.byPlayer
-- end
-- function abgs:ByPlayerSet(val)
	-- local i = ilt[self[2]]
	
	-- db.auras[i].data.byPlayer = val
	-- abgs:UpdateAll()
-- end

local skillButtonNames = { "Main skill", "Secondary skill" }

-- Sets to the rotation module db instead of main db
local function RotationGet(info)
	local xdb = clcret.db.profile.rotation
	return xdb[info[#info]]
end

local function RotationSet(info, val)
	local xdb = clcret.db.profile.rotation
	xdb[info[#info]] = val
	
end

-- Sets to main db
local function Get(info)
	return db[info[#info]]
end

local function Set(info, val)
	db[info[#info]] = val
end

local tx = {}
for k, v in pairs(clcret.RR_actions) do
	table.insert(tx, format("\n%s - %s", k, v.info))
end
table.sort(tx)
local prioInfo = "Legend:\n" .. table.concat(tx)

local options = {
	type = "group",
	name = "CLCRet",
	args = {
			mainGlobal = {
			type = "group",
			name = "Main Settings",
			order = 1,
			args = {
			
				headerOne = {
					order = 1,
					type = "header",
					name = "Information",
				},
				oneDesc = {
					order = 2,
					type = "description",
					name = "-Rotation is based off Blizzard's Assisted Combat API and cannot be changed due to addon restrictions",
				},
				spacerTwo = {
					order = 3,
					type = "description",
					name = "",
				},
				twoDesc = {
					order = 4,
					type = "description",
					name = "-You can set the addon to load per spec. Since it uses Blizzard's API, it will automatically adjust the rotation.",
				},
				spacerThree = {
					order = 5,
					type = "description",
					name = "",
				},
				threeDesc = {
					order = 6,
					type = "description",
					name = "-The addon has a built in shortcut command: You can type /rl instead of the full /reload",
				},
				spacerFour = {
					order = 7,
					type = "description",
					name = "",
				},
				fourDesc = {
					order = 8,
					type = "description",
					name = "-You can activate on-use trinkets for the Main Rotation icon in Rotation Settings. If you see a Gear icon, it means the addon could not load the icon and is suggesting your on-use trinket",
				},
				spacerFive = {
					order = 9,
					type = "description",
					name = "",
				},
				fiveDesc = {
					order = 10,
					type = "description",
					name = "-You can track Trinkets or other specific Items (such as certain combat pots) in the Item Cooldowns section. Due to Blizzard's addon restrictions, you can NOT track Buffs/Debuffs or other Spells.",
				},
				headerFive = {
					order = 11,
					type = "header",
					name = "",
				},
				-- lock frame
				lock = {
					order = 12,
					width = "full",
					type = "toggle",
					name = "Lock Frame",
					get = function(info) return clcret.locked end,
					set = function(info, val)
						clcret:ToggleLock()
					end,
				},
				show = {
					order = 13,
					type = "select",
					name = "Show",
					get = function(info) return db.show end,
					set = function(info, val)
						db.show = val
						clcret:UpdateShowMethod()
					end,
					values = { always = "Always", combat = "In Combat", valid = "Valid Target", boss = "Boss" }
				},
				__strata = {
					order = 15,
					type = "header",
					name = "",
				},
				____strata = {
					order = 16,
					type = "description",
					name = "|cffff0000WARNING|cffffffff Changing Strata value will automatically reload your UI."
				},
				strata = {
					order = 17,
					type = "select",
					name = "Frame Strata",
					get = function(info) return db.strata end,
					set = function(info, val)
						db.strata = val
						ReloadUI()
					end,
					values = strataLevels,
				},
				
				-- spec enable toggle
				___specenable = {
					order = 28,
					type = "description",
					name = "",
				},
				__specenable = {
					order = 28,
					type = "header",
					name = "Enabled on the following specs:",
				},
				
				fullDisable = {
					order = 38,
					width = "full",
					type = "toggle",
					name = "Fully Disable (overrides Spec Disable)",
					get = function(info) return db.fullDisable end,
					set = function(info, val) clcret:FullDisableToggle() end,
				},
			},
		},
		
			rotato = {
		order = 2, 
		type = "group",  
		name = "Rotation Settings",
		args = {
		
			__behaviorSpacer = {
					order = 19,
					type = "header",
					name = "Update Frequency",
			},
		
			rangeSpacer = {
					order = 1,
					type = "header",
					name = "Range Check",
			},
			rangeCheckSkill = {
				order = 2,
				type = "select",
				name = "",
				get = function(info) return db.rotation.rangeCheckSkill end,
				set = function(info, val)
				db.rotation.rangeCheckSkill = val
				end,
				-- activate the comment/comment out the alternative line when a melee range check option is needed
				-- values = { _rangeoff = "Off", rangemelee = "Melee Range", rangeperability = "Per Ability" } -- with melee check
				values = { _rangeoff = "Off", rangeperability = "Per Ability" } -- without melee check
			},
					
			spacerOne = {
				order = 11,
				type = "description",
				name = "",
			},
			oneDesc = {
				order = 12,
				type = "description",
				name = "|cffFF0000OFF|r Range check is turned off",
			},
			spacerThree = {
				order = 13,
				type = "description",
				name = "",
			},
			threeDesc = {
				order = 14,
				type = "description",
				name = "|cff35FF00PER ABILITY|r Range check will check individual ability ranges",
			},
				
			-- classIconToggle = {
				-- order = 47, 
				-- type = "group", 
				-- inline = true, 
				-- name = "Class Icon in place of Secondary Skill",
				-- args = {
					-- classIconToggle = {
						-- type = "toggle", 
						-- width = "full", 
						-- name = "On/Off",
						-- get = RotationGet, 
						-- set = RotationSet,
					-- },
				-- },
			-- },	
					
			trinketMode = {
				order = 47, 
				type = "group", 
				inline = true, 
				name = "Trinkets",
				args = {
					trinketMode = {
						type = "toggle", 
						width = "full", 
						name = "Suggest equipped on-use trinkets in Main Rotation",
						get = RotationGet, 
						set = RotationSet,
					},
				},
			},
			-- ups
				__behaviorSpacer = {
					order = 19,
					type = "header",
					name = "Update Frequency",
				},
				_behaviorDesc = {
					order = 20,
					type = "description",
					name = "These settings control how long the suggestion is displayed before allowing the next one to appear",
				},
				_behaviorDescSpacer = {
					order = 21,
					type = "description",
					name = "",
				},
				__behaviorDesc = {
					order = 21,
					type = "description",
					name = "|cff20A8F7Lower Number|r = Suggestion stays longer before moving on",
				},
				__behaviorDescSpacer = {
					order = 22,
					type = "description",
					name = "",
				},
				___behaviorDesc = {
					order = 23,
					type = "description",
					name = "|cffF54927Higher Number|r = Suggestion moves on quicker",
				},
				___behaviorDescSpacer = {
					order = 24,
					type = "description",
					name = "",
				},
				ups = {
					order = 25,
					type = "range",
					name = "|cffCDD615Rotation|r",
					min = 1,
					max = 100,
					step = 1,
					get = function(info) return db.rotation.updatesPerSecond end,
					set = function(info, val)
						db.rotation.updatesPerSecond = val
						clcret.scanFrequency = 1 / val
					end,
				},
				upsAuras =				{
					order = 27,
					type = "range",
					name = "|cffCDD615Aura Buttons|r",
					min = 1,
					max = 100,
					step = 1,
					get = function(info) return db.rotation.updatesPerSecondAuras end,
					set = function(info, val)
						db.rotation.updatesPerSecondAuras = val
						clcret.scanFrequencyAuras = 1 / val
					end,
				},
				____behaviorDescSpacer = {
					order = 28,
					type = "header",
					name = "",
				},
		},
	},
	
			appearance = {
			order = 10,
			name = "Appearance",
			type = "group",
			args = {	


				
				__buttonAspect = {
					type = "header",
					name = "Button Aspect",
					order = 2,
				},
				zoomIcons = {
					order = 3,
					type = "toggle",
					name = "Zoomed icons",
					get = function(info) return db.zoomIcons end,
					set = function(info, val)
						db.zoomIcons = val
						clcret:UpdateSkillButtonsLayout()
						clcret:UpdateAuraButtonsLayout()
					end,
				},
				noBorder = {
					order = 4,
					type = "toggle",
					name = "Hide border",
					get = function(info) return db.noBorder end,
					set = function(info, val)
						db.noBorder = val
						clcret:UpdateSkillButtonsLayout()
						clcret:UpdateAuraButtonsLayout()
					end,
				},
				borderColor = {
					order = 5,
					type = "color",
					name = "Border color",
					hasAlpha = true,
					get = function(info) return unpack(db.borderColor) end,
					set = function(info, r, g, b, a)
						db.borderColor = {r, g, b, a}
						clcret:UpdateSkillButtonsLayout()
						clcret:UpdateAuraButtonsLayout()
					end,
				},
				borderType = {
					order = 6,
					type = "select",
					name = "Border type",
					get = function(info) return db.borderType end,
					set = function(info, val)
						db.borderType = val
						clcret:UpdateSkillButtonsLayout()
						clcret:UpdateAuraButtonsLayout()
					end,
					values = { "Light", "Medium", "Heavy" }
				},
				-- grayOOM = {
					-- order = 7,
					-- type = "toggle",
					-- name = "Gray when OOM",
					-- get = function(info) return db.grayOOM end,
					-- set = function(info, val)
						-- db.grayOOM = val
						-- clcret:ResetButtonVertexColor()
					-- end,
				-- },
				
				__hudAspect = {
					type = "header",
					name = "HUD Aspect",
					order = 10,
				},
				scale = {
					order = 11,
					type = "range",
					name = "Scale",
					min = 0.01,
					max = 3,
					step = 0.01,
					get = function(info) return db.scale end,
					set = function(info, val)
						db.scale = val
						clcret:UpdateFrameSettings()
					end,
				},
				alpha = {
					order = 12,
					type = "range",
					name = "Alpha",
					min = 0,
					max = 1,
					step = 0.001,
					get = function(info) return db.alpha end,
					set = function(info, val)
						db.alpha = val
						clcret:UpdateFrameSettings()
					end,
				},
				_hudPosition = {
					type = "header",
					name = "HUD Position",
					order = 13,
				},
				x = {
					order = 20,
					type = "range",
					name = "X",
					min = 0,
					max = 5000,
					step = 21,
					get = function(info) return db.x end,
					set = function(info, val)
						db.x = val
						clcret:UpdateFrameSettings()
					end,
				},
				y = {
					order = 22,
					type = "range",
					name = "Y",
					min = 0,
					max = 3000,
					step = 1,
					get = function(info) return db.y end,
					set = function(info, val)
						db.y = val
						clcret:UpdateFrameSettings()
					end,
				},
				align = {
					order = 23,
					type = "execute",
					name = "Center Horizontally",
					func = function()
						clcret:CenterHorizontally()
					end,
				},
				_spacer = {
					order = 24,
					type = "description",
					name = "     ",
				},
				
				-- Main button
				main_spacer2 = {
					order = 32,
					type = "header",
					name = "Main Rotation Icon",
				},
				
				mainsize = {
					order = 34,
					type = "range",
					name = "Size",
					min = 1,
					max = 300,
					step = 1,
					get = function(info) return db.layout["button" .. 1].size end,
					set = function(info, val)
						db.layout["button" .. 1].size = val
						clcret:UpdateSkillButtonsLayout()
					end,
				},
				mainalpha = {
					order = 35,
					type = "range",
					name = "Alpha",
					min = 0,
					max = 1,
					step = 0.01,
					get = function(info) return db.layout["button" .. 1].alpha end,
					set = function(info, val)
						db.layout["button" .. 1].alpha = val
						clcret:UpdateSkillButtonsLayout()
					end,
				},
				mainanchor = {
					order = 36,
					type = "select",
					name = "Anchor",
					get = function(info) return db.layout["button" .. 1].point end,
					set = function(info, val)
						db.layout["button" .. 1].point = val
						clcret:UpdateSkillButtonsLayout()
					end,
					values = anchorPoints,
				},
				mainanchorTo = {
					order = 36,
					type = "select",
					name = "Anchor To",
					get = function(info) return db.layout["button" .. 1].pointParent end,
					set = function(info, val)
						db.layout["button" .. 1].pointParent = val
						clcret:UpdateSkillButtonsLayout()
					end,
					values = anchorPoints,
				},
				mainx = {
					order = 37,
					type = "range",
					name = "X",
					min = -1000,
					max = 1000,
					step = 1,
					get = function(info) return db.layout["button" .. 1].x end,
					set = function(info, val)
						db.layout["button" .. 1].x = val
						clcret:UpdateSkillButtonsLayout()
					end,
				},
				mainy = {
					order = 38,
					type = "range",
					name = "Y",
					min = -1000,
					max = 1000,
					step = 1,
					get = function(info) return db.layout["button" .. 1].y end,
					set = function(info, val)
						db.layout["button" .. 1].y = val
						clcret:UpdateSkillButtonsLayout()
					end,
				},
				main_spacer3 = {
					order = 39,
					type = "description",
					name = "",
				},
				
				-- Secondary button
					-- sec_spacer2 = {
					-- order = 42,
					-- type = "header",
					-- name = "Secondary Skill Button",
				-- },
				
				-- secsize = {
					-- order = 44,
					-- type = "range",
					-- name = "Size",
					-- min = 1,
					-- max = 300,
					-- step = 1,
					-- get = function(info) return db.layout["button" .. 2].size end,
					-- set = function(info, val)
						-- db.layout["button" .. 2].size = val
						-- clcret:UpdateSkillButtonsLayout()
					-- end,
				-- },
				-- secalpha = {
					-- order = 45,
					-- type = "range",
					-- name = "Alpha",
					-- min = 0,
					-- max = 1,
					-- step = 0.01,
					-- get = function(info) return db.layout["button" .. 2].alpha end,
					-- set = function(info, val)
						-- db.layout["button" .. 2].alpha = val
						-- clcret:UpdateSkillButtonsLayout()
					-- end,
				-- },
				-- secanchor = {
					-- order = 46,
					-- type = "select",
					-- name = "Anchor",
					-- get = function(info) return db.layout["button" .. 2].point end,
					-- set = function(info, val)
						-- db.layout["button" .. 2].point = val
						-- clcret:UpdateSkillButtonsLayout()
					-- end,
					-- values = anchorPoints,
				-- },
				-- secanchorTo = {
					-- order = 46,
					-- type = "select",
					-- name = "Anchor To",
					-- get = function(info) return db.layout["button" .. 2].pointParent end,
					-- set = function(info, val)
						-- db.layout["button" .. 2].pointParent = val
						-- clcret:UpdateSkillButtonsLayout()
					-- end,
					-- values = anchorPoints,
				-- },
				-- secx = {
					-- order = 47,
					-- type = "range",
					-- name = "X",
					-- min = -1000,
					-- max = 1000,
					-- step = 1,
					-- get = function(info) return db.layout["button" .. 2].x end,
					-- set = function(info, val)
						-- db.layout["button" .. 2].x = val
						-- clcret:UpdateSkillButtonsLayout()
					-- end,
				-- },
				-- secy = {
					-- order = 48,
					-- type = "range",
					-- name = "Y",
					-- min = -1000,
					-- max = 1000,
					-- step = 1,
					-- get = function(info) return db.layout["button" .. 2].y end,
					-- set = function(info, val)
						-- db.layout["button" .. 2].y = val
						-- clcret:UpdateSkillButtonsLayout()
					-- end,
				-- },
				
				
			},
		},
	
		rotation = clcret.RR_BuildOptions(),
		
		-- item tracking
		
			-- trinkets = {
		-- order = 29,
		-- name = "Trinket Trackers",
		-- type = "group",
		-- args = {
			-- ____info = {
				-- order = 1,
				-- type = "description",
				-- name = "Auto-tracking for equipped trinkets in slots 13 & 14.",
			-- },
			-- ____infospacer = {
				-- order = 2,
				-- type = "description",
				-- name = "",
			-- },
		-- },
	-- },
		
		
		
		
		auras = {
			order = 30,
			name = "CD Trackers",
			type = "group",
			args = {
			
		
			
					____info = {
						order = 1,
						type = "description",
						name = "Click the little Plus sign for Consumable/Item CD tracking options.",
					},
					____infospacer = {
						order = 2,
						type = "description",
						name = "",
					},
					____moreinfo = {
						order = 5,
						type = "description",
						name = "These can be used to track Consumables or Item CDs. They can NOT track buffs or spells.",
					},
				
			},
		},
	
	},
}

-- Dynamically add a toggle for each spec
for i = 1, GetNumSpecializations() do
	options.args.mainGlobal.args["spec"..i.."Enable"] = {
		order = 29,
		width = "full",
		type = "toggle",
		name = function()
		
			local specID, specName, _, icon = C_SpecializationInfo.GetSpecializationInfo(i)
			
			if specName and icon then
				return ("|T%s:16:16:0:0|t %s"):format(icon, specName)
			elseif specName then
				return specName
			end
			
			return "Spec " .. i
		end,
		
		get = function(info) return db["spec"..i.."Enable"] end,
        set = function(info, val)
            db["spec"..i.."Enable"] = val

            -- Check if this spec is now unchecked and if player is in this spec
            local currentSpec = C_SpecializationInfo.GetSpecialization()
            if not val and currentSpec == i then
                clcret:CLCRETDisable()
            elseif val and currentSpec == i then
                clcret:CLCRETEnable()
            end
        end,
		
    }
end

-- trinket aura duplicate
-- for f = 1, 2 do


-- local i = (MAX_AURAS + f)


-- options.args.auras.args

		



-- end


-- add the aura buttons to options
for i = 1, MAX_AURAS do
	-- aura options
	
	
local f = (i + 2)


		options.args.auras.args["Trinket" .. 1] = {
		order = 5.1,
		type = "group",
		name = "Trinket " .. 1,
		args = {
		
			_aurainfo = {
					order = 1,
					type = "description",
					name = "-This tracks the trinket in the Top Slot (Slot 13)",
				},
			_auraHead = {
					order = 1,
					type = "header",
					name = "Tracking Options",
				},
			enabled = {
				order = 1,
				type = "toggle",
				name = "Enabled",
				get = abgs.EnabledGet,
				set = abgs.EnabledSet,
			},
									procFlipbook = {
					order = 4,
					type = "toggle",
					name = "Proc Loop Effect",
					get = function(info) return db.auras[MAX_AURAS + 1].layout.procFlipbook end,
					set = function(info, val)
						db.auras[MAX_AURAS + 1].layout.procFlipbook = val
						clcret:UpdateAuraButtonLayout(MAX_AURAS + 1)
					end,
				},
			
						procFlipbook = {
				order = 4,
				type = "toggle",
				name = "Proc Loop Effect",
				get = function(info) return db.auras[MAX_AURAS + 1].layout.procFlipbook end,
				set = function(info, val)
					db.auras[MAX_AURAS + 1].layout.procFlipbook = val
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 1)
				end,
			},
			
			procFlipbookWidth = {
				order = 10,
				type = "range",
				name = "Glow Border Width",
				min = 1,
				max = 10,
				step = 1,
				get = function(info) return db.auras[MAX_AURAS + 1].layout.procFlipbookWidth end,
				set = function(info, val)
					db.auras[MAX_AURAS + 1].layout.procFlipbookWidth = val
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 1)
				end,
			},
			
			procFlipbookColor = {
				order = 4.2,
				type = "color",
				name = "Glow Color",
				hasAlpha = true,
				get = function(info) return unpack(db.auras[MAX_AURAS + 1].layout.procFlipbookColor) end,
				set = function(info, r, g, b, a)
					db.auras[MAX_AURAS + 1].layout.procFlipbookColor = {r, g, b, a}
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 1)
				end,
			},
			

			exec = {
				order = 4.1,
				type = "select",
				name = "Type",
				get = abgs.TrinketExecGet,
				set = abgs.TrinketExecSet,
				values = execList,
			},
			
			_auraSpace = {
					order = 18,
					type = "description",
					name = "",
				},
			___auraHead = {
					order = 18,
					type = "header",
					name = "Size & Positioning",
				},
			size = {
				order = 20,
				type = "range",
				name = "Size",
				min = 1,
				max = 300,
				step = 1,
				get = function(info) return db.auras[MAX_AURAS + 1].layout.size end,
				set = function(info, val)
					db.auras[MAX_AURAS + 1].layout.size = val
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 1)
				end,
			},
			_sizSpace = {
					order = 21,
					type = "description",
					name = "",
				},
			anchor = {
				order = 23,
				type = "select",
				name = "Anchor",
				get = function(info) return db.auras[MAX_AURAS + 1].layout.point end,
				set = function(info, val)
					db.auras[MAX_AURAS + 1].layout.point = val
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 1)
				end,
				values = anchorPoints,
			},
			anchorTo = {
				order = 25,
				type = "select",
				name = "Anchor To",
				get = function(info) return db.auras[MAX_AURAS + 1].layout.pointParent end,
				set = function(info, val)
					db.auras[MAX_AURAS + 1].layout.pointParent = val
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 1)
				end,
				values = anchorPoints,
			},
			x = {
				order = 27,
				type = "range",
				name = "X",
				min = -1000,
				max = 1000,
				step = 1,
				get = function(info) return db.auras[MAX_AURAS + 1].layout.x end,
				set = function(info, val)
					db.auras[MAX_AURAS + 1].layout.x = val
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 1)
				end,
			},
			y = {
				order = 28,
				type = "range",
				name = "Y",
				min = -1000,
				max = 1000,
				step = 1,
				get = function(info) return db.auras[MAX_AURAS + 1].layout.y end,
				set = function(info, val)
					db.auras[MAX_AURAS + 1].layout.y = val
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 1)
				end,
			},
		
		
	}
}


options.args.auras.args["Trinket" .. 2] = {
		order = 5.1,
		type = "group",
		name = "Trinket " .. 2,
		args = {
		
			_aurainfo = {
					order = 1,
					type = "description",
					name = "-This tracks the trinket in the Top Slot (Slot 13)",
				},
			_auraHead = {
					order = 1,
					type = "header",
					name = "Tracking Options",
				},
			enabled = {
				order = 1,
				type = "toggle",
				name = "Enabled",
				get = abgs.EnabledGet,
				set = abgs.EnabledSet,
			},
									procFlipbook = {
					order = 4,
					type = "toggle",
					name = "Proc Loop Effect",
					get = function(info) return db.auras[MAX_AURAS + 2].layout.procFlipbook end,
					set = function(info, val)
						db.auras[MAX_AURAS + 2].layout.procFlipbook = val
						clcret:UpdateAuraButtonLayout(MAX_AURAS + 2)
					end,
				},
			
						procFlipbook = {
				order = 4,
				type = "toggle",
				name = "Proc Loop Effect",
				get = function(info) return db.auras[MAX_AURAS + 2].layout.procFlipbook end,
				set = function(info, val)
					db.auras[MAX_AURAS + 2].layout.procFlipbook = val
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 2)
				end,
			},
			
			procFlipbookWidth = {
				order = 10,
				type = "range",
				name = "Glow Border Width",
				min = 1,
				max = 10,
				step = 1,
				get = function(info) return db.auras[MAX_AURAS + 2].layout.procFlipbookWidth end,
				set = function(info, val)
					db.auras[MAX_AURAS + 2].layout.procFlipbookWidth = val
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 2)
				end,
			},
			
			procFlipbookColor = {
				order = 4.2,
				type = "color",
				name = "Glow Color",
				hasAlpha = true,
				get = function(info) return unpack(db.auras[MAX_AURAS + 2].layout.procFlipbookColor) end,
				set = function(info, r, g, b, a)
					db.auras[MAX_AURAS + 2].layout.procFlipbookColor = {r, g, b, a}
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 2)
				end,
			},
			

			exec = {
				order = 4.1,
				type = "select",
				name = "Type",
				get = abgs.TrinketExecGet,
				set = abgs.TrinketExecSet,
				values = execList,
			},
			
			_auraSpace = {
					order = 18,
					type = "description",
					name = "",
				},
			___auraHead = {
					order = 18,
					type = "header",
					name = "Size & Positioning",
				},
			size = {
				order = 20,
				type = "range",
				name = "Size",
				min = 1,
				max = 300,
				step = 1,
				get = function(info) return db.auras[MAX_AURAS + 2].layout.size end,
				set = function(info, val)
					db.auras[MAX_AURAS + 2].layout.size = val
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 2)
				end,
			},
			_sizSpace = {
					order = 21,
					type = "description",
					name = "",
				},
			anchor = {
				order = 23,
				type = "select",
				name = "Anchor",
				get = function(info) return db.auras[MAX_AURAS + 2].layout.point end,
				set = function(info, val)
					db.auras[MAX_AURAS + 2].layout.point = val
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 2)
				end,
				values = anchorPoints,
			},
			anchorTo = {
				order = 25,
				type = "select",
				name = "Anchor To",
				get = function(info) return db.auras[MAX_AURAS + 2].layout.pointParent end,
				set = function(info, val)
					db.auras[MAX_AURAS + 2].layout.pointParent = val
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 2)
				end,
				values = anchorPoints,
			},
			x = {
				order = 27,
				type = "range",
				name = "X",
				min = -1000,
				max = 1000,
				step = 1,
				get = function(info) return db.auras[MAX_AURAS + 2].layout.x end,
				set = function(info, val)
					db.auras[MAX_AURAS + 2].layout.x = val
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 2)
				end,
			},
			y = {
				order = 28,
				type = "range",
				name = "Y",
				min = -1000,
				max = 1000,
				step = 1,
				get = function(info) return db.auras[MAX_AURAS + 2].layout.y end,
				set = function(info, val)
					db.auras[MAX_AURAS + 2].layout.y = val
					clcret:UpdateAuraButtonLayout(MAX_AURAS + 2)
				end,
			},
		
		
	}
}


	options.args.auras.args["CD Tracker" .. f] = {
		order = f + 10,
		type = "group",
		name = "CD Tracker " .. i,
		args = {
			
			
			_aurainfo = {
					order = 1,
					type = "description",
					name = "-These are cooldown watchers. You can select an item or consumable to watch.",
				},
			_aurainfo2 = {
					order = 1,
					type = "description",
					name = "-You can NOT track Buffs/Debuffs or Spells.",
				},
			_auraHead = {
					order = 1,
					type = "header",
					name = "Item Trackers",
				},
			enabled = {
				order = 1,
				type = "toggle",
				name = "Enabled",
				get = abgs.EnabledGet,
				set = abgs.EnabledSet,
			},
			
	
							procFlipbook = {
					order = 4,
					type = "toggle",
					name = "Proc Loop Effect",
					get = function(info) return db.auras[i].layout.procFlipbook end,
					set = function(info, val)
						db.auras[i].layout.procFlipbook = val
						clcret:UpdateAuraButtonLayout(i)
					end,
				},
			
						procFlipbook = {
				order = 4,
				type = "toggle",
				name = "Proc Loop Effect",
				get = function(info) return db.auras[i].layout.procFlipbook end,
				set = function(info, val)
					db.auras[i].layout.procFlipbook = val
					clcret:UpdateAuraButtonLayout(i)
				end,
			},
			
			procFlipbookWidth = {
				order = 10,
				type = "range",
				name = "Glow Border Width",
				min = 1,
				max = 10,
				step = 1,
				get = function(info) return db.auras[i].layout.procFlipbookWidth end,
				set = function(info, val)
					db.auras[i].layout.procFlipbookWidth = val
					clcret:UpdateAuraButtonLayout(i)
				end,
			},
			
			procFlipbookColor = {
				order = 4.2,
				type = "color",
				name = "Glow Color",
				hasAlpha = true,
				get = function(info) return unpack(db.auras[i].layout.procFlipbookColor) end,
				set = function(info, r, g, b, a)
					db.auras[i].layout.procFlipbookColor = {r, g, b, a}
					clcret:UpdateAuraButtonLayout(i)
				end,
			},
			
			spell = {
				order = 5,
				type = "input",
				name = "Item name/id to track",
				get = abgs.SpellGet,
				set = abgs.SpellSet,
			},
			exec = {
				order = 4.1,
				type = "select",
				name = "Type",
				get = abgs.ExecGet,
				set = abgs.ExecSet,
				values = execList,
			},
			_auraSpace = {
					order = 18,
					type = "description",
					name = "",
				},
			___auraHead = {
					order = 18,
					type = "header",
					name = "Size & Positioning",
				},
			size = {
				order = 20,
				type = "range",
				name = "Size",
				min = 1,
				max = 300,
				step = 1,
				get = function(info) return db.auras[i].layout.size end,
				set = function(info, val)
					db.auras[i].layout.size = val
					clcret:UpdateAuraButtonLayout(i)
				end,
			},
			_sizSpace = {
					order = 21,
					type = "description",
					name = "",
				},
			anchor = {
				order = 23,
				type = "select",
				name = "Anchor",
				get = function(info) return db.auras[i].layout.point end,
				set = function(info, val)
					db.auras[i].layout.point = val
					clcret:UpdateAuraButtonLayout(i)
				end,
				values = anchorPoints,
			},
			anchorTo = {
				order = 25,
				type = "select",
				name = "Anchor To",
				get = function(info) return db.auras[i].layout.pointParent end,
				set = function(info, val)
					db.auras[i].layout.pointParent = val
					clcret:UpdateAuraButtonLayout(i)
				end,
				values = anchorPoints,
			},
			x = {
				order = 27,
				type = "range",
				name = "X",
				min = -1000,
				max = 1000,
				step = 1,
				get = function(info) return db.auras[i].layout.x end,
				set = function(info, val)
					db.auras[i].layout.x = val
					clcret:UpdateAuraButtonLayout(i)
				end,
			},
			y = {
				order = 28,
				type = "range",
				name = "Y",
				min = -1000,
				max = 1000,
				step = 1,
				get = function(info) return db.auras[i].layout.y end,
				set = function(info, val)
					db.auras[i].layout.y = val
					clcret:UpdateAuraButtonLayout(i)
				end,
			},
		},
	
	}
end


-- for i = 1, 2 do
	-- trinket options
	-- options.args.auras.args["Trinket" .. i] = {
		-- order = i + 30,
		-- type = "group",
		-- name = "Trinket " .. i,
		-- args = {
		
			-- _aurainfot = {
					-- order = 1,
					-- type = "description",
					-- name = "-These are cooldown watchers. You can select an item or consumable to watch.",
				-- },
			-- _aurainfo2 = {
					-- order = 1,
					-- type = "description",
					-- name = "-You can NOT track Buffs/Debuffs or Spells.",
				-- },
			-- _auraHeadt = {
					-- order = 1,
					-- type = "header",
					-- name = "Item Trackers",
				-- },
			-- enabledt = {
				-- order = 1,
				-- type = "toggle",
				-- name = "Enabled",
				-- get = abgs.EnabledGet,
				-- set = abgs.EnabledSet,
			-- },
			
	
					-- procFlipbook = {
					-- order = 4,
					-- type = "toggle",
					-- name = "Proc Loop Effect",
					-- get = function(info) return db.auras[i].layout.procFlipbook end,
					-- set = function(info, val)
						-- db.auras[i].layout.procFlipbook = val
						-- clcret:UpdateAuraButtonLayout(i)
					-- end,
				-- },
			
				-- procFlipbook = {
				-- order = 4,
				-- type = "toggle",
				-- name = "Proc Loop Effect",
				-- get = function(info) return db.auras[i].layout.procFlipbook end,
				-- set = function(info, val)
					-- db.auras[i].layout.procFlipbook = val
					-- clcret:UpdateAuraButtonLayout(i)
				-- end,
			-- },
			
			-- procFlipbookWidth = {
				-- order = 10,
				-- type = "range",
				-- name = "Glow Border Width",
				-- min = 1,
				-- max = 10,
				-- step = 1,
				-- get = function(info) return db.auras[i].layout.procFlipbookWidth end,
				-- set = function(info, val)
					-- db.auras[i].layout.procFlipbookWidth = val
					-- clcret:UpdateAuraButtonLayout(i)
				-- end,
			-- },
			
			-- procFlipbookColor = {
				-- order = 4.2,
				-- type = "color",
				-- name = "Glow Color",
				-- hasAlpha = true,
				-- get = function(info) return unpack(db.auras[i].layout.procFlipbookColor) end,
				-- set = function(info, r, g, b, a)
					-- db.auras[i].layout.procFlipbookColor = {r, g, b, a}
					-- clcret:UpdateAuraButtonLayout(i)
				-- end,
			-- },
			
			-- spell = {
				-- order = 5,
				-- type = "input",
				-- name = "Item name/id to track",
				-- get = abgs.SpellGet,
				-- set = abgs.SpellSet,
			-- },
			-- exec = {
				-- order = 4.1,
				-- type = "select",
				-- name = "Type",
				-- get = abgs.ExecGet,
				-- set = abgs.ExecSet,
				-- values = execList,
			-- },
			-- _auraSpace = {
					-- order = 18,
					-- type = "description",
					-- name = "",
				-- },
			-- ___auraHead = {
					-- order = 18,
					-- type = "header",
					-- name = "Size & Positioning",
				-- },
			-- size = {
				-- order = 20,
				-- type = "range",
				-- name = "Size",
				-- min = 1,
				-- max = 300,
				-- step = 1,
				-- get = function(info) return db.auras[i].layout.size end,
				-- set = function(info, val)
					-- db.auras[i].layout.size = val
					-- clcret:UpdateAuraButtonLayout(i)
				-- end,
			-- },
			-- _sizSpace = {
					-- order = 21,
					-- type = "description",
					-- name = "",
				-- },
			-- anchor = {
				-- order = 23,
				-- type = "select",
				-- name = "Anchor",
				-- get = function(info) return db.auras[i].layout.point end,
				-- set = function(info, val)
					-- db.auras[i].layout.point = val
					-- clcret:UpdateAuraButtonLayout(i)
				-- end,
				-- values = anchorPoints,
			-- },
			-- anchorTo = {
				-- order = 25,
				-- type = "select",
				-- name = "Anchor To",
				-- get = function(info) return db.auras[i].layout.pointParent end,
				-- set = function(info, val)
					-- db.auras[i].layout.pointParent = val
					-- clcret:UpdateAuraButtonLayout(i)
				-- end,
				-- values = anchorPoints,
			-- },
			-- x = {
				-- order = 27,
				-- type = "range",
				-- name = "X",
				-- min = -1000,
				-- max = 1000,
				-- step = 1,
				-- get = function(info) return db.auras[i].layout.x end,
				-- set = function(info, val)
					-- db.auras[i].layout.x = val
					-- clcret:UpdateAuraButtonLayout(i)
				-- end,
			-- },
			-- y = {
				-- order = 28,
				-- type = "range",
				-- name = "Y",
				-- min = -1000,
				-- max = 1000,
				-- step = 1,
				-- get = function(info) return db.auras[i].layout.y end,
				-- set = function(info, val)
					-- db.auras[i].layout.y = val
					-- clcret:UpdateAuraButtonLayout(i)
				-- end,
			-- },
			
			
		-- },
	
	-- }
-- end

	local AceConfig = LibStub("AceConfig-3.0")
	AceConfig:RegisterOptionsTable("CLCRet", options)

	-- Profiles
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(clcret.db)
	options.args.profiles.order = 900

	if C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel then
        LibStub("AceConfigDialog-3.0"):Open("CLCRet");
        return;
    end
