--[[

clearkey.lua
by Felipe Vogel
fps.vogel@gmail.com

Deletes the contents of key.txt (except for manual entries) and sources.txt.

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
lfs.chdir("..")		-- to "Macronizer" root folder
local macra = require "scripts.macra"
local utf8 = require "scripts.utf8"		-- from https://github.com/alexander-yakushev/awesompd/blob/master/utf8.lua


print("\nDeleting the contents of \"key.txt\" (manual entries excepted) and \"sources.txt\" ...\n")
local keystr = macra.readutf8(macra.DIR_DATA.."key.txt")
local divstart, divend = keystr:find(macra.DIVIDER)
if divstart then keystr = keystr:sub(divend+1) end
local linestart, lineend = keystr:find("[^\t\n]+\t[^\t\n]+\t[^\n]+")
while linestart do
	keystr = keystr:sub(1, linestart-1)..keystr:sub(lineend+2)
	linestart, lineend = keystr:find("[^\t\n]+\t[^\t\n]+\t[^\n]+", linestart)
end
keystr = macra.cleanup(keystr)
local keyf = io.open(macra.DIR_DATA.."key.txt", "w")
keyf:write(macra.bom()..keystr)
keyf:close()
io.open(macra.DIR_DATA.."sources.txt", "w"):close()
print("Done.\n\n")