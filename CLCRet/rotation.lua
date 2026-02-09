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
	
	local activeModule = xmod.genericmodule
	
	if not clcret.db.profile.rotation then
		clcret.db.profile.rotation = {}
	end
		clcret.db.profile.rotation.specBlizzMode = clcret.db.profile.rotation.specBlizzMode or {}

	-- Get current spec ID
	local specID = C_SpecializationInfo.GetSpecialization()

	-- Set default for new spec
	if clcret.db.profile.rotation.specBlizzMode[specID] == nil then
		clcret.db.profile.rotation.specBlizzMode[specID] = true -- or true if you want default ON
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