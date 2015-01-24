(function (window) {
	"use strict";
	
	luatools = 
'function utf8replace (s, mapping) \
   local pos = 1 \
   local bytes = string.len(s) \
   local charbytes \
   local newstr = "" \
   while pos <= bytes do \
	print(pos) \
      charbytes = utf8charbytes(s, pos) \
      local c = string.sub(s, pos, pos + charbytes - 1) \
      newstr = newstr .. (mapping[c] or c) \
      pos = pos + charbytes \
   end \
   return newstr \
end \
function utf8charbytes (s, i) \
   i = i or 1 \
   local c = string.byte(s, i)  \
   if c > 0 and c <= 127 then \
      return 1 \
   elseif c >= 194 and c <= 223 then \
      local c2 = string.byte(s, i + 1) \
      return 2 \
   elseif c >= 224 and c <= 239 then \
      local c2 = s:byte(i + 1) \
      local c3 = s:byte(i + 2) \
      return 3 \
   elseif c >= 240 and c <= 244 then \
      local c2 = s:byte(i + 1) \
      local c3 = s:byte(i + 2) \
      local c4 = s:byte(i + 3) \
      return 4 \
   end \
end \
function hyphens(text) \
	text = text:gsub("a%-","ā"):gsub("e%-","ē"):gsub("i%-","ī"):gsub("o%-","ō"):gsub("u%-","ū"):gsub("y%-","ȳ"):gsub("ã%-","ā"):gsub("ẽ%-","ē"):gsub("ĩ%-","ī"):gsub("õ%-","ō"):gsub("ũ%-","ū"):gsub("ỹ%-","ȳ"):gsub("A%-","Ā"):gsub("E%-","Ē"):gsub("I%-","Ī"):gsub("O%-","Ō"):gsub("U%-","Ū"):gsub("Y%-","Ȳ"):gsub("Ã%-","Ā"):gsub("Ẽ%-","Ē"):gsub("Ĩ%-","Ī"):gsub("Õ%-","Ō"):gsub("Ũ%-","Ū"):gsub("Ỹ%-","Ȳ") \
	return text \
end \
 \
function clearflags(text) \
	local flagstbl =  {["✖"]="", ["✒"]="", ["✪"]="", ["❡"]="", ["☛"]=""} \
	return utf8replace(text, flagstbl) \
end \
 \
function clearmacs(text) \
	local asciitbl = { ["Ã"]="A", ["ã"]="a", ["Õ"]="O", ["õ"]="o", ["Ā"]="A", ["ā"]="a", ["Ē"]="E", ["ē"]="e", ["Ĩ"]="I", ["ĩ"]="i", ["Ī"]="I", ["ī"]="i", ["Ō"]="O", ["ō"]="o", ["Ũ"]="U", ["ũ"]="u", ["Ū"]="U", ["ū"]="u", ["Ȳ"]="Y", ["ȳ"]="y", ["Ẽ"]="E", ["ẽ"]="e", ["Ỹ"]="Y", ["ỹ"]="y" } \
	return utf8replace(text, asciitbl) \
end \
 \
local command, text = ... \
if command == "hyphens" then text = hyphens(text) \
elseif command == "clearflags" then text = clearflags(text) \
elseif command == "clearmacs" then text = clearmacs(text) end \
return text \ ';




	luamacfirst =
'function index(t) \
	local dt={} for k,v in pairs(t) do dt[v]=k end \
	return dt \
end \
 \
function utf8len (s) \
   local pos = 1 \
   local bytes = string.len(s) \
   local len = 0 \
   while pos <= bytes and len ~= chars do \
      local c = string.byte(s,pos) \
      len = len + 1 \
      pos = pos + utf8charbytes(s, pos) \
   end \
   if chars ~= nil then \
      return pos - 1 \
   end \
   return len \
end \
function utf8sub (s, i, j) \
   j = j or -1 \
   if i == nil then \
      return "" \
   end \
   local pos = 1 \
   local bytes = string.len(s) \
   local len = 0 \
   local l = (i >= 0 and j >= 0) or utf8len(s) \
   local startChar = (i >= 0) and i or l + i + 1 \
   local endChar = (j >= 0) and j or l + j + 1 \
   if startChar > endChar then \
      return "" \
   end \
   local startByte, endByte = 1, bytes \
   while pos <= bytes do \
      len = len + 1 \
      if len == startChar then \
	 startByte = pos \
      end \
      pos = pos + utf8charbytes(s, pos) \
      if len == endChar then \
	 endByte = pos - 1 \
	 break \
      end \
   end \
   return string.sub(s, startByte, endByte) \
end \
function utf8replace (s, mapping) \
   local pos = 1 \
   local bytes = string.len(s) \
   local charbytes \
   local newstr = "" \
   while pos <= bytes do \
	print(pos) \
      charbytes = utf8charbytes(s, pos) \
      local c = string.sub(s, pos, pos + charbytes - 1) \
      newstr = newstr .. (mapping[c] or c) \
      pos = pos + charbytes \
   end \
   return newstr \
end \
function utf8charbytes (s, i) \
   i = i or 1 \
   local c = string.byte(s, i)  \
   if c > 0 and c <= 127 then \
      return 1 \
   elseif c >= 194 and c <= 223 then \
      local c2 = string.byte(s, i + 1) \
      return 2 \
   elseif c >= 224 and c <= 239 then \
      local c2 = s:byte(i + 1) \
      local c3 = s:byte(i + 2) \
      return 3 \
   elseif c >= 240 and c <= 244 then \
      local c2 = s:byte(i + 1) \
      local c3 = s:byte(i + 2) \
      local c4 = s:byte(i + 3) \
      return 4 \
   end \
end \
 \
function ignorechars(w, wstart, wend, ignoretbl, abbrevcheck) \
	if abbrevcheck == nil then abbrevcheck = true end \
	local first = w:sub(1,1) \
	while first == "."  do \
		w = w:sub(2) \
		wstart = wstart + 1 \
		if wstart > wend then wend = wstart end \
		first = w:sub(1,1) \
	end \
	if dotstart and dotstart ~= 1 and dotstart ~= #w then \
		w = split(w, "%.")[1].."." \
		wend = wstart + #w - 1 \
	end \
	if w:sub(#w) == "." then \
		local utf8len = utf8len(w) \
		if ignoretbl[utf8sub(w, utf8len-1, utf8len-1)] then \
			w = w:sub(1, #w-1) \
			wend = wend - 1 \
		end \
	end \
	if w == "." then end \
	local posright, userignore, userabbrev, middlefound, isabbrev = utf8len(w), false, false, false, false \
	if not wstart then wstart = 1 end \
	if not wend then wend = utf8len(w) end \
	if w ~= "" then \
		repeat \
			local goodstart, goodend = true, true \
			local leftchar, rightchar = utf8sub(w, 1, 1), utf8sub(w, posright, posright) \
			if ignoretbl[leftchar] then \
				w = utf8sub(w, 2) \
				local leftcharlen = #leftchar \
				wstart = wstart + leftcharlen \
				posright = posright - 1 \
				goodstart = false \
				if leftchar == USER_IGNORE then userignore = true \
				elseif leftchar == USER_ABBREV then userabbrev = true end \
			end \
			if ignoretbl[rightchar] then \
				w = utf8sub(w, 1, posright - 1) \
				wend = wend - #rightchar \
				goodend = false \
			end \
			if not goodend then posright = posright - 1 end \
			if posright < 1 then w = nil end \
		until (goodstart and goodend) or not w \
		if w then \
			for ig,_ in pairs(ignoretbl) do \
				if not userignore and not middlefound then \
					if w:find(ig) then middlefound = true end \
				end \
			end \
			if abbrevcheck then \
				local wlen = #w \
				if userabbrev then \
					if w:sub(wlen) ~= "." then w = w.."." end \
					isabbrev = true \
				elseif w:sub(wlen) == "." then \
					local firstchar, autoabbrev = utf8sub(w, 1,1), false \
					if capsinvtbl[firstchar] and not middlefound then \
						autoabbrev = true \
						isabbrev = true \
					else \
						w = w:sub(1, wlen - 1) \
						wend = wend - 1 \
					end \
				end \
			end \
		end \
	end \
	return w, wstart, wend, userignore, middlefound, isabbrev \
end \
function subword(w, origtbl, repltbl, modtbl, includedoubtful, prevdsubw, prevdsubatpostbl) \
	if includedoubtful == nil then includedoubtful = true end \
	local i, subw, subatpostbl, subbed = 1, w, {}, false \
	while subw and i <= #repltbl do \
		local findstart = 1 \
		repeat \
			local replstart, replend = subw:find(origtbl[i], findstart) \
			local nexti = false \
			if replstart and issubvalid(subw, modtbl[i], replstart, replend, subbed) then \
				if includedoubtful or not (modtbl[i] or ""):find(DOUBT_CHAR) then \
					local newsubw, prevdsubi = subw:sub(1, replstart-1)..repltbl[i]..subw:sub(replend+1), nil \
					if prevdsubatpostbl then \
						prevdsubi = prevdsubatpostbl[replstart] \
						if not prevdsubi then \
							local j, dlen = 1, utf8len(prevdsubw) \
							while not prevdsubi and j <= dlen do \
								local trysubi = prevdsubatpostbl[j] \
								if (modtbl[trysubi] or ""):find(DOUBT_CHAR) then prevdsubi = trysubi end \
								j = j + 1 \
							end \
						end \
					end \
					if not prevdsubw or ((prevdsubw or "") ~= newsubw and (prevdsubi or i+1) < i) then \
						subatpostbl[replstart] = i \
						subw = newsubw \
						subbed = true \
					end \
				end \
				findstart = replend + 1 \
			else nexti = true end \
		until nexti \
		i = i + 1 \
	end \
	if subw == w then subatpostbl = {} end \
	return subw, subatpostbl \
end \
function issubvalid(w, modstr, replstart, replend, subbed) \
	local matches, encliticmatch = nil, nil \
	if not modstr or (modstr or "") == DOUBT_CHAR then return true \
	else \
		if modstr:find("%"..NO_CHAIN) then \
			matches = not subbed end \
		if modstr:find("%"..LEFT_BEGIN) and matches ~= false then \
			matches = replstart == 1 and true or false \
		elseif modstr:find(LEFT_CONTINUE) then \
			matches = replstart > 1 and true or false \
		end \
		if modstr:find("%"..RIGHT_END) and matches ~= false then \
				if replend == #w then matches = true \
				else \
					for enc,_ in pairs(enclitictbl) do \
						if not encliticmatch then \
							if w:sub(#w-#enc+1) == enclitic then encliticmatch = enc end \
						end \
					end \
					matches = (encliticmatch and (replend + #encliticmatch == #w)) and true or false \
				end \
		elseif modstr:find(RIGHT_CONTINUE) and matches ~= false then \
			matches = replend < #w and true or false \
		end \
	end \
	return matches, (encliticmatch ~= nil and true or false) \
end \
function getpars(plainw, keytbl) \
	local parw0 = keytbl[plainw] \
	if not parw0 then return nil end \
	local parwtbl, parnum, plainwkey, parw = {}, 0, plainw, parw0 \
	repeat \
		parwtbl[parw] = plainwkey \
		parnum = parnum + 1 \
		plainwkey = plainw..parnum \
		parw = keytbl[plainwkey] \
	until not parw \
	return parwtbl, parnum, plainwkey \
end \
function getcommentset(text) \
	local commentstbl = {} \
	local cstart, cend = text:find(COMMENT) \
	while cstart do \
		for p = cstart,cend do commentstbl[p] = true end \
		cstart, cend = text:find(COMMENT, cend+1) \
	end \
	cstart, cend = text:find(COMMENT_MULTI) \
	while cstart do \
		for p = cstart,cend do commentstbl[p] = true end \
		cstart, cend = text:find(COMMENT_MULTI, cend+1) \
	end \
	return commentstbl \
end \
function throwerror(errormsg) \
 \
end \
 \
local LETTERS = "[^\x5Ct\x5Cn%s%d%!%\x5C"%#%$%%%&%\x5Cx27%(%)%*%+%,%-%/%:%;%<%=%>%?%@%[%\x5C\x5C%]%^%_%`%{%|%}%~]+" \
local NOTFOUND, AMBIG, GUESS, AFFIX, INVALID = "✖", "✒", "✪", "❡", "☛" \
USER_IGNORE, NO_CHAIN, DOUBT_CHAR, LEFT_BEGIN, LEFT_CONTINUE, RIGHT_END, RIGHT_CONTINUE = "≠", "*", "~", "[", "<", "]", ">" \
COMMENT, COMMENT_MULTI = "//([^\x5Cn]+)", "/%*(.*)%*/" \
local GUESS_THRESHOLD, SHORT, LONG, EITHER = 0.75, 0, 1, 2';



	luamaclast =
'local macroninvtbl = { ["ō"]="o", ["ū"]="u", ["ā"]="a", ["ȳ"]="y", ["ē"]="e", ["ī"]="i" } \
local macrontbl = { ["i"]="ī", ["o"]="ō", ["u"]="ū", ["y"]="ȳ", ["a"]="ā", ["e"]="ē" } \
local tildetbl = { ["o"]="õ", ["i"]="ĩ", ["a"]="ã", ["u"]="ũ", ["y"]="ỹ", ["e"]="ẽ" } \
local capsinvtbl = { ["B"]="b", ["Õ"]="õ", ["Ỹ"]="ỹ", ["D"]="d", ["E"]="e", ["T"]="t", ["Ō"]="ō", ["N"]="n", ["G"]="g", ["W"]="w", ["Ā"]="ā", ["H"]="h", ["Ĩ"]="ĩ", ["I"]="i", ["F"]="f", ["Ã"]="ã", ["Ũ"]="ũ", ["V"]="v", ["K"]="k", ["J"]="j", ["Ū"]="ū", ["Ȳ"]="ȳ", ["Ī"]="ī", ["M"]="m", ["O"]="o", ["R"]="r", ["Y"]="y", ["U"]="u", ["A"]="a", ["P"]="p", ["Ē"]="ē", ["L"]="l", ["Q"]="q", ["X"]="x", ["Ẽ"]="ẽ", ["Z"]="z", ["C"]="c", ["S"]="s" } \
local capstbl = { ["ã"]="Ã", ["c"]="C", ["b"]="B", ["ō"]="Ō", ["s"]="S", ["d"]="D", ["e"]="E", ["t"]="T", ["u"]="U", ["ỹ"]="Ỹ", ["g"]="G", ["w"]="W", ["ũ"]="Ũ", ["h"]="H", ["ā"]="Ā", ["i"]="I", ["ĩ"]="Ĩ", ["y"]="Y", ["v"]="V", ["ī"]="Ī", ["k"]="K", ["j"]="J", ["l"]="L", ["m"]="M", ["z"]="Z", ["ẽ"]="Ẽ", ["x"]="X", ["q"]="Q", ["f"]="F", ["õ"]="Õ", ["o"]="O", ["ē"]="Ē", ["ū"]="Ū", ["ȳ"]="Ȳ", ["n"]="N", ["r"]="R", ["a"]="A", ["p"]="P" } \
local ignoretbl = { ["≠"]=true, ["•"]=true, ["›"]=true, ["»"]=true, ["✪"]=true, ["•"]=true, ["«"]=true, ["”"]=true, ["‹"]=true, ["☛"]=true, ["–"]=true, ["“"]=true, ["’"]=true, ["✒"]=true, ["‘"]=true, ["❡"]=true, ["—"]=true, ["†"]=true, ["±"]=true, ["✖"]=true } \
local enclitictbl = { ["ve"]=true, ["ne"]=false, ["que"]=true } \
local prefixtbl = { "abs", "ab", "ac", "ad", "aedi", "aequi", "af", "ag", "alti", "ambi", "amb", "amphi", "am", "ante", "anti", "an", "ap", "archi", "as", "at", "auri", "au", "a", "bene", "beni", "bis", "bi", "blandi", "cardio", "centi", "centu", "circum", "col", "com", "conn", "contra", "con", "co", "decem", "decu", "de", "dif", "dir", "dis", "di", "duode", "duoet", "du", "ef", "electro", "extra", "ex", "e", "inaequi", "inter", "intra", "intro", "ig", "il", "im", "in", "ir", "male", "multi", "ne", "non", "ob", "octu", "of", "omni", "op", "os", "per", "por", "praeter", "prae", "pro", "pseudo", "quadri", "quadru", "quincu", "quinqu", "quinti", "red", "re", "sed", "semi", "septem", "septu", "sesque", "sesqui", "sexqui", "ses", "sexti", "sextu", "sex", "se", "sim", "sub", "suc", "super", "supra", "superquadri", "sur", "sus", "trans", "tra", "tre", "tri", "ultra", "unde", "uni", "ve" } \
local prefixmactbl = { ["quinqu"]="quīnqu", ["quincu"]="quīncu", ["non"]="nōn", ["pro"]="prō", ["de"]="dē", ["di"]="dī", ["uni"]="ūni", ["quinti"]="quīnti", ["a"]="ā", ["e"]="ē" } \
local orthorigtbl = { "Ă", "Ĕ", "Ĭ", "Ŏ", "Ŭ", "ă", "ĕ", "ĭ", "ŏ", "ŭ", "ë", "abu_", "adu_", "circumu_", "conu_", "disu_", "exu_", "interu_", "inu_", "obu_", "peru_", "praeteru_", "septemu_", "sexu_", "subu_", "superu_", "transu", "adc", "adg", "adp", "adt", "conb", "conp", "conm", "conl", "conr", "connect", "connex", "conniv", "connīt", "connīs", "connīx", "connūbi", "inp", "inb", "inm", "obc", "obf", "obp", "subc", "subf", "subg", "subp", "disr", "disv", "disf", "exf", "exv", "quu", "ex", "oe", "oe", "ae", "ae", "coel", "foen", "j", "quum", "iui", "iuu", "iuy", "iuȳ", "iuī", "iuo", "iuū", "iuō", "iue", "iua", "iuā", "uui", "uuu", "uuy", "uuȳ", "uuī", "uuo", "uuū", "uuō", "uue", "uua", "uuā", "yui", "yuu", "yuy", "yuȳ", "yuī", "yuo", "yuū", "yuō", "yue", "yua", "yuā", "ȳui", "ȳuu", "ȳuy", "ȳuȳ", "ȳuī", "ȳuo", "ȳuū", "ȳuō", "ȳue", "ȳua", "ȳuā", "īui", "īuu", "īuy", "īuȳ", "īuī", "īuo", "īuū", "īuō", "īue", "īua", "īuā", "oui", "ouu", "ouy", "ouȳ", "ouī", "ouo", "ouū", "ouō", "oue", "oua", "ouā", "ūui", "ūuu", "ūuy", "ūuȳ", "ūuī", "ūuo", "ūuū", "ūuō", "ūue", "ūua", "ūuā", "ōui", "ōuu", "ōuy", "ōuȳ", "ōuī", "ōuo", "ōuū", "ōuō", "ōue", "ōua", "ōuā", "eui", "euu", "euy", "euȳ", "euī", "euo", "euū", "euō", "eue", "eua", "euā", "aui", "auu", "auy", "auȳ", "auī", "auo", "auū", "auō", "aue", "aua", "auā", "āui", "āuu", "āuy", "āuȳ", "āuī", "āuo", "āuū", "āuō", "āue", "āua", "āuā" } \
local orthrepltbl = { "a", "e", "i", "o", "u", "a", "e", "i", "o", "u", "ē", "abv_", "adv_", "circumv_", "conv_", "disv_", "exv_", "interv_", "inv_", "obv_", "perv_", "praeterv_", "septemv_", "sexv_", "subv_", "superv_", "transv_", "acc", "agg", "app", "att", "comb", "comp", "comm", "coll", "corr", "cōnect", "cōnex", "cōniv", "cōnīt", "cōnīs", "cōnīx", "cōnūbi", "imp", "imb", "imm", "occ", "off", "opp", "succ", "suff", "sugg", "supp", "dī", "dīv", "diff", "eff", "ēv", "cu", "exs", "ae", "ē", "oe", "ē", "cael", "faen", "i", "cum", "ivi", "ivu", "ivy", "ivȳ", "ivī", "ivo", "ivū", "ivō", "ive", "iva", "ivā", "uvi", "uvu", "uvy", "uvȳ", "uvī", "uvo", "uvū", "uvō", "uve", "uva", "uvā", "yvi", "yvu", "yvy", "yvȳ", "yvī", "yvo", "yvū", "yvō", "yve", "yva", "yvā", "ȳvi", "ȳvu", "ȳvy", "ȳvȳ", "ȳvī", "ȳvo", "ȳvū", "ȳvō", "ȳve", "ȳva", "ȳvā", "īvi", "īvu", "īvy", "īvȳ", "īvī", "īvo", "īvū", "īvō", "īve", "īva", "īvā", "ovi", "ovu", "ovy", "ovȳ", "ovī", "ovo", "ovū", "ovō", "ove", "ova", "ovā", "ūvi", "ūvu", "ūvy", "ūvȳ", "ūvī", "ūvo", "ūvū", "ūvō", "ūve", "ūva", "ūvā", "ōvi", "ōvu", "ōvy", "ōvȳ", "ōvī", "ōvo", "ōvū", "ōvō", "ōve", "ōva", "ōvā", "evi", "evu", "evy", "evȳ", "evī", "evo", "evū", "evō", "eve", "eva", "evā", "avi", "avu", "avy", "avȳ", "avī", "avo", "avū", "avō", "ave", "ava", "avā", "āvi", "āvu", "āvy", "āvȳ", "āvī", "āvo", "āvū", "āvō", "āve", "āva", "āvā" } \
local orthmodtbl = { [28]=">", [29]=">", [30]=">", [31]=">", [32]=">", [33]=">", [34]=">", [35]=">", [36]=">", [44]=">", [45]=">", [46]=">", [47]=">", [48]=">", [49]=">", [50]=">", [51]=">", [52]=">", [53]=">", [54]=">", [55]=">", [56]=">", [57]=">", [58]=">", [59]="~", [60]=">~", [61]="~", [62]="~", [63]="*~", [64]="*~", [68]="[]" } \
local vowels = {["a"]=true, ["e"]=true, ["i"]=true, ["o"]=true, ["u"]=true, ["y"]=true, ["ā"]=true, ["ā"]=true, ["ī"]=true, ["ō"]=true, ["ū"]=true, ["ȳ"]=true} \
for left,_ in pairs(vowels) do \
	for right,_ in pairs(vowels) do \
		table.insert(orthorigtbl, left.."u"..right) \
		table.insert(orthrepltbl, left.."v"..right) \
	end \
end \
 \
function macronize(text) \
	local hascomments = text:find(COMMENT) or text:find(COMMENT_MULTI) \
	local commentstbl = hascomments and getcommentset(text) or nil \
	local wstart, wend = text:find(LETTERS) \
	while wstart do \
		if hascomments then commentstbl = getcommentset(text) end \
		if not hascomments or not commentstbl[wstart] then \
			local w, userignore, isinvalid, periodremoved = text:sub(wstart, wend), false, false, false \
			w, wstart, wend, userignore, isinvalid = ignorechars(w, wstart, wend, ignoretbl, false) \
			local finalw, flagstbl = w, {} \
			local plainw, flags = w, nil \
			if not userignore and w and w ~= "" then \
				if isinvalid then flagstbl[INVALID] = true \
				else \
					local cappostbl = {} \
					for pos = 1,utf8len(w) do \
						local pchar = utf8sub(w, pos, pos) \
						if capsinvtbl[pchar] then table.insert(cappostbl, pos) end \
					end \
					local wlower = utf8replace(w, capsinvtbl) \
					local suresubw, suresubatpostbl = subword(wlower, orthorigtbl, orthrepltbl, orthmodtbl, false) \
					suresubw = utf8replace(suresubw, macroninvtbl) \
					local doubtsubw, doubtsubatpostbl = nil, nil \
					local isapplied, isnotfound, enclitic, prefix = false, false, nil, nil \
					local wende, wstartp = nil, nil \
					local subatpostbl = suresubatpostbl \
					local triedenclitics, triedprefixes, triedencliticstwice, tryingabbrev, trieddoubtsub = false, false, false, false, false, false \
					plainw = suresubw \
					local plainwtry = plainw \
					while not isapplied and not isnotfound do \
						local macronw = keytbl[plainwtry] \
						if macronw then \
								local guessw, ambigw = nil, nil \
								local partbl, parcount = getpars(plainwtry, keytbl) \
								if parcount > 1 then \
									local topparw, topfreq, totalfreq = nil, 0, 0 \
									for parw,plainwkey in pairs(partbl) do \
										local freq = freqtbl[parw] or 0 \
										if not topparw or freq > topfreq then \
											topparw, topfreq = parw, freq \
										end \
										totalfreq = totalfreq + freq \
									end \
									if totalfreq > 0 and topfreq / totalfreq >= GUESS_THRESHOLD then guessw = topparw \
									else \
										ambigw = plainwtry \
										for pos = 1,utf8len(plainwtry) do \
											local letter = utf8sub(plainwtry, pos, pos) \
											local tildevowel = tildetbl[letter] \
											if tildevowel then \
												local length, parlength, firstlength = 0, 0, nil \
												for parw,_ in pairs(partbl) do \
													if length ~= EITHER then \
														parlength = macroninvtbl[utf8sub(parw, pos, pos)] and LONG or SHORT \
														if not firstlength then length, firstlength = parlength, parlength end \
														if parlength ~= firstlength then length = EITHER end \
													end \
												end \
												if length == EITHER then \
													ambigw = utf8sub(ambigw, 1, pos-1)..tildevowel..utf8sub(ambigw, pos+1) \
												elseif length == LONG then \
													ambigw = utf8sub(ambigw, 1, pos-1)..macrontbl[letter]..utf8sub(ambigw, pos+1) \
												end \
											end \
										end \
									end \
								end \
								finalw = (prefix or "")..((guessw or ambigw) or macronw)..(enclitic or "") \
								for pos = utf8len(finalw),1,-1 do \
									if subatpostbl[pos] then \
										local origstr, replstr = orthorigtbl[subatpostbl[pos]], orthrepltbl[subatpostbl[pos]] \
										local origlen, repllen = utf8len(origstr), utf8len(replstr) \
										local macreplstr, macorigstr = utf8sub(finalw, pos, pos-1+repllen), nil \
										if macreplstr ~= replstr then \
											if not orthreplinvtbl then orthreplinvtbl = index(orthrepltbl) end \
											local macorigindex = orthreplinvtbl[macreplstr] \
											macorigstr = macorigindex and orthorigtbl[macorigindex] or nil \
											if not macorigstr then \
												throwerror("No macronized original form found for \x5C""..macreplstr.."\x5C" after the substitution \x5C""..origstr.."\x5C" -> \x5C""..replstr.."\x5C", for the word \x5C""..macs2hats(finalw).."\x5C". See \x5C"substitute.txt\x5C".") \
												macorigstr = origstr \
											end \
										else macorigstr = origstr end \
										finalw = utf8sub(finalw, 1, pos-1)..macorigstr..utf8sub(finalw, pos+repllen) \
									end \
								end \
								for _,pos in pairs(cappostbl) do \
									finalw = utf8sub(finalw, 1, pos-1)..capstbl[utf8sub(finalw, pos, pos)]..utf8sub(finalw, pos+1) \
								end \
								if enclitic or prefix then flagstbl[AFFIX] = true end \
								if guessw then flagstbl[GUESS] = true \
								elseif ambigw then flagstbl[AMBIG] = true end \
								isapplied = true \
						elseif not triedenclitics then \
							if not enclitic then \
								for enc,_ in pairs(enclitictbl) do \
									if plainwtry:sub(#plainwtry-#enc+1) == enc then \
										plainwtry = plainwtry:sub(1, #plainwtry-#enc) \
										enclitic = enc \
										break \
									end \
								end \
								triedenclitics = true \
							else \
								plainwtry = plainwtry:sub(1, #plainwtry-#enclitic) \
								triedenclitics = true \
							end \
						elseif not triedprefixes then \
							for _,pfplain in pairs(prefixtbl) do \
								if plainw:sub(1, #pfplain) == pfplain then \
									plainwtry = plainw:sub(#pfplain+1) \
									prefix = prefixmactbl[pfplain] or pfplain \
									break \
								end \
							end \
							triedprefixes = true \
						elseif triedprefixes and enclitic and prefix and not triedencliticstwice then \
							triedenclitics = false \
							triedencliticstwice = true \
						else \
							if plainw:sub(#plainw) == "." then \
								plainw = plainw:sub(1, #plainw-1) \
								plainwtry = plainw \
								periodremoved = true \
								triedenclitics, triedprefixes, triedencliticstwice = false, false, false \
								enclitic, prefix, wende, wstartp = nil, nil, nil, nil \
							else \
								periodremoved = false \
								local prevdoubtsubw = doubtsubw \
								doubtsubw, doubtsubatpostbl = subword(wlower, orthorigtbl, orthrepltbl, orthmodtbl, true, doubtsubw, doubtsubatpostbl) \
								doubtsubw = utf8replace(doubtsubw, macroninvtbl) \
								if doubtsubw ~= suresubw and doubtsubw ~= prevdoubtsubw then \
									plainw = doubtsubw \
									plainwtry = plainw \
									subatpostbl = doubtsubatpostbl \
									triedenclitics, triedprefixes, triedencliticstwice = false, false, false \
									enclitic, prefix, wende, wstartp = nil, nil, nil, nil \
								else isnotfound = true end \
							end \
						end \
					end \
					if isnotfound then flagstbl[NOTFOUND] = true end \
				end \
				local flagstr = "" \
				for flag,_ in pairs(flagstbl) do \
					flagstr = flagstr..flag \
				end \
				local periodchar = periodremoved and 1 or 0 \
				text = text:sub(1, wstart-1)..flagstr..finalw..text:sub(wend+1-periodchar) \
				wend = wend + #flagstr \
				local lendiff = #finalw - #w + periodchar \
				if lendiff > 0 then wend = wend + lendiff end \
			end \
		end \
		wstart, wend = text:find(LETTERS, wend+1) \
	end \
	return text \
end \
\
function clearflags(text) \
	local flagstbl =  {[NOTFOUND]="", [AMBIG]="", [GUESS]="", [AFFIX]="", [INVALID]=""} \
	return utf8replace(text, flagstbl) \
end \
\
local text = ... \
return macronize(clearflags(text)) \ ';
	
}(window));
