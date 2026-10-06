local name = "SuperIgnore"
local version = GetAddOnMetadata(name, "Version") or ""

local SS = {
	["AddonName"]			= name,
	["AddonDir"]			= strlower(name),
	["AddonVersion"] 		= version,

	["TextGeneral"] 		= "General",
	["TextOptions"] 		= "Ignore Filter",
	["TextDuration"]		= "Default Ignore Time",
	["TextWhisperBlock"]	= "Do not let me whisper ignored players",
	["TextWhisperUnignore"]	= "Unignore players if I whisper them",

	["TextModules"]			= "Modules",
	["TextEdit"]			= "Edit",

	["ChatIgnored"]			= "%s is now being ignored. Duration: %s.",
	["ChatIgnoredReason"]	= "%s is now being ignored. Duration: %s. Reason: %s",
	["ChatUnignored"]		= "%s is no longer being ignored.",
	["ChatBlocked"]			= "Your message was not sent because you are ignoring %s.",
	["ChatSelf"]			= "You can't ignore yourself.",
	["ChatExpired"]			= "Timed ignores that expired while offline: %s.",

	["BanWhisper"]			= "Whispers",
	["BanParty"]			= "Party / Raid",
	["BanGuild"]			= "Guild Chat",
	["BanOfficer"]			= "Officer Chat",
	["BanSay"]				= "Say",
	["BanYell"]				= "Yell",
	["BanBG"]				= "Battleground",
	["BanChannel"]			= "Public Channels",
	["BanEmote"]			= "Emotes",
	["BanTrade"]			= "Trade Requests",
	["BanInvite"]			= "Invites",
	["BanDuel"]				= "Duels",

	["LogTitle"]			= "Blocked this session",
	["LogEmpty"]			= "Nothing blocked yet.",
	["LogDuel"]				= "[Duel]",
	["LogTrade"]			= "[Trade]",
	["LogInviteGuild"]		= "[Guild Invite]",
	["LogInviteParty"]		= "[Group Invite]",

	["TimeRelog"]			= "Until Relog",
	["TimeHour"]			= "Hour",
	["TimeDay"]				= "Day",
	["TimeWeek"]			= "Week",
	["TimeMonth"]			= "Month",
	["TimeForever"]			= "Forever",
	["TimeAsk"]				= "Ask",
	["PopupIgnore"]			= "Ignore %s",
	["PopupDuration"]		= "Duration",
	["PopupReasonLabel"]	= "Reason (optional)",
	["TimeAuto"]			= "Auto-Block",

	["PopupRemove"]			= "Remove",

	["MenuDuration"]		= "Ignore Duration",
	["MenuReason"]			= "Set Reason...",
	["MenuUnignore"]		= "Unignore",
	["PopupReason"]			= "Ignore reason for %s:",
	["ChatDuration"]		= "%s ignore duration changed to: %s.",
}

local T_RELOG		= 1
local T_HOUR		= 2
local T_DAY			= 3
local T_WEEK		= 4
local T_MONTH		= 5
local T_FOREVER		= 6
local T_AUTOBLOCK	= 7
local T_ASK			= 8 -- setting only; never a stored ignore duration

local TI_RELOG		= -1
local TI_FOREVER	= 1e30 -- lol
local TI_AUTOBLOCK	= 1e31

-- Ban entry slots; slot 3 was used by old versions and is left empty
local B_NAME		= 1
local B_DURATION	= 2
local B_REASON		= 4
local B_OPTION		= 5 -- duration menu option the ignore was set with, nil if set directly

local T_Time = {
	TI_RELOG,
	60 * 60,
	60 * 60 * 24,
	60 * 60 * 24 * 7,
	60 * 60 * 24 * 30,
	TI_FOREVER,
	TI_AUTOBLOCK,
}

local T_Time_TextOpt = {
	SS.TimeRelog,
	SS.TimeHour,
	SS.TimeDay,
	SS.TimeWeek,
	SS.TimeMonth,
	SS.TimeForever
}

-- Locals UI.lua needs as well
SI_Shared = {
	SS				= SS,
	B_NAME			= B_NAME,
	B_DURATION		= B_DURATION,
	B_REASON		= B_REASON,
	T_Time			= T_Time,
	T_Time_TextOpt	= T_Time_TextOpt,
	T_ASK			= T_ASK,
	T_FOREVER		= T_FOREVER,
}

------------- Global

SI_NameFilter = {}
SI_ChatFilter = {}
-- filter -> short tag of the mod that installed it, shown as the auto-block reason
SI_FilterSource = {}

SI_MainFrame = nil
SI_OptionsFrame = nil
SI_RealmSpecific = nil
SI_TimeCheck_Last = 0


SI_Mods = {}
-- OnBlock(text, name, source) of enabled mods, called for each newly blocked action
SI_BlockListeners = {}
-- Next free vertical offset in SI_OptionsFrame; mods are appended there
SI_OptionsFramePad = 0

SI_Log = {}

------------- Mods

SI_ModsGetNumber = function()
	return table.getn(SI_Mods)
end

SI_ModsGetMod = function(index)
	return SI_Mods[index]
end

SI_ModInstall = function(mod)
	local index = SI_ModsGetNumber() + 1
	SI_Mods[index] = mod

	if not SI_Global.Mods[mod.Name] then
		SI_Global.Mods[mod.Name] = {
			["Enabled"] = false,
			["Vars"] = {}
		}
	end

	SI_CreateModUI(index, mod)

	if SI_Global.Mods[mod.Name].Enabled then
		SI_ModEnable(index)
	end

	return index
end

SI_ModEnable = function(index)
	local mod = SI_Mods[index]
	SI_Global.Mods[mod.Name].Enabled = true

	if mod.NameFilter then
		SI_FilterSource[mod.NameFilter] = mod.Tag or mod.Name
		SI_AddNameFilter(mod.NameFilter)
	end
	if mod.ChatFilter then
		SI_FilterSource[mod.ChatFilter] = mod.Tag or mod.Name
		SI_AddChatFilter(mod.ChatFilter)
	end
	if mod.OnBlock then
		table.insert(SI_BlockListeners, mod.OnBlock)
	end
	if mod.OnEnable then
		mod.OnEnable()
	end
end

SI_ModDisable = function(index)
	local mod = SI_Mods[index]
	SI_Global.Mods[mod.Name].Enabled = false

	if mod.NameFilter then
		SI_DelNameFilter(mod.NameFilter)
	end
	if mod.ChatFilter then
		SI_DelChatFilter(mod.ChatFilter)
	end
	if mod.OnBlock then
		for i = table.getn(SI_BlockListeners), 1, -1 do
			if SI_BlockListeners[i] == mod.OnBlock then
				table.remove(SI_BlockListeners, i)
			end
		end
	end
	if mod.OnDisable then
		mod.OnDisable()
	end
end

SI_ModGetVar = function(mod, name)
	local modinfo = SI_Global.Mods[mod.Name]
	return modinfo.Vars[name]
end

SI_ModSetVar = function(mod, name, value)
	local modinfo = SI_Global.Mods[mod.Name]
	modinfo.Vars[name] = value
end

------------- Filter

SI_AddNameFilter = function(filter)
	table.insert(SI_NameFilter, filter)
end
SI_DelNameFilter = function(filter)
	for i = table.getn(SI_NameFilter), 1, -1 do
		if SI_NameFilter[i] == filter then
			table.remove(SI_NameFilter, i)
		end
	end
end

SI_AddChatFilter = function(filter)
	table.insert(SI_ChatFilter, filter)
end
SI_DelChatFilter = function(filter)
	for i = table.getn(SI_ChatFilter), 1, -1 do
		if SI_ChatFilter[i] == filter then
			table.remove(SI_ChatFilter, i)
		end
	end
end

SI_FilterIsPlayerIgnored = function(name)
	if name == nil then
		return false
	end
	if name == UnitName("player") then
		return false
	end

	for _, filter in SI_NameFilter do
		if filter(name) then
			SI_CheckAutoBlock(name, SI_FilterSource[filter])
			return true
		end
	end

	return false
end

SI_FilterIsChatIgnored = function(message, name, chatType)
	if name == UnitName("player") then
		return false
	end

	for _, filter in SI_ChatFilter do
		if filter(message, name, chatType) then
			SI_CheckAutoBlock(name, SI_FilterSource[filter])
			return true
		end
	end

	return false
end


------------- Helper

SI_Print = function(msg)
	local info = ChatTypeInfo["SYSTEM"]
	DEFAULT_CHAT_FRAME:AddMessage(msg, info.r, info.g, info.b, info.id);
end

SI_IsTimeSpecial = function(t)
	return t == TI_FOREVER or t == TI_RELOG or t == TI_AUTOBLOCK
end

SI_CalcBanTime = function(option)
	local t = T_Time[option or SI_Global.BanDuration]
	if SI_IsTimeSpecial(t) then
		return t
	else
		return time() + t
	end
end
SI_IsBanTimeOver = function(t)
	if SI_IsTimeSpecial(t) then
		return false
	else
		return time() > t
	end
end
SI_BannedClearRelog = function()
	local unbanNames = {}
	for _, banned in SI_RealmSpecific.BannedPlayers do
		local d = banned[B_DURATION]
		if d == TI_RELOG or d == TI_AUTOBLOCK then
			table.insert(unbanNames, banned[B_NAME])
		end
	end

	for _, name in unbanNames do
		SI_DelIgnore_New(name, true)
	end
end
-- quiet: remove without a chat line per player; returns the removed names
SI_BannedCheckTimes = function(quiet)
	local unbanNames = {}
	for _, banned in SI_RealmSpecific.BannedPlayers do
		if SI_IsBanTimeOver(banned[B_DURATION]) then
			table.insert(unbanNames, banned[B_NAME])
		end
	end

	for _, name in unbanNames do
		SI_DelIgnore_New(name, quiet)
	end
	return unbanNames
end
SI_BannedCheckTimesPeriodic = function()
	if GetTime() - SI_TimeCheck_Last > 60 then
		SI_TimeCheck_Last = GetTime()
		SI_BannedCheckTimes()
		-- Keep the time left current while the list stays open (minutes are the finest unit)
		if IgnoreListFrame:IsVisible() then
			IgnoreList_Update()
		end
	end
end

-- Expires timed ignores on time, not only when a filter happens to run; shown once loaded
local expiryFrame = CreateFrame("Frame")
expiryFrame:Hide()
expiryFrame:SetScript("OnUpdate", SI_BannedCheckTimesPeriodic)
SI_FormatTimeNoColor = function(t)

	local _s = function(n)
		if n == 1 then return "" else return "s" end
	end

	if t == TI_FOREVER then
		return SS.TimeForever, "ff00ff"
	elseif t == TI_RELOG then
		return SS.TimeRelog, "00ff00"
	elseif t == TI_AUTOBLOCK then
		return SS.TimeAuto, "ffffff"
	else
		local tt = t - time()
		if tt < 0 then
			return "0", "00ffff"
		else
			tt = tt / 60
			if tt < 60 then
				tt = math.ceil(tt)
				return tt .. " Min" .. _s(tt), "00ffff"
			end

			tt = tt / 60
			if tt < 24 then
				tt = math.ceil(tt)
				return tt .. " Hour" .. _s(tt), "ffff00"
			end

			tt = tt / 24
			tt = math.ceil(tt)
			return tt .. " Day" .. _s(tt), "ff0000"
		end
	end
end
SI_FixPlayerName = function(name)
	return string.gsub(string.lower(name), "^%l", string.upper)
end

-- Matches s against a GlobalStrings format ("%s has invited you.", or positional
-- "%2$s ... %1$s" as some locales use). Returns start, end and the values in argument
-- order; argument 1 is a player name, so it can't contain spaces.
SI_StringFindPattern = function(s, format)
	local order = {}
	local r = string.gsub(format, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
	r = string.gsub(r, "%%(%d*)%%?%$?s", function(pos)
		local arg = tonumber(pos) or table.getn(order) + 1
		table.insert(order, arg)
		return arg == 1 and "([^ ]+)" or "(.*)"
	end)

	local found = { string.find(s, "^" .. r .. "$") }
	if not found[1] then return nil end
	local values = {}
	for i = 1, table.getn(order) do
		values[order[i]] = found[i + 2]
	end
	return found[1], found[2], values[1], values[2], values[3]
end

SI_FixBannedSelected = function()
	 local selected = SI_RealmSpecific.BannedSelected
	 if selected > 1 and selected > GetNumIgnores() then
		SI_RealmSpecific.BannedSelected = selected - 1
	 end
end

-- name -> index into BannedPlayers; rebuilt on the next lookup after the list changes
local bannedIndex = nil

SI_BannedIndexChanged = function()
	bannedIndex = nil
end

SI_BannedGetIndex = function(name)
	if not bannedIndex then
		bannedIndex = {}
		for index, banned in SI_RealmSpecific.BannedPlayers do
			bannedIndex[banned[B_NAME]] = index
		end
	end
	return bannedIndex[name]
end

SI_BannedGetDuration = function(index)
	return SI_RealmSpecific.BannedPlayers[index][B_DURATION]
end
SI_BannedSetDuration = function(index, duration)
	SI_RealmSpecific.BannedPlayers[index][B_DURATION] = duration
end
SI_BannedGetReason = function(index)
	return SI_RealmSpecific.BannedPlayers[index][B_REASON]
end
SI_BannedSetReason = function(index, reason)
	SI_RealmSpecific.BannedPlayers[index][B_REASON] = reason
end
SI_BannedGetOption = function(index)
	return SI_RealmSpecific.BannedPlayers[index][B_OPTION]
end
SI_BannedSetOption = function(index, option)
	SI_RealmSpecific.BannedPlayers[index][B_OPTION] = option
end
SI_BannedGetName = function(index)
	return SI_RealmSpecific.BannedPlayers[index][B_NAME]
end

SI_BannedSortByTime = function()
	local selected = SI_RealmSpecific.BannedPlayers[SI_RealmSpecific.BannedSelected]
	table.sort(SI_RealmSpecific.BannedPlayers, function(a, b)
		local at = a[B_DURATION]
		local bt = b[B_DURATION]
		if at == bt then
			return a[B_NAME] < b[B_NAME]
		else
			return at < bt
		end
	end)
	SI_BannedIndexChanged()
	-- Keep the selection on the same player, not the same row
	if selected then
		SI_RealmSpecific.BannedSelected = SI_BannedGetIndex(selected[B_NAME])
	end
end

SI_IsChannelBanned = function(c)
	local g = SI_Global

	if(c == "WHISPER" or c == "AFK" or c == "DND")
						then return g.BanOptWhisper end
	if(c == "PARTY" or c == "RAID" or c == "RAID_LEADER" or c == "RAID_WARNING")
						then return g.BanOptParty end
	if c == "GUILD"		then return g.BanOptGuild end
	if c == "OFFICER"	then return g.BanOptOfficer end
	if c == "SAY"		then return g.BanOptSay end
	if c == "YELL"		then return g.BanOptYell end
	if(c == "BATTLEGROUND" or c == "BATTLEGROUND_LEADER")
						then return g.BanOptBg end
	if c == "CHANNEL"	then return g.BanOptPublic end
	if c == "HARDCORE"  then return g.BanOptPublic end
	if(c == "EMOTE" or c == "TEXT_EMOTE")
						then return g.BanOptEmote end

	return false
end

SI_CheckInteractRules = function(name)
	if SI_Global.WhisperBlock then
		SI_Print(string.format(SS.ChatBlocked, name))
		return true
	elseif SI_Global.WhisperUnignore then
		SI_DelIgnore_New(name)
		return false
	else
		return false
	end
end

-- Auto-block entries only list the player for review (log icon) until relog;
-- they don't ignore them, only the filtered messages are hidden
SI_CheckAutoBlock = function(name, source)
	local index = SI_BannedGetIndex(name)
	if not index then
		SI_AddIgnore_New(name, true, TI_AUTOBLOCK, source)
	end
end

local isChatIgnored

-- Every chat frame (and WIM) asks about the same message in the same frame; answer once
local lastTime, lastEvent, lastArg1, lastArg2, lastArg4, lastResult

SI_IsChatIgnored = function(event, arg1, arg2, arg3, arg4)
	local now = GetTime()
	if now == lastTime and event == lastEvent and arg1 == lastArg1
		and arg2 == lastArg2 and arg4 == lastArg4 then
		return lastResult
	end
	local result = isChatIgnored(event, arg1, arg2, arg3, arg4)
	lastTime, lastEvent, lastArg1, lastArg2, lastArg4, lastResult = now, event, arg1, arg2, arg4, result
	return result
end

-- Forget the cached answer, for checks that change settings within one frame
SI_ChatCacheReset = function()
	lastTime = nil
end

isChatIgnored = function(event, arg1, arg2, arg3, arg4)

	if strsub(event, 1, 8) == "CHAT_MSG" then
		local chatType = strsub(event, 10)

		local source = strsub(chatType,1,1)
		if chatType == "CHANNEL" and arg4 then
			source = strsub(arg4,1,1)
		end

		if arg1 and chatType == "SYSTEM" then
			if SI_IsCancelMessage(arg1) then
				return true
			end

			local found, _, name = SI_StringFindPattern(arg1, ERR_IGNORE_REMOVED_S)
			if found and name then
				return true
			end

			-- The "X has invited you..." lines that come with an invite we auto-decline
			if SI_Global.BanOptInvite then
				found, _, name = SI_StringFindPattern(arg1, ERR_INVITED_TO_GUILD_SS)
				if found and name and SI_FilterIsPlayerIgnored(name) then
					SI_LogIgnore(SS.LogInviteGuild, name, "ginvite")
					return true
				end

				found, _, name = SI_StringFindPattern(arg1, ERR_INVITED_TO_GROUP_S)
				if found and name and SI_FilterIsPlayerIgnored(name) then
					SI_LogIgnore(SS.LogInviteParty, name, "invite")
					return true
				end
			end
		end

		if arg1 and arg2 and SI_IsChannelBanned(chatType) then
			if SI_FilterIsPlayerIgnored(arg2) or SI_FilterIsChatIgnored(arg1, arg2, chatType) then
				SI_LogIgnore(arg1, arg2, source)
				SI_BubbleBlock(chatType, arg1)
				return true
			end
		end
	end

	return false
end

------------- Cancel Messages

-- Declining an ignored player's duel or trade makes the client print "Duel cancelled." /
-- "Trade cancelled." Those two messages are swallowed for a moment after we cancel.
local CANCEL_MESSAGE_TIME = 3
local cancelMessageUntil = 0

SI_SuppressCancelMessage = function()
	cancelMessageUntil = GetTime() + CANCEL_MESSAGE_TIME
end

SI_IsCancelMessage = function(msg)
	return GetTime() < cancelMessageUntil
		and (msg == ERR_DUEL_CANCELLED or msg == ERR_TRADE_CANCELLED)
end

SI_UIErrorsFrame_AddMessage_New = function(self, msg, r, g, b, a, holdTime)
	if SI_IsCancelMessage(msg) then return end
	SI_UIErrorsFrame_AddMessage_Old(self, msg, r, g, b, a, holdTime)
end

------------- Overrides

SI_FriendsFrameIgnoreButton_OnClick_Old	= nil
SI_AddIgnore_Old						= nil
SI_AddOrDelIgnore_Old					= nil
SI_DelIgnore_Old						= nil
SI_GetIgnoreName_Old					= nil
SI_GetNumIgnores_Old					= nil
SI_GetSelectedIgnore_Old				= nil
SI_SetSelectedIgnore_Old				= nil
SI_TradeFrame_OnEvent_Old				= nil
SI_InitiateTrade_Old					= nil
SI_UIErrorsFrame_AddMessage_Old			= nil
SI_DropItemOnUnit_Old					= nil
SI_StaticPopup_Show_Old					= nil
SI_ChatFrame_OnEvent_Old				= nil
SI_WIM_ChatFrame_OnEvent_Old			= nil
SI_SendChatMessage_Old					= nil

SI_FriendsFrameIgnoreButton_OnClick_New = function()
	local button = arg1
	if button == "LeftButton" then
		SI_FriendsFrameIgnoreButton_OnClick_Old()
	elseif button == "RightButton" then
		SI_RightClickMenu(this:GetID())
	end
end

-- Set by every ignore change; the unit menu hook uses it to skip clicks already handled
SI_IgnoreHandled = false

SI_AddIgnore_New = function(name, quiet, banTime, reason)
	SI_IgnoreHandled = true
	if not name then return end

	name = SI_FixPlayerName(name)
	if name == UnitName("player") then
		SI_Print(SS.ChatSelf)
		return
	end

	local option
	if not banTime then
		option = SI_Global.BanDuration
		if option == T_ASK then
			if not quiet then
				SI_ShowIgnorePrompt(name, reason)
				return
			end
			option = T_FOREVER
		end
		banTime = SI_CalcBanTime(option)
	end

	local index = SI_BannedGetIndex(name)
	if index then
		SI_BannedSetDuration(index, banTime)
		SI_BannedSetReason(index, reason)
		SI_BannedSetOption(index, option)
	else
		table.insert(SI_RealmSpecific.BannedPlayers, {name, banTime, nil, reason, option})
		SI_BannedIndexChanged()
	end

	SI_BannedSortByTime()
	IgnoreList_Update()

	if not quiet then
		if reason then
			SI_Print(string.format(SS.ChatIgnoredReason,
				name, SI_FormatTimeNoColor(banTime), reason))
		else
			SI_Print(string.format(SS.ChatIgnored,
				name, SI_FormatTimeNoColor(banTime)))
		end
	end
end

SI_AddOrDelIgnore_New = function(name, quiet, banTime, reason)
	SI_IgnoreHandled = true
	if not name then return end
	-- Typed names ("/ignore bob") must match the stored "Bob"
	name = SI_FixPlayerName(name)
	local index = SI_BannedGetIndex(name)
	if index then
		SI_DelIgnore_New(name, quiet)
	else
		SI_AddIgnore_New(name, quiet, banTime, reason)
	end
end

SI_DelIgnore_New = function(name, quiet)
	SI_IgnoreHandled = true
	if not name then return end

	name = SI_FixPlayerName(name)

	local index = SI_BannedGetIndex(name)
	if index then
		 table.remove(SI_RealmSpecific.BannedPlayers, index)
		 SI_BannedIndexChanged()
		 SI_FixBannedSelected()
		 IgnoreList_Update()

		 if not quiet then
			SI_Print(string.format(SS.ChatUnignored, name))
		end
	end
end

SI_GetIgnoreName_New = function(index)
	local banned = SI_RealmSpecific.BannedPlayers[index]
	if banned then
		-- Plain name, since other addons compare it; the ignore list adds the reason itself
		return banned[B_NAME]
	else
		return UNKNOWN
	end
end

SI_GetNumIgnores_New = function()
	return table.getn(SI_RealmSpecific.BannedPlayers)
end

SI_GetSelectedIgnore_New = function()
	return SI_RealmSpecific.BannedSelected
end

SI_SetSelectedIgnore_New = function(index)
	SI_RealmSpecific.BannedSelected = index
end

SI_StaticPopup_Show_New = function(which, text_arg1, text_arg2, data)
	local name = text_arg1
	if SI_Global.BanOptInvite then
		if which == "PARTY_INVITE" then
			if SI_FilterIsPlayerIgnored(name) then
				DeclineGroup()
				SI_LogIgnore(SS.LogInviteParty, name)
				return
			end
		elseif which == "GUILD_INVITE" then
			if SI_FilterIsPlayerIgnored(name) then
				DeclineGuild()
				SI_LogIgnore(SS.LogInviteGuild, name)
				return
			end
		end
	end
	if SI_Global.BanOptDuel then
		if which == "DUEL_REQUESTED" then
			if SI_FilterIsPlayerIgnored(name) then
				SI_SuppressCancelMessage()
				CancelDuel()
				SI_LogIgnore(SS.LogDuel, name)
				return
			end
		end
	end

	return SI_StaticPopup_Show_Old(which, text_arg1, text_arg2, data)
end

-- Trades I start myself are never auto-cancelled: remember who I asked to trade,
-- then let the trade window with that player through until it closes.
local tradeRequestName, tradeRequestTime, tradeAllowedName = nil, 0, nil

local rememberTradeRequest = function(unit)
	local name = unit and UnitIsPlayer(unit) and UnitName(unit)
	if name then
		tradeRequestName, tradeRequestTime = name, GetTime()
	end
end

SI_InitiateTrade_New = function(unit)
	rememberTradeRequest(unit)
	return SI_InitiateTrade_Old(unit)
end

SI_DropItemOnUnit_New = function(unit)
	if CursorHasItem() then
		rememberTradeRequest(unit)
	end
	return SI_DropItemOnUnit_Old(unit)
end

SI_TradeFrame_OnEvent_New = function()
	if event == "TRADE_CLOSED" then
		tradeAllowedName = nil
	elseif event == "TRADE_SHOW" then
		local name = UnitName("NPC")
		-- Only a recent request counts, so a stale one can't let that player's own trade through later
		tradeAllowedName = (name and name == tradeRequestName and GetTime() - tradeRequestTime < 10) and name or nil
		tradeRequestName = nil
	end

	if SI_Global.BanOptTrade then
		if event == "TRADE_SHOW" or event == "TRADE_UPDATE" then
			local name = UnitName("NPC")
			if name ~= tradeAllowedName and SI_FilterIsPlayerIgnored(name) then
				SI_SuppressCancelMessage()
				CloseTrade()
				SI_LogIgnore(SS.LogTrade, name)
				return
			end
		end
	end

	SI_TradeFrame_OnEvent_Old()
end

SI_ChatFrame_OnEvent_New = function(event)
	if not SI_IsChatIgnored(event, arg1, arg2, arg3, arg4) then
		SI_ChatFrame_OnEvent_Old(event)
	end
end

SI_WIM_ChatFrame_OnEvent_New = function(event)
	if not SI_IsChatIgnored(event, arg1, arg2, arg3, arg4) then
		SI_WIM_ChatFrame_OnEvent_Old(event)
	end
end

SI_WhisperFu_OnReceiveWhisper_New = function()
	if not SI_IsChatIgnored("CHAT_MSG_WHISPER", arg1, arg2, arg3, arg4) then
		WhisperFu:OnReceiveWhisper_Old()
	end
end

SI_SendChatMessage_New = function(msg, chatType, lang, channel)
	-- Typed whisper targets ("/w bob") must match the stored "Bob"
	local name = chatType == "WHISPER" and channel and SI_FixPlayerName(channel)
	-- Only players I ignored myself; filters (auto-block, name filters) don't stop my whispers
	local index = name and SI_BannedGetIndex(name)
	if index and SI_BannedGetDuration(index) ~= TI_AUTOBLOCK then
		if SI_CheckInteractRules(name) then
			return
		end
	end
	SI_SendChatMessage_Old(msg, chatType, lang, channel)
end


------------- Main Code

SI_HookFunctions = function()

	SI_FriendsFrameIgnoreButton_OnClick_Old = FriendsFrameIgnoreButton_OnClick
	FriendsFrameIgnoreButton_OnClick = SI_FriendsFrameIgnoreButton_OnClick_New

	SI_AddIgnore_Old			= AddIgnore
	AddIgnore					= SI_AddIgnore_New

	SI_AddOrDelIgnore_Old		= AddOrDelIgnore
	AddOrDelIgnore				= SI_AddOrDelIgnore_New

	SI_DelIgnore_Old			= DelIgnore
	DelIgnore					= SI_DelIgnore_New

	SI_GetIgnoreName_Old		= GetIgnoreName
	GetIgnoreName				= SI_GetIgnoreName_New

	SI_IgnoreList_Update_Old	= IgnoreList_Update
	IgnoreList_Update			= SI_IgnoreList_Update_New

	SI_GetNumIgnores_Old		= GetNumIgnores
	GetNumIgnores				= SI_GetNumIgnores_New

	SI_GetSelectedIgnore_Old	= GetSelectedIgnore
	GetSelectedIgnore			= SI_GetSelectedIgnore_New

	SI_SetSelectedIgnore_Old	= SetSelectedIgnore
	SetSelectedIgnore			= SI_SetSelectedIgnore_New

	SI_StaticPopup_Show_Old		= StaticPopup_Show
	StaticPopup_Show			= SI_StaticPopup_Show_New

	SI_TradeFrame_OnEvent_Old	= TradeFrame_OnEvent
	TradeFrame_OnEvent			= SI_TradeFrame_OnEvent_New

	SI_InitiateTrade_Old		= InitiateTrade
	InitiateTrade				= SI_InitiateTrade_New

	SI_DropItemOnUnit_Old		= DropItemOnUnit
	DropItemOnUnit				= SI_DropItemOnUnit_New

	SI_UIErrorsFrame_AddMessage_Old	= UIErrorsFrame.AddMessage
	UIErrorsFrame.AddMessage		= SI_UIErrorsFrame_AddMessage_New

	SI_ChatFrame_OnEvent_Old	= ChatFrame_OnEvent
	ChatFrame_OnEvent			= SI_ChatFrame_OnEvent_New

	if WIM_ChatFrame_OnEvent then
		SI_WIM_ChatFrame_OnEvent_Old	= WIM_ChatFrame_OnEvent
		WIM_ChatFrame_OnEvent			= SI_WIM_ChatFrame_OnEvent_New
	end

	if WhisperFu then
		WhisperFu.OnReceiveWhisper_Old	= WhisperFu.OnReceiveWhisper
		WhisperFu.OnReceiveWhisper		= SI_WhisperFu_OnReceiveWhisper_New
	end

	SI_SendChatMessage_Old		= SendChatMessage
	SendChatMessage				= SI_SendChatMessage_New
end

-- The ignore list itself, as a name filter; Auto-Block entries are listed only, not ignored
SI_BanListFilter = function(name)
	local index = SI_BannedGetIndex(name)
	if index and SI_BannedGetDuration(index) ~= TI_AUTOBLOCK then
		return true
	end
end

SI_ApplyFilters = function()
	SI_AddNameFilter(SI_BanListFilter)
end

SI_ReplaceOldIgnores = function()

	local oldNames = {}
	for i = 1, SI_GetNumIgnores_Old() do
		table.insert(oldNames, SI_GetIgnoreName_Old(i))
	end

	for _, name in oldNames do
		if name then
			SI_DelIgnore_Old(name)
			SI_AddIgnore_New(name, true)
		end
	end
end

SI_BannedChangeDuration = function(name, option)
	local index = SI_BannedGetIndex(name)
	if not index then return end

	local banTime = SI_CalcBanTime(option)
	SI_BannedSetDuration(index, banTime)
	SI_BannedSetOption(index, option)
	SI_BannedSortByTime()
	SI_RealmSpecific.BannedSelected = SI_BannedGetIndex(name)
	IgnoreList_Update()
	SI_Print(string.format(SS.ChatDuration, name, SI_FormatTimeNoColor(banTime)))
end

SI_BannedChangeReason = function(name, reason)
	local index = SI_BannedGetIndex(name)
	if not index then return end

	reason = string.gsub(reason or "", "^%s*(.-)%s*$", "%1")
	if reason == "" then reason = nil end
	SI_BannedSetReason(index, reason)
	IgnoreList_Update()
end

------------- Log


SI_LogIgnore = function(text, name, source)
	local logSuccess = SI_LogAdd(text, name)

	if logSuccess then
		for i = 1, table.getn(SI_BlockListeners) do
			SI_BlockListeners[i](text, name, source)
		end
	end

	-- Light up the row's log icon
	if logSuccess and IgnoreListFrame:IsVisible() then
		IgnoreList_Update()
	end

	if logSuccess and SI_LogFrame and SI_LogFrame:IsShown() and SI_LogFrame.name == name then
		if SI_LogFrame.empty then
			SI_LogFrame.messages:ClearLines()
			SI_LogFrame.empty = nil
		end
		SI_LogFrameAddLine(SI_Log[table.getn(SI_Log)])
	end
end

-- Lookups into SI_Log: name .. "\n" .. text -> true, and name -> true
local logSeen = {}
local logNames = {}

SI_LogAdd = function(text, name)
	local key = name .. "\n" .. text
	if logSeen[key] then
		return false
	end
	logSeen[key] = true
	logNames[name] = true
	table.insert(SI_Log, {[1] = name, [2] = text, [3] = date("%H:%M")})
	return true
end

SI_LogGetByName = function(name)
	local log = {}
	for _, msg in SI_Log do
		if msg[1] == name then
			table.insert(log, msg)
		end
	end
	return log
end

SI_LogHasName = function(name)
	return logNames[name] or false
end

------------- Initialization

local SETTINGS_VERSION = 1

local SI_Defaults = {
	WhisperBlock	= false,
	WhisperUnignore	= true,
	BanDuration		= T_ASK,

	BanOptWhisper	= true,
	BanOptParty		= false,
	BanOptGuild		= false,
	BanOptOfficer	= false,
	BanOptSay		= true,
	BanOptYell		= true,
	BanOptBg		= true,
	BanOptPublic	= true,
	BanOptEmote		= true,
	BanOptTrade		= true,
	BanOptInvite	= true,
	BanOptDuel		= true,
}

-- Fills in missing settings, so options added in later versions get their default
SI_LoadSettings = function()
	if not SI_Global then
		SI_Global = { SettingsVersion = SETTINGS_VERSION }
	elseif not SI_Global.SettingsVersion then
		-- Older versions saved unchecked boxes as nil: keep those off
		for k, v in SI_Defaults do
			if SI_Global[k] == nil and type(v) == "boolean" then
				SI_Global[k] = false
			end
		end
		SI_Global.SettingsVersion = SETTINGS_VERSION
	end

	for k, v in SI_Defaults do
		if SI_Global[k] == nil then
			SI_Global[k] = v
		end
	end

	-- Replaced by the Debugger module
	SI_Global.DebugLog = nil
end

SI_MainFrame = CreateFrame("frame")
SI_MainFrame:RegisterEvent("ADDON_LOADED")
SI_MainFrame:RegisterEvent("IGNORELIST_UPDATE")
SI_MainFrame:RegisterEvent("PLAYER_LOGIN")
SI_MainFrame:SetScript("OnEvent", function()
	if event == "ADDON_LOADED" then
		if string.lower(arg1) == SS.AddonDir then

			SI_LoadSettings()
			if not SI_Global.Mods then
				SI_Global.Mods = {}
			end

			if not SI_Global.DataByRealm then
				SI_Global.DataByRealm = {}
			end

			local realm = GetRealmName()
			if not SI_Global.DataByRealm[realm] then
				SI_Global.DataByRealm[realm] = {
					BannedPlayers	= SI_Global.BannedPlayers or {},
					BannedSelected	= SI_Global.BannedSelected or 1,
				}
			end
			-- The pre-realm list goes to the first realm only, not to every new one
			SI_Global.BannedPlayers = nil
			SI_Global.BannedSelected = nil

			SI_RealmSpecific = SI_Global.DataByRealm[realm]

			SI_HookFunctions()
			SI_SkinDetect()
			SI_CreateFrames()
			SI_EnableIgnoreListRightclick()
			SI_ApplyFilters()

			SI_Print(string.format("%s %s loaded.", SS.AddonName, SS.AddonVersion))

			SI_BannedClearRelog()
			local expired = SI_BannedCheckTimes(true)
			if table.getn(expired) > 0 then
				SI_Print(string.format(SS.ChatExpired, table.concat(expired, ", ")))
			end
			SI_TimeCheck_Last = GetTime()
			expiryFrame:Show()
		end
	elseif event == "PLAYER_LOGIN" then
		-- Every addon (incl. pfUI) is loaded by now regardless of load order
		SI_SkinDetect()
	elseif event == "IGNORELIST_UPDATE" then
		SI_MainFrame:UnregisterEvent("IGNORELIST_UPDATE")
		SI_ReplaceOldIgnores()
	end
end)

SlashCmdList["IGNORE"] = function(msg)
	local target = GetSlashCmdTarget(msg)
	if target then
		local _, _, name, reason = string.find(target, "^([^ ]+) +(.*)")
		if name and reason then
			SI_AddOrDelIgnore_New(name, false, nil, reason)
		else
			SI_AddOrDelIgnore_New(target)
		end
	else
		ShowIgnorePanel()
	end
end

------------- Sandbox

-- Runs fn(printed) against a throwaway ignore list, a copy of the settings, an empty
-- session log, filter lists holding only the ignore list, and empty FriendLib lists.
-- The addon's chat output goes to `printed` instead of the chat frame. Everything is
-- put back afterwards, also when fn errors. Used by the Debugger's simulation.
SI_Sandbox = function(fn)
	local saved = {
		realm = SI_RealmSpecific, global = SI_Global, log = SI_Log, print = SI_Print,
		nameFilter = SI_NameFilter, chatFilter = SI_ChatFilter, filterSource = SI_FilterSource,
		listeners = SI_BlockListeners, seen = logSeen, names = logNames, cancel = cancelMessageUntil,
		tradeName = tradeRequestName, tradeTime = tradeRequestTime, tradeAllowed = tradeAllowedName,
		whispered = FriendLib.whispered, friends = FriendLib.friends,
		guild = FriendLib.guild, group = FriendLib.group,
	}

	local settings = {}
	for k, v in SI_Global do
		settings[k] = v
	end
	local printed = {}

	SI_RealmSpecific = { BannedPlayers = {}, BannedSelected = 1 }
	SI_Global = settings
	SI_Log, logSeen, logNames = {}, {}, {}
	SI_Print = function(msg) table.insert(printed, msg) end
	SI_NameFilter, SI_ChatFilter = { SI_BanListFilter }, {}
	SI_FilterSource, SI_BlockListeners = {}, {}
	cancelMessageUntil = 0
	tradeRequestName, tradeRequestTime, tradeAllowedName = nil, 0, nil
	FriendLib.whispered, FriendLib.friends, FriendLib.guild, FriendLib.group = {}, {}, {}, {}
	SI_BannedIndexChanged()
	SI_ChatCacheReset()

	local ok, err = pcall(fn, printed)

	SI_RealmSpecific, SI_Global, SI_Log, SI_Print = saved.realm, saved.global, saved.log, saved.print
	SI_NameFilter, SI_ChatFilter, SI_FilterSource = saved.nameFilter, saved.chatFilter, saved.filterSource
	SI_BlockListeners, logSeen, logNames = saved.listeners, saved.seen, saved.names
	cancelMessageUntil = saved.cancel
	tradeRequestName, tradeRequestTime, tradeAllowedName = saved.tradeName, saved.tradeTime, saved.tradeAllowed
	FriendLib.whispered, FriendLib.friends = saved.whispered, saved.friends
	FriendLib.guild, FriendLib.group = saved.guild, saved.group
	SI_BannedIndexChanged()
	SI_ChatCacheReset()
	IgnoreList_Update()
	return ok, err
end
