local _, trueclass = UnitClass("player")

clcret.optionsLoaded = true

local MAX_AURAS = 20

local db = clcret.db.profile
local root

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
-- Aura Butoon stuff
-- -------------------
local execList = {
	AuraButtonExecaNone = "None",
	AuraButtonExecSkillVisibleAlways = "Skill always visible",
	AuraButtonExecSkillVisibleNoCooldown = "Skill visible off CD",
	AuraButtonExecSkillVisibleOnCooldown = "Skill visible on CD",
	AuraButtonExecSkillVisibleOnCooldown2 = "---",
	AuraButtonExecItemVisibleAlways = "Item always visible",
	AuraButtonExecItemVisibleNoCooldown = "Item visible off CD",
	AuraButtonExecItemVisibleNoCooldownEquip = "Equipped; visible off CD",
	AuraButtonExecItemVisibleNoCooldownEquip2 = "---",
	AuraButtonExecPlayerMissingBuff = "Missing player buff",
	AuraButtonExecPlayerMissingBuff2 = "---",
}
-- index lookup for aura buttons
local ilt = {}
for i = 1, MAX_AURAS do
	ilt["aura" .. i] = i
end
-- aura buttons get/set functions
local abgs = {}

function abgs:UpdateAll()
	clcret:UpdateEnabledAuraButtons()
	clcret:UpdateAuraButtonsCooldown()
	clcret:AuraButtonUpdateICD()
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
	if db.auras[i].data.spell == "" then
		val = false
		print("Not a valid spell name/id or buff name!")
	end
	db.auras[i].enabled = val
	if not val then clcret:AuraButtonHide(i) end
	abgs:UpdateAll()
end
-- id/name field
function abgs:SpellGet()
	local i = ilt[self[2]]
	
	-- special case for items since link is used instead of name
	if (db.auras[i].data.exec == "AuraButtonExecItemVisibleAlways") or (db.auras[i].data.exec == "AuraButtonExecItemVisibleNoCooldown") then
		return db.auras[i].data.spell
	elseif db.auras[i].data.exec == "AuraButtonExecICDItem" then
		return C_Spell.GetSpellInfo(db.auras[i].data.spell)
	end
	return db.auras[i].data.spell
end
function abgs:SpellSet(val)
	local i = ilt[self[2]]
	
	-- skill
	if (db.auras[i].data.exec == "AuraButtonExecSkillVisibleAlways") or (db.auras[i].data.exec == "AuraButtonExecSkillVisibleNoCooldown") or (db.auras[i].data.exec == "AuraButtonExecSkillVisibleOnCooldown") then
		local name = C_Spell.GetSpellInfo(val)
		if name then
			db.auras[i].data.spell = name
		else
			db.auras[i].data.spell = ""
			db.auras[i].enabled = false
			clcret:AuraButtonHide(i)
			print("Not a valid spell name or id !")
		end
	-- item
	elseif (db.auras[i].data.exec == "AuraButtonExecItemVisibleAlways") or (db.auras[i].data.exec == "AuraButtonExecItemVisibleNoCooldown") then
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
	elseif (db.auras[i].data.exec == "AuraButtonExecICDItem") then
		local tid = tonumber(val)
		local name = C_Spell.GetSpellInfo(tid)
		if name then
			db.auras[i].data.spell = tid
		else
			db.auras[i].data.spell = ""
			db.auras[i].enabled = false
			clcret:AuraButtonHide(i)
			print("Not a valid spell id!")
		end
	else
		db.auras[i].data.spell = val
	end
	
	abgs:UpdateAll()
end
-- type select
function abgs:ExecGet()
	local i = ilt[self[2]]
	
	return db.auras[i].data.exec
end
function abgs:ExecSet(val)
	local i = ilt[self[2]]
	local aura = db.auras[i]
	
	-- reset every other setting when this is changed
	aura.enabled = false
	aura.data.spell = ""
	aura.data.unit = ""
	aura.data.byPlayer = false
	clcret:AuraButtonHide(i)
	
	aura.data.exec = val
	
	abgs:UpdateAll()
end
-- target field
function abgs:UnitGet()
	local i = ilt[self[2]]
	
	return db.auras[i].data.unit
end
function abgs:UnitSet(val)
	local i = ilt[self[2]]
	
	db.auras[i].data.unit = val
	abgs:UpdateAll()
end
-- cast by player toggle
function abgs:ByPlayerGet()
	local i = ilt[self[2]]
	
	return db.auras[i].data.byPlayer
end
function abgs:ByPlayerSet(val)
	local i = ilt[self[2]]
	
	db.auras[i].data.byPlayer = val
	abgs:UpdateAll()
end

local skillButtonNames = { "Main skill", "Secondary skill" }

-- things n stuff
local function RotationGet(info)
	local xdb = clcret.db.profile.rotation
	return xdb[info[#info]]
end

local function RotationSet(info, val)
	local xdb = clcret.db.profile.rotation
	xdb[info[#info]] = val
	
	if info[#info] == "prio" then
		clcret.RR_UpdateQueue()
	end
end

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
		global = {
			type = "group",
			name = "Information",
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
					name = "-If available, the Rotation settings will automatically change the Options for your spec (You will still have to manually /Reload your UI, though)",
				},
				spacerTwo = {
					order = 21,
					type = "description",
					name = "",
				},
				twoDesc = {
					order = 22,
					type = "description",
					name = "-The addon has a built in shortcut command: You can type /rl instead of the full /reload",
				},
				spacerThree = {
					order = 31,
					type = "description",
					name = "",
				},
				threeDesc = {
					order = 32,
					type = "description",
					name = "-To activate AOE mode (if available for your spec) go to Rotation > Rotation Settings",
				},
				spacerFour = {
					order = 41,
					type = "description",
					name = "",
				},
				fourDesc = {
					order = 42,
					type = "description",
					name = "-To activate Trinket suggestions (if available for your spec) go to Rotation > Rotation Settings. If you see a Gear icon, it means the addon could not load the icon and is suggesting your on-use trinket",
				},
				headerFive = {
					order = 45,
					type = "header",
					name = "Generic Module Information",
				},
				spacerFive = {
					order = 51,
					type = "description",
					name = "",
				},
				fiveDesc = {
					order = 52,
					type = "description",
					name = "-If a rotation module is not available for your spec, it will use the 'Generic' module.",
				},
				spacerFiveone = {
					order = 54,
					type = "description",
					name = "",
				},
				fiveoneDesc = {
					order = 55,
					type = "description",
					name = "-If you're in the United States, it's half the cost of Brand Name and probabaly covered by your insurance with a small co-pay. Everyone else is 100% covered",
				},
				spacerSix = {
					order = 61,
					type = "description",
					name = "",
				},
				sixDesc = {
					order = 62,
					type = "description",
					name = "-The 'Generic' module uses Blizzard's Rotation Assist API to determine the next action, and cannot go beyond the main suggestion.",
				},
				spacerSeven = {
					order = 71,
					type = "description",
					name = "",
				},
				sevenDesc = {
					order = 72,
					type = "description",
					name = "-By default, the 'Generic' module uses the class icon in place of the next suggestion. This can be turned off in 'Rotation Settings'. The class icon used in the 'Generic' module can look similar to a class ability, so turn it off if you get confused.",
				},
				
			},
		},
		
		mainGlobal = {
			type = "group",
			name = "Global",
			order = 9,
			args = {
			
				show = {
					order = 10,
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
					name = "|cffF54927Higher Number|r = Suggestions move really quick (possibly faster than you can react)",
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
					get = function(info) return db.updatesPerSecond end,
					set = function(info, val)
						db.updatesPerSecond = val
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
					get = function(info) return db.updatesPerSecondAuras end,
					set = function(info, val)
						db.updatesPerSecondAuras = val
						clcret.scanFrequencyAuras = 1 / val
					end,
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
	
		appearance = {
			order = 10,
			name = "Appearance",
			type = "group",
			args = {	

				-- lock frame
				lock = {
					order = 1,
					width = "full",
					type = "toggle",
					name = "Lock Frame",
					get = function(info) return clcret.locked end,
					set = function(info, val)
						clcret:ToggleLock()
					end,
				},
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
				grayOOM = {
					order = 7,
					type = "toggle",
					name = "Gray when OOM",
					get = function(info) return db.grayOOM end,
					set = function(info, val)
						db.grayOOM = val
						clcret:ResetButtonVertexColor()
					end,
				},
				
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
				_skillPosition = {
					type = "header",
					name = "Skill Button Positions",
					order = 27,
				},
				_spacer2 = {
					order = 32,
					type = "description",
					name = "        ",
				},
			},
		},
	
		rotation = clcret.RR_BuildOptions(),
		
		-- aura buttons
		auras = {
			order = 30,
			name = "Aura Buttons",
			type = "group",
			args = {
				____info = {
					order = 1,
					type = "description",
					name = "These are cooldown watchers. You can select a player skill, an item or a buff/debuff (on a valid target) to watch.\nItems and skills only need a valid item/spell id (or name) and the type. Target (the target to scan) and Cast by player (filters or not buffs cast by others) are specific to buffs/debuffs.\nValid targets are the ones that work with /cast [target=name] macros. For example: player, target, focus, raid1, raid1target.\n\nICD Proc:\nYou need to specify a valid proc ID (example: 60229 for Greatness STR proc) Name doesn't work, if the ID is valid it will be replaced by the name after the edit.\nIn the \"Target unit\" field you have to enter the ICD and duration of the proc separated by \":\" (example: for Greatness the value should be 45:15).",
				},
			},
		},
		-- layout
		layout = {
			order = 31,
			name = "Layout",
			type = "group",
			args = {},
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

	-- add main buttons to "Appearance"
for i = 1, 2 do
	options.args.appearance.args["button" .. i] = {
		order = 29,
		name = skillButtonNames[i],
		type = "group",
		args = {
			size = {
				order = 1,
				type = "range",
				name = "Size",
				min = 1,
				max = 300,
				step = 1,
				get = function(info) return db.layout["button" .. i].size end,
				set = function(info, val)
					db.layout["button" .. i].size = val
					clcret:UpdateSkillButtonsLayout()
				end,
			},
			alpha = {
				order = 2,
				type = "range",
				name = "Alpha",
				min = 0,
				max = 1,
				step = 0.01,
				get = function(info) return db.layout["button" .. i].alpha end,
				set = function(info, val)
					db.layout["button" .. i].alpha = val
					clcret:UpdateSkillButtonsLayout()
				end,
			},
			anchor = {
				order = 6,
				type = "select",
				name = "Anchor",
				get = function(info) return db.layout["button" .. i].point end,
				set = function(info, val)
					db.layout["button" .. i].point = val
					clcret:UpdateSkillButtonsLayout()
				end,
				values = anchorPoints,
			},
			anchorTo = {
				order = 6,
				type = "select",
				name = "Anchor To",
				get = function(info) return db.layout["button" .. i].pointParent end,
				set = function(info, val)
					db.layout["button" .. i].pointParent = val
					clcret:UpdateSkillButtonsLayout()
				end,
				values = anchorPoints,
			},
			x = {
				order = 10,
				type = "range",
				name = "X",
				min = -1000,
				max = 1000,
				step = 1,
				get = function(info) return db.layout["button" .. i].x end,
				set = function(info, val)
					db.layout["button" .. i].x = val
					clcret:UpdateSkillButtonsLayout()
				end,
			},
			y = {
				order = 11,
				type = "range",
				name = "Y",
				min = -1000,
				max = 1000,
				step = 1,
				get = function(info) return db.layout["button" .. i].y end,
				set = function(info, val)
					db.layout["button" .. i].y = val
					clcret:UpdateSkillButtonsLayout()
				end,
			},
		},
	}
end

-- add the aura buttons to options
for i = 1, MAX_AURAS do
	-- aura options
	options.args.auras.args["aura" .. i] = {
		order = i + 10,
		type = "group",
		name = "Aura Button " .. i,
		args = {
			_auraHead = {
					order = 1,
					type = "header",
					name = "Aura Buttons",
				},
			enabled = {
				order = 1,
				type = "toggle",
				name = "Enabled",
				get = abgs.EnabledGet,
				set = abgs.EnabledSet,
			},
			byPlayer = {
				order = 2,
				type = "toggle",
				name = "Cast by player",
				get = abgs.ByPlayerGet,
				set = abgs.ByPlayerSet,
			},
			spell = {
				order = 5,
				type = "input",
				name = "Spell/item name/id or buff to track",
				get = abgs.SpellGet,
				set = abgs.SpellSet,
			},
			exec = {
				order = 10,
				type = "select",
				name = "Type",
				get = abgs.ExecGet,
				set = abgs.ExecSet,
				values = execList,
			},
			unit = {
				order = 15,
				type = "input",
				name = "Target unit",
				get = abgs.UnitGet,
				set = abgs.UnitSet,
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

local AceConfig = LibStub("AceConfig-3.0")
AceConfig:RegisterOptionsTable("CLCRet", options)

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
AceConfigDialog:AddToBlizOptions("CLCRet", "CLCRet", nil, "global")
AceConfigDialog:AddToBlizOptions("CLCRet", "Global Options", "CLCRet", "mainGlobal")
AceConfigDialog:AddToBlizOptions("CLCRet", "Appearance", "CLCRet", "appearance")
AceConfigDialog:AddToBlizOptions("CLCRet", "Rotation", "CLCRet", "rotation")
AceConfigDialog:AddToBlizOptions("CLCRet", "Aura Buttons", "CLCRet", "auras")

-- profiles
options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(clcret.db)
options.args.profiles.order = 900
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("CLCRet", "Profiles", "CLCRet", "profiles")

Settings.OpenToCategory("CLCRet")