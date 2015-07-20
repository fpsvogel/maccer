--[[

remmac.lua
by Felipe Vogel
fps.vogel@gmail.com

Utility tool that removes all flags from all macronized texts.

Copyright 2015 Felipe Vogel. Distributed under the terms of the GNU General Public License.

	This file is part of the Macronizer.

    The Macronizer is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    The Macronizer is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with the Macronizer.  If not, see <http://www.gnu.org/licenses/>.

--]]


package.path = package.path..";../?.lua"	-- because running from a subdirectory
local lfs = require "lfs"
local glue = require "glue"
lfs.chdir("..")		-- to "Macronizer" root folder
local macra = require "scripts.macra"
local utf8 = require "scripts.utf8"		-- from https://github.com/alexander-yakushev/awesompd/blob/master/utf8.lua


local textstbl, filenamestbl = macra.gettexts(macra.DIR_MACRONIZE)	-- all texts to be formatted
for header,text in pairs(textstbl) do
	macra.backup(text, filenamestbl[header], "remove flags")
	text = macra.remflags(text)
	-- write the text to file again
	local textf = io.open(macra.DIR_MACRONIZE..filenamestbl[header], "w")
	textf:write(text)
	textf:close()
end