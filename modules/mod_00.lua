
local namefilter = function(name)
	if FriendLib:IsFriend(name) then
		return false
	end
	if string.find(name, "[^a-zA-Z]") then
		return true
	end
	return false
end

local mod = {
	["Name"] = "Special Snowflake Blocker",
	["Tag"] = "name",
	["Description"] = "Blocks messages sent by players who have special characters in their names.",
	["Help"] = "Any letter outside a-z counts, including accents. They are listed as Auto-Block until relog, so you can review them via the log icon. Friends, party and guild members are never filtered.",
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
