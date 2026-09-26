
local chatfilter = function(message, name, type)
	return name
		and (not FriendLib:IsFriend(name))
		and (FilterLib:Filter(message) == "")
end

local mod = {
	["Name"] = "ChatSanitizer",
	["Tag"] = "spam",
	["Description"] = "Blocks gold spam and advertisements.",
	["Help"] = "Knows how common spam messages look like, e.g. what words they are made of. Matching messages are hidden, the player is not ignored. They are listed as Auto-Block until relog, so you can review their messages via the log icon. Friends, party and guild members are never filtered. More info here:|n|nhttps://github.com/Aviana/ChatSanitizer",
	["OnEnable"] = nil,
	["OnDisable"] = nil,
	["NameFilter"] = nil,
	["ChatFilter"] = chatfilter,
}

local f = CreateFrame("frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	SI_ModInstall(mod)
end)
