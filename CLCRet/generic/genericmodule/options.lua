local _, class = UnitClass("player")
local spec = GetSpecialization()
-- if class ~= "PALADIN" then return end -- change to correct class!!!

local _, xmod = ...
xmod = xmod.genericmodule -- change to spec module!!!

local db

local function Get(info)
	return db[info[#info]]
end

local function Set(info, val)
	db[info[#info]] = val
	
	if info[#info] == "genericprio" then -- change genericprio to specprio!!!
		xmod.Update()
	end
end

function xmod.BuildOptions()
	db = xmod.db
	
	-- legend for the actions
	local tx = {}
	local actions
	
	if xmod and xmod.GetActions then
		actions = xmod.GetActions()
	else
		actions = {}
	end

		for k, v in pairs(actions) do
		table.insert(tx, format("\n%s - %s", k, v.info))
		end
		table.sort(tx)
		
	local prioInfo = "Legend:\n" .. table.concat(tx)

	return {
		order = 1, 
		type = "group", 
		childGroups = "tab", 
		name = "Generic Module", -- change Generic to Spec!!!
		args = {
			priotabdesc = {
			order = 1,
			type = "description",
			name = "You can't set a rotation in this module!",
			},
			-- _priotabdesc = {
			-- order = 2,
			-- type = "description",
			-- name = "The secondary suggestion reverts to your Class icon in this module!",
			-- },
			
			-- tabPriority = {
			-- order = 1, 
			-- type = "group", 
			-- name = "Priority", 
			-- args = {
				-- igPrio = {
				-- order = 1, 
				-- type = "group", 
				-- inline = true, 
				-- name = "",
					-- args = {
						-- info = {
							-- order = 1, 
							-- type = "description", 
							-- name = prioInfo,
							-- },
							-- normalPrio = {
								-- order = 2, type="group", inline = true, name = "Priority",
								-- args = {
									-- genericprio = { -- change genericprio to specprio!!!
										-- order = 2, 
										-- type = "input", 
										-- width = "full", 
										-- name = "",
										-- get = Get, set = Set,
									-- },
								-- },
							-- },
						-- },
					-- },
				-- },
			-- },
			
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
								-- activate the comment/comment out the alternative line when a melee range check option is needed
								-- values = { _rangeoff = "Off", rangemelee = "Melee Range", rangeperability = "Per Ability" } -- with melee check
								values = { _rangeoff = "Off", rangeperability = "Per Ability" } -- without melee check
							},
							oneDesc = {
								order = 12,
								type = "description",
								name = "|cffFF0000OFF|r Range check is turned off",
							},
						-- activate the following when melee range check is needed
						-- --------------------------------------------------------------------
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
						-- ---------------------------------------------------------------------
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
					
					-- BlizzMode = {
						-- order = 46, 
						-- type = "group", 
						-- inline = true, 
						-- name = "Blizzard's Assisted Combat API",
						-- args = {
							-- BlizzMode = {
							-- type = "toggle",
							-- width = "full",
							-- name = "Use Blizzard's Assisted Combat API to determine Main Skill priority",
								-- get = function(info)
								-- local specID = C_SpecializationInfo.GetSpecialization()
								-- return clcret.db.profile.rotation.specBlizzMode[specID] or false
							-- end,
								-- set = function(info, val)
								-- local specID = C_SpecializationInfo.GetSpecialization()
								-- clcret.db.profile.rotation.specBlizzMode[specID] = val
							-- end,
							-- }
						-- },
					-- },				
					
					classIconToggle = {
						order = 47, 
						type = "group", 
						inline = true, 
						name = "Class Icon in place of Secondary Skill",
						args = {
							classIconToggle = {
								type = "toggle", 
								width = "full", 
								name = "On/Off",
								get = Get, 
								set = Set,
							},
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
					
					-- Activate AOE mode setting as needed per spec. Spell used to detect AOE is set in spec rotation file
						-- aoeMode = {
						-- order = 2, 
						-- type = "group", 
						-- inline = true, 
						-- name = "AOE Mode",
						-- args = {
							-- aoeMode = {
								-- type = "toggle", 
								-- width = "full", 
								-- name = "Detect AOE: Addon will attempt to detect when to use AOE",
								-- get = Get, set = Set,
							-- },
						-- },
					-- },	
					
				},
			},			
		},
	}
end