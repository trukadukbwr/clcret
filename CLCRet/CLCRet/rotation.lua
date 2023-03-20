-- don't load if class is wrong
local _, class = UnitClass("player")
if class ~= "PALADIN" then return end

local _, xmod = ...
xmod = xmod.retmodule

-- overwrite default variables
clcret.db_defaults.profile.rotation = xmod.defaults

clcret.RR_actions = xmod.GetActions()

function clcret.RR_UpdateQueue()
	xmod.db = clcret.db.profile.rotation
	xmod.Init()
end

function clcret.RetRotation()
	return xmod.Rotation()
end

function clcret.RR_BuildOptions()
	return xmod.BuildOptions()
end