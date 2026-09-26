
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
	["Test"] = function(t)
		t.check("Accented names are filtered", namefilter("\195\132rger"))
		t.check("Names with symbols are filtered", namefilter("Dummy\226\152\133"))
		t.check("Plain names pass", not namefilter("Dummyplain"))
		FriendLib:AddFriend("\195\132rger")
		t.check("Friends are never filtered", not namefilter("\195\132rger"))
	end,
}


local f = CreateFrame("frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	SI_ModInstall(mod)
end)
