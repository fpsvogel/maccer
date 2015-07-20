--[[

exmac.lua
by Felipe Vogel
fps.vogel@gmail.com

Exmacronize. Word key builder for Maccer. Extracts new word forms from texts and adds them to the key.

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


-- results table (to be logged)
FILENAME = 1
NEW = 2			-- new words
NEWCOUNT = 3
AMBIGS = 4		-- new ambiguous words
AMBIGCOUNT = 5
SUBS = 6		-- orthographic substitutions applied (note: those in "orthography.txt" marked with macra.DOUBT_CHAR are not tried; they are used by Macronize in guessing alternative spellings to find matches)
INVALIDMIDDLE = 7	-- words with invalid (ignore) characters in the middle (which characters are NOT removed)
ABBREVS = 8		-- abbreviations (i.e. capitalized and followed by a period, or marked with macra.USER_ABBREV)
local results = {}
for i = 1,8 do results[i] = {} end

-- initialize script-wide data
local logf, backupkeystr = macra.initialize("exmacronize", true)	-- back up below only if new sources are found


--[[returns:
	- an expanded keytbl,
	- a table of new forms (newtbl[plainword]==macronword),
	- the number of new forms,
	- a table of new ambiguous forms (ambigs[macronword]==parallels). --]]
function exmacronize(text, header)
	local newtbl, newcount, ambigtbl, ambigcount = {}, 0, nil, 0
	for w in text:gmatch(macra.LETTERS) do	-- each word, excluding whitespace characters, in original Unicode form
		local plainw = utf8.replace(w, macra.macroninvtbl)	-- ASCII word
		local partbl, parcount, nextplainwkey = macra.getpars(plainw)
		if not partbl then		-- if new form with no parallels already in the key
			macra.keytbl[plainw] = w
			macra.freqtbl[w] = 1
			macra.headerstbl[w] = {[header] = true}
			newtbl[plainw], newcount = w, newcount + 1
		else	-- one or more parallels exist, so find out whether this is a new one
			local isduplicate = false
			for parw,plainwkey in pairs(partbl) do
				if w == parw then isduplicate = true end
			end
			if not isduplicate then	-- if this macron-form is new, add it and save its parallels for later logging
				local parstr = ""
				for parw,plainwkey in pairs(partbl) do
					parstr = parstr..", "..parw
				end
				parstr = parstr:sub(3)	-- remove leading comma and space
				ambigtbl = {}
				ambigtbl[w] = parstr
				macra.keytbl[nextplainwkey] = w
				macra.freqtbl[w] = 1
				macra.headerstbl[w] = {[header] = true}
				newtbl[nextplainwkey], ambigcount, newcount = w, ambigcount + 1, newcount + 1
			else	-- this word form already exists, so simply increase its frequency by 1 and add the header
				macra.freqtbl[w] = macra.freqtbl[w] + 1
				macra.headerstbl[w][header] = true
			end
		end
	end
	return keytbl, newtbl, newcount, ambigtbl, ambigcount
end


-- removes bad elements (comments, uppercase, words with invalid characters) from the text, makes orthographic substitutions, and detects abbreviations
-- returns the changed text and tables of substitutions, invalid words, and abbreviations.
function formatsource(text, header)
	text = macra.decomment(text)
	local invalidtbl, substbl, abbrevtbl = {}, {}, {}
	local wstart, wend = text:find(macra.LETTERS)
	while wstart do
		local w, wstartnew, wendnew, invalidmiddle, isabbrev = macra.ignorechars(text:sub(wstart,wend), wstart, wend)
		if w and not invalidmiddle then
			w = utf8.replace(w, macra.capsinvtbl)	-- to lowercase
			if wstartnew ~= wstart or wendnew ~= wend then	-- remove the invalid leading and ending characters from the text
				text = text:sub(1, wstart-1)..text:sub(wstartnew, wendnew)..text:sub(wend+1)
				wend = wendnew - (wstartnew - wstart)
			end 
			if not macra.REPAIR_ORTH then	-- see _CONFIG.txt
				local suresubw = macra.subword(w, macra.orthorigtbl, macra.orthrepltbl, macra.orthmodtbl, false)
				if suresubw and suresubw ~= w then
					text = text:sub(1, wstart-1)..suresubw..text:sub(wend+1)
					wend = wend + (#suresubw - #w)
					substbl[w] = suresubw
					w = suresubw
				else text = text:sub(1, wstart-1)..w..text:sub(wend+1) end	-- no substtitution: insert lowercase w into text
			else text = text:sub(1, wstart-1)..w..text:sub(wend+1) end	-- no orthog. changes: insert lowercase w into text
			if isabbrev then abbrevtbl[macra.utf8capitalize(w)] = true end
		else	-- this word is only invalid characters, or contains them, so remove it from consideration
			if invalidmiddle then table.insert(invalidtbl, w) end
			text = text:sub(1, wstart-1)..text:sub(wend+1)
			wend = wstart - 1
		end
		wstart, wend = text:find(macra.LETTERS, wend+1)
	end
	return text, substbl, invalidtbl, abbrevtbl
end


--===========  S T A R T  =================================================

-- get the names of sources previously processed
local oldsourcestbl = {}
for l in glue.gsplit(macra.readutf8(macra.DIR_DATA.."sources.txt"), "\n") do
	local header, filename = l:match("([^\t]+)\t([^\t]+)")
	if header then oldsourcestbl[header] = filename end
end
local newsourcestbl, filenamestbl, sourcecount = macra.gettexts(macra.DIR_SOURCES, oldsourcestbl)
if sourcecount == 0 then
	print("\nNo new source texts found in \""..macra.DIR_SOURCES.."\".\n")
	logf:write("No new source texts found in \""..macra.DIR_SOURCES.."\".\n")
else
	macra.backup(backupkeystr, "key", "exmacronize")
	print("\n"..sourcecount.." new source "..(sourcecount > 1 and "texts" or "text").." found from which word forms will be learned.")
	results[FILENAME] = filenamestbl
	macra.backup(macra.readutf8(macra.DIR_DATA.."key.txt"), "key", "ex-macronize")
	-- make a set of the old sources' headers, to compare with the new sources and avoid duplicates in key.txt
	local existingheaderstbl = {}
	for _,header in pairs(macra.headersbynumtbl) do
		existingheaderstbl[header] = true
	end
	-- extract existing key, then pass it to the exmacronize function for each new source
	local curfilenum, curheadernum, newtotal, ambigtotal, invalidtotal = 0, #macra.headersbynumtbl + 1, 0,0,0
	for header,text in glue.sortedpairs(newsourcestbl) do
		curfilenum = curfilenum + 1
		print("\nExmacronizing \""..macra.macs2ascii(header).."\" ("..curfilenum.." of "..sourcecount..")...\n")
		text, results[SUBS][header], results[INVALIDMIDDLE][header], results[ABBREVS][header] = formatsource(text, header)
		keytbl, results[NEW][header], results[NEWCOUNT][header], results[AMBIGS][header], results[AMBIGCOUNT][header] = exmacronize(text, header)
		if results[NEWCOUNT][header] > 0 and not existingheaderstbl[header] then
			macra.headersbynumtbl[curheadernum] =  header
			curheadernum = curheadernum + 1
		end
		newtotal = newtotal + results[NEWCOUNT][header]
		ambigtotal = ambigtotal + results[AMBIGCOUNT][header]
		invalidtotal = invalidtotal + #results[INVALIDMIDDLE][header]
	end
	local formstotal = macra.savekey()	-- write key to file, store total number of forms for logging
	-- add the new texts to the sources list, so that next time they won't be processed again
	sourcesf = io.open(macra.DIR_DATA.."sources.txt", "w")
	sourcesf:write(macra.bom())
	sourcesf:write("// SOURCE LIST\n\n// [source header]\t[filename]\n// If you have manually changed a source text and would like to Exmacronize it again, delete the appropriate line in this file before Exmacronizing.\n// To Exmacronize all source texts again (i.e. re-build the key), delete this file before Exmacronizing.\n\n")
	local sources = glue.merge(oldsourcestbl, results[FILENAME])
	for header,filename in glue.sortedpairs(sources) do
		sourcesf:write(header.."\t"..filename.."\n")
	end
	-- write to the log
	logf:write("#### SUMMARY ####\n")
	logf:write("\nProcessed "..sourcecount.." new file(s) in \""..macra.DIR_SOURCES.."\".\n"..newtotal.." new forms added, "..ambigtotal.." of these ambiguous.\n"..invalidtotal.." words skipped containing invalid characters.\n"..formstotal.." forms total now in the key.\n")
	for header,filename in glue.sortedpairs(results[FILENAME]) do
		logf:write("\n\""..header.."\"\n    File: \""..filename.."\"\n    "..results[NEWCOUNT][header].." new forms, "..results[AMBIGCOUNT][header].." of these ambiguous.\n")
		if #results[INVALIDMIDDLE][header] > 0 then
			logf:write("\n    Words containing invalid characters:\n")
			for _,invmid in glue.sortedpairs(results[INVALIDMIDDLE][header]) do logf:write("\t"..invmid.."\n") end
		end
		local abbrevheaderwritten = false
		for abbrev,_ in glue.sortedpairs(results[ABBREVS][header]) do
			if not abbrevheaderwritten then
				logf:write("\n    Possible abbreviations (fix with Analyze/Repair Key):\n")
				abbrevheaderwritten = true
			end
			logf:write("\t"..abbrev.."\n")
		end
		if not macra.REPAIR_ORTH then
			local orthheaderwritten = false
			for origw,subw in glue.sortedpairs(results[SUBS][header]) do
				if not orthheaderwritten then
					logf:write("\n    Orthographic substitutions:\n")
					orthheaderwritten = true
				end
				logf:write("\t"..origw.." -> "..subw.."\n")
			end
		end
		if results[AMBIGS][header] then
			logf:write("\n    Ambiguous new forms (fix with Analyze/Repair Key):\n")
			for macronw,equivstr in glue.sortedpairs(results[AMBIGS][header]) do
				logf:write("\t"..macronw.." ("..equivstr..")\n")
			end
		end
	end
	logf:write("\n\n#### ALL NEW FORMS ####\n")
	for header,newtbl in glue.sortedpairs(results[NEW]) do
		logf:write("\nFrom \""..header.."\":\n")
		for _,macronw in glue.sortedpairs(newtbl) do logf:write("    "..macronw.."\n") end
	end
end

logf:write("\nEnd of log.")
logf:close()

print("\nDone.\n\n\"key.txt\" updated. See log file in \""..macra.DIR_LOGS.."\" for details.\n\n")