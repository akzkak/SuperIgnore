
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

m.chatfilter = function(message, name, type)
	if name and FriendLib:IsFriend(name) then
		return false
	end

	message = strupper(message)
	for _, p in phrases do
		if strfind(message, p, nil, true) then
			return true
		end
	end
	return false
end
m.updatePhrases = function()
	local text = box:GetText()
	SI_ModSetVar(m.mod, "Text", text)
	phrases = {}
	for _, p in getlines(text) do
		if p ~= "" then
			table.insert(phrases, strupper(p))
		end
	end
end

m.createUI = function(frame)
	gui = SI_FrameCreateFrame("SI_CMB", 240, frame, -10, 0)
	gui:SetHeight(300)

	SI_FrameCreateHeader(gui, m.mod.Name, 12, -15)
	local hint = gui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOP", gui, "TOP", 0, -32)
	hint:SetText("One phrase per line")

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
	scroll:SetPoint("TOPLEFT", gui, "TOPLEFT", 15, -50)
	scroll:SetPoint("BOTTOMRIGHT", gui, "BOTTOMRIGHT", -37, 15)
	scroll:SetScrollChild(box)
	SI_Skin("scroll", scroll)

	box:SetText(SI_ModGetVar(m.mod, "Text") or "")
end

m.toggle = function()
	if gui:IsShown() then
		gui:Hide()
	else
		gui:Show()
	end
end

m.mod = {
	["Name"] = "Custom Filter",
	["Description"] = "Blocks all messages containing a phrase.",
	["Help"] = "Click 'Edit' and enter one phrase per line. Players that write messages containing one of these phrases will be temporarily ignored. Friends, party and guild members are never ignored.",
	["OnEnable"] = m.updatePhrases,
	["OnDisable"] = nil,
	["CreateUI"] = m.createUI,
	["OnEdit"] = m.toggle,
	["NameFilter"] = nil,
	["ChatFilter"] = m.chatfilter,
}

local f = CreateFrame("frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	SI_ModInstall(m.mod)
end)
