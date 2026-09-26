local name = "SuperIgnore"
local version = "1.4.8"

local SS = {
	["AddonName"]			= name,
	["AddonDir"]			= strlower(name),
	["AddonVersion"] 		= version,

	["TextGeneral"] 		= "General",
	["TextOptions"] 		= "Ignore Filter",
	["TextDuration"]		= "Default Ignore Time",
	["TextWhisperBlock"]	= "Do not let me whisper ignored players",
	["TextWhisperUnignore"]	= "Unignore players if I whisper them",
	["TextDebugLog"]		= "Debug: Log ignored actions in chat",

	["TextModules"]			= "Modules",
	["TextEdit"]			= "Edit",

	["ChatIgnored"]			= "%s is now being ignored. Duration: %s.",
	["ChatIgnoredReason"]	= "%s is now being ignored. Duration: %s. Reason: %s",
	["ChatUnignored"]		= "%s is no longer being ignored.",
	["ChatBlocked"]			= "Your message was not sent because are ignoring %s.",
	["ChatSelf"]			= "You can't ignore yourself.",

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

local TI_RELOG		= -1
local TI_FOREVER	= 1e30 -- lol
local TI_AUTOBLOCK	= 1e31

local B_NAME		= 1
local B_DURATION	= 2
local B_REASON		= 4

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

------------- Global

SI_NameFilter = {}
SI_ChatFilter = {}
-- filter -> short tag of the mod that installed it, shown as the auto-block reason
SI_FilterSource = {}

SI_MainFrame = nil
SI_OptionsFrame = nil
SI_RealmSpecific = nil
SI_TimeCheck_Last = 0

SI_LastIgnoreListButton = nil

SI_Mods = {}
-- Next free vertical offset in SI_OptionsFrame; mods are appended there
SI_OptionsFramePad = 0

SI_Log = {}

------------- pfUI Skin

-- pfUI api table while pfUI skinning is active, nil otherwise
SI_PF = nil
-- Every skinnable widget, so the skin can be applied whenever pfUI becomes ready
SI_SkinWidgets = {}

local skinApply = function(w)
	local kind, obj = w[1], w[2]
	if kind == "frame" then
		local _, border = SI_PF.GetBorderSize()
		local parent = w[3]
		local anchor = (parent == IgnoreListFrame and FriendsFrame.backdrop) or parent.backdrop or parent
		obj:SetBackdrop(nil)
		SI_PF.CreateBackdrop(obj, nil, nil, .75)
		SI_PF.CreateBackdropShadow(obj)
		obj:ClearAllPoints()
		obj:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 2 * border + 2, anchor == parent and 0 or -border)
	elseif kind == "font" then
		obj:SetFont(pfUI.font_default, w[3] or pfUI_config.global.font_size, "OUTLINE")
	elseif kind == "checkbox" then
		SI_PF.SkinCheckbox(obj)
	elseif kind == "button" then
		SI_PF.SkinButton(obj)
	elseif kind == "dropdown" then
		SI_PF.SkinDropDown(obj, nil, nil, nil, true)
	elseif kind == "close" then
		SI_PF.SkinCloseButton(obj, obj:GetParent().backdrop, -6, -6)
	elseif kind == "scroll" then
		SI_PF.SkinScrollbar(getglobal(obj:GetName() .. "ScrollBar"))
	end
end

-- kind: frame (arg = parent), font (arg = pfUI font size or nil for pfUI default), checkbox, button, dropdown, scroll
SI_Skin = function(kind, obj, arg)
	local w = {kind, obj, arg}
	table.insert(SI_SkinWidgets, w)
	if SI_PF then skinApply(w) end
end

local skinActivate = function()
	if SI_PF then return end
	SI_PF = pfUI.api
	for _, w in SI_SkinWidgets do
		skinApply(w)
	end
	if IgnoreListFrame:IsVisible() then SI_SkinPlaceShowButton(SI_OpenButton) end
end

-- Safe to call repeatedly; pfUI may load before or after SuperIgnore
SI_SkinDetect = function()
	if SI_PF or not (pfUI and pfUI.api and pfUI.api.CreateBackdrop and pfUI.RegisterSkin and pfUI_config) then return end
	-- Registered as a pfUI skin so it can be toggled in pfUI's settings
	if pfUI_config.disabled and pfUI_config.disabled["skin_SuperIgnore"] == "1" then return end
	-- Runs immediately if pfUI finished booting, otherwise once it does.
	-- pfUI setfenv()s skin functions into its own environment, so only call through an upvalue here.
	pfUI:RegisterSkin("SuperIgnore", function() skinActivate() end)
end

-- Aligns the SuperIgnore toggle with pfUI's relocated ignore list tabs/buttons
SI_SkinPlaceShowButton = function(b)
	if not (SI_PF and b and FriendsFrame.backdrop and IgnoreFrameToggleTab1 and FriendsFrameStopIgnoreButton) then return end
	local right, top = FriendsFrameStopIgnoreButton:GetRight(), IgnoreFrameToggleTab1:GetTop()
	local left, ptop = IgnoreListFrame:GetLeft(), IgnoreListFrame:GetTop()
	if not (right and top and left and ptop) then return end
	b:SetHeight(IgnoreFrameToggleTab1:GetHeight())
	b:ClearAllPoints()
	b:SetPoint("TOPRIGHT", IgnoreListFrame, "TOPLEFT", right - left, top - ptop)
end

------------- GUI Misc

SI_FrameCreateFrame = function(name, width, parent, x, y)
	local f = CreateFrame("Frame", name, parent)

	f:SetWidth(width)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 32,
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		insets = {left = 11, right = 12, top = 12, bottom = 11},
	})
	f:SetPoint("TOPLEFT", parent, "TOPRIGHT", x, y)
	f:Hide()
	SI_Skin("frame", f, parent)

	return f
end

SI_FrameCreateHeader = function(frame, text, fontSize, pad)
	local t = frame:CreateFontString(nil, "OVERLAY", frame)
	t:SetPoint("TOP", frame, "TOP", 0, pad)
	t:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
	SI_Skin("font", t, fontSize)
	t:SetTextColor(1,0.82,0)
	t:SetText(text)
	return t
end

SI_FrameCreateCheckbox = function(name, frame, x, pad, desc)
	local c = CreateFrame("CheckButton", name, frame, "UICheckButtonTemplate")
	c:SetHeight(20)
	c:SetWidth(20)
	c:SetPoint("TOPLEFT", frame, "TOPLEFT", x, pad)
	SI_Skin("checkbox", c)

	local ct = frame:CreateFontString(nil, "OVERLAY", frame)
	ct:SetPoint("LEFT", c, "RIGHT", 0, 0)
	ct:SetFont("Fonts\\FRIZQT__.TTF", 11)
	SI_Skin("font", ct)
	ct:SetText(desc)

	return c, ct
end

SI_FrameCreateOption = function(frame, name, desc, pad, onclick)
	local c, ct = SI_FrameCreateCheckbox(name, frame, 15, pad, desc)
	c:SetScript("OnClick", function()
		onclick(c:GetChecked())
	end)

	return c, ct
end

SI_FrameCreateButton = function(frame, text, pad, onclick)
	local b = CreateFrame("Button", text, frame, "UIPanelButtonTemplate")
	b:SetHeight(20)
	b:SetWidth(85)
	b:SetPoint("TOPLEFT", frame, "TOPLEFT", 100, pad)
	b:SetText(text)
	b:SetScript("OnClick", onclick)
	SI_Skin("button", b)

	return b
end

------------- Mods

SI_ModsGetNumber = function()
	return table.getn(SI_Mods)
end

SI_ModsGetMod = function(index)
	return SI_Mods[index]
end

local createModUI = function(index, mod)
	local f = SI_OptionsFrame

	if index == 1 then
		SI_OptionsFramePad = SI_OptionsFramePad - 5
		SI_FrameCreateHeader(f, SS.TextModules, 11, SI_OptionsFramePad)
		SI_OptionsFramePad = SI_OptionsFramePad - 15
	end

	local c, ct = SI_FrameCreateCheckbox("SI_ModEnable_"..index, f, 15, SI_OptionsFramePad, mod.Name)
	c:SetScript("OnClick", function()
		local checked = c:GetChecked()
		if checked then SI_ModEnable(index) else SI_ModDisable(index) end
	end)
	c:SetChecked(SI_Global.Mods[mod.Name].Enabled)
	-- Leave room for the Edit button
	SI_OptionsFrameAddLabel(ct, mod.OnEdit and 45 or 0)

	if mod.Description then
		c:SetScript("OnEnter", function()
			GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
			GameTooltip:SetText(mod.Name)
			GameTooltip:AddLine(mod.Description, 1, 1, 1, 1)
			if mod.Help then
				GameTooltip:AddLine(mod.Help, .8, .8, .8, 1)
			end
			GameTooltip:Show()
		end)
		c:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	if mod.CreateUI then
		mod.CreateUI(f)
	end

	if mod.OnEdit then
		local b = CreateFrame("Button", "SI_ModEdit_"..index, f, "UIPanelButtonTemplate")
		b:SetHeight(18)
		b:SetWidth(40)
		b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, SI_OptionsFramePad - 1)
		b:SetText(SS.TextEdit)
		b:SetScript("OnClick", mod.OnEdit)
		SI_Skin("button", b)
	end

	SI_OptionsFramePad = SI_OptionsFramePad - 15
	SI_OptionsFrameUpdateHeight()
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

	createModUI(index, mod)

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
	for k, v in SI_NameFilter do
		if v == filter then
			table.remove(SI_NameFilter, k)
		end
	end
end

SI_AddChatFilter = function(filter)
	table.insert(SI_ChatFilter, filter)
end
SI_DelChatFilter = function(filter)
	for k, v in SI_ChatFilter do
		if v == filter then
			table.remove(SI_ChatFilter, k)
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

SI_FilterIsChatIgnored = function(message, name, type)
	if name == UnitName("player") then
		return false
	end

	for _, filter in SI_ChatFilter do
		if filter(message, name, type) then
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
SI_BannedCheckTimes = function()
	local unbanNames = {}
	for _, banned in SI_RealmSpecific.BannedPlayers do
		if SI_IsBanTimeOver(banned[B_DURATION]) then
			table.insert(unbanNames, banned[B_NAME])
		end
	end

	for _, name in unbanNames do
		SI_DelIgnore_New(name)
	end
end
SI_BannedCheckTimesPeriodic = function()
	if GetTime() - SI_TimeCheck_Last > 60 then
		SI_TimeCheck_Last = GetTime()
		SI_BannedCheckTimes()
	end
end
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

SI_StringFindPattern = function(s, r)
	-- %s
	-- ([^ ]+)
	-- (.*)
	r = string.gsub(r, "%%s", "%(%[%^ %]%+%)", 1)
	r = string.gsub(r, "%%s", "%(%.%*%)")
	return string.find(s, r)
end

SI_FixBannedSelected = function()
	 local selected = SI_RealmSpecific.BannedSelected
	 if selected > 1 and selected > GetNumIgnores() then
		SI_RealmSpecific.BannedSelected = selected - 1
	 end
end

SI_BannedGetIndex = function(name)
	for index, banned in SI_RealmSpecific.BannedPlayers do
		if banned[B_NAME] == name then
			return index
		end
	end

	return nil
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
SI_BannedGetName = function(index)
	return SI_RealmSpecific.BannedPlayers[index][B_NAME]
end
SI_BannedSetName = function(index, name)
	SI_RealmSpecific.BannedPlayers[index][B_NAME] = name
end

SI_BannedSortByTime = function()
	table.sort(SI_RealmSpecific.BannedPlayers, function(a, b)
		local at = a[B_DURATION]
		local bt = b[B_DURATION]
		if at == bt then
			return a[B_NAME] < b[B_NAME]
		else
			return at < bt
		end
	end)
end

SI_IsChannelBanned = function(c)
	local g = SI_Global

	if c == "WHISPER"	then return g.BanOptWhisper end
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

SI_IsChatIgnored = function(event, arg1, arg2, arg3, arg4)

	if strsub(event, 1, 8) == "CHAT_MSG" then
		local type = strsub(event, 10)

		local source = strsub(type,1,1)
		if type == "CHANNEL" and arg4 then
			source = strsub(arg4,1,1)
		end

		if arg1 and type == "SYSTEM" then
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

		if arg1 and arg2 and SI_IsChannelBanned(type) then
			if SI_FilterIsPlayerIgnored(arg2) or SI_FilterIsChatIgnored(arg1, arg2, type) then
				SI_LogIgnore(arg1, arg2, source)
				SI_BubbleBlock(type, arg1)
				return true
			end
		end
	end

	return false
end

------------- Chat Bubbles

-- Bubbles are drawn by the client and don't know the sender, so blocked messages are
-- remembered for a few seconds and any bubble (unnamed WorldFrame child) showing that
-- exact text is made invisible. Hidden bubbles are tracked because the client recycles them.
local BUBBLE_TYPES = { SAY = true, YELL = true, PARTY = true }
local BUBBLE_TTL = 5

local bubbleTexts = {}		-- text -> expiry time
local bubbleHidden = {}		-- frame -> text it was hidden for
local bubbleFrame = CreateFrame("Frame")
bubbleFrame:Hide()

local bubbleGetText = function(frame)
	local regions = { frame:GetRegions() }
	for i = 1, table.getn(regions) do
		local r = regions[i]
		if r:GetObjectType() == "FontString" then
			local text = r:GetText()
			if text then return text end
		end
	end
end

bubbleFrame:SetScript("OnUpdate", function()
	local now = GetTime()
	local active = false

	for text, expiry in bubbleTexts do
		if expiry < now then
			bubbleTexts[text] = nil
		else
			active = true
		end
	end

	-- Keep hidden bubbles invisible, give recycled ones their alpha back
	for frame, text in bubbleHidden do
		if frame:IsShown() and bubbleGetText(frame) == text then
			frame:SetAlpha(0)
			active = true
		else
			frame:SetAlpha(1)
			bubbleHidden[frame] = nil
		end
	end

	if next(bubbleTexts) then
		local kids = { WorldFrame:GetChildren() }
		for i = 1, table.getn(kids) do
			local frame = kids[i]
			if not bubbleHidden[frame] and not frame:GetName() and frame:IsShown() then
				local text = bubbleGetText(frame)
				if text and bubbleTexts[text] then
					frame:SetAlpha(0)
					bubbleHidden[frame] = text
					active = true
				end
			end
		end
	end

	if not active then
		this:Hide()
	end
end)

SI_BubbleBlock = function(type, text)
	if not BUBBLE_TYPES[type] then return end
	bubbleTexts[text] = GetTime() + BUBBLE_TTL
	bubbleFrame:Show()
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

local SI_IgnoreHandled = false

SI_AddIgnore_New = function(name, quiet, banTime, reason)
	SI_IgnoreHandled = true
	if not name then return end

	name = SI_FixPlayerName(name)
	if name == UnitName("player") then
		SI_Print(SS.ChatSelf)
		return
	end

	if not banTime then
		banTime = SI_CalcBanTime()
	end

	local index = SI_BannedGetIndex(name)
	if index then
		SI_BannedSetDuration(index, banTime)
		SI_BannedSetReason(index, reason)
	else
		table.insert(SI_RealmSpecific.BannedPlayers, {name, banTime, nil, reason})
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

-- The row's name text, which lives on the row's "$parentButtonText" child frame
local ignoreRowNameText = function(button)
	return getglobal(button:GetName() .. "ButtonTextName")
end

-- Offset from the row's right edge that mirrors the name's left padding.
-- pfUI: measured between the Friends/Ignore tabs (left) and the SuperIgnore button (right).
-- Default UI: the tabs are centered, not edge-aligned, so mirror the padding within the row itself.
local ignoreRowRightOffset = function(button)
	local nameText = ignoreRowNameText(button)
	local textLeft = nameText and nameText:GetLeft()
	local rowLeft, rowRight = button:GetLeft(), button:GetRight()
	if not (textLeft and rowLeft and rowRight) then
		return nil
	end
	if SI_PF then
		local leftEdge = IgnoreFrameToggleTab1 and IgnoreFrameToggleTab1:GetLeft()
		local rightEdge = SI_OpenButton and SI_OpenButton:GetRight()
		if not (leftEdge and rightEdge) then
			return nil
		end
		return (rightEdge - (textLeft - leftEdge)) - rowRight
	end
	return -(textLeft - rowLeft)
end

-- Friends list style "Name - Reason"; the reason is cut with "..." so the row text
-- ends before the duration column
local ignoreRowFitText = function(nameText, banned, duration)
	local name, reason = banned[B_NAME], banned[B_REASON]
	local textLeft, durationLeft = nameText:GetLeft(), duration:GetLeft()
	if not reason then return true end
	nameText:SetText(name .. " |cff808080- " .. reason .. "|r")
	if not (textLeft and durationLeft) then return false end

	local maxWidth = durationLeft - 8 - textLeft
	if nameText:GetStringWidth() <= maxWidth then return true end

	local len = string.len(reason)
	while len > 0 do
		len = len - 1
		local cut = string.gsub(string.sub(reason, 1, len), "%s+$", "")
		nameText:SetText(name .. " |cff808080- " .. cut .. "...|r")
		if nameText:GetStringWidth() <= maxWidth then return true end
	end
	nameText:SetText(name)
	return true
end

-- Positions aren't always resolved on the frame a list first shows; retry a few frames later
local ignoreRowRetries = 0
local ignoreRowRetry = CreateFrame("Frame")
ignoreRowRetry:Hide()
ignoreRowRetry:SetScript("OnUpdate", function()
	this:Hide()
	IgnoreList_Update()
end)

-- Right-aligned, dimmed duration on each ignore list row
SI_IgnoreList_Update_Old = nil
SI_IgnoreList_Update_New = function()
	SI_IgnoreList_Update_Old()
	local unmeasured = false

	for i = 1, IGNORES_TO_DISPLAY do
		local button = getglobal("FriendsFrameIgnoreButton" .. i)
		if button then
			if not button.siDuration then
				local log = CreateFrame("Button", nil, button)
				log:SetWidth(14)
				log:SetHeight(14)
				log:SetFrameLevel(button:GetFrameLevel() + 2)
				log:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
				log:SetHighlightTexture("Interface\\Buttons\\GlowStar", "ADD")
				log:SetScript("OnEnter", function() this:SetAlpha(1) end)
				log:SetScript("OnLeave", function() this:SetAlpha(this.alpha) end)
				log:SetScript("OnClick", function() SI_LogFrameShow(this.name) end)
				button.siLog = log

				button.siDuration = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
				button.siDuration:SetPoint("RIGHT", log, "LEFT", -4, 0)
				button.siDuration:SetJustifyH("RIGHT")
			end
			local banned = SI_RealmSpecific.BannedPlayers[button:GetID()]

			local offset = ignoreRowRightOffset(button)
			if not offset then
				offset = -8
				if banned then unmeasured = true end
			end
			button.siLog:ClearAllPoints()
			button.siLog:SetPoint("RIGHT", button, "RIGHT", offset, 0)
			button.siDuration:SetText(banned and SI_FormatTimeNoColor(banned[B_DURATION]) or "")
			if banned then
				local log = button.siLog
				log.name = banned[B_NAME]
				-- Dim and grey when empty, full color when something was blocked
				if SI_LogHasName(log.name) then
					log.alpha = 1
					log:GetNormalTexture():SetVertexColor(1, 1, 1)
				else
					log.alpha = .35
					log:GetNormalTexture():SetVertexColor(.6, .6, .6)
				end
				if not MouseIsOver(log) then log:SetAlpha(log.alpha) end
				log:Show()

				local nameText = ignoreRowNameText(button)
				if nameText and not ignoreRowFitText(nameText, banned, button.siDuration) then
					unmeasured = true
				end
			else
				button.siLog:Hide()
			end
		end
	end

	if unmeasured and ignoreRowRetries < 5 and IgnoreListFrame:IsVisible() then
		ignoreRowRetries = ignoreRowRetries + 1
		ignoreRowRetry:Show()
	elseif not unmeasured then
		ignoreRowRetries = 0
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
	if not SI_IsChatIgnored(event, arg1, arg2, agr3, arg4) then
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
	if name and SI_FilterIsPlayerIgnored(name) then
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

SI_ApplyFilters = function()

	SI_AddNameFilter(function(name)
		SI_BannedCheckTimesPeriodic()
		local index = SI_BannedGetIndex(name)
		if index and SI_BannedGetDuration(index) ~= TI_AUTOBLOCK then
			return true
		end
	end)
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

-- Player whose reason is being edited, and the popup doing it
SI_ReasonTarget = nil
SI_ReasonDialog = nil

StaticPopupDialogs["SI_SetReason"] = {
	text = SS.PopupReason,
	button1 = TEXT(ACCEPT),
	button2 = TEXT(CANCEL),
	hasEditBox = 1,
	maxLetters = 64,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnShow = function()
		local box = getglobal(this:GetName() .. "EditBox")
		local index = SI_BannedGetIndex(SI_ReasonTarget)
		box:SetText(index and SI_BannedGetReason(index) or "")
		box:HighlightText()
		box:SetFocus()
	end,
	OnAccept = function()
		if SI_ReasonDialog then
			SI_BannedChangeReason(SI_ReasonTarget, getglobal(SI_ReasonDialog:GetName() .. "EditBox"):GetText())
		end
	end,
	EditBoxOnEnterPressed = function()
		SI_BannedChangeReason(SI_ReasonTarget, this:GetText())
		this:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function()
		this:GetParent():Hide()
	end,
}

SI_BannedChangeDuration = function(name, option)
	local index = SI_BannedGetIndex(name)
	if not index then return end

	local banTime = SI_CalcBanTime(option)
	SI_BannedSetDuration(index, banTime)
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

local rightClickName = nil

local rightClickMenuInit = function()
	local name = rightClickName
	local index = name and SI_BannedGetIndex(name)
	if not index then return end
	local info

	if UIDROPDOWNMENU_MENU_LEVEL == 2 then
		local current = SI_BannedGetDuration(index)
		for i = 1, table.getn(T_Time_TextOpt) do
			local option = i
			info = {}
			info.text = T_Time_TextOpt[i]
			info.checked = SI_IsTimeSpecial(T_Time[i]) and current == T_Time[i]
			info.func = function()
				SI_BannedChangeDuration(name, option)
				CloseDropDownMenus()
			end
			UIDropDownMenu_AddButton(info, 2)
		end
		return
	end

	info = {}
	info.text = name
	info.isTitle = 1
	info.notCheckable = 1
	UIDropDownMenu_AddButton(info)

	info = {}
	info.text = SS.MenuDuration
	info.hasArrow = 1
	info.value = "SI_DURATION"
	info.notCheckable = 1
	UIDropDownMenu_AddButton(info)

	info = {}
	info.text = SS.MenuReason
	info.notCheckable = 1
	info.func = function()
		SI_ReasonTarget = name
		SI_ReasonDialog = StaticPopup_Show("SI_SetReason", name)
	end
	UIDropDownMenu_AddButton(info)

	info = {}
	info.text = SS.MenuUnignore
	info.notCheckable = 1
	info.func = function()
		SI_DelIgnore_New(name)
	end
	UIDropDownMenu_AddButton(info)

	info = {}
	info.text = TEXT(CANCEL)
	info.notCheckable = 1
	info.func = function() CloseDropDownMenus() end
	UIDropDownMenu_AddButton(info)
end

SI_RightClickMenu = function(index)
	if not SI_RealmSpecific.BannedPlayers[index] then return end
	rightClickName = SI_BannedGetName(index)

	SI_RealmSpecific.BannedSelected = index
	IgnoreList_Update()

	if not SI_IgnoreMenu then
		CreateFrame("Frame", "SI_IgnoreMenu", UIParent, "UIDropDownMenuTemplate")
	end
	UIDropDownMenu_Initialize(SI_IgnoreMenu, rightClickMenuInit, "MENU")
	ToggleDropDownMenu(1, nil, SI_IgnoreMenu, "cursor")
end

------------- Log


SI_LogIgnore = function(text, name, source)
	local logSuccess = SI_LogAdd(text, name)
	if not source then source = "" end

	if logSuccess and SI_Global.DebugLog then
		SI_Print("IGNORED: ["..source.."] " .. "\124cffff10f0\124Hplayer:"..name.."\124h["..name.."]\124h\124r" .. ": " .. text)
	end

	-- Light up the row's log icon
	if logSuccess and IgnoreListFrame:IsVisible() then
		IgnoreList_Update()
	end

	if logSuccess and SI_LogFrame and SI_LogFrame:IsShown() and SI_LogFrame.name == name then
		if SI_LogFrame.empty then
			SI_LogFrame.messages:Clear()
			SI_LogFrame.empty = nil
		end
		SI_LogFrameAddLine(SI_Log[table.getn(SI_Log)])
	end
end

SI_LogAdd = function(text, name)
	for _, msg in SI_Log do
		if msg[1] == name and msg[2] == text then
			return false
		end
	end
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
	for _, msg in SI_Log do
		if msg[1] == name then
			return true
		end
	end
	return false
end

------------- Frames


SI_CreateOptionsFrame = function()

	-- Height set at function end
	SI_OptionsFrame = SI_FrameCreateFrame("SI_OptionsFrame", 185, IgnoreListFrame, -34, -7)
	local f = SI_OptionsFrame

	local pad = 0

	local createOpt = function(index, var, desc, padding, onclick)
		local c, ct = SI_FrameCreateOption(f, "SI_Box_"..index, desc, padding, function(checked)
			SI_Global[var] = checked and true or false
			if onclick then onclick(checked) end
		end)
		c:SetChecked(SI_Global[var])
		SI_OptionsFrameAddLabel(ct)

		return c, ct
	end

	pad = pad - 15
	local version = f:CreateFontString(nil, "OVERLAY", f)
	version:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 8)
	version:SetFont("Fonts\\FRIZQT__.TTF", 9)
	SI_Skin("font", version, 9)
	version:SetTextColor(.5, .5, .5, .6)
	version:SetText("v" .. SS.AddonVersion)

	SI_FrameCreateHeader(f, SS.TextGeneral, 11, pad)
	pad = pad - 15

	createOpt(100, "WhisperBlock", SS.TextWhisperBlock, pad, function(checked)
		if checked and SI_Box_101:GetChecked() then SI_Box_101:Click() end
	end)
	pad = pad - 18

	createOpt(101, "WhisperUnignore", SS.TextWhisperUnignore, pad, function(checked)
		if checked and SI_Box_100:GetChecked() then SI_Box_100:Click() end
	end)
	pad = pad - 18

	createOpt(103, "DebugLog", SS.TextDebugLog, pad)
	pad = pad - 28

	SI_FrameCreateHeader(f, SS.TextOptions, 11, pad)
	pad = pad - 15

	local options = {
		{"BanOptWhisper",	SS.BanWhisper,	15},
		{"BanOptParty",		SS.BanParty,	15},
		{"BanOptGuild",		SS.BanGuild,	15},
		{"BanOptOfficer",	SS.BanOfficer,	15},
		{"BanOptSay",		SS.BanSay,		15},
		{"BanOptYell",		SS.BanYell,		15},
		{"BanOptBg",		SS.BanBG,		15},
		{"BanOptPublic",	SS.BanChannel,	15},
		{"BanOptEmote",		SS.BanEmote,	15},
		{"BanOptTrade",		SS.BanTrade,	15},
		{"BanOptInvite",	SS.BanInvite,	15},
		{"BanOptDuel",		SS.BanDuel,		25}
	}

	for i = 1, table.getn(options) do
		local optVar		= options[i][1]
		local optDesc		= options[i][2]
		local optPadding	= options[i][3]
		createOpt(i, optVar, optDesc, pad)
		pad = pad - optPadding
	end

	SI_FrameCreateHeader(f, SS.TextDuration, 11, pad)
	pad = pad - 15

	local dd = CreateFrame("Button", "SI_BanDuration", f, "UIDropDownMenuTemplate")
	dd:SetPoint("TOP", f, "TOP", 0, pad)
	UIDropDownMenu_SetWidth(100, dd)
	UIDropDownMenu_JustifyText("LEFT", dd)
	UIDropDownMenu_Initialize(dd, function()
		local info = {}
		for i = 1, table.getn(T_Time_TextOpt) do
			info.text = T_Time_TextOpt[i]
			info.value = i
			info.func = function()
				UIDropDownMenu_SetSelectedID(dd, this:GetID())
				SI_Global.BanDuration = this:GetID()
			end
			info.checked = nil
			UIDropDownMenu_AddButton(info, 1)
		end
	end)
	UIDropDownMenu_SetSelectedID(dd, SI_Global.BanDuration)
	SI_Skin("dropdown", dd)

	SI_OptionsFramePad = pad - 35
	SI_OptionsFrameUpdateHeight()
	f:SetScript("OnShow", SI_OptionsFrameUpdateWidth)
end

-- Option labels and the extra space each row needs to their right
SI_OptionsFrameLabels = {}

SI_OptionsFrameAddLabel = function(label, extra)
	table.insert(SI_OptionsFrameLabels, {label, extra or 0})
end

-- Fits the frame to its widest row, so labels never wrap (font depends on pfUI)
SI_OptionsFrameUpdateWidth = function()
	local width = 185
	for _, l in SI_OptionsFrameLabels do
		-- checkbox offset + checkbox + label + row extra + right margin
		width = math.max(width, 15 + 20 + l[1]:GetStringWidth() + l[2] + 20)
	end
	SI_OptionsFrame:SetWidth(math.ceil(width))
end

SI_OptionsFrameUpdateHeight = function()
	SI_OptionsFrame:SetHeight(28 + (- SI_OptionsFramePad))
end

SI_CreateLogFrame = function()
	SI_LogFrame = SI_FrameCreateFrame("SI_LogFrame", 260, IgnoreListFrame, -34, -7)
	local f = SI_LogFrame
	f:SetHeight(300)

	f.title = SI_FrameCreateHeader(f, "", 12, -15)

	local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	sub:SetPoint("TOP", f, "TOP", 0, -32)
	sub:SetText(SS.LogTitle)

	local close = CreateFrame("Button", "SI_LogFrameClose", f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	SI_Skin("close", close)

	local msgs = CreateFrame("ScrollingMessageFrame", "SI_LogFrameMessages", f)
	msgs:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -50)
	msgs:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 15)
	msgs:SetFontObject(GameFontHighlightSmall)
	msgs:SetJustifyH("LEFT")
	msgs:SetMaxLines(500)
	msgs:SetFading(false)
	msgs:EnableMouseWheel(true)
	msgs:SetScript("OnMouseWheel", function()
		if arg1 > 0 then msgs:ScrollUp() else msgs:ScrollDown() end
	end)
	f.messages = msgs
end

SI_LogFrameAddLine = function(msg)
	SI_LogFrame.messages:AddMessage("|cff808080" .. msg[3] .. "|r  " .. msg[2])
end

-- Toggles the log panel for one player; shares its spot with the options panel
SI_LogFrameShow = function(name)
	local f = SI_LogFrame
	if f:IsShown() and f.name == name then
		f:Hide()
		return
	end

	f.name = name
	f.title:SetText(name)
	f.messages:Clear()
	local log = SI_LogGetByName(name)
	for _, msg in log do
		SI_LogFrameAddLine(msg)
	end
	f.empty = table.getn(log) == 0 or nil
	if f.empty then
		f.messages:AddMessage(SS.LogEmpty, .5, .5, .5)
	end

	SI_OptionsFrame:Hide()
	f:Show()
end

SI_CreateShowButton = function()
	local b = CreateFrame("Button", "SI_OpenButton", IgnoreListFrame, "UIPanelButtonTemplate")
	b:SetHeight(21)
	b:SetWidth(130)
	b:SetText(SS.AddonName)
	b:SetPoint("TOPLEFT", IgnoreListFrame, "TOPLEFT", 210, -50)
	SI_Skin("button", b)
	b:SetScript("OnClick", function()
		if SI_OptionsFrame:IsShown() then
			SI_OptionsFrame:Hide()
		else
			SI_LogFrame:Hide()
			SI_OptionsFrame:Show()
		end
	end)
end

SI_CreateFrames = function()
	SI_CreateOptionsFrame()
	SI_CreateLogFrame()
	SI_CreateShowButton()

	local oldOnShow = IgnoreListFrame:GetScript("OnShow")
	IgnoreListFrame:SetScript("OnShow", function()
		if oldOnShow then oldOnShow() end
		-- Place the button first; row padding is measured against it
		SI_SkinPlaceShowButton(SI_OpenButton)
		IgnoreList_Update()
	end)
end

SI_EnableIgnoreListRightclick = function()
	for i = 1, 20 do
		local item = getglobal("FriendsFrameIgnoreButton" .. i)
		item:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	end
end

------------- Initialization

local SETTINGS_VERSION = 1

local SI_Defaults = {
	WhisperBlock	= false,
	WhisperUnignore	= true,
	DebugLog		= false,
	BanDuration		= T_FOREVER,

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
			SI_BannedCheckTimes()
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

--Add Ignore button to dropdown menus (skip on Turtle WoW, which already has it)
if getglobal("TURTLE_WOW_VERSION") == nil then
	UnitPopupButtons["IGNORE"]	= { text = TEXT(IGNORE), dist = 0 };
	tinsert(UnitPopupMenus["FRIEND"], 4, "IGNORE");
	tinsert(UnitPopupMenus["PLAYER"], 8, "IGNORE");
	tinsert(UnitPopupMenus["RAID"], 5, "IGNORE");
	tinsert(UnitPopupMenus["PARTY"], 10, "IGNORE");
end

local function PostHookFunction(original, hook, pre)
	return function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
		if pre then pre() end
		original(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
		hook(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
	end
end

local function SI_UnitPopup_HideButtons()
	local dropdownMenu = getglobal(UIDROPDOWNMENU_INIT_MENU);
	local canCoop = 0;
	if ( dropdownMenu.unit and UnitCanCooperate("player", dropdownMenu.unit) ) then
		canCoop = 1;
	end
	for index, value in ipairs(UnitPopupMenus[dropdownMenu.which]) do
		if ( value == "IGNORE" ) then
			if ( dropdownMenu.name == UnitName("player") or (dropdownMenu.unit and canCoop == 0) ) then
				UnitPopupShown[index] = 0;
			end
		end
	end
end
UnitPopup_HideButtons = PostHookFunction(UnitPopup_HideButtons, SI_UnitPopup_HideButtons)
local function SI_UnitPopup_OnClick()
	local dropdownFrame = getglobal(UIDROPDOWNMENU_INIT_MENU);
	local button = this.value;
	local name = dropdownFrame.name;

	if ( button == "IGNORE" and not SI_IgnoreHandled ) then
		SI_AddOrDelIgnore_New(name);
	end
	PlaySound("UChatScrollButton");
end
-- Clear the flag before the original runs, so only this click can mark it handled
-- (ignores from /ignore, filters or expiry would otherwise leave it set)
UnitPopup_OnClick = PostHookFunction(UnitPopup_OnClick, SI_UnitPopup_OnClick,
	function() SI_IgnoreHandled = false end)
----
