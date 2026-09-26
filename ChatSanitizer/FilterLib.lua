if not FilterLib then

	FilterLib = {}
	-- Ratings of recent messages (each one is rated once per chat frame); cleared when
	-- full so it can't grow for the whole session
	FilterLib.cachedRatings = {}
	FilterLib.cachedCount = 0
	FilterLib.cacheMax = 200

	-- Stolen from SpamMeNot
	FilterLib.words = {
		["5uneed"] = 50,
		["gold4guild"] = 50,
		["mm4ss"] = 50,
		["peons"] = 50,
		["peonz"] = 50,
		["fcwow"] = 50,
		["4hire"] = 30,
		["p4hire"] = 50,
		["g4pwowitems"] = 50,
		["ourgamecenter"] = 50,
		["mmo4store"] = 50,
		["worker"] = 25,
		["wow%-europe%.cn"] = 80,
		["epicinn"] = 50,
		["working"] = 20,
		["delivery"] = 30,
		["deliveries"] = 30,
		["manfarm"] = 20,
		["power"] = 25,
		["povver"] = 25,
		["level"] = 15,
		["lvl"] = 15,
		["mmo"] = 15,
		["pwr"] = 20,
		["store"] = 20,
		["gold"] = 30,
		["coin"] = 30,
		["get%s*gold"] = 10,
		["currency"] = 30,
		["account"] = 30,
		["%d+g"] = 10,
		["all%scustomer"] = 10,
		["profession"] = 30,
		["buy"] = 20,
		["purchase"] = 20,
		["sell"] = 20,
		["payment"] = 20,
		["dollar"] = 30,
		["pound"] = 30,
		["euro"] = 30,
		["€"] = 30,
		["%d+%s*eur"] = 30,
		["%d+%s*pound"] = 30,
		["%d+%s*usd"] = 30,
		["%d+%s*gbp"] = 30,
		["$$"] = 30,
		["$%d+"] = 30,
		["£"] = 30,
		["offer"] = 10,
		["free"] = 10,
		["order"] = 15,
		["fast"] = 15,
		["cheap"] = 15,
		["price"] = 10,
		["low"] = 10,
		["courtious"] = 15,
		["safe"] = 15,
		["special"] = 15,
		["service"] = 30,
		["p&l"] = 50,
		["days"] = 10,
		["discount"] = 20,
		["code"] = 10,
		["web:"] = 25,
		["www"] = 25,
		["3vv"] = 25,
		["wvvw"] = 25,
		["three w"] = 25,
		["%.com"] = 25,
		["%,com"] = 25,
		[" com"] = 10,
		["dot%s*com"] = 25,
		["dot%s*cn"] = 75,
		["%.cn"] = 75,
		["%,cn"] = 75,
		["banned"] = 15,
		["web"] = 20,
		["site"] = 20,
		["welcome%s*to"] = 30,
		["wellcome%s*to"] = 15,
		["wellcome"] = 15,
		["choice"] = 15,
		["promotion"] = 15,
		["wow%-toolbox"] = 50,
		["hack"] = 40,
		["undetectable"] = 20,
		["guarantee"] = 15,
		[">>"] = 12,
		["<<"] = 12,
		["=="] = 10,
		["server"] = 10,
		["1%s*%-%s*60"] = 15,
		["24%s*/*%s*7"] = 15,
		["level%s*%d+%s*account"] = 40,
		["stat%s*changer"] = 50,
		["live%s*chat"] = 30,
		["dude,%syou%ssuck,%sstop%sbeing%sa%sn00b."] = 100,
		["sell.*account"] = 50,
		["%d%s*customers"] = 15,
		["bonus"] = 10,
		["with%s*in%s*%d"] = 10,
		["e%-shop"] = 50,
		["c@m"] = 25,
		["buyeugold"] = 80,
		["byeugold"] = 80,
		["goldcat"] = 80,
		["m%s*4"] = 15,
		["pvpbank"] = 80,
		["g4wow"] = 80,
		["okogames"] = 80,
		["mmotank"] = 80,
		["elysiumnwow"] = 80,
		["mmogo"] = 80,
		["mmook"] = 80,
		["3w%."] = 25,
		["3w%,"] = 25,
		["%d+g=%d+"] = 20,
		["legacy%-?boost"] = 80,
		["rnrnoo%!<"] = 80,
		["doublemotank"] = 80,
		["money%-?circle"] = 80,
		["ovewowhaha"] = 80,
	}

	-- Common words that also appear inside normal words ("follow", "golden", "border").
	-- These only count as whole words ("gold", not "golden").
	FilterLib.wordOnly = {
		["worker"] = true, ["working"] = true, ["delivery"] = true, ["deliveries"] = true,
		["power"] = true, ["level"] = true, ["store"] = true, ["gold"] = true, ["coin"] = true,
		["currency"] = true, ["account"] = true, ["profession"] = true, ["buy"] = true,
		["purchase"] = true, ["sell"] = true, ["payment"] = true, ["dollar"] = true,
		["pound"] = true, ["euro"] = true, ["offer"] = true, ["free"] = true, ["order"] = true,
		["fast"] = true, ["cheap"] = true, ["price"] = true, ["low"] = true, ["safe"] = true,
		["special"] = true, ["service"] = true, ["days"] = true, ["discount"] = true,
		["code"] = true, ["banned"] = true, ["web"] = true, ["site"] = true, ["wellcome"] = true,
		["choice"] = true, ["promotion"] = true, ["hack"] = true, ["guarantee"] = true,
		["server"] = true, ["bonus"] = true,
	}

	function FilterLib:Filter(text)
		local count = self:RateMessage(text)
		if count >= 100 then
			return ""
		else
			return text
		end
	end

	-- The main spam rating formula.  Takes a string and returns a rating.  >= 100 is considered
	-- to be spam.
	function FilterLib:RateMessage(s)

		-- Strip out wow hyperlinks and colors
		s = self:RemoveHyperLinks(s)
		s = string.lower(s)

		local cached = self.cachedRatings[s]
		if cached then
			return cached
		end

		-- Everything but letters, digits and the symbols spam uses (ASCII only: UTF-8
		-- symbols between letters are removed too, "g★o★l★d" -> "gold")
		local spacestrip = "[^%w&$!.,<>=?]+"
		local sCompact = string.gsub(s, spacestrip, "")

		local weight1 = self:SpacedWordCheck(s)
		local weight2 = self:SubstringCheck(s)
		local weight3 = self:SubstringCheck(sCompact)

		local weight = weight1
		if weight2 > weight then
			weight = weight2
		end

		if weight3 > weight then
			weight = weight3
		end

		if self.cachedCount >= self.cacheMax then
			self.cachedRatings = {}
			self.cachedCount = 0
		end
		self.cachedRatings[s] = weight
		self.cachedCount = self.cachedCount + 1
		return weight
	end

	function FilterLib:RemoveHyperLinks(text)
		text = string.gsub(text, "|H.-|h(.-)|h", "%1")
		text = string.gsub(text, "|c%w%w%w%w%w%w%w%w(.-)|r", "%1")
		return text
	end

	-- Regular spaced word check.
	function FilterLib:SpacedWordCheck(s)
		local weight = 0
		local wordsChecked = {}

		-- Check individual words
		weight = weight + self:TestWords(wordsChecked, s)

		-- Remove double spacing and replace odd characters used for spaces with real ones
		-- and check again
		-- Everything but letters, digits and the symbols spam uses (ASCII only: UTF-8
		-- symbols between letters are removed too, "g★o★l★d" -> "gold")
		local spacestrip = "[^%w&$!.,<>=?]+"
		s = string.gsub(s, spacestrip, " ")
		weight = weight + self:TestWords(wordsChecked, s)

		-- Change numbers commonly used as letters to their letter and check again
		s = self:NumbersToLetters(s)
		weight = weight + self:TestWords(wordsChecked, s)

		-- and vice-versa
		s = self:LettersToNumbers(s)
		weight = weight + self:TestWords(wordsChecked, s)

		return weight
	end

	-- Simply search for word matches anywhere in the text
	function FilterLib:SubstringCheck(s)
		local word = ""
		local value = 0
		local weight = 0

		local wordsFound = {}

		weight = self:TestSubstringWords(wordsFound, s)

		weight = weight + self:TestSubstringWords(wordsFound, string.gsub(s,"[^%w]",""))

		-- Revert numerics
		s = self:NumbersToLetters(s)
		weight = weight + self:TestSubstringWords(wordsFound, s)

		-- and backwards
		s = self:LettersToNumbers(s)
		weight = weight + self:TestSubstringWords(wordsFound, s)

		return weight
	end

	-- Searches for substring matches for words in the word list
	-- Will not check for words listed in wordsFound
	function FilterLib:TestSubstringWords(wordsFound, s)
		local word = ""
		local value = 0
		local weight = 0

		-- Padded so whole-word matches work at the start and end of the text too
		local padded = " " .. s .. " "
		for word, value in pairs(self.words) do
			if not wordsFound[word] then
				local _, w
				if self.wordOnly[word] then
					_,_,w = string.find(padded, "[^%w]("..word..")[^%w]")
				else
					_,_,w = string.find(s, "("..word..")")
				end
				if (w) then
					weight = weight + value
					wordsFound[word] = 1
				end
			end
		end
		return weight
	end

	-- Tests individual words and returns a summed spam rating.  Words
	-- listed in wordsChecked are not checked again
	function FilterLib:TestWords(wordsChecked, s)
		local w = ""
		local weight = 0
		-- Check individual words
		for w in string.gfind(s, "%w+") do
			if (not wordsChecked[w]) then
				if (self.words[w]) then
					weight = weight + self.words[w]
				end
				wordsChecked[w] = 1;
			end
		end
		return weight;
	end

	function FilterLib:NumbersToLetters(s)
		s = string.gsub(s, "0" , "o")
		s = string.gsub(s, "1" , "l")
		s = string.gsub(s, "3" , "e")
		s = string.gsub(s, "4" , "a")
		s = string.gsub(s, "5" , "s")
		return s
	end

	function FilterLib:LettersToNumbers(s)
		s = string.gsub(s, "o" , "0")
		s = string.gsub(s, "l" , "1")
		s = string.gsub(s, "e" , "3")
		s = string.gsub(s, "a" , "4")
		s = string.gsub(s, "s" , "5")
		return s
	end
end
