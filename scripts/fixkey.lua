--[[

fixkey.lua
by Felipe Vogel
fps.vogel@gmail.com

Analyze/Repair Key. Key maintenance tool for Maccer. With the "-analyze" parameter, finds
possible errors in the key and saves them to a file, then after the user
has corrected this file, with "-repair", errors in the key and source texts
are corrected by applying string substitutions.

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


package.path = package.path..";../?.lua"	-- because running from a subdirectory
local lfs = require "lfs"
local glue = require "glue"
lfs.chdir("..")		-- to Maccer root folder
local macra = require "scripts.macra"
local utf8 = require "scripts.utf8"		-- from https://github.com/alexander-yakushev/awesompd/blob/master/utf8.lua

local mode, ANALYZE, REPAIR = nil, false, true

-- initialize script-wide data
if arg[1] == "-analyze" then
	mode = ANALYZE
	logf = macra.initialize("key -analyze")
elseif arg[1] == "-repair" then
	mode = REPAIR
	logf = macra.initialize("key -repair", true)
else print("\nInvalid parameter. Use -analyze or -repair.\n") end


-- results table for analyze: will be written to repairs.txt for user inspection and correction.
-- to keep alphabetical order, all subtables are arrays except for _OK, _AUTO, and those noted.
-- e.g. analysis[HID_ORIG][45] = "tectum", _REPL][45] = "tēctum", _NOTES]["tectum"] = "from tegō", _DOUBT]["est"] = true
-- and e.g. analysis[AMB_NEW][5] = "comis", _PARS][5] = {"cōmis", "comīs"}
-- note: these _AUTO and _OK subtables contain only the entries of autotbl and oktbl to which matches are found in the key
local CUSTOM, MULTI = 1, 2		-- forms in which multiple problems are detected
local ABV_OK, ABV_AUTO, ABV_NEW 			= 15, 9, 3			-- possible abbreviations
local ENC_OK, ENC_AUTO, ENC_NEW				= 16, 10, 4			-- possible enclitics
	local ENC_DOUBT = 21								-- not array: keyed to values of ENC_NEW
local PRF_OK, PRF_AUTO, PRF_NEW				= 17, 11, 5			-- possible perfects
local HID_OK, HID_AUTO, HID_ORIG, HID_REPL	= 18, 12, 6, 22		-- hidden long vowels
	local HID_NOTES, HID_DOUBT = 23, 24					-- not arrays: keyed to values of HID_ORIG
local ORTH_OK,ORTH_AUTO,ORTH_ORIG,ORTH_REPL	= 19, 13, 7, 25		-- orthographic changes
	local ORTH_NOTES = 26								-- not array: keyed to values of ORTH_ORIG
local AMB_OK, AMB_AUTO, AMB_NEW, AMB_PARS 	= 20, 14, 8, 27		-- ambiguities i.e. parallel macron-forms
local analysis = {}
for i = 1,27 do analysis[i] = {} end

local wsections = {}	-- what section each word is in (each word can be in only one section)

-- constants for sections visible in the file, used for wsections and the table read from repairs.txt
local ABV, ENC, PRF, HID, ORTH, AMB = ABV_NEW, ENC_NEW, PRF_NEW, HID_ORIG, ORTH_ORIG, AMB_NEW

-- indices for the table of "repairs.txt" section headers are the same as the above set
local HID_NEW, ORTH_NEW = HID_ORIG, ORTH_ORIG	-- differently named to match the other section header constants
local SECTIONS = {nil, nil, "ABBREVIATIONS", "ENCLITICS", "PERFECT SUBJUNCTIVES", "HIDDEN LONG VOWELS", "ORTHOGRAPHY", "AMBIGUITIES"}
for i = 3,8 do
	SECTIONS[12+i] = "// "..macra.SECTION..SECTIONS[i].." (OK)"..macra.LINE
	SECTIONS[6+i] = "// "..macra.SECTION..SECTIONS[i].." (auto replace)"..macra.LINE
	SECTIONS[i] = "// "..macra.SECTION..SECTIONS[i].." (new)"..macra.LINE
end
SECTIONS[CUSTOM] = "// "..macra.SECTION.."CUSTOM REPLACEMENTS"..macra.LINE
SECTIONS[MULTI] = "// "..macra.SECTION.."MULTIPLE ISSUES"..macra.LINE	

-- these tables will be built from "repairs.txt" after user corrections
local repltbl = {}		-- replacements, e.g. replace["tectum"] = "tēctum"
local addtbl = {}			-- forms manually added by the user; addtbl[5] = "Augustīnus"

-- these two tables store the history of previous actions that are now repeated automatically
local abvtbl, enctbl, autotbl, oktbl = macra.loadrepairhistory()  --  replaced (autotbl["tectum"] = "tēctum"), ignored (oktbl["ūsque"] = true)

local textstbl, filenamestbl, hidorigtbl, hidrepltbl, hidmodtbl, hidnotetbl = nil, nil, nil, nil, nil, nil
if mode == REPAIR then
	textstbl, filenamestbl = macra.gettexts(macra.DIR_SOURCES)
	for header,text in pairs(textstbl) do macra.backup(text, filenamestbl[header], "fixkey -repair") end
elseif mode == ANALYZE then
	hidorigtbl, hidrepltbl, hidmodtbl, hidnotetbl = macra.setupsubs(macra.readutf8(macra.DIR_DATA.."hidden.txt"), true)
end

-- used for analyzing/repairing perfect subjunctives
local shorttbl, longtbl = {"eris", "erimus", "eritis"}, {"erīs", "erīmus", "erītis"}
local preferredtbl = macra.LONG_PERF_SUBJ and longtbl or shorttbl
local opptbl = macra.LONG_PERF_SUBJ and shorttbl or longtbl



--===========  A N A L Y Z E  =============================================


-- if the given word exists in another section already, move both to MULTI
function add(section, w, repl)
	local inmulti, replinmulti = tomulti(w), false	-- if true, this word/replacement existed already in another section, but is now in MULTI
	if repl then replinmulti = tomulti(repl) end
	if inmulti or replinmulti then
		if not analysis[MULTI][w] then analysis[MULTI][w] = {} end
		analysis[MULTI][w][section] = true	-- add the new section to MULTI
	else	-- this word is new, not in any other section
		if section == HID then end
		table.insert(analysis[section], w)
		wsections[w] = section
	end
end


function tomulti(w)
	local oldsection = wsections[w]
	if oldsection then
		if oldsection ~= MULTI then		-- if it's not already been moved to MULTI
			delete(w)
			analysis[MULTI][w] = {}
			analysis[MULTI][w][oldsection] = true
			wsections[w] = MULTI
			return true
		else return true end
	end
	return false
end


function delete(w)
	local oldsection = wsections[w]
	for i = 1,#analysis[oldsection] do
		if analysis[oldsection][i] == w then
			local sectlen = #analysis[oldsection]
			analysis[oldsection][i] = nil
			for j = i,sectlen-1 do
				analysis[oldsection][j] = analysis[oldsection][j+1]
			end
			analysis[oldsection][#analysis[oldsection]] = nil
		end
	end
	wsections[w] = nil
end


-- finds and stores various uncertainties in the key; separate loops are used because the key may change during each loop
function analyze()
	print("\tAscertaining abbreviations ...")
	-- 1. ABBREVIATIONS (period not removed by default)
	for plainwkey,macronw in glue.sortedpairs(macra.keytbl) do
		local plainw = plainwkey:match("(%D+)")
		if plainw:sub(#plainw) == "." then
			if oktbl[macronw] then table.insert(analysis[ABV_OK], macronw)
			elseif autotbl[macronw] then table.insert(analysis[ABV_AUTO], macronw) autotbl[macronw] = nil
			else add(ABV, macronw) end
		end
	end
	print("\tEncountering enclitics ....")
	-- 2. ENCLITICS (enclitic-matching ending removed by default)
	for plainwkey,macronw in glue.sortedpairs(macra.keytbl) do
		local plainw = plainwkey:match("(%D+)")
		local wlen = #plainw
		for enc,likely in pairs(macra.enclitictbl) do
			local enclen = #enc
			if utf8.sub(macronw, wlen - enclen + 1) == enc then
				if oktbl[macronw] then table.insert(analysis[ENC_OK], macronw)
				elseif autotbl[macronw] then table.insert(analysis[ENC_AUTO], macronw)
				elseif macronw ~= enc then	-- to prevent replacing the words "ne", "que", "ve"
					add(ENC, macronw)
					if not likely then analysis[ENC_DOUBT][macronw] = true end
				end
			end
		end
	end
	-- 3. "I" IN PERFECT SUBJUNCTIVE ENDINGS (shorten or lengthen, according to option)
	-- autotbl may here be changed! any replacement contrary to the current option is removed, e.g. "ceperis" -> "ceperīs" with a short-ending preference in place
	print("\tLocating perfect subjunctives ending in "..(macra.LONG_PERF_SUBJ and "short \"i" or "long \""..string.char(140)).."\" ...")
	for plainwkey,macronw in glue.sortedpairs(macra.keytbl) do
		local plainw = plainwkey:match("(%a+)")
		local wlen = #plainw
		for i,ending in pairs(preferredtbl) do
			local endlen = (i == 1 and 4 or 6)	-- "erĩs" 4 chars long, the other two 6 chars long
			if utf8.sub(macronw, wlen-endlen+1) == ending then	-- possible perfect form
				local oppw = utf8.sub(macronw, 1, wlen-endlen)..opptbl[i]	-- same word, opposite "i" length
				if oktbl[macronw] then table.insert(analysis[PRF_OK], macronw)
				elseif oktbl[oppw] then		-- remove OK counter to current option
					autotbl[oppw] = nil
					add(PRF, macronw)
				elseif autotbl[macronw] then table.insert(analysis[PRF_AUTO], macronw)
				elseif autotbl[oppw] then	-- remove auto-repl. counter to current option
					autotbl[oppw] = nil
					add(PRF, macronw)
				else add(PRF, macronw) end
			end
		end
	end
	-- 4. HIDDEN VOWELS (certain replacements made by default, doubtful ones reported but not effected by default)
	print("\tRevealing hidden long vowels ...")
	for plainwkey,macronw in glue.sortedpairs(macra.keytbl) do
		local plainw = plainwkey:match("(%a+)")
		local replw, replatpostbl = macra.subword(macronw, hidorigtbl, hidrepltbl, hidmodtbl, true)
		if replw ~= macronw then	-- at least one substitution has been made
			if oktbl[macronw] then table.insert(analysis[HID_OK], macronw)
			elseif autotbl[macronw] then table.insert(analysis[HID_AUTO], macronw)
			else
				add(HID, macronw, replw)
				analysis[HID_REPL][macronw] = replw
				-- save which substitutions were doubtful, and the notes from the last (rightmost) substitution
				local lastnotepos = 0
				for pos,i in pairs(replatpostbl) do
					if pos > lastnotepos and hidnotetbl[i] then lastnotepos = pos end
					if (hidmodtbl[i] or ""):find(macra.DOUBT_CHAR) then analysis[HID_DOUBT][macronw] = true end
				end
				if lastnotepos > 0 then analysis[HID_NOTES][macronw] = hidnotetbl[replatpostbl[lastnotepos]] end
			end
		end
	end
	-- 5. ORTHOGRAPHY (if option enabled, certain replacements made by default, doubtful ones ignored. but see _CONFIG.txt.)
	if macra.REPAIR_ORTH then
		print("\tOuting odd orthography...")
		for plainwkey,macronw in glue.sortedpairs(macra.keytbl) do
			local plainw = plainwkey:match("(%a+)")
			local replw, replatpostbl = macra.subword(macronw, macra.orthorigtbl, macra.orthrepltbl, macra.orthmodtbl, false)
			if replw ~= macronw then	-- at least one substitution has been made
				if oktbl[macronw] then table.insert(analysis[ORTH_OK], macronw)
				elseif autotbl[macronw] then table.insert(analysis[ORTH_AUTO], macronw)
				else
					add(ORTH, macronw, replw)
					analysis[ORTH_REPL][macronw] = replw
					-- save the notes from the last (rightmost) substitution (but doubtful substitutions are simply ignored)
					local lastnotepos = 0
					for pos,i in pairs(replatpostbl) do
						if pos > lastnotepos and macra.orthnotetbl[i] then lastnotepos = pos end
					end
					if lastnotepos > 0 then analysis[ORTH_NOTES][macronw] = macra.orthnotetbl[replatpostbl[lastnotepos]] end
				end
			end
		end
	end
	-- 6. AMBIGUITIES
	print("\tClarifying ambiguities...")
	local ambigstbl = {}
	for plainwkey,macronw in glue.sortedpairs(macra.keytbl) do
		local plainw, parnum = plainwkey:match("(%a+)(%d+)")
		-- first create a table of the set of ambiguous word forms, where ambigstbl[plainw][x] = macra.keytbl[plainw..(x-1)]
		if parnum and not ambigstbl[plainw] then	-- if this is an ambiguous set not yet stored
			ambigstbl[plainw], i = {}, 1
			ambigstbl[plainw][1] = macra.keytbl[plainw]	-- first word listed in key (not detected before)
			while macra.keytbl[plainw..i] do
				ambigstbl[plainw][i+1] = macra.keytbl[plainw..i]
				i = i + 1
			end
		end
	end
	-- for each set, if a word form isn't on the OK or auto lists, remove set from consideration (& auto-replace the latter)
	for plainw,macronwtbl in glue.sortedpairs(ambigstbl) do
		local hasneww = false
		for _,macronw in pairs(ambigstbl[plainw]) do
			if oktbl[macronw] then table.insert(analysis[AMB_OK], macronw)
			elseif analysis[AMB_AUTO][macronw] then table.insert(analysis[AMB_AUTO], macronw)
			else hasneww = true end
		end
		if hasneww then
			local ismulti = false
			for _,parw in pairs(ambigstbl[plainw]) do
				if wsections[parw] then ismulti = true end
			end
			if ismulti then 
				for _,parw in pairs(ambigstbl[plainw]) do
					if not tomulti(parw) then analysis[MULTI][parw] = {} end
					analysis[MULTI][parw][AMB] = true
				end
			else table.insert(analysis[AMB_NEW], plainw) end
			analysis[AMB_PARS][plainw]= ambigstbl[plainw]
		end
	end
end


function writerepairsfile()
	local pre, xpre, xdoubtpre, commentpre, autopre, okpre = "\n\t? ", "\nx\t? ", "\nx\t?? ", "\n\t\t// ", "\t(auto)\t: ", "\t(OK)\t: "
	local orthdisabled = "// Orthographic repairs are disabled. To enable, change the option in \"_CONFIG.txt\".\n"
	local str = "// REPAIRS\n// Generated by Analyze Key on "..os.date()..".\n\n// Instructions: For each list of entries below, enter your corrections at the beginning of each line beginning with \"?\" as directed at the beginning of each list (minus the quote marks).\n// Multiple inputs can be in any order, except that \"x\" must be the first character on the line, where it is required.\n\n// The first set of lists is of words with new issues, and the other two sets are of problematic words encountered in the past, which will be fixed or ignored automatically based on your previous actions.\n// After correcting these lists, run Repair Key to apply the changes therein to \"key.txt\" and (except in the cases of enclitics and abbreviations) to all source texts. All repairs except those in the Multi section will be saved in the \"repair-x.txt\" files and will be automatically repeated in the future.\n\n// Note: The following can be entered at any point where input is expected, except in the Custom section:\n//\t- \"= α\" where α is a replacement for the word in question (except in the Ambiguities section).\n//\t- \"+ α\" where α is a new word.\n// The input specific to each section will be processed before these.\nExample:\n//\t(in the Enclitics section)\n//\t\"= ergo-\t? ergone\"\n//\tThe lack of an \"x\" before \"?\" means this word does in fact have an attached enclitic that will be removed in the word key (not in the source texts), resulting in \"ergo\", which is then replaced in the key and sources with \"ergō\".\n// Note that if a custom replacement is entered, \"x\" is still required to cancel an abbreviation or enclitic, but is not required to cancel other types of repairs (since they are themselves replacements).\n\n"
	str = str..SECTIONS[CUSTOM]
	str = str.."// Enter manual replacements.\n"
	str = str.."// Input: \"α > β\" where α is the original, β the replacement word.\n//\tor \"α*** = β\" where α is any part of a word, β the replacement, and *** are any number of string substitution modifiers. See introductory comments in \"hidden.txt\" for more information.\n//\tor simply \"α\" where α is a new word.\n"
	str = str.."\n"..macra.DIVIDER.."\n"..SECTIONS[MULTI]
	str = str.."// Forms with multiple issues. (?? = doubtful.)\n// Enter custom replacements.\n"
	str = str..'// Input: "\\e", "\\a", "\\p", "\\h", "\\o", and/or "\\m" to affirm that the word has an issue pertaining to, respectively, enclitics, abbreviations, perfect subjunctives, hidden vowels, orthography, and ambiguities.\n//\t(Note: "\\a" for an abbreviated word means that the final period will NOT be removed in the key. "\\e" for a word with an enclitic means that the enclitic WILL be removed in the key. For the input expected after "\\m" see the AMBIGUITIES section below.)'
	for w,sectionstbl in glue.sortedpairs(analysis[MULTI]) do
		str = str.."\n--------------------\n"..pre..w
		-- these concatenations are adapted or copied from each loop below. these MUST correspond to those!
		if sectionstbl[ABV] then str = str..commentpre.."(abbreviation?)" end
		if sectionstbl[ENC] then str = str..commentpre.."(enclitic?"..(analysis[ENC_DOUBT][w] and "?)" or ")") end
		if sectionstbl[PRF] and macra.REPAIR_PERF_SUBJ then str = str..commentpre.."(perfect subjunctive?)" end
		if sectionstbl[HID] then
			str = str..commentpre.."(hidden?"..(analysis[HID_DOUBT][w] and ") " or "?) ")..w.." -> "..analysis[HID_REPL][w]
			if analysis[HID_NOTES][w] then str = str.."\n\t\t\t// (N.B.:"..analysis[HID_NOTES][w]..")" end
		end
		if sectionstbl[ORTH] and macra.REPAIR_ORTH then
			str = str..commentpre.."(orthography?) "..w.." -> "..analysis[ORTH_REPL][w]
			if analysis[ORTH_NOTES][w] then str = str.."\n\t\t\t// (N.B.:"..analysis[ORTH_NOTES][w]..")" end
		end
		if sectionstbl[AMB] then 
			local plainw = utf8.replace(w, macra.macroninvtbl)
			local parstr, partbl = "", analysis[AMB_PARS][plainw]
			for parnum = 1,#partbl do parstr = parstr.." ["..parnum.."]"..partbl[parnum] end 
			parstr = parstr:sub(3)	-- remove leading comma and space
			str = str..commentpre.."(ambiguous) "..parstr
		end
	end
	str = str.."\n"..macra.DIVIDER.."\n"..SECTIONS[ABV_NEW]
	str = str.."// Periods will be kept in abbreviations.\n// Un-cancel true abbreviations.\n"
	str = str.."// Input: \"x\" cancels.\n"
	for i,abvw in ipairs(analysis[ABV_NEW]) do
		str = str..xpre..abvw
	end
	str = str.."\n"..macra.DIVIDER.."\n"..SECTIONS[ENC_NEW]
	str = str.."// Enclitics will be removed.\n// Cancel words that do not have enclitics.\n"
	str = str.."// Input: \"x\" to cancel.\n"
	for i,encw in ipairs(analysis[ENC_NEW]) do
		str = str..(analysis[ENC_DOUBT][encw] and xpre or pre)..encw
	end
	str = str.."\n"..macra.DIVIDER.."\n"..SECTIONS[PRF_NEW]
	local lps = macra.LONG_PERF_SUBJ
	str = str.."// "..(lps and "Short \"i\" will be lengthened" or "Long \"ī\" will be shortened").." in perfect subjunctive verb forms.\n// Cancel forms that are not perfect subjunctives.\n"
	str = str.."// Input: \"x\" to cancel.\n"
	for i,prfw in ipairs(analysis[PRF_NEW]) do
		str = str..pre..prfw
	end
	str = str.."\n"..macra.DIVIDER.."\n"..SECTIONS[HID_NEW]
	str = str.."// Hidden long vowels will be marked.\n// Cancel incorrect replacements. (?? = doubtful.)\n"
	str = str.."// Input: \"x\" to cancel.\n"
	for i,origw in ipairs(analysis[HID_ORIG]) do
		str = str..(analysis[HID_DOUBT][origw] and xdoubtpre or pre)..origw.." -> "..analysis[HID_REPL][origw]
		if analysis[HID_NOTES][origw] then str = str.."\n\t\t// (N.B.:"..analysis[HID_NOTES][origw]..")" end
	end
	str = str.."\n"..macra.DIVIDER.."\n"..SECTIONS[ORTH_NEW]
	if macra.REPAIR_ORTH then
		str = str.."// Orthography will be standardized.\n// Cancel incorrect replacements.\n"
		str = str.."// Input: \"x\" to cancel.\n"
		for i,origw in ipairs(analysis[ORTH_ORIG]) do
			str = str..pre..origw.." -> "..analysis[ORTH_REPL][origw]
			if analysis[ORTH_NOTES][origw] then str = str.."\n\t\t// (N.B.:"..analysis[ORTH_NOTES][origw]..")" end
		end
	else str = str..orthdisabled end
	str = str.."\n"..macra.DIVIDER.."\n"..SECTIONS[AMB_NEW]
	str = str.."// Incorrect parallel word forms may be replaced, and new parallel forms may be added.\n// Enter any desired changes.\n"
	str = str.."// Input: \"x\" where x is a number referring to the form that will replace all other forms.\n// OR\n// \"x = y, x = α\" where x and y are numbers, α is an unknown word form, and \"=\" means \"replace with\".\n// Example: \"2=mālā, 1=3\" replaces form [2] with \"mālā\" (and adds \"mālā\" to the key) and replaces form [1] with form [3].\n"
	for i,plainw in ipairs(analysis[AMB_NEW]) do
		local parstr, partbl = "", analysis[AMB_PARS][plainw]
		for parnum = 1,#partbl do parstr = parstr.." ["..parnum.."]"..partbl[parnum] end 
		parstr = parstr:sub(3)	-- remove leading comma and space
		str = str..pre..parstr
	end
	-- append the auto-replace tables
	for i = ABV_AUTO,AMB_AUTO do
		str = str.."\n"..macra.DIVIDER.."\n"..SECTIONS[i]
		if i == ABV_AUTO then
			str = str.."// Input: \"x\" to cancel and remove from \"repair-abbrev.txt\".\n"
			for abvw in glue.sortedpairs(analysis[i]) do
				str = str.."\t(auto)\t"..abv.."\n"
			end
		elseif i == ENC_AUTO then
			str = str.."// Input: \"x\" to cancel and remove from \"repair-enclitic.txt\".\n"
			for encw in glue.sortedpairs(analysis[i]) do
				str = str.."\t(auto)\t"..encw.."\n"
			end
		elseif i == ORTH_AUTO and not macra.REPAIR_ORTH then
			str = str..orthdisabled
		else
			str = str.."// Input: \"x\" to cancel and remove from \"repair-replace.txt\".\n"
			for origw,replw in glue.sortedpairs(analysis[i]) do
				str = str.."\t(auto)\t"..origw.." -> "..replw.."\n"
			end
		end
	end
	-- append the OK tables
	for i = ABV_OK,AMB_OK do
		str = str.."\n"..macra.DIVIDER.."\n"..SECTIONS[i]
		if i == ORTH_OK and not macra.REPAIR_ORTH then
			str = str..orthdisabled
		else
			str = str.."// Input: \"x\" to cancel and remove from \"repair-ok.txt\".\n"
			for okw in glue.sortedpairs(analysis[i]) do
				str = str.."\t(OK)\t"..okw.."\n"
			end
		end
	end
	local repairsf = io.open(macra.DIR_ROOT.."_repairs.txt", "w")
	repairsf:write(macra.bom())
	repairsf:write(str)
	repairsf:close()
end



--===========  R E P A I R  ===============================================


function loadrepairsfile()
	local repairspath = macra.DIR_ROOT.."_repairs.txt"
	local rawstr = macra.readutf8(repairspath, false)
	if not rawstr then macra.throwerror("No repairs found. (Repair-list file \""..repairspath.."\" does not exist.) Run key-analyze, then try again.") end
	if rawstr == "" then macra.throwerror("No repairs found. (Repair-list file \""..repairspath.."\" is empty.) Run key-analyze, then try again.") end
	local cleanstr = macra.hyphens2macs(rawstr)
	-- split the contents of the repairs file by section, then fill in the blanks for sections that arent [origw] -> [replw]
	local sectionstbl = macra.split(cleanstr, macra.DIVIDER)
	-- NEW SECTIONS
	for i = 1,#sectionstbl do
		sectionstbl[i] = macra.cleanup(sectionstbl[i], false, false)
		if i ~= MULTI then sectionstbl[i] = macra.decomment(sectionstbl[i]) end
		--if i > 8 then print('"'..sectionstbl[i]..'"') end
	end
	-- BUG: fancy substitution (with modifiers) doesn't work below, so commented out
	for _,line in pairs(macra.split(sectionstbl[CUSTOM], "\n")) do
		local origw, replw = line:match("("..macra.LETTERS..")[ ]*>[ ]*(.+)")
		--local suborigstr, subreplstr, submodstr = line:match("("..macra.LETTERS..")[ ]*=[ ]*("..macra.LETTERS..")("..macra.PUNCT.."+)")
		if origw then repltbl[origw] = replw
		--elseif suborigstr then
		--	for _,w in pairs(macra.keytbl) do
		--		local subreplw = macra.subword(w, {suborigstr}, {subreplstr}, {submodstr})
		--		if subreplw ~= origw then replaceword(origw, subreplw) end	-- custom fixes not in repltbl (not saved in repair history)
		--	end
		elseif not line:find("<") and not line:find("=") then
			local addw = line:match("("..macra.LETTERS..")")
			if addw then table.insert(addtbl, addw) end
		end
	end
	for _,entry in pairs(macra.split(sectionstbl[MULTI], "%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-")) do
		local choices, multiw = entry:match("([^%?]+)%?"), entry:match("%?[ ]*("..macra.LETTERS..")")
		if entry ~= "" and entry:sub(1,2) ~= "//" then
			if choices then
				local replw = nil
				if entry:find("%(hidden%?") and choices:find("\\h") then replw = entry:match("%(hidden%?%)[ ]*"..macra.LETTERS.."[ ]*%->[ ]*("..macra.LETTERS..")") end	-- no closing parenthesis in entry:find - may have extra question mark
				if entry:find("%(orthography%?%)") and choices:find("\\o") then replw = entry:match("%(orthography%?%)[ ]*"..macra.LETTERS.."[ ]*%->[ ]*("..macra.LETTERS..")") end
				if entry:find("%(ambiguous%)") and choices:find("\\m") then
					--entry = entry:gsub("%?", "\\?")		-- for defining the end of the ambig entry string, below
					replw = fixambig(macra.split(entry:match("\\m([^\\]+"), ","), entry:match("%(ambiguous%) [^\n]+"))
				end
				if entry:find("%(abbreviation%?%)") and not choices:find("\\a") then replw = fixabv(replw or multiw) end
				if entry:find("%(enclitic%?%)") and choices:find("\\e") then replw = fixenc(replw or multiw) end
				if entry:find("%(perfect[ ]*subjunctive%?%)") and choices:find("\\p") then replw = fixprf(replw or multiw) end
				replw = entry:match("=[ ]*("..macra.LETTERS..")") or replw		-- manual replacement
				if replw then replaceword(multiw, replw) end	-- don't save in repltbl: words with multiple problems shouldn't be saved in repair history, e.g. then the perfect subjunctive might be reversed if the _CONFIG.txt option is changed, and the word would be reverted to having multiple problems
				manadd(entry)
			else oktbl[multiw] = true end
		end
	end
	for _,line in pairs(macra.split(sectionstbl[ABV], "\n")) do
		if line:sub(1,2) ~= "//" then
			local x, origw = line:sub(1,1), line:match("%?[ ]*([^%s%d]+)")	-- %P excluded: period in abbreviations
			if x and origw then
				local replw = line:match("=[ ]*([^%s%d%?]+)")	-- find manually-entered replacement word (if any)
				if not replw and x ~= "x" then replw = fixabv(origw) end -- word fixed (i.e. not abbrev) if "x" NOT entered
				if replw then
					abvtbl[origw] = replw
					replaceword(origw, replw, false)  -- don't save in repltbl: abbrevs changed in key only, NOT in sources
				else oktbl[origw] = true end
				manadd(line)
			end
		end
	end
	for _,line in pairs(macra.split(sectionstbl[ENC], "\n")) do
		if line:sub(1,2) ~= "//" then
			local x, origw = line:sub(1,1), line:match("%?[ ]*("..macra.LETTERS..")")
			if x and origw then
				local replw = line:match("=[ ]*([^%s%d%?]+)")	-- manual replacement
				if not replw and x ~= "x" then replw = fixenc(origw) end -- word fixed (i.e. has enclitic) if "x" is entered
				if replw then
					enctbl[origw] = replw
					replaceword(origw, replw, false)  -- don't save in repltbl: enclitics changed in key only, NOT in sources
				else oktbl[origw] = true end
				manadd(line)
			end
		end
	end
	for _,line in pairs(macra.split(sectionstbl[PRF], "\n")) do
		if line:sub(1,2) ~= "//" then
			local x, origw = line:sub(1,1), line:match("%?[ ]*("..macra.LETTERS..")")
			if x and origw then
				local replw = line:match("=[ ]*([^%s%d%?]+)")	-- manual replacement
				if not replw and x ~= "x" then replw = fixprf(origw) end -- word fixed (i.e. is perf subj) if "x" NOT entered
				if replw then repltbl[origw] = replw
				else oktbl[origw] = true end
				manadd(line)
			end
		end
	end
	for _,line in pairs(macra.split(sectionstbl[HID], "\n")) do
		if line:gsub("\t", ""):sub(1,2) ~= "//" then
			local x  = line:sub(1,1)
			local origw, hidreplw = line:match("%?[ ]*("..macra.LETTERS..")[ ]*%->[ ]*("..macra.LETTERS..")")
			if x and origw and hidreplw then
				local replw = line:match("=[ ]*([^%s%d%?]+)")	-- manual replacement
				if not replw and x ~= "x" then replw = hidreplw end
				if replw then repltbl[origw] = replw
				else oktbl[origw] = true end
				manadd(line)
			end
		end
	end
	for _,line in pairs(macra.split(sectionstbl[ORTH], "\n")) do
		if line:sub(1,2) ~= "//" then
			local x  = line:sub(1,1)
			local origw, orthreplw = line:match("%?[ ]*("..macra.LETTERS..")[ ]*%->[ ]*("..macra.LETTERS..")")
			if x and origw and orthreplw then
				local replw = line:match("=[ ]*([^%s%d%?]+)")	-- manual replacement
				if not replw and x ~= "x" then replw = orthreplw end
				if replw then repltbl[origw] = replw
				else oktbl[origw] = true end
				manadd(line)
			end
		end
	end
	for _,line in pairs(macra.split(sectionstbl[AMB], "\n")) do
		local entrystr, parstr = line:match("([^%?]+)%?"), line:match("%?[ ]*(.+)")
		if entrystr then fixamb(macra.split(entrystr, ","), parstr) end
		manadd(line)
	end
	for i = ABV,AMB do
		-- AUTO-REPAIR SECTIONS
		for _,line in pairs(macra.split(sectionstbl[6+i], "\n")) do
			if line ~= "" then
				local x = line:sub(1,1)
				local manreplw = line:match("=[ ]*("..macra.LETTERS..")")
				if i == ABV then
					local abvw = line:match("%)\t([^%s%d]+)")
					if manreplw then repltbl[abvw] = manreplw end
					if x == "x" or manreplw then oktbl[abvw] = nil
					else fixabv(abvw) end
					manadd(line)
				elseif i == ENC then
					local encw = line:match("%)\t([^%s%d]+)")
					if manreplw then repltbl[encw] = manreplw end
					if x == "x" or manreplw then oktbl[encw] = nil
					else fixenc(encw) end
					manadd(line)
				else
					local origw, replw = line:match("%)\t("..macra.LETTERS..")[ ]*%->[ ]*("..macra.LETTERS..")")
					if origw then
						if manreplw then
							repltbl[origw] = manreplw
						else
							if x ~= "x" then repltbl[origw] = replw
							else
								autotbl[origw] = nil
								oktbl[origw] = true
							end
						end
					end
				end
				manadd(line)
			end
		end
		-- OK SECTIONS
		for _,line in pairs(macra.split(sectionstbl[12+i], "\n")) do
			local x = line:sub(1,1)
			local okw = line:match("%)\t("..macra.LETTERS..")")
			local manreplw = line:match("=[ ]*("..macra.LETTERS..")")
			if x == "x" or manualreplw then oktbl[okw] = nil end
			manadd(line)
		end
	end
	return rawstr
end


-- add w to repltbl, for the different types of issues
function fixabv(w)
	local replw = w:sub(1,#w-1)
	return replw
end
function fixenc(w)
	local replw, wlen = w, utf8.len(w)
	for enc,_ in pairs(macra.enclitictbl) do
		local realwlen = wlen - #enc
		if utf8.sub(w, realwlen + 1) == enc then replw = utf8.sub(w, 1, realwlen) end
	end
	return replw
end
function fixprf(w)
	local replw, origwlen = w, utf8.len(w)
	for i,ending in pairs(preferredtbl) do
		local rootlen = origwlen - (i == 1 and 4 or 6)	-- "eris"/"-īs" is 4 characters long, etc.
		if utf8.sub(w, rootlen + 1) == opptbl[i] then replw = utf8.sub(w, 1, rootlen)..ending end
	end
	return replw
end
function fixamb(entrytbl, parstr)
	local partbl = macra.split(parstr, ",")
	local parcount = #partbl
	for i = 1,#partbl do partbl[i] = partbl[i]:match("%](.+)") end
	local paroktbl = {}
	for parnum = 1,parcount do paroktbl[parnum] = true end
	local allnum = entrytbl[1]:len() == 1 and entrytbl[1]:match("(%d)") or nil	-- all forms -> the form under the given option
	if allnum then
		for n=1,#partbl do
			if n ~= allnum then
				repltbl[partbl[n]] = partbl[allnum]
				paroktbl[n], paroktbl[allnum] = false, true
			end
		end
	else
		for _,entry in pairs(entrytbl) do
			if entry:sub(1,2) ~= "//" then
				local num1, num2 = entry:match("(%d)[ ]*=[ ]*(%d)")	-- a form under one given option -> a form under another
				if num1 then
					repltbl[partbl[num1]] = partbl[num2]
					paroktbl[num1], paroktbl[num2] = false, true
				else
					local num, w = entry:match("(%d)[ ]*=[ ]*(.+)")	-- a form under a given option -> a custom form
					num = tonumber(num)
					if num then
						repltbl[partbl[num]] = w
						paroktbl[num] = false
						oktbl[w] = true
					end
				end
			end
		end
	end
	-- mark all parallel forms as OK except those that were replaced (if any)
	for okpar,ok in pairs(paroktbl) do
		if ok then oktbl[okpar] = true end
	end
end
-- manual add (e.g. "+ certa-mine")
function manadd(entry)
	local addw = entry:match("%+[ ]*([^%?%s%p%d]+)")
	if addw then
		table.insert(addtbl, addw)
		return true
	end
end


-- add the given word to the key
function addword(w, plainw, partbl, parcount)
	if not plainw then plainw = utf8.replace(w, macra.macroninvtbl) end
	if not partbl then partbl, parcount = macra.getpars(plainw) end
	if not partbl or not partbl[w] then
		macra.keytbl[plainw..(parcount or "")] = w
		return true
	else return false end
end


-- substitute a word in the key and texts in lowercase, capitalized, and all-caps, plus each of these with enclitics
function replaceword(orig, repl, changesources)
	local origplainw, replplainw = utf8.replace(orig, macra.macroninvtbl), utf8.replace(repl, macra.macroninvtbl)
	local origpartbl, origparcount = macra.getpars(origplainw)
	if origparcount == nil or not origpartbl[orig] then macra.throwerror("\""..orig.."\" could not be repaired: not found in word key!")
	else
		if changesources == nil then changesources = true end
		if changesources and macra.headerstbl[orig] then
			for header,_ in pairs(macra.headerstbl[orig]) do
				textstbl[header] = replaceintext(textstbl[header], orig, repl)
				for enc,_ in pairs(macra.enclitictbl) do
					textstbl[header] = replaceintext(textstbl[header], orig..enc, repl..enc)
				end
			end
		end
		-- look for the replacement in the key. if it doesn't exist, add it.
		if not macra.keytbl[replplainw] then	-- create a new keytbl entry, and delete the old one
			local replpartbl, replparcount = macra.getpars(replplainw)
			macra.keytbl[replplainw..(replpartbl and replparcount or "")] = repl
		else	-- add replacement form into an existing keytbl entry, if the form does not already exist
			local savedplainwkey = nil	-- DEBUG; DELETE!!
			local replpartbl, replparcount = macra.getpars(replplainw)
			local parfound = false	-- whether or not the replacement form already exists in the key
			for parw,plainwkey in pairs(replpartbl) do
				if parw == repl then parfound = true end
			end
			if not parfound then macra.keytbl[replplainw..replparcount] = repl end
		end
		macra.keyremove(orig, origplainw, origpartbl, origparcount)
		-- move the headers and frequency to the replacement entry
		local hocount, hrcount, hmcount = 0, 0, 0
		for ho,_ in pairs(macra.headerstbl[orig]) do hocount = hocount + 1 end
		for hr,_ in pairs(macra.headerstbl[repl] or {}) do hrcount = hrcount + 1 end
		local fo, fr, fm = macra.freqtbl[orig], macra.freqtbl[repl] or 0, 0
		macra.headerstbl[repl] = glue.merge(macra.headerstbl[repl] or {}, macra.headerstbl[orig])
		macra.headerstbl[orig] = nil
		for hm,_ in pairs(macra.headerstbl[repl]) do hmcount = hmcount + 1 end
		macra.freqtbl[repl] = (macra.freqtbl[repl] or 0) + macra.freqtbl[orig]
		macra.freqtbl[orig] = nil
		fm = macra.freqtbl[repl]
	end
end


-- substitutes lowercase, capitalized, and all-uppercase versions of orig with the corresponding version of repl
function replaceintext(text, orig, repl)
	local origcap, replcap = macra.utf8capitalize(orig), macra.utf8capitalize(repl)
	local origallcaps, replallcaps = macra.utf8upper(orig), macra.utf8upper(repl)
	local commentstbl = macra.getcommentset(text)
	text = replacesingle(text, orig, repl, commentstbl)
	text = replacesingle(text, origcap, replcap, commentstbl)
	text = replacesingle(text, origallcaps, replallcaps, commentstbl)
	return text
end


-- substitutes orig with repl in str (unless in comments) wherever orig is a distinct word (bounded by spaces or punctuation, except a following period in order to avoid replacing abbreviations e.g. "a. Kal." and "ā")
-- limitation: when two words are divided by punctuation but no space, only ASCII punctuation is detected ("%p" pattern)
function replacesingle(str, orig, repl, commentstbl)
	local findtbl = {"(%s)"..orig.."(%s)", "(%p)"..orig.."(%s)", "(%s)"..orig.."("..macra.PUNCT..")", "(%p)"..orig.."("..macra.PUNCT..")"}
	local replstr, strfinal = "%1"..repl.."%2", str
	for _,findstr in pairs(findtbl) do
		local wstart, wend = strfinal:find(findstr)
		while wstart and not commentstbl[wstart] do
			strfinal = strfinal:sub(1, wstart-1)..strfinal:sub(wstart, wend):gsub(findstr, replstr, 1)..strfinal:sub(wend+1)
			wstart, wend = strfinal:find(findstr, wend)
		end
	end
	return strfinal
end



--===========  S T A R T  =================================================


if mode == ANALYZE then
	print("Searching for possible errors in \"key.txt\" ...\n")
	analyze()
	writerepairsfile()
	macra.saverepairhistory(abvtbl, enctbl, autotbl, oktbl)	-- because step 3 (perfect subjunctive endings) in analyze() may change autotbl

	logf:write("\nEnd of log.")
	logf:close()

	print("\nDone.\n\nPossible errors in the key have been saved in \""..macra.DIR_ROOT.."_repairs.txt\". Please review these and then run Repair Key to effect any changes.\n\nSee also log file for details.\n\n")
elseif mode == REPAIR then
	print("Loading \"_repairs.txt\" ...\n")
	local rawrepairstxt = loadrepairsfile()
	print("Adding new words ...\n")
	for _,addw in pairs(addtbl) do
		addword(addw)
	end
	print("Replacing words ...\n")
	-- first merge "chain" replacements (a -> b, b -> c)
	for origw,replw in pairs(repltbl) do
		if repltbl[replw] then
			repltbl[origw] = repltbl[replw]
			repltbl[replw] = nil
		end
	end
	for origw,replw in pairs(repltbl) do replaceword(origw, replw) end
	for origw,replw in pairs(repltbl) do
		if oktbl[origw] then oktbl[origw] = nil end
		oktbl[replw] = true
		autotbl[origw] = replw
	end
	macra.savekey()
	for header,filename in pairs(filenamestbl) do
		local textf = io.open(macra.DIR_SOURCES..filename, "w")	-- write the text to file again
		textf:write(textstbl[header])
		textf:close()
	end
	macra.saverepairhistory(abvtbl, enctbl, autotbl, oktbl)

	logf:write("Below are the contents of \"repairs.txt\" from which changes were made to the word key and all source texts:\n==================================================================\n"..rawrepairstxt)

	logf:write("\nEnd of log.")
	logf:close()

	print("\nDone. \n\n\"key.txt\" has been updated in \""..macra.DIR_DATA.."\". See also log file in \""..macra.DIR_LOGS.."\" for details.\n\n")
end