-- don't load if class is wrong
local _, class = UnitClass("player")
if class ~= "WARRIOR" then return end

local _, xmod = ...
xmod = xmod.furywarriormodule
local db

local function Get(info)
	return db[info[#info]]
end

local function Set(info, val)
	db[info[#info]] = val
	
	if info[#info] == "furyprio" then
		xmod.Update()
	end
end

function xmod.BuildOptions()
	db = xmod.db

	-- legend for the actions
	local tx = {}
	local actions = xmod.GetActions()
	for k, v in pairs(actions) do
		table.insert(tx, format("\n%s - %s", k, v.info))
	end
	table.sort(tx)
	local prioInfo = "Legend:\n" .. table.concat(tx)

	return {
		order = 1, type = "group", childGroups = "tab", name = "Fury",
		args = {
			tabPriority = {
				order = 1, type = "group", name = "Priority", args = {
					igPrio = {
						order = 1, type = "group", inline = true, name = "",
						args = {
							info = {
								order = 1, type = "description", name = prioInfo,
							},
							normalPrio = {
								order = 2, type="group", inline = true, name = "Normal priority",
								args = {
									furyprio = {
										order = 2, type = "input", width = "full", name = "",
										get = Get, set = Set,
									},
								},
							},
						},
					},
				},
			},
			tabSettings = {
				order = 3, 
				type = "group", 
				name = "Rotation Settings", 
				args = {
							rangeCheckSkill = {
								order = 1,
								type = "select",
								name = "Range Check",
								get = function(info) return db.rangeCheckSkill end,
								set = function(info, val)
									db.rangeCheckSkill = val
								end,
								-- values = { _rangeoff = "Off", rangemelee = "Melee Range", rangeperability = "Per Ability" } -- with melee check
								values = { _rangeoff = "Off", rangeperability = "Per Ability" } -- without melee check
							},
							oneDesc = {
								order = 12,
								type = "description",
								name = "|cffFF0000OFF|r Range check is turned off",
							},
							-- spacerTwo = {
								-- order = 21,
								-- type = "description",
								-- name = "",
							-- },
							-- twoDesc = {
								-- order = 22,
								-- type = "description",
								-- name = "|cffFFF200MELEE RANGE|r Range check will check for melee range, regardless of actual ability range",
							-- },
							spacerThree = {
								order = 31,
								type = "description",
								name = "",
							},
							threeDesc = {
								order = 32,
								type = "description",
								name = "|cff35FF00PER ABILITY|r Range check will check individual ability ranges",
							},
							_rangeCheckSkillEnd = {
								order = 35,
								type = "header",
								name = "",
							},
							__rangeCheckSkillEnd = {
								order = 5,
								type = "header",
								name = "",
							},
					-- aoeMode = { -- Activate AOE mode setting as needed per spec. Spell used to detect AOE is set in spec rotation file!!!
						-- order = 2, 
						-- type = "group", 
						-- inline = true, 
						-- name = "AOE Mode",
						-- args = {
							-- aoeMode = {
								-- type = "toggle", 
								-- width = "full", 
								-- name = "Detect AOE: |cffF58CBACLCRet|r will attempt to detect when to use AOE",
								-- get = Get, set = Set,
							-- },
						-- },
					-- },		
					
					BlizzMode = {
						order = 46, 
						type = "group", 
						inline = true, 
						name = "Blizzard's Assisted Combat API",
						args = {
							BlizzMode = {
							type = "toggle",
							width = "full",
							name = "Use Blizzard's Assisted Combat API to determine Main Skill priority",
								get = function(info)
								local specID = C_SpecializationInfo.GetSpecialization()
								return clcret.db.profile.rotation.specBlizzMode[specID] or false
							end,
								set = function(info, val)
								local specID = C_SpecializationInfo.GetSpecialization()
								clcret.db.profile.rotation.specBlizzMode[specID] = val
							end,
							}
						},
					},	
					
					trinketMode = {
						order = 47, 
						type = "group", 
						inline = true, 
						name = "Trinkets",
						args = {
							trinketMode = {
								type = "toggle", 
								width = "full", 
								name = "Suggest usable trinkets as Main Skill priority",
								get = Get, 
								set = Set,
							},
						},
					},	
					
				},
			},
		},
	}
end
