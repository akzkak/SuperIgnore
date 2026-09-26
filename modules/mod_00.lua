
local namefilter = function(name)
	if string.find(name, "[^a-zA-Z]") then
		return true
	end
	return false
end

local mod = {
	["Name"] = "Special Snowflake Blocker",
	["Tag"] = "name",
	["Description"] = "Blocks messages sent by players who have special characters in their names.",
	["OnEnable"] = nil,
	["OnDisable"] = nil,
	["NameFilter"] = namefilter,
	["ChatFilter"] = nil,
}


local f = CreateFrame("frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	SI_ModInstall(mod)
end)
