local _, class = UnitClass("player")
local _, xmod = ...

-- Only set default values if not present/empty
	local function EnsureDefaults(db_rotation, defaults)
		for k, v in pairs(defaults) do
			if db_rotation[k] == nil or db_rotation[k] == "" then
				db_rotation[k] = v
			end
		end
	end

-- Avoid errors before init
clcret.RR_UpdateQueue = function() end
clcret.Rotation = function() end
clcret.RR_BuildOptions = function() end

local function clcInit()
	
	local spec = C_SpecializationInfo.GetSpecialization()	
	if not spec or spec == 0 then
		-- Wait for spec to load if not available yet
		C_Timer.After(0.5, clcInit)
		return
	end
	
	local activeModule
	
	-- Paladin Modules
	if class == "PALADIN" then
		if spec == 1 and xmod.holypaladinmodule then
			activeModule = xmod.holypaladinmodule
		elseif spec == 2 and xmod.protectionpaladinmodule then
			activeModule = xmod.protectionpaladinmodule
		elseif spec == 3 and xmod.retributionpaladinmodule then
			activeModule = xmod.retributionpaladinmodule
		end

	-- Warrior Modules
	elseif class == "WARRIOR" then
		if spec == 1 and xmod.armswarriormodule then
			activeModule = xmod.armswarriormodule
		elseif spec == 2 and xmod.furywarriormodule then
			activeModule = xmod.furywarriormodule
		elseif spec == 3 and xmod.protectionwarriormodule then
		    activeModule = xmod.protectionwarriormodule
		end

	-- DK Modules
	elseif class == "DEATHKNIGHT" then
		if spec == 1 and xmod.blooddeathknightmodule then
			activeModule = xmod.blooddeathknightmodule
		elseif spec == 2 and xmod.frostdeathknightmodule then
			activeModule = xmod.frostdeathknightmodule
		elseif spec == 3 and xmod.unholydeathknightmodule then
		    activeModule = xmod.unholydeathknightmodule
		end
	
	-- DH Modules
	elseif class == "DEMONHUNTER" then
		if spec == 1 and xmod.havocdemonhuntermodule then
			activeModule = xmod.havocdemonhuntermodule
		elseif spec == 2 and xmod.vengeancedemonhuntermodule then
			activeModule = xmod.vengeancedemonhuntermodule
		-- elseif spec == 3 and xmod.annihilatordemonhuntermodule then -- (Midnight) (Placeholder)
		    -- activeModule = xmod.annihilatordemonhuntermodule
		end
		
	-- Druid Modules
	elseif class == "DRUID" then
		if spec == 1 and xmod.balancedruidmodule then
			activeModule = xmod.balancedruidmodule
		elseif spec == 2 and xmod.feraldruidmodule then
			activeModule = xmod.feraldruidmodule
		elseif spec == 3 and xmod.guardiandruidmodule then
		    activeModule = xmod.guardiandruidmodule
		elseif spec == 4 and xmod.restorationdruidmodule then
			activeModule = xmod.restorationdruidmodule
		end
	
	-- Evoker Modules
	elseif class == "EVOKER" then
		if spec == 1 and xmod.devastationevokermodule then
			activeModule = xmod.devastationevokermodule
		elseif spec == 2 and xmod.preservationevokermodule then
			activeModule = xmod.preservationevokermodule
		elseif spec == 3 and xmod.augmentationevokermodule then
		    activeModule = xmod.augmentationevokermodule
		end
		
	-- Hunter Modules
	elseif class == "HUNTER" then
		if spec == 1 and xmod.beastmasteryhuntermodule then
			activeModule = xmod.beastmasteryhuntermodule
		elseif spec == 2 and xmod.marksmanshiphuntermodule then
			activeModule = xmod.marksmanshiphuntermodule
		elseif spec == 3 and xmod.survivalhuntermodule then
		    activeModule = xmod.survivalhuntermodule
		end
		
	-- Mage Modules
	elseif class == "MAGE" then
		if spec == 1 and xmod.arcanemagemodule then
			activeModule = xmod.arcanemagemodule
		elseif spec == 2 and xmod.firemagemodule then
			activeModule = xmod.firemagemodule
		elseif spec == 3 and xmod.frostmagemodule then
		    activeModule = xmod.frostmagemodule
		end
		
	-- Monk Modules
	elseif class == "MONK" then
		if spec == 1 and xmod.brewmastermodule then
			activeModule = xmod.brewmastermodule
		elseif spec == 2 and xmod.mistweavermodule then
			activeModule = xmod.mistweavermodule
		elseif spec == 3 and xmod.windwalkermodule then
		    activeModule = xmod.windwalkermodule
		end
		
	-- Priest Modules
	elseif class == "PRIEST" then
		if spec == 1 and xmod.disciplinepriestmodule then
			activeModule = xmod.disciplinepriestmodule
		elseif spec == 2 and xmod.holypriestmodule then
			activeModule = xmod.holypriestmodule
		elseif spec == 3 and xmod.shadowpriestmodule then
		    activeModule = xmod.shadowpriestmodule
		end
		
	-- Rogue Modules
	elseif class == "ROGUE" then
		if spec == 1 and xmod.assassinationroguemodule then
			activeModule = xmod.assassinationroguemodule
		elseif spec == 2 and xmod.outlawroguemodule then
			activeModule = xmod.outlawroguemodule
		elseif spec == 3 and xmod.subtletyroguemodule then
		    activeModule = xmod.subtletyroguemodule
		end
	
	-- Shaman Modules
	elseif class == "SHAMAN" then
		if spec == 1 and xmod.elementalshamanmodule then
			activeModule = xmod.elementalshamanmodule
		elseif spec == 2 and xmod.enhancementshamanmodule then
			activeModule = xmod.enhancementshamanmodule
		elseif spec == 3 and xmod.restorationshamanmodule then
		    activeModule = xmod.restorationshamanmodule
		end
	
	-- Warlock Modules
	elseif class == "WARLOCK" then
		if spec == 1 and xmod.afflictionwarlockmodule then
			activeModule = xmod.afflictionwarlockmodule
		elseif spec == 2 and xmod.demonologywarlockmodule then
			activeModule = xmod.demonologywarlockmodule
		elseif spec == 3 and xmod.destructionwarlockmodule then
		    activeModule = xmod.destructionwarlockmodule
		end
	
	end
	
	-- Fallback to genericmodule if no specmodule found
	if not activeModule then
		activeModule = xmod.genericmodule
	end
	
	-- if not activeModule then
		-- print "|cffF58CBAclcRet|r: A module is not yet available for this spec. |cff33E8CDGeneric Module|r Loaded"
		-- return
	-- end
	
    -- If no valid module or missing required functions, retry
	if not activeModule.defaults or not activeModule.GetActions then
		C_Timer.After(0.5, clcInit)
		return
	end
	
	if not clcret.db.profile.rotation then
		clcret.db.profile.rotation = {}
	end
		clcret.db.profile.rotation.specBlizzMode = clcret.db.profile.rotation.specBlizzMode or {}

	-- Get current spec ID
	local specID = C_SpecializationInfo.GetSpecialization()

	-- Set default for new spec (optional: set to true or false as your default)
	if clcret.db.profile.rotation.specBlizzMode[specID] == nil then
		clcret.db.profile.rotation.specBlizzMode[specID] = false -- or true if you want default ON
	end

	-- Usage: check if BlizzMode is enabled for current spec
	local blizzEnabled = clcret.db.profile.rotation.specBlizzMode[specID]
	if blizzEnabled then
    -- Blizzard's Assisted Combat API is enabled for this spec
	end
	

	-- Ensure the profile rotation table exists
	clcret.db.profile.rotation = clcret.db.profile.rotation or {}

	-- Only set defaults for missing/empty rotation values
	EnsureDefaults(clcret.db.profile.rotation, activeModule.defaults)

	-- Actions table from current module
	clcret.RR_actions = activeModule.GetActions()

	-- Functions for updating the queue, performing rotation, and building options
	function clcret.RR_UpdateQueue()
		activeModule.db = clcret.db.profile.rotation
		if activeModule.Init then activeModule.Init() end
	end

	function clcret.Rotation()
		if activeModule.Rotation then
			return activeModule.Rotation()
		end
	end

	function clcret.RR_BuildOptions()
		if activeModule.BuildOptions then
			return activeModule.BuildOptions()
		end
	end
	
end

-- Frame for events
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event)
	clcInit()
	self:UnregisterEvent(event)
end)