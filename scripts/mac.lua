--[[

mac.lua
by Felipe Vogel
fps.vogel@gmail.com

Macronize. Primary functionality of Maccer. Adds macrons to a text based on the macron-form key.

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

local LETTERS = macra.LETTERS
local NOTFOUND, AMBIG, GUESS, AFFIX, INVALID = macra.FLAG_NOTFOUND, macra.FLAG_AMBIG, macra.FLAG_GUESS, macra.FLAG_AFFIX, macra.FLAG_INVALID
local IGNORE, DOUBT, GUESS_THRESHOLD = macra.USER_IGNORE, macra.DOUBT_CHAR, macra.GUESS_THRESHOLD
local COMMENT, COMMENT_MULTI = macra.COMMENT, macra.COMMENT_MULTI
local SHORT, LONG, EITHER = 0, 1, 2
local overwrite = macra.OVERWRITE_MACS

local logf = macra.initialize("macronize")

-- cut here for conversion to mac-web

-- returns text with macrons and flags added
function macronize(text)
	if overwrite then text = macra.remmacs(text) end
	local hascomments = text:find(COMMENT) or text:find(COMMENT_MULTI)
	local commentstbl = hascomments and getcommentset(text) or nil
	local wstart, wend = text:find(LETTERS)
	while wstart do
		if hascomments then commentstbl = getcommentset(text) end
		if not hascomments or not commentstbl[wstart] then
			local w, isinvalid, periodremoved = text:sub(wstart, wend), false, false
			w, wstart, wend, isinvalid = macra.ignorechars(w, wstart, wend, false)
			local finalw, flagstbl = w, {}
			local plainw, flags = w, nil
			if w and w ~= "" then
				if isinvalid then flagstbl[INVALID] = true
				else
					local hasmacrons = false
					if not overwrite then
						for mac,_ in pairs(macra.macroninvtbl) do
							if w:find(mac) then hasmacrons = true end
						end
					end
					if not hasmacrons then
						-- save position of uppercase chars
						local cappostbl = {}
						for pos = 1,utf8.len(w) do
							local pchar = utf8.sub(w, pos, pos)
							if macra.capsinvtbl[pchar] then table.insert(cappostbl, pos) end
						end
						local wlower = utf8.replace(w, macra.capsinvtbl)
						-- make orthographic substitutions and save their positions
						local suresubw, suresubatpostbl = macra.subword(wlower, macra.orthorigtbl, macra.orthrepltbl, macra.orthmodtbl, false, true)
						suresubw = utf8.replace(suresubw, macra.macroninvtbl) -- to ASCII
						local doubtsubw, doubtsubatpostbl = nil, nil
						-- VARIATION LOOP: will run up to 16 times, where:
						--	 1. plainwtry = plainw
						--   2. plainwtry = plainw minus an enclitic
						--   3. plainwtry = plainw minus a prefix,
						--	 4. plainwtry = plainwtry from (2) minus the prefix from (3) (only if both enclitic and prefix found)
						-- If at any point a match is found, whether ambiguous or not, the loop is ended early.
						-- These 4 loops are then repeated with same word minus the period, if it's been tried as an abbreviation.
						-- They're then repeated up to twice again (as and as not abbrev.) with any doubtful substitutions.
						local isapplied, isnotfound, enclitic, prefix = false, false, nil, nil
						local wende, wstartp = nil, nil -- end of word before enclitic, start of word after prefix
						local subatpostbl = suresubatpostbl
						local triedenclitics, triedprefixes, triedencliticstwice, tryingabbrev, trieddoubtsub = false, false, false, false, false, false
						plainw = suresubw	-- current plain word (later, minus a period, then subwdoubt)
						local plainwtry = plainw -- current variation taking into account enclitic/prefix
						while not isapplied and not isnotfound do
							local macronw = macra.keytbl[plainwtry]		-- macronized form of the lowercase
							if macronw then
								-- determine if other possibilities exist, i.e. other macron-form parallels for this ASCII word,
								-- (e.g. "hoc" and "hoc", or "comis" and "comis")
								-- if so, guess the most frequent if it is frequent enough:
								-- i.e. if f / (f + f1 + f2 + ...) > t, where f are frequencies and t is the minimum % likelihood
								-- if no parallels are likely enough, this word is ambiguous
								local guessw, ambigw = nil, nil
								local partbl, parcount = macra.getpars(plainwtry, true)
								if parcount > 1 then	-- if two or more parallels, then try to guess based on frequency
									local topparw, topfreq, totalfreq = nil, 0, 0
									for parw,plainwkey in pairs(partbl) do
										local freq = macra.freqtbl[parw] or macra.freqtbl[macra.keytbl[plainwkey]] or 1
										if not topparw or freq > topfreq then
											topparw, topfreq = parw, freq
										end
										totalfreq = totalfreq + freq
									end
									if totalfreq > 0 and topfreq / totalfreq >= macra.GUESS_THRESHOLD then guessw = topparw
									else	-- ambiguous (could not be guessed), so create a word with "~" over uncertain vowels
										ambigw = plainwtry
										for pos = 1,utf8.len(plainwtry) do
											local letter = utf8.sub(plainwtry, pos, pos)
											local tildevowel = macra.tildetbl[letter]
											if tildevowel then	-- if this letter is a vowel
												local length, parlength, firstlength = 0, 0, nil
												for parw,_ in pairs(partbl) do
													if length ~= EITHER then
														parlength = macra.macroninvtbl[utf8.sub(parw, pos, pos)] and LONG or SHORT
														if not firstlength then length, firstlength = parlength, parlength end
														if parlength ~= firstlength then length = EITHER end
													end
												end
												if length == EITHER then
													ambigw = utf8.sub(ambigw, 1, pos-1)..tildevowel..utf8.sub(ambigw, pos+1)
												elseif length == LONG then	-- because plainwtry does not have macrons
													ambigw = utf8.sub(ambigw, 1, pos-1)..macra.macrontbl[letter]..utf8.sub(ambigw, pos+1)
												end
											end
										end
									end
								end
								finalw = (prefix or "")..((guessw or ambigw) or macronw)..(enclitic or "")
								-- restore substitutions
								for pos = utf8.len(finalw),1,-1 do
									if subatpostbl[pos] then
										local origstr, replstr = macra.orthorigtbl[subatpostbl[pos]], macra.orthrepltbl[subatpostbl[pos]]
										local origlen, repllen = utf8.len(origstr), utf8.len(replstr)	-- lengths of the string originally substituted and of that replaced, e.g. 3 and 2 for "cu" from "quu"
										local macreplstr, macorigstr = utf8.sub(finalw, pos, pos-1+repllen), nil
										-- if substituted string has been macronized (unless subst. already has macron, e.g. Camoen -> Camēn), look for another entry with the macronized original form
										macorigstr = origstr
										-- NOTE: the below method caused problems "reverting" to the wrong "original" (not original) strings
										--if macreplstr ~= replstr then
											--if not macra.orthreplinvtbl then macra.orthreplinvtbl = glue.index(macra.orthrepltbl) end
											--local macorigindex = macra.orthreplinvtbl[macreplstr] -- nil if a macronized original form does not exist
											--macorigstr = macorigindex and macra.orthorigtbl[macorigindex] or nil
											--macorigstr = origstr
											--if not macorigstr then
											--	local revert = not string.find(macra.orthmodtbl[subatpostbl[pos]], macra.NO_REVERT)
											--	macra.throwerror("No macronized original form found for \""..macreplstr.."\" after the substitution \""..origstr.."\" -> \""..replstr.."\", for the word \""..macra.macs2ascii(finalw).."\" (originally \""..w.."\"). "..(revert and "REVERTING TO \""..origstr.."\"." or "NOT REVERTING (substitution marked with \"%\").").." See \"orthography.txt\".", "ORTHOGRAPHIC WARNING")
											--	macorigstr = origstr	-- revert to the unmacronized original that exists
											--end
										--else macorigstr = origstr end	-- e.g. "Camēna" back to "Camoena"
										finalw = utf8.sub(finalw, 1, pos-1)..macorigstr..utf8.sub(finalw, pos+repllen)
									end
								end
								-- lengthen vowels before ns, nf -- see Bennet - The Latin Language, ch. 3, #37 (http://web.comhem.se/alatius/latin/bennetthidden.html)
								if prefix then finalw = finalw:gsub("ins", "īns"):gsub("inf", "īnf"):gsub("cons", "cōns"):gsub("conf", "cōnf") end
								-- restore capitalization
								for _,pos in pairs(cappostbl) do
									finalw = utf8.sub(finalw, 1, pos-1)..macra.capstbl[utf8.sub(finalw, pos, pos)]..utf8.sub(finalw, pos+1)
								end
								-- flag the word for enclitic/prefix if necessary
								if enclitic or prefix then flagstbl[AFFIX] = true end
								if guessw then flagstbl[GUESS] = true
								elseif ambigw then flagstbl[AMBIG] = true end
								isapplied = true
							elseif not triedenclitics then
								if not enclitic then	-- at the end of 1st loop, setting up for the 2nd (minus enclitic)
									for enc,_ in pairs(macra.enclitictbl) do
										if plainwtry:sub(#plainwtry-#enc+1) == enc then
											plainwtry = plainwtry:sub(1, #plainwtry-#enc)
											enclitic = enc
											break
										end
									end
									triedenclitics = true
								else	-- setting up for 4th loop (minus enclitic and prefix), after prefix try
									plainwtry = plainwtry:sub(1, #plainwtry-#enclitic)	-- prefix is already excluded from plainwtry at this point
									triedenclitics = true
								end
							elseif not triedprefixes then	-- setting up for 3rd loop (minus prefix)
								for _,pfplain in pairs(macra.prefixtbl) do
									if plainw:sub(1, #pfplain) == pfplain then	-- revert to plainw (before enclitic try)
										plainwtry = plainw:sub(#pfplain+1)
										prefix = macra.prefixmactbl[pfplain] or pfplain
										break
									end
								end
								triedprefixes = true
							elseif triedprefixes and enclitic and prefix and not triedencliticstwice then
								triedenclitics = false		-- setting up for 4th loop: try enclitics again using the prefixed form
								triedencliticstwice = true
							else	-- 4 basic loops done: now try them again with non-abbreviation and doubtful subs
								if plainw:sub(#plainw) == "." then
									plainw = plainw:sub(1, #plainw-1)
									plainwtry = plainw
									periodremoved = true
									triedenclitics, triedprefixes, triedencliticstwice = false, false, false
									enclitic, prefix, wende, wstartp = nil, nil, nil, nil
								else
									periodremoved = false
									local prevdoubtsubw = doubtsubw
									doubtsubw, doubtsubatpostbl = macra.subword(wlower, macra.orthorigtbl, macra.orthrepltbl, macra.orthmodtbl, true, true, doubtsubw, doubtsubatpostbl)
									doubtsubw = utf8.replace(doubtsubw, macra.macroninvtbl)
									if doubtsubw ~= suresubw and doubtsubw ~= prevdoubtsubw then
										plainw = doubtsubw
										plainwtry = plainw
										subatpostbl = doubtsubatpostbl
										triedenclitics, triedprefixes, triedencliticstwice = false, false, false
										enclitic, prefix, wende, wstartp = nil, nil, nil, nil
									else isnotfound = true end
								end
							end
						end
						if isnotfound then flagstbl[NOTFOUND] = true end
					end
				end
				local flagstr = ""
				for flag,_ in pairs(flagstbl) do
					flagstr = flagstr..flag
				end
				local periodchar = periodremoved and 1 or 0
				text = text:sub(1, wstart-1)..flagstr..finalw..text:sub(wend+1-periodchar)
				-- move end-of-word position based on a possible flag and new character lengths
				wend = wend + #flagstr
				local lendiff = #finalw - #w + periodchar
				if lendiff > 0 then wend = wend + lendiff end
			end
		end
		wend = wend + 1
		wstart, wend = text:find(macra.LETTERS, wend)
	end
	return text
end


--===========  S T A R T  =================================================


local textstbl, filenamestbl, textcount = macra.gettexts(macra.DIR_MACRONIZE)	-- texts to be macronized
for header,filename in pairs(filenamestbl) do
	textstbl[header] = macronize(macra.remflags(textstbl[header]))
	local textf = io.open(macra.DIR_MACRONIZE..filename, "w")	-- write the text to file again
	textf:write(textstbl[header])
	textf:close()
end
if textcount == 0 then
	print("\nNo new texts found in \""..macra.DIR_MACRONIZE.."\".\n")
	logf:write("No texts found in \""..macra.DIR_MACRONIZE.."\".\n")
else	-- log results
	local str = textcount.." text(s) macronized:\n"
	for header,filename in glue.sortedpairs(filenamestbl) do
		str = str.."\nFile: \""..filename.."\".\n"
		if header ~= "" then str = str.."    (Header: \""..header.."\".)\n" end
	end
	logf:write(str)
end

logf:write("\n\nEnd of log.")
logf:close()

print("\nDone.\n\nSee updated text(s) in \""..macra.DIR_MACRONIZE.."\".\n\n")