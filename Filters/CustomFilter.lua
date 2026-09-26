
local getlines = function(text)
	text = text .. "\n"
	local lines = {}
	local index = 1
	local pos = 0
	while true do
		local newpos = strfind(text, "\n", pos, true)
		if not newpos then
			break
		end
		local line = strsub(text, pos, newpos - 1)
		if line ~= "" then
			lines[index] = line
			index = index + 1
		end
		pos = newpos + 1
	end
	return lines
end

local gui = nil
local box = nil
local phrases = {}

local m = {}

-- Drops non-latin characters (every UTF-8 multibyte byte), so unicode symbols or
-- lookalike letters inserted between latin letters can't dodge a phrase
local stripNonLatin = function(text)
	return (string.gsub(text, "[\128-\255]", ""))
end

-- Keeps only the visible text: "|cff1eff00|Hitem:...|h[Name]|h|r" becomes "[Name]"
local stripLinks = function(text)
	text = string.gsub(text, "|H.-|h(.-)|h", "%1")
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	return (string.gsub(text, "|r", ""))
end

m.chatfilter = function(message, name, chatType)
	if name and FriendLib:IsFriend(name) then
		return false
	end

	message = strupper(stripNonLatin(stripLinks(message)))
	for _, p in phrases do
		-- p[2]: phrase is a Lua pattern (had wildcards), otherwise a plain substring
		if strfind(message, p[1], 1, not p[2]) then
			return true
		end
	end
	return false
end

-- "*" matches any text, "?" any single character; everything else is literal
local wildcardToPattern = function(phrase)
	if not strfind(phrase, "[%*%?]") then
		return phrase, false
	end
	local pattern = string.gsub(phrase, "([%^%$%(%)%%%.%[%]%+%-])", "%%%1")
	pattern = string.gsub(pattern, "%*", ".-")
	pattern = string.gsub(pattern, "%?", ".")
	return pattern, true
end

local buildPhrases = function(text)
	local list = {}
	for _, p in getlines(text) do
		p = stripNonLatin(p)
		-- A line of only wildcards would match every message
		if strfind(p, "[^%*%?%s]") then
			local pattern, isPattern = wildcardToPattern(strupper(p))
			table.insert(list, {pattern, isPattern})
		end
	end
	return list
end

m.updatePhrases = function()
	local text = box:GetText()
	SI_ModSetVar(m.mod, "Text", text)
	phrases = buildPhrases(text)
end

-- Self-test for the Debugger's simulation, on its own phrase list
m.test = function(t)
	local realPhrases = phrases
	phrases = buildPhrases("buy*gold\nw?w\nDummy Phrase\n(wts)*\nhitem\n1eff00\n*\n   \n")
	local ok, err = pcall(function()
		local f = function(msg) return m.chatfilter(msg, "Dummyspammer") end
		t.check("* matches any text", f("BUY some cheap GOLD"))
		t.check("? matches one character", f("w0w"))
		t.check("? doesn't match two", not f("w00w"))
		t.check("Plain phrases match in any case", f("have a dUMMY pHRASE here"))
		t.check("Linked item names are matched", f("|cff1eff00|Hitem:2589:0:0:0|h[Dummy Phrase]|h|r"))
		t.check("Link codes are not ('hitem', '1eff00')", not f("|cff1eff00|Hitem:2589:0:0:0|h[Linen Cloth]|h|r"))
		t.check("Symbols between letters are ignored", f("dummy phr\226\152\133ase"))
		t.check("Special characters are literal", f("(wts) stuff") and not f("wts stuff"))
		t.check("A line of only wildcards is skipped", not f("anything at all"))
		FriendLib:AddFriend("Dummypal")
		t.check("Friends are never filtered", not m.chatfilter("buy gold", "Dummypal"))
	end)
	phrases = realPhrases
	if not ok then error(err) end
end

m.createUI = function(frame)
	gui = SI_FrameCreateFrame("SI_CMB", 240, frame, -10, 0)
	gui:SetHeight(300)

	SI_FrameCreateHeader(gui, m.mod.Name, 12, -15)
	local hint = gui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOP", gui, "TOP", 0, -32)
	hint:SetText("One phrase per line\n* = any text, ? = any character")

	box = CreateFrame("EditBox", "SI_CMB_Box", gui)
	box:SetMultiLine(true)
	box:SetAutoFocus(true)
	box:EnableMouse(true)
	box:SetMaxLetters(99999)
	box:SetFont("Fonts\\ARIALN.ttf", 13, "THINOUTLINE")
	SI_Skin("font", box, 13)
	box:SetWidth(180)
	box:SetHeight(3000)
	box:SetScript("OnEscapePressed", function() gui:Hide() end)
	box:SetScript("OnTextChanged", function() m.updatePhrases() end)

	local scroll = CreateFrame("scrollFrame", "SI_CMB_Scroll", gui, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", gui, "TOPLEFT", 15, -60)
	scroll:SetPoint("BOTTOMRIGHT", gui, "BOTTOMRIGHT", -37, 40)
	scroll:SetScrollChild(box)
	SI_Skin("scroll", scroll)

	SI_FrameCreateButton("SI_CMB_Copy", gui, "Copy", 85, "BOTTOMLEFT", 15, 14, function()
		SI_ShowCopyText(m.mod.Name, box:GetText())
	end)

	box:SetText(SI_ModGetVar(m.mod, "Text") or "")
end

m.toggle = function()
	SI_ToggleModPanel(gui)
end

m.mod = {
	["Name"] = "Custom Filter",
	["Tag"] = "filter",
	["Description"] = "Blocks all messages containing a phrase.",
	["Help"] = "Click 'Edit' and enter one phrase per line. Use * to match any text and ? to match any single character, e.g. 'buy*gold' or 'w?w'. Non-latin characters (accents, symbols, other alphabets) are ignored in both phrases and messages. Matching messages are hidden, the player is not ignored. They are listed as Auto-Block until relog, so you can review their messages via the log icon. Friends, party and guild members are never filtered.",
	["OnEnable"] = m.updatePhrases,
	["OnDisable"] = nil,
	["CreateUI"] = m.createUI,
	["OnEdit"] = m.toggle,
	["NameFilter"] = nil,
	["ChatFilter"] = m.chatfilter,
	["Test"] = m.test,
}

local f = CreateFrame("frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	SI_ModInstall(m.mod)
end)
