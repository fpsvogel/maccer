--[[

macra.lua
by Felipe Vogel
fps.vogel@gmail.com

Function library for Maccer.

Copyright 2015 Felipe Vogel. Distributed under the terms of the GNU General Public License.

	This file is part of Maccer.

    Maccer is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Maccer is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with the Macronizer.  If not, see <http://www.gnu.org/licenses/>.
--]]

local glue = require "glue"
local utf8 = require "scripts.utf8"	-- from https://github.com/alexander-yakushev/awesompd/blob/master/utf8.lua

local macra = {}

-- misc. constants
macra.SEP = package.config:sub(1,1)		-- directory separator
macra.IS_UNIX = (SEP == "/" and true or false)
macra.DIVIDER = "_____"		-- used in data files: key.txt, unicode.txt
macra.SECTION = "##### "	-- used in "_repairs.txt"
macra.LINE = " ================================\n"		-- used in "_repairs.txt"
macra.MAX_HEADER = 40		-- maximum number of characters in a text's header
macra.FLAG_NOTFOUND, macra.FLAG_AMBIG, macra.FLAG_GUESS, macra.FLAG_AFFIX, macra.FLAG_INVALID = "✖", "✒", "✪", "❡", "❋"
macra.USER_ABBREV = "@"		-- words preceded by this are treated as abbreviations by exmac
macra.PUNCT = "[\t\n%s%d%!%\"%#%$%%%&%'%(%)%*%+%,%@%-%/%:%;%<%=%>%?%[%\\%]%^%_%`%{%|%}%~]"	-- minus period (abbreviations); used by Repair Key
macra.LETTERS = string.gsub("[^\t\n%s%d%!%\"%#%$%%%&%'%(%)%*%+%,%@%-%/%:%;%<%=%>%?%[%\\%]%^%_%`%{%|%}%~]+", "%%"..macra.USER_ABBREV, "")
	-- LETTERS = ^(%p minus "." (to find abbreviations) and macra.USER_ABBREV plus escape characters); %p = !"#$%&'()*+,-/:;<=>?.@[\]^_`{|}~
macra.GUESS_THRESHOLD = 0.75	-- minimum percent likelihood of a macron-form variation for it to be guessed (e.g. "est" is guessed because it is >75% likely, "ēst" being very unlikely)
macra.ABV, macra.ENC, macra.AUTO, macra.OK = 1, 2, 3, 4		-- repair type constants, used in load/save history
macra.repairnametbl = {"abbrev", "enclitic", "replace", "ok"}	-- strings in "repair-[x].txt"

-- modifiers for replacement strings in the substitution lists "hidden.txt" and "orthography.txt"
-- see "_README.txt"
LEFT_BEGIN = "["
LEFT_CONTINUE = "<"
RIGHT_END = "]"
RIGHT_CONTINUE = ">"
NO_CHAIN = "*"
macra.DOUBT_CHAR = "~"		-- accessed by fixkey.lua
macra.COMMENT, macra.COMMENT_MULTI = "//([^\n]+)", "/%*(.*)%*/"

-- directories
macra.DIR_ROOT = lfs.currentdir()..macra.SEP
macra.DIR_MACRONIZE = macra.DIR_ROOT.."macronize"..macra.SEP
macra.DIR_SOURCES = macra.DIR_ROOT.."sources"..macra.SEP
macra.DIR_DATA = macra.DIR_ROOT.."data"..macra.SEP
macra.DIR_LOGS = macra.DIR_ROOT.."logs"..macra.SEP
macra.DIR_BACKUP = macra.DIR_ROOT.."backup"..macra.SEP

-- global program data, from the "data" folder (those assigned a nil value are initialized elsewhere)
macra.keytbl = {}		-- (key) e.g. keytbl["hoc"] = "hōc", keytbl["hoc1"] == "hoc"
macra.freqtbl = {}		-- (key) e.g. freqtbl["hōc"] = 152
macra.headerstbl = {}	-- (key) e.g. headerstbl["hōc"] = {["De Bello Gallico"] = true, ["Metamorphoses"] = true}
macra.headersbynumtbl = nil	-- e.g. headersbynumtbl[3] = "Metamorphoses"
macra.macroninvtbl = {}	-- e.g. macron["ā"] = "a"
macra.macrontbl = nil	-- same as macroninvtbl but with keys and values inverted
macra.tildeinvtbl = {}
macra.tildetbl = nil	-- e.g. tildetbl["a"] = "ã"
macra.capsinvtbl = {}	-- e.g. capstbl["Ā"] = "ā", capstbl["Ã"] = "ã", capstbl["A"] = "a"
macra.capstbl = nil		-- same as capstbl but with keys and values inverted
macra.unicodeinvtbl = {}	-- all Unicode-ASCII pairs
macra.ignoretbl = {}	-- e.g. ignoretbl["«"] = true
macra.enclitictbl = {}	-- e.g. enclitictbl["ne"] = false (whether it is on average a real enclitic)
macra.prefixtbl = {}	-- e.g. prefixtbl[5] = "pro", prefixmactbl["pro"] = "prō"
macra.prefixmactbl = {}

macra.orthorigtbl = nil	-- originals of orthographic substitutions, e.g. sorigtbl[5] = "Camoen"
macra.orthrepltbl = nil	-- replacements of substitutions, e.g. srepltbl[5] = "Camēn"
macra.orthreplinvtbl = nil	-- initialized at runtime by mac.lua if necessary
macra.orthmodtbl = nil	-- modifiers of substitutions, e.g. smodtbl[5] = "[" (can only begin a word)
macra.orthnotetbl = nil

macra.logf = nil	-- keep a copy of the log here when it is opened, for use by macra functions

-- see "_CONFIG.txt"
macra.OVERWRITE_MACS = false
macra.REPAIR_ORTH = false
macra.LONG_PERF_SUBJ = false


--===========  I N I T I A L I Z A T I O N  ===============================


-- loads program data
function macra.initialize(action, backupkey, delaybackup)
	if backupkey == nil then backupkey = false end
	print("\nInitializing ...\n")
	macra.logf = macra.openlog(action)
	-- unicode.txt
	macra.loadunicode(macra.DIR_DATA.."unicode.txt")
	local backupkeystr = nil
	if backupkey then backupkeystr = macra.loadkey(macra.DIR_DATA.."key.txt", action, delaybackup)
	else macra.loadkey(macra.DIR_DATA.."key.txt") end
	-- orthography.txt
	macra.orthorigtbl, macra.orthrepltbl, macra.orthmodtbl, macra.orthnotestbl = macra.setupsubs(macra.readutf8(macra.DIR_DATA.."orthography.txt"))
	-- add intervocallic "u" -> "v"
	local vowelstbl = {["a"]=true, ["e"]=true, ["i"]=true, ["o"]=true, ["u"]=true, ["y"]=true, ["ā"]=true, ["ā"]=true, ["ī"]=true, ["ō"]=true, ["ū"]=true, ["ȳ"]=true}
	for left,_ in pairs(vowelstbl) do
		for right,_ in pairs(vowelstbl) do
			table.insert(macra.orthorigtbl, left.."u"..right)
			table.insert(macra.orthrepltbl, left.."v"..right)
		end
	end
	-- ignore.txt
	local ignoretblarray = macra.split(macra.cleanup(macra.decomment(macra.readutf8(macra.DIR_DATA.."ignore.txt")), false, false), "\n")
	for k,v in pairs(ignoretblarray) do macra.ignoretbl[v] = true end
	-- enclitics.txt
	local encrawtbl = macra.setsplit(macra.cleanup(macra.decomment(macra.readutf8(macra.DIR_DATA.."enclitics.txt")), false, false), "\n")
	for enc,_ in pairs(encrawtbl) do
		if enc:sub(1,1) == "*" then
			macra.enclitictbl[enc:sub(2)] = false
		else macra.enclitictbl[enc] = true end
	end
	-- prefixes.txt
	local pftblraw = macra.split(macra.cleanup(macra.decomment(macra.readutf8(macra.DIR_DATA.."prefixes.txt")), false, false), "\n")
	for _,pfstr in pairs(pftblraw) do
		local pfplain, pfmac = pfstr:match("([^=]+)=(.+)")
		table.insert(macra.prefixtbl, pfplain)
		if pfmac ~= pfplain then macra.prefixmactbl[pfplain] = pfmac end
	end
	-- _CONFIG.txt
	local configstr = macra.decomment(macra.readutf8(macra.DIR_DATA.."_CONFIG.txt")):gsub(" ", ""):gsub("\t", "")
	macra.OVERWRITE_MACS = macra.readconfigoption(configstr, "Overwrite macrons?")
	macra.REPAIR_ORTH = macra.readconfigoption(configstr, "Repair orthography in source texts?")
	macra.LONG_PERF_SUBJ = macra.readconfigoption(configstr, "Length of \"i\" in perfect subjunctive endings?", {["long"]=true, ["short"]=false})
	return macra.logf, backupkeystr
end


-- opens a log file with the give name in the filename, and returns it
function macra.openlog(name)
	lfs.mkdir("logs")
	macra.logf = io.open(macra.DIR_LOGS..name.." "..macra.filesafe(os.date())..".txt", "w")
	macra.logf:write(macra.bom())
	macra.logf:write(os.date().."\n\n")
	return macra.logf
end


-- reads the Unicode-ASCII conversion file and stores it in macra.macroninvtbl, macra.tildetbl, and macron.capsinvtbl
function macra.loadunicode(path)
	local unicodestr = macra.cleanup(macra.readutf8(path), false, true)
	unicodestr = macra.cleanup(macra.decomment(unicodestr), false, false)
	local capsection = false
	for line in glue.gsplit(unicodestr, "\n") do
		line = glue.trim(line)
		if utf8.sub(line, 1, string.len(macra.DIVIDER)) == macra.DIVIDER then capsection = true
		elseif capsection and line ~= "" then	-- uppercase section
			local uppermac, lowermac = utf8.sub(line, 1, 1), utf8.sub(line, 3, 3)
			macra.capsinvtbl[uppermac] = lowermac
			local macascii, tildeascii = macra.macroninvtbl[lowermac], macra.tildeinvtbl[lowermac]	-- one is nil
			if macascii then macra.macroninvtbl[uppermac] = string.upper(macascii)
			elseif tildeascii then macra.tildeinvtbl[uppermac] = string.upper(tildeascii) end
		elseif line ~= "" then		-- lowercase section (first)
			local ascii = utf8.sub(line, 3, 3)
			macra.macroninvtbl[utf8.sub(line, 1, 1)] = ascii
			macra.tildeinvtbl[utf8.sub(line, 2, 2)] = ascii
		end
	end
	macra.capsinvtbl = glue.merge(macra.capsinvtbl, macra.asciicapsinvtbl())
	macra.macrontbl, macra.tildetbl, macra.capstbl = glue.index(macra.macroninvtbl), glue.index(macra.tildeinvtbl), glue.index(macra.capsinvtbl)
	macra.unicodeinvtbl = glue.merge(macra.macroninvtbl, macra.tildeinvtbl)
end


-- reads the word key at the given path and saves it in macra.keytbl, macra.freqtbl, and macra.headerstbl
function macra.loadkey(path, backupaction, delaybackup)
	local keystrall = macra.decomment(macra.readutf8(path))
	if backupaction and not delaybackup then macra.backup(keystrall, "key", backupaction) end	-- true for Exmacronize
	local sourcesstr = keystrall:match("(.+)"..macra.DIVIDER)
	local keystr = sourcesstr and keystrall:match(macra.DIVIDER.."(.+)") or keystrall
	local headersbynumtbl, numstbl, headernum = {}, {}, 1	-- e.g. numstbl["A"] == 1
	if keystr and keystr ~= "" then
		-- READ SOURCES
		if sourcesstr then
			for sourceline in glue.gsplit(macra.cleanup(sourcesstr), "\n") do
				local letter, header = sourceline:match("([^=]+) = (.+)")
				headersbynumtbl[headernum] = header
				numstbl[letter] = headernum
				headernum = headernum + 1
			end
		end
		-- READ WORDS
		for keyline in glue.gsplit(macra.cleanup(keystr, true, false), "\n") do
			local macronw, freq, thisheaderstbl = keyline:match("[^\t]+"), 0, {}
			local tab1 = keyline:find("\t")
			if tab1 then	-- if a tab is present, i.e. if it is not a manual entry
				freqstr, headersstr = keyline:match("\t([^\t]+)\t(.+)")
				freq = tonumber(freqstr)
				thisheaderstbl = {}
				for letter in glue.gsplit(headersstr, ",") do
					thisheaderstbl[headersbynumtbl[numstbl[letter]]] = true
				end
			end
			local plainw = utf8.replace(macronw, macra.macroninvtbl)
			local plainwkey = macra.getnextkey(plainw)	-- next available key
			macra.keytbl[plainwkey] = macronw
			macra.freqtbl[macronw] = freq
			macra.headerstbl[macronw] = thisheaderstbl
		end
	end
	macra.headersbynumtbl = headersbynumtbl
	return keystrall	-- for delayed backup in Exmacronize
end


-- splits the given substitution list (as a string, previously read from a file) and return it as tables: original word, replacement word, modifiers ([]<>*~), and notes
-- used to load "substitute.txt" and "hidden.txt"
function macra.setupsubs(liststr)
	liststr = macra.cleanup(macra.decomment(liststr), false, true)
	local origtbl, repltbl, modtbl, notetbl = {}, {}, {}, {}
	local i, constanttbl, sublinetbl = 1, {}, nil
	for line in glue.gsplit(liststr, "\n") do
		line = glue.trim(line)
		if #line > 0 then
			local note = line:match("%(([^%)]+)")
			line = line:gsub(" ", "")
			local constant, values = line:match("(%p)=(.+)")
			if constant and line:sub(2,2) == "=" then
				if constant == LEFT_BEGIN or constant == LEFT_CONTINUE or constant == RIGHT_BEGIN or constant == RIGHT_CONTINUE or constant == NO_CHAIN or constant == macra.DOUBT_CHAR then macra.throwerror("\""..constant.."\". A constant in a substitution list must be a non-alphanumeric ASCII character that is not a modifier.", "ERROR--INVALID SUBSTITUTION CONSTANT")
				else
					local valuestbl = macra.split(values, ",")
					constanttbl[constant] = valuestbl
				end
			else
				for constant,value in pairs(constanttbl) do
					if line:find(constant) then
						if type(value) == "table" then
							for _,singleval in pairs(value) do
								local subline = line:gsub("%"..constant, singleval)
								table.insert(sublinetbl, subline)
							end
						elseif type(value) == "string" then
							line = line:gsub("%"..constant, value)
						end
					end
				end
				sublinetbl = {line}
				for _,subline in pairs(sublinetbl) do
					local note = subline:match("%(([^%)]+)")
					subline = subline.."("	-- in case the entry has no note, see next line
					local origfull, repl = subline:match("([^=]+)=([^%(]+)")	-- end at first "("
					if not origfull or not repl then
						macra.throwerror("\""..line.."\". Line could not be interpreted.", "UNREADABLE SUBSTITUTION LINE")
					else
						if repl:find("[%[%]<>~%*]") then
							macra.throwerror("\""..line.."\". Modifiers must be placed on the left side only.", "UNREADABLE SUBSTITUTION LINE")
							repl = repl:gsub("[%[%]<>~%*]", "")
						end
						origfull = origfull.."|"	-- filler character
						local orig, mod = origfull:match("([^%[%]<>%(%)~%*|]+)(.+)")
						mod = mod:sub(1, #mod-1)	-- remove filler
						origtbl[i] = utf8.replace(orig, macra.capsinvtbl)
						repltbl[i] = utf8.replace(repl, macra.capsinvtbl)
						notetbl[i] = note
						modtbl[i] = #mod > 0 and mod or nil
					end
					i = i + 1
				end
			end
		end
	end
	return origtbl, repltbl, modtbl, notetbl
end


-- returns nil if the option of the given name is not found, or if its response is not in responsetbl ("Y","N" by default)
-- to accept any string value as a response, call with responsetbl == false (not passing a value means Y/N option)
function macra.readconfigoption(configstr, optionname, responsetbl)
	if responsetbl == nil then responsetbl = {["y"]=true, ["n"]=false} end
	local response = configstr:match(optionname:gsub(" ", ""):gsub("?", "%%?").."(%a+)")
	if not response then
		macra.throwerror("Option \""..optionname.."\" not found in \"_CONFIG.txt\".")
		return nil
	end
	if responsetbl == false then return response
	else
		local allrespstr = ""
		for respstr,respval in pairs(responsetbl) do
			if response == respstr or response == macra.utf8upper(respstr) then
				return respval
			end
			allrespstr = allrespstr..", \""..respstr.."\""
		end
		allrespstr = allrespstr:sub(3)	-- remove leading ", "
		macra.throwerror("Invalid response \""..response.."\" to the \"_CONFIG.txt\" option \""..optionname.."\". Response must be one of the following: "..allrespstr..".")
	end
	return nil
end


--===========  M A J O R   F U N C T I O N S  =============================


-- takes any characters to be ignored (in data/ignore.txt) off of the start and end of the given word, and logs any found in the middle
-- utf8 functions not used because the non-utf8-aware find function is used here (on which wstart and wend are based)
function macra.ignorechars(w, wstart, wend, abbrevcheck)
	if abbrevcheck == nil then abbrevcheck = true end
	-- first deal with periods, which do not automatically separate and separate from words as other chars in macra.LETTERS
	-- remove leading periods
	local first = w:sub(1,1)
	while first == "."  do
		w = w:sub(2)
		wstart = wstart + 1
		if wstart > wend then wend = wstart end
		first = w:sub(1,1)
	end
	-- if a period is in the middle of the word, split it and take the first period-bounded string as the word
	local dotpos = w:find("%.")
	if dotpos and dotpos ~= 1 and dotpos ~= #w then
		w = w:sub(1, dotpos)
		wend = wstart + dotpos - 1
	end
	-- remove the period at the end if the character before it is invalid, since this cannot be an abbreviation, as in "“Ī”."
	if w:sub(#w) == "." then
		local utf8len = utf8.len(w)
		if macra.ignoretbl[utf8.sub(w, utf8len-1, utf8len-1)] then
			w = w:sub(1, #w-1)
			wend = wend - 1
		end
	end
	-- then exclude ignore strings from start and end of word, shifting the in-text start and end points, and cutting w accordingly. nothing in the middle is deleted.
	local posright, userabbrev, middlefound, isabbrev = utf8.len(w), false, false, false, false
	if not wstart then wstart = 1 end
	if not wend then wend = utf8.len(w) end
	if w ~= "" then	-- if empty as a result of removing periods, e.g. from "..."
		repeat
			local goodstart, goodend = true, true	-- will change to false if match found
			local leftchar, rightchar = utf8.sub(w, 1, 1), utf8.sub(w, posright, posright)
			if macra.ignoretbl[rightchar] then
				w = utf8.sub(w, 1, posright - 1)
				wend = wend - #rightchar
				posright = posright - 1
				goodend = false
			end
			if not goodend then posright = posright - 1 end
			if posright < 1 then	-- no valid characters found in w, so abort and return w as nil
				w = nil
				if wend < wstart then wend = wend + #rightchar end	-- wend will be < wstart if w is all invalid
			else
				if macra.ignoretbl[leftchar] then
					w = utf8.sub(w, 2)
					local leftcharlen = #leftchar
					wstart = wstart + leftcharlen
					posright = posright - 1
					goodstart = false
					if leftchar == macra.USER_ABBREV then userabbrev = true end
				end
			end
		until (goodstart and goodend) or not w
		if w then
			-- next, find ignore strings in the middle of word, logging each removal ONLY IF this word is not user-ignored
			for ig,_ in pairs(macra.ignoretbl) do
				if not middlefound then
					if w:find(ig) then middlefound = true end
				end
			end
			-- finally, determine whether the word is possibly an abbreviation (either indicated by the user with a special character, or capitalized and followed by a period)
			if abbrevcheck then
				local wlen = #w
				if userabbrev then
					if w:sub(wlen) ~= "." then w = w.."." end
					isabbrev = true
				elseif w:sub(wlen) == "." then
					local firstchar, autoabbrev = utf8.sub(w, 1,1), false
					if macra.capsinvtbl[firstchar] and not middlefound then
						autoabbrev = true -- excludes e.g. "“Ī”inquit."
						isabbrev = true
					else
						w = w:sub(1, wlen - 1)
						wend = wend - 1
					end
				end
			end
		end
	end
	--if wend < wstart then wend = wstart + 1 end
	return w, wstart, wend, middlefound, isabbrev
end


-- tries to apply substitutions to the given word, with the given tables of substitution entries (originals, replacements, modifiers), and returns the word and a table containing each substitutions original and position
-- includedoubtful, ascii, prevsubw, and prevdsubatpostbl are provided by Macronize
function macra.subword(w, origtbl, repltbl, modtbl, includedoubtful, ascii, prevdsubw, prevdsubatpostbl)
	if includedoubtful == nil then includedoubtful = true end
	local i, subw, subatpostbl, subbed = 1, w, {}, false	-- substitutions at positions (index is start position in word)
	while subw and i <= #repltbl do
		local orig = (ascii and utf8.replace(origtbl[i], macra.unicodeinvtbl) or origtbl[i])	-- Macronize deals with ASCII text only, so convert (same for repl below)
		local findstart = 1
		repeat
			local replstart, replend = subw:find(orig, findstart)
			local nexti = false		-- when no more of the original string is found in this word, nexti becomes true
			if replstart and macra.issubvalid(subw, modtbl[i], replstart, replend, subbed) then
				if includedoubtful or not (modtbl[i] or ""):find(macra.DOUBT_CHAR) then
					local repl = (ascii and utf8.replace(repltbl[i], macra.unicodeinvtbl) or repltbl[i])
					local newsubw, prevdsubi = subw:sub(1, replstart-1)..repl..subw:sub(replend+1), nil
					if prevdsubatpostbl then
						prevdsubi = prevdsubatpostbl[replstart]
						if not prevdsubi then	-- find any doubtful sub in the previous doubtful word
							local j, dlen = 1, utf8.len(prevdsubw)
							while not prevdsubi and j <= dlen do
								local trysubi = prevdsubatpostbl[j]
								if (modtbl[trysubi] or ""):find(macra.DOUBT_CHAR) then prevdsubi = trysubi end
								j = j + 1
							end
						end
					end
					if not prevdsubw or ((prevdsubw or "") ~= newsubw and (prevdsubi or i+1) < i) then
						subatpostbl[replstart] = i
						subw = newsubw
						subbed = true
					end
				end
				findstart = replend + 1
			else nexti = true end
		until nexti
		i = i + 1
	end
	if subw == w then subatpostbl = {} end -- in case of chain replacement (exsecutus -> exssecutus -> exsecutus)
	return subw, subatpostbl
end


-- determines whether a substitution (e.g. from substitute.txt or hidden.txt) with the given modifier string is valid for a word with a possible substitution at the given start and end index and with the given length
-- possible enclitics, if detected, are ignored for the purposes of strings substituted only at the ends of words
function macra.issubvalid(w, modstr, replstart, replend, subbed)
	local matches, encliticmatch = nil, nil	-- 0 = not known so far, -1 = does not match, 1 = matches
	if not modstr or (modstr or "") == macra.DOUBT_CHAR then return true	-- if doubt is the only modifier
	else
		if modstr:find("%"..NO_CHAIN) then
			matches = not subbed end
		if modstr:find("%"..LEFT_BEGIN) and matches ~= false then
			matches = replstart == 1 and true or false
		elseif modstr:find(LEFT_CONTINUE) then
			matches = replstart > 1 and true or false
		end
		if modstr:find("%"..RIGHT_END) and matches ~= false then
				if replend == #w then matches = true
				else	--can detect one possible enclitic
					for enc,_ in pairs(macra.enclitictbl) do
						if not encliticmatch then
							if w:sub(#w-#enc+1) == enclitic then encliticmatch = enc end
						end
					end
					matches = (encliticmatch and (replend + #encliticmatch == #w)) and true or false
				end
		elseif modstr:find(RIGHT_CONTINUE) and matches ~= false then
			matches = replend < #w and true or false
		end
	end
	return matches, (encliticmatch ~= nil and true or false)
end


--[[ returns:
	- a table of parallel macron-forms and their plain-form keys, e.g. partbl["hōc"] = "hoc1" (keytbl["hoc1"] = "hōc")
	- the total number of these parallels
	- the next available plain-form key
also takes into account non-abbreviated forms of possible abbreviations, e.g. "ī" for "i." --]]
function macra.getpars(plainw, tryabbrevloop)
	local parw0 = macra.keytbl[plainw]
	if not parw0 then return nil end
	local parwtbl, parnum, curparnum, plainwkey, parw, abbrevloop = {}, 0, 0, plainw, parw0, false
	repeat
		repeat
			if abbrevloop then parw = parw.."." end
			parwtbl[parw] = plainwkey
			curparnum = curparnum + 1
			plainwkey = plainw..curparnum
			parw = macra.keytbl[plainwkey]
		until not parw
		parnum = parnum + curparnum
		-- note: spoils plainwkey for returning, so don't use tryabbrevloop if plainwkey is needed, or revise
		if tryabbrevloop and plainw:sub(#plainw-1) == "." and not abbrevloop then
			plainwkey = plainw:sub(1, #plainw-1)
			parw = macra.keytbl[plainwkey]
			if parw then
				abbrevloop, curparnum = true, 0
			end
		elseif abbrevloop then abbrevloop = false end
	until not abbrevloop
	return parwtbl, (parnum > 0 and parnum or nil), plainwkey
end


-- returns the first available key, e.g. if macra.keytbl["hoc"] == "hōc", then "hoc1"
function macra.getnextkey(plainw)
	local plainwkey, curpar = plainw, 0
	while macra.keytbl[plainwkey] do
		curpar = curpar + 1
		plainwkey = plainw..curpar
	end
	return plainwkey
end


-- delete the given form in the key and shift keys of parallels stored above it (if any) down one number
function macra.keyremove(w, plainw, partbl, parcount)
	if not plainw or not partbl or not parcount then
		plainw = utf8.replace(w, macra.macroninvtbl)
		partbl, parcount = macra.getpars(plainw)
	end
	local plainwkey = nil
	for parw,k in pairs(partbl) do
		if parw == w then plainwkey = k end
	end
	if plainwkey then	-- if w found in key
		local parnum = plainwkey:match("%d+") or 0
		for n = parnum,parcount-1 do
			macra.keytbl[plainw..(n == 0 and "" or n)] = macra.keytbl[plainw..(n+1)]
		end
		macra.keytbl[plainw..(parcount == 1 and "" or parcount-1)] = nil
	end
end


-- saves the key in "data/key.txt" and returns the total number of forms in the key
function macra.savekey()
	local formstotal, keyf = 0, io.open(macra.DIR_DATA.."key.txt", "w")
	keyf:write(macra.bom())
	keyf:write("// WORD KEY\n\n// To manually add words, simply add them to the end of this file, one word per line.\n// To manually correct a word, change it in this file ONLY if it is a manually added word. If it is taken from a source text (i.e. if it has a header and frequency), enter it into \"_repairs.txt\" in the \"Custom\" section (according to that section's instructions) after running Analyze Key, then run Repair Key. This will correct the word in the key as well as in the source text(s) in which it occurs.\n\n")
	-- SAVE SOURCES
	keyf:write("// SOURCES\n// [ID] = [source header]\n// Do not change this section!\n\n")
	for num,header in glue.sortedpairs(macra.headersbynumtbl) do
		keyf:write(macra.letterkey(num).." = "..header.."\n")
	end
	keyf:write("\n"..macra.DIVIDER.."\n\n")
	-- SAVE WORDS
	keyf:write("// WORDS\n// [word]\t[frequency]\t[IDs of sources in which it occurs]\n\n")
	for _,macronw in glue.sortedpairs(macra.keytbl) do
		local line = macronw
		if macra.freqtbl[macronw] and macra.freqtbl[macronw] > 0 then
			line = line.."\t"..macra.freqtbl[macronw].."\t"
			local headersbylettertbl, numsbyheadertbl = {}, glue.index(macra.headersbynumtbl)
			for header,_ in pairs(macra.headerstbl[macronw]) do
				headersbylettertbl[macra.letterkey(numsbyheadertbl[header])] = header
			end
			local lettersstr = ""
			for letter,_ in glue.sortedpairs(headersbylettertbl) do lettersstr = lettersstr..","..letter end
			lettersstr = lettersstr:sub(2)	-- exclude the leading comma
			line = line..lettersstr
		end
		keyf:write(line.."\n")
		formstotal = formstotal + 1
	end
	keyf:close()
	return formstotal
end


-- converts a number to a letter key, e.g. 1 = A, 27 = a, 53 = A2, 54 = B2, etc. (for sources in key.txt)
function macra.letterkey(num)
	local quotient, factorial = math.floor(num / 26), num % 26
	if factorial == 0 then
		quotient = quotient - 1
		factorial = 26
	end
	local key = ""
	if quotient % 2 == 0 then key = string.char(64 + factorial) end	-- odd quotient: uppercase
	if quotient % 2 == 1 then key = string.char(96 + factorial) end -- even quotient: lowercase
	if quotient >= 2 then key = key..(math.floor(quotient / 2)) end -- beyond second set (num=52), append numbers
	return key
end


--===========  S T R I N G    F U N C T I O N S  ==========================


-- 3 formatting functions (implemented also in web version)

-- utf8.replace is not used as in macra.remmacs because utf8.replace works only with single characters
function macra.hyphens2macs(text)
	text = text:gsub("a%-","ā"):gsub("e%-","ē"):gsub("i%-","ī"):gsub("o%-","ō"):gsub("u%-","ū"):gsub("y%-","ȳ"):gsub("ã%-","ā"):gsub("ẽ%-","ē"):gsub("ĩ%-","ī"):gsub("õ%-","ō"):gsub("ũ%-","ū"):gsub("ỹ%-","ȳ"):gsub("A%-","Ā"):gsub("E%-","Ē"):gsub("I%-","Ī"):gsub("O%-","Ō"):gsub("U%-","Ū"):gsub("Y%-","Ȳ"):gsub("Ã%-","Ā"):gsub("Ẽ%-","Ē"):gsub("Ĩ%-","Ī"):gsub("Õ%-","Ō"):gsub("Ũ%-","Ū"):gsub("Ỹ%-","Ȳ"):gsub("\\%-", "-")	-- (escaped hyphen)
	return text
end

function macra.remflags(text)
	local flagstbl = {[macra.FLAG_NOTFOUND]="", [macra.FLAG_AMBIG]="", [macra.FLAG_GUESS]="", [macra.FLAG_AFFIX]="", [macra.FLAG_INVALID]=""}
	return utf8.replace(text, flagstbl)
end

function macra.remmacs(text)
	--local asciitbl = { ["Ã"]="A", ["ã"]="a", ["Õ"]="O", ["õ"]="o", ["Ā"]="A", ["ā"]="a", ["Ē"]="E", ["ē"]="e", ["Ĩ"]="I", ["ĩ"]="i", ["Ī"]="I", ["ī"]="i", ["Ō"]="O", ["ō"]="o", ["Ũ"]="U", ["ũ"]="u", ["Ū"]="U", ["ū"]="u", ["Ȳ"]="Y", ["ȳ"]="y", ["Ẽ"]="E", ["ẽ"]="e", ["Ỹ"]="Y", ["ỹ"]="y" }
	return utf8.replace(macra.remflags(text), macra.unicodeinvtbl)
end


-- returns an array of the given string split by the given other string (rather than glues iterator)
function macra.split(a, b)
	local tbl = {}
	for s in glue.gsplit(a, b) do
		table.insert(tbl, s)
	end
	return tbl
end


-- same as macra.split, but creates a set instead of an array
function macra.setsplit(a, b)
	local tbl = {}
	for s in glue.gsplit(a, b) do
		tbl[s] = true
	end
	return tbl
end


-- returns a string containing all the values of the given table
function macra.tbltostr(tbl)
	local str = ""
	for _,v in pairs(tbl) do str = str..v end
	return str
end


-- returns a cleaned up string: remove extra newlines from beginning, end, and middle, remove ALL tabs, remove extra spaces
function macra.cleanup(str, keeptabs, keepspaces)
	if keeptabs == nil then keeptabs = true end
	if keepspaces == nil then keepspaces = true end
	if not str then return nil end
	-- remove all tabs if requested: otherwise, just turn multiple tabs in a row into one & remove tabs before/after newlines
	if not keeptabs then str = str:gsub("\t", " ")
	else
		str = str:gsub("\n\t", "\n"):gsub("\t\n", "\n")
		str = macra.cutmultiple(str, "\t")
	end
	if not keepspaces then str = str:gsub(" ", "")	-- remove all spaces if requested, otherwise just clusters
	else str = macra.cutmultiple(str, " ") end
	-- remove all blank lines
	str = macra.cutmultiple(str, "\n")
	-- remove leading and ending blank lines
	while str:sub(1,1) == "\n" do str = str:sub(2) end
	while str:sub(#str) == "\n" do str = str:sub(1, #str-1) end
	if str == "\n\n" then print("yo!!") str = nil end
	return str
end


-- replaces any number of continuous repetitions of the character singlechar, e.g. removing extra spaces: "     " -> " "
function macra.cutmultiple(str, singlechar)
	local subscount, pair = 0, singlechar..singlechar
	repeat
		str, subscount = str:gsub(pair, singlechar)
	until subscount == 0
	return str
end


-- returns a table with true values at each position that is inside a comment
function macra.getcommentset(text)
	local commentstbl = {}
	-- find single-line comments
	local cstart, cend = text:find(macra.COMMENT)
	while cstart do
		for p = cstart,cend do commentstbl[p] = true end
		cstart, cend = text:find(macra.COMMENT, cend+1)
	end
	-- find multi-line comments
	cstart, cend = text:find(macra.COMMENT_MULTI)
	while cstart do
		for p = cstart,cend do commentstbl[p] = true end
		cstart, cend = text:find(macra.COMMENT_MULTI, cend+1)
	end
	return commentstbl
end


-- removes single- and multi-line comments from the given string
function macra.decomment(text)
	if not text then return nil
	else return text:gsub("/%*.+%*/", ""):gsub("//[^\n]*", "") end
end


-- returns an ASCII version of a string with macrons, for display in a console window
function macra.macs2ascii(str)
	--local a, e, i, o, u, y, A, E, I, O, U, Y = string.char(131), string.char(136), string.char(140), string.char(147), string.char(150), string.char(152), string.char(142), string.char(144), string.char(173), string.char(153), string.char(154), string.char(157)
	local a, e, i, o, u, y, A, E, I, O, U, Y = "a-", "e-", "i-", "o-", "u-", "y-", "A-", "E-", "I-", "O-", "U-", "Y-"
	--local map = { ["ā"]=a, ["ē"]=e, ["ī"]=i, ["ō"]=o, ["ū"]=u, ["ȳ"]=y, ["Ā"]=A, ["Ē"]=E, ["Ī"]=I, ["Ō"]=O, ["Ū"]=U, ["Ȳ"]=Y}--, ["ã"]=a.."~", ["ẽ"]=e.."~", ["ĩ"]=i.."~", ["õ"]=o.."~", ["ũ"]=u.."~", ["ỹ"]=y.."~", ["Ã"]=A.."~", ["Ẽ"]=E.."~", ["Ĩ"]=I.."~", ["Õ"]=O.."~", ["Ũ"]=U.."~", ["Ỹ"]=Y.."~" }
	local asciistr = str:gsub("ā",a):gsub("ē",e):gsub("ī",i):gsub("ō",o):gsub("ū",u):gsub("ȳ",y):gsub("Ā",A):gsub("Ē",E):gsub("Ī",I):gsub("Ō",O):gsub("Ū",U):gsub("Ȳ",Y):gsub("ã",a.."~"):gsub("ẽ",e.."~"):gsub("ĩ",i.."~"):gsub("õ",o.."~"):gsub("ũ",u.."~"):gsub("ỹ",y.."~"):gsub("Ã",A.."~"):gsub("Ẽ",E.."~"):gsub("Ĩ",I.."~"):gsub("Õ",O.."~"):gsub("Ũ",U.."~"):gsub("Ỹ",Y.."~")
	return asciistr
	--return utf8.replace(str, map)
end


-- capitalizes only the first character of the given string
-- handles an error thrown by utf8.sub when substring contains an extended-ASCII character
function macra.utf8capitalize(str)
	local first = ""
	if pcall(utf8.sub(str, 1, 1)) then first = utf8.sub(str, 1, 1)
	else first = str:sub(1, 1) end
	return (#first == 1 and first:upper() or (macra.capstbl[first] or first))..str:sub(#first+1)	
end


-- uppercases all characters of the given string, like string.upper()
-- throws an error if str contains extended-ASCII character (problematic for utf8.len, utf8.sub)
-- this error can't be caught: (1) pcall(utf8.len(...)) always returns false, (2) can't check each byte character of str (i.e. for p=1,#str ...) because Unicode characters might appear as several extended-ASCII characters
function macra.utf8upper(str)
	local capstr = ""
	local strlen = utf8.len(str)
	for pos = 1,strlen do
		poschar = utf8.sub(str, pos, pos)
		capstr = capstr..(#poschar == 1 and poschar:upper() or (macra.capstbl[poschar] or poschar))
	end
	return capstr
end


-- used by macra.loadunicode
function macra.asciicapsinvtbl()
	local t = {}
	local uc, lc = 65, 97
	for i = 1,26 do
		t[string.char(uc)] = string.char(lc)
		uc = uc + 1
		lc = lc + 1
	end
	return t
end


--===========  I / O  =====================================================


-- returns a filename-safe version of the given string
function macra.filesafe(str)
	return str:gsub("/","-"):gsub(":","_")
end


-- makes a copy of a text, storing it in the backup folder
function macra.backup(text, name, actionname)
	name = (name:match(macra.SEP.."([^"..macra.SEP.."]+).txt") or name)	-- remove .txt extension if present
	lfs.mkdir("backup")
	local copyf = io.open(macra.DIR_BACKUP..macra.filesafe(os.date()).." "..macra.filesafe(name).." - before "..actionname..".txt", "w")
	copyf:write(macra.bom())
	copyf:write(text)
	copyf:close()
end


-- recursively finds all .txt files in the given directory and its subdirectories, and returns a table of them (only those not in oldtbl, if oldtbl is provided)
-- lfs not used becuase lfs.attributes seems to be broken in luapower, always returning nil
function macra.gettexts(dir, oldtbl, subpath)
	if not subpath then subpath = "" end
	local textstbl, filenamestbl, count, popen = {}, {}, 0, io.popen
	local filecmd = macra.IS_UNIX and "ls -1" or "dir /b /a-h"
	local dircmd = macra.IS_UNIX and "ls -d */" or "dir /b /ad-h"
	for filename in popen(filecmd.." \""..dir.."\""):lines() do
		-- make a list of directories
		local dirstbl = {}
		for dirname in popen(dircmd.." \""..dir.."\""):lines() do	dirstbl[dirname] = true	end
		-- if the file is not a directory and ends in ".txt", load it into textstbl
		if not dirstbl[filename] and filename:sub(#filename - 3) == ".txt" then
			local textf = macra.utf8readhandle(dir..filename)
			-- find the header as the first line that is not empty or just a comment mark
			local firstlinestr = textf:read()
			local header = firstlinestr and glue.trim(firstlinestr) or ""
			if firstlinestr then
				while header == "" or header == "//" or header == "//*" do header = glue.trim(textf:read()) end
				if header:sub(1, 2) == "//" then
					header = glue.trim(header.sub(3,3) == "*" and header:sub(4) or header:sub(3))
				end
				if #header > macra.MAX_HEADER then header = utf8.sub(header, 1, macra.MAX_HEADER).."..." end
			end
			if (oldtbl and not oldtbl[header]) or not oldtbl then
				textf = macra.utf8readhandle(dir..filename)	-- reset read position to read entire text
				textstbl[header] = textf:read("*all") or ""
				filenamestbl[header] = subpath..filename
				count = count + 1
			end
			textf:close()
		elseif dirstbl[filename] then	-- if it is a directory, run this function on it
			if not macra.IS_UNIX then filename = filename..macra.SEP end
			subttbl, subftbl, subcount = macra.gettexts(dir..filename, oldtbl or nil, subpath..filename)
			textstbl = glue.merge(textstbl, subttbl)
			filenamestbl = glue.merge(filenamestbl, subftbl)
			count = count + subcount
		end
	end
	return textstbl, filenamestbl, count
end


-- loads repair-x.txt files into tables and return them
function macra.loadrepairhistory()
	local repairtbls = { {}, {}, {}, {} }
	for i=1,macra.OK do
		local path = macra.DIR_DATA.."repair-"..macra.repairnametbl[i]..".txt"
		local rawstr = macra.cleanup(macra.decomment(macra.readutf8(path)), true, false)
		if not rawstr then
			rawstr = ""
			macra.throwerror("File \""..path.."\" not found! Blank file created.")
		elseif i ~= macra.AUTO and rawstr ~= "" then	-- auto-replacements are more complex, so loaded below
			for w in glue.gsplit(rawstr, "\n") do	-- one word per line
				repairtbls[i][w] = true
			end
		elseif i == macra.AUTO and rawstr ~= "" then
			for autoline in glue.gsplit(rawstr, "\n") do
				if autoline ~= "" then
					local origw, replw = autoline:match("([^\t]+)\t(.+)")
					repairtbls[macra.AUTO][origw] = replw
					repairtbls[macra.OK][replw] = true	-- add replacement to the OK table in case deleted from ok.txt
				end
			end	
		end
	end
	return repairtbls[macra.ABV], repairtbls[macra.ENC], repairtbls[macra.AUTO], repairtbls[macra.OK]
end


-- saves given tables to repair-x.txt files
function macra.saverepairhistory(abvtbl, enctbl, autotbl, oktbl)
	local repairtbls = {abvtbl, enctbl, autotbl, oktbl}
	for i=1,macra.OK do
		local repairf = io.open(macra.DIR_DATA.."repair-"..macra.repairnametbl[i]..".txt", "w")
		repairf:write(macra.bom())
		if i == macra.AUTO then
			for origw,replw in pairs(autotbl) do
				if oktbl[origw] then macra.throwerror("\""..origw.."\" on both OK and auto-replace lists.") end
				repairf:write(origw.."\t"..replw.."\n")
			end
		else
			for w,_ in pairs(repairtbls[i]) do repairf:write(w.."\n") end
		end
		repairf:close()
	end
end


-- returns entire contents of UTF-8 file at specified path, skipping the UTF-8 BOM, if present
function macra.readutf8(path, createnew)
	if createnew == nil then createnew = true end
	local utf8f = io.open(path, "r")
	if not utf8f then
		if createnew then
			utf8f = io.open(path, "w")
			utf8f:write(macra.bom())
			utf8f:close()
		end
		return nil
	end
	local first3 = utf8f:read(3)
	if not first3 then first3 = ""
	elseif first3:sub(1,1):byte() == 239 and first3:sub(2,2):byte() == 187 and first3:sub(3,3):byte() == 191 then
		first3 = ""		-- delete the BOM
	end
	local contents = first3..utf8f:read("*a")
	utf8f:close()
	return contents
end


-- returns the file handle of utf-8 file at specified path, after reading in the BOM
-- NOTE: the file must be manually closed after this function!
function macra.utf8readhandle(path, createnew)
	if createnew == nil then createnew = true end
	local utf8f = io.open(path, "r")
	if not utf8f then
		if createnew then
			utf8f = io.open(path, "w")
			utf8f:write(macra.bom())
			utf8f:close()
		end
		return nil
	end
	local first3 = utf8f:read(3)
	if not first3 or (first3:sub(1,1):byte() == 239 and first3:sub(2,2):byte() == 187 and first3:sub(3,3):byte() == 191) then
		return utf8f
	else return io.open(path, "r") end	-- restart from beginning of file
end


function macra.bom()
	return string.char(239)..string.char(187)..string.char(191)
end


function macra.throwerror(errormsg, prestr)
	if not prestr then prestr = "ERROR" end
	local fullmsg = "\n"..prestr..": "..macra.macs2ascii(errormsg)
	print(fullmsg)
	if macra.logf then macra.logf:write(fullmsg.."\n") end
end


-- saves macra tables to a file for import into web version
-- the complication of splitting the key into two is the result of insufficient memory available for exporting it all at once
function macra.exportdata()
	local key = macra.exporttable(macra.keytbl, "keytbl", "labant", false)
	local f1 = io.open(macra.DIR_ROOT.."export"..macra.SEP.."key1.txt", "w")
	f1:write(macra.bom()..key)
	f1:close()
	key = nil
	key = macra.exporttable(macra.keytbl, "keytbl", "labant", true)
	local f2 = io.open(macra.DIR_ROOT.."export"..macra.SEP.."key2.txt", "w")
	f2:write(macra.bom()..key)
	f2:close()
	local freq = macra.exporttable(macra.freqtbl, "freqtbl")
	local f3 = io.open(macra.DIR_ROOT.."export"..macra.SEP.."freq.txt", "w")
	f3:write(macra.bom()..freq)
	f3:close()
	-- str = str..macra.exporttable(macra.macroninvtbl, "macroninvtbl")
	-- str = str..macra.exporttable(macra.macrontbl, "macrontbl")
	-- str = str..macra.exporttable(macra.tildetbl, "tildetbl")
	-- str = str..macra.exporttable(macra.capsinvtbl, "capsinvtbl")
	-- str = str..macra.exporttable(macra.capstbl, "capstbl")
	-- str = str..macra.exporttable(macra.ignoretbl, "ignoretbl")
	-- str = str..macra.exporttable(macra.enclitictbl, "enclitictbl")
	-- str = str..macra.exporttable(macra.prefixtbl, "prefixtbl")
	-- str = str..macra.exporttable(macra.prefixmactbl, "prefixmactbl")
	-- str = str..macra.exporttable(macra.orthorigtbl, "orthorigtbl")
	-- str = str..macra.exporttable(macra.orthrepltbl, "orthrepltbl")
	-- str = str..macra.exporttable(macra.orthmodtbl, "orthmodtbl")
end


function macra.exporttable(tbl, name, splitword, secondsplit)
	local decl, elements, isarray = "local "..name.." = { ", "", macra.isarray(tbl)
	if isarray then
		for k,v in ipairs(tbl) do
			local quotes, vtype = true, type(v)
			if vtype == "number" or vtype == "boolean" then quotes = false end
			elements = elements..", "..(quotes and "\"" or "")..v..(quotes and "\"" or "")
		end
		elements = elements:sub(3)
	else
		local reachedsplit = false
		for k,v in glue.sortedpairs(tbl) do
			if splitword and v == splitword then reachedsplit = true end
			if (not secondsplit and not reachedsplit) or (secondsplit and reachedsplit) then
				--print(k,v)
				local kquotes, vquotes, ktype, vtype = true, true, type(k), type(v)
				if ktype == "number" or ktype == "boolean" then kquotes = false end
				if vtype == "number" or vtype == "boolean" then vquotes = false end
				-- note: the space after the comma IS NECESSARY for web execution under lua.vm.js
				elements = elements..", ["..(kquotes and "\"" or "")..tostring(k)..(kquotes and "\"]=" or "]=")..(vquotes and "\"" or "")..tostring(v)..(vquotes and "\"" or "")
			end
		end
		elements = elements:sub(3)
	end
	return decl..elements.." }\n"
end


function macra.isarray(tbl)
	local i = 0
	for _ in pairs(tbl) do
		i = i + 1
		if tbl[i] == nil then return false end
	end
	return true
end






------- UNUSED FUNCTIONS -------


-- identical to utf8.replace except that it can handle extended-ASCII characters and not UTF8, and the replacements can involve multiple replacements
function macra.replace(s, mapping)
	for k,v in pairs(mapping) do
		s = s:gsub(k, v)
	end
	return s
end


-- (unused)
function macra.getkey(t, val)
	for k,v in pairs(t) do
	  if v == val then
		return k
	  end
	end
end


-- returns an iterator in order of table keys
-- (unused; redundant with glue.sortedkeys(t))
function macra.pairsbykey(t)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a)
	local i = 0
	local iter = function()
		i = i + 1
		if a[i] == nil then return nil
		else return a[i], t[a[i]] end
	end
	return iter
end


-- (unused, but potentially useful!)
-- returns a string corresponding to the given Unicode code point
-- for alternates, see http://stackoverflow.com/questions/26071104/more-elegant-simpler-way-to-convert-code-point-to-utf-8
function macra.unichar(cp)
  local string_char = string.char
  if cp < 128 then
    return string_char(cp)
  end
  local s = ""
  local prefix_max = 32
  while true do
    local suffix = cp % 64
    s = string_char(128 + suffix)..s
    cp = (cp - suffix) / 64
    if cp < prefix_max then
      return string_char((256 - (2 * prefix_max)) + cp)..s
    end
	prefix_max = prefix_max / 2
  end
end


return macra
