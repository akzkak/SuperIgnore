
local chatfilter = function(message, name, chatType)
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
	["Test"] = function(t)
		local spam = {
			"Cheap gold fast delivery www.buywowgold.com 24/7 live chat",
			"WWW.MMOGO.COM 100% safe, 5000g = 10 usd, discount code",
			"buy gold cheap, visit wowgold dot com",
			"BUY_GOLD_CHEAP_MMOGO_DOT_COM",
		}
		local legit = {
			"LF healer for Scarlet Monastery, follow me to the entrance",
			"Selling [Arcanite Bar] low price, fast, 5g each, pst",
			"WTS |cff1eff00|Hitem:2589:0:0:0|h[Golden Pearl]|h|r, cheap, whisper me",
			"anyone know the code for the opposite side of the border in Goldshire?",
			"LFG lvl 58 warrior, powerful dps, any server event today?",
		}
		for i = 1, table.getn(spam) do
			t.check("Spam is caught: " .. string.sub(spam[i], 1, 32) .. "...", chatfilter(spam[i], "Dummyspammer"),
				"score " .. FilterLib:RateMessage(spam[i]))
		end
		for i = 1, table.getn(legit) do
			t.check("Normal chat passes: " .. string.sub(FilterLib:RemoveHyperLinks(legit[i]), 1, 32) .. "...", not chatfilter(legit[i], "Dummynice"),
				"score " .. FilterLib:RateMessage(legit[i]))
		end
		t.eq("A message without spam words scores 0", FilterLib:RateMessage("hello there, see you in the dungeon tonight"), 0)
		FriendLib:AddFriend("Dummypal")
		t.check("Friends are never filtered", not chatfilter(spam[1], "Dummypal"))
		for i = 1, FilterLib.cacheMax + 50 do
			FilterLib:RateMessage("dummy cache " .. i)
		end
		t.check("Rating cache stays capped", FilterLib.cachedCount <= FilterLib.cacheMax, FilterLib.cachedCount)
	end,
}

local f = CreateFrame("frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	SI_ModInstall(mod)
end)
