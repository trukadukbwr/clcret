local _, class = UnitClass("player")
local spec = GetSpecialization()
if class ~= "MAGE" then return end -- change to correct class!!!

local _, xmod = ...
xmod = xmod.firemagemodule -- change to spec module!!!

local db

local function Get(info)
	return db[info[#info]]
end

local function Set(info, val)
	db[info[#info]] = val
	
	if info[#info] == "fireprio" then -- change genericprio to specprio!!!
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
		name = "Fire Mage", -- change Generic to Spec!!!
		args = {
			tabPriority = {
			order = 1, 
			type = "group", 
			name = "Priority", 
			args = {
				igPrio = {
				order = 1, 
				type = "group", 
				inline = true, 
				name = "",
					args = {
						info = {
							order = 1, 
							type = "description", 
							name = prioInfo,
							},
							normalPrio = {
								order = 2, type="group", inline = true, name = "Priority",
								args = {
									fireprio = { -- change genericprio to specprio!!!
										order = 2, 
										type = "input", 
										width = "full", 
										name = "",
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