if not FriendLib then

	FriendLib = {}

	FriendLib.debug = false
	-- One name set per source, rebuilt on every update so removed friends,
	-- ex-guildmates and past group members drop out again
	FriendLib.friends = {}
	FriendLib.guild = {}
	FriendLib.group = {}
	-- Players I whispered this session
	FriendLib.whispered = {}
	FriendLib.scm = SendChatMessage

	SendChatMessage = function(text, type, lang, chan)
		if type == "WHISPER" and chan then
			FriendLib:AddFriend(chan)
		end
		FriendLib.scm(text, type, lang, chan)
	end

	function FriendLib.DebugPrint(m)
		if FriendLib.debug then
			DEFAULT_CHAT_FRAME:AddMessage("FriendLib: " .. m)
		end
	end

	function FriendLib:AddFriend(name)
		FriendLib.whispered[strupper(name)] = 1
		FriendLib.DebugPrint("Add: " .. strupper(name))
	end

	local collect = function(count, getName)
		local names = {}
		for i = 1, count do
			local name = getName(i)
			if name then
				names[strupper(name)] = 1
			end
		end
		return names
	end

	function FriendLib:CheckFriendList()
		FriendLib.friends = collect(GetNumFriends(), GetFriendInfo)
	end

	function FriendLib:CheckGuild()
		FriendLib.guild = collect(GetNumGuildMembers(), GetGuildRosterInfo)
	end

	function FriendLib:CheckGroup()
		local names = collect(GetNumRaidMembers(), function(i) return UnitName("raid" .. i) end)
		for i = 1, GetNumPartyMembers() do
			local name = UnitName("party" .. i)
			if name then
				names[strupper(name)] = 1
			end
		end
		FriendLib.group = names
	end

	function FriendLib:IsFriend(name)
		name = strupper(name)
		return FriendLib.whispered[name] or FriendLib.friends[name]
			or FriendLib.guild[name] or FriendLib.group[name]
	end

	FriendLib.frame = CreateFrame("frame")
	FriendLib.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	FriendLib.frame:RegisterEvent("FRIENDLIST_UPDATE")
	FriendLib.frame:RegisterEvent("GUILD_ROSTER_UPDATE")
	FriendLib.frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
	FriendLib.frame:RegisterEvent("RAID_ROSTER_UPDATE")
	FriendLib.frame:SetScript("OnEvent", function()
		if event == "PLAYER_ENTERING_WORLD" then
			-- The default UI only requests the guild roster while the guild tab is open
			if not FriendLib.rosterRequested and IsInGuild() then
				FriendLib.rosterRequested = true
				GuildRoster()
			end
			FriendLib:CheckFriendList()
			FriendLib:CheckGroup()
		elseif event == "FRIENDLIST_UPDATE" then
			FriendLib:CheckFriendList()
		elseif event == "GUILD_ROSTER_UPDATE" then
			FriendLib:CheckGuild()
		else
			FriendLib:CheckGroup()
		end
	end)
end
