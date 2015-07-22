Maccer
------
A tool for macronizing Latin text
by Felipe Vogel  
fps.vogel@gmail.com  
version 1.0.0 (July 20, 2015)  
web version: http://fps-vogel.github.io/maccer/

Copyright 2015 Felipe Vogel. Copyright of source texts belongs to their respective owners. Distributed under the terms of the GNU General Public License. See Lua source files and COPYING.txt for license details.

**WARNING:** Maccer has been tested very little and is probably not user-friendly, but since it is as complete I set out to make it, I do not plan on continuing active development aside from fixing bugs. Please report bugs at https://github.com/fps-vogel/maccer/issues.

News
----
- 20 July 2015: v1.0.0 released.
- 13 Jan. 2015: Thanks to Dr. Chris Francese for reviewing the web version of Maccer at the [Dickinson College Commentaries blog](http://blogs.dickinson.edu/dcc/2015/01/13/a-new-latin-macronizer/).

Introduction
------------
Maccer is a tool for macronizing Latin texts. The following are its functions, each of which can be run via an executable .bat file found in the Maccer root folder.

*NOTE: These .bat files run in Windows only. Theoretically the scripts can be run under Linux/OS X by executing `luapower/luajit ../scripts/X.lua` from the Maccer root folder, where X is the script name. When in doubt about the script name, check the .bat file.*

- **Exmacronize:** The "learning" function. Builds a word key by analyzing texts with macrons already. The word key is a list of unique word forms with macrons, along with their frequencies.
- **Analyze Key:** Detects possible errors in the word key, and saves them for user review and correction.
- **Repair Key:** Fixes errors in the word key and its source texts, based on user-corrected output of Analyze Key.
- **Macronize:** The primary function. Using the word key, adds macrons to plain text, or guesses where possible, flagging uncertain or unknown words for user review.
- *utility functions (`util - [name].bat`):*
  - **Hyphens to Macrons:** Replaces vowels followed by a macron to that vowel with a macron, e.g. "a-" → "ā".
  - **Remove Flags**
  - **Remove Macrons**
  - **Clear Key:** Removes all non-manually-entered entries (i.e. all entries from source texts) from the word key, and removes all entries in the source list (`data/sources.txt`).
  - **Clear backup and logs**

The three formatting functions (the first three utility functions above) apply to all texts in the `macronize/` folder.

Macronizing a text
------------------
1. Copy plain Latin text(s) (in .txt format) into the `macronize/` folder.
2. Run `macronize.bat`. This adds macrons and flags to all texts in `macronize/`. A backup file of each text is created in `backup/`.
  - To exclude any words that should not be macronized, e.g. a passage in another language, use C-style comments: // at the beginning of a line to excludes that line, and /*...*/ excludes everything (...) in between.
3. Manually correct the text(s). See the table below for the meaning of each flag.
  - Add missing macrons either using a special keyboard or via the following method:
    1. Replace all hyphens following a vowel in all texts in `macronize/` with "\-". This prevents intended hyphens from becoming macrons in step 3 below.
	2. Insert a hyphen after each vowel to be marked with a macron.
	3. Run `util - hyphens to macrons.bat`. Backslashes before hyphens (placed in step 1) are automatically removed.
  - After corrections, run `util - remove flags.bat`.
4. Help improve Maccer: send me your macronized texts, and I'll incorporate them as source texts in the next release and give you credit for your contribution. (See below for credits.)

If at any time a plain version of a macronized text is desired, copy the text into `macronize/` and run `util - remove macrons.bat`. A backup file of each text is created in `backup/`.

|FLAG| MEANING                                               |
|----|-------------------------------------------------------|
| ✖ | Unknown word.                                         |
| ✒ | Ambiguous: uncertain vowels marked with a tilde (~).  |
| ✪ | Guessed based on frequency.                           |
| ❡ | Prefix or enclitic detected attached to a known word. |
| ❋ | Invalid characters detected.                          |

### Errors and warnings
Note: In the console window and log files,  are displayed instead of macrons above long vowels because of font limitations.

1. `ERROR--INVALID SUBSTITUTION CONSTANT`
  - Thrown by: 
  - Example: `"*". A constant must be a non-alphanumeric ASCII character that is not a modifier.`
  - What it means: See `data/orthography.txt` and `data/hidden.txt` for information on constants and modifiers, respectively. But if you haven't created any substitution constants, you may have an unclosed multi-line comment (i.e. /* without */) in one of the two above-mentioned files.

2. `ERROR--UNREADABLE SUBSTITUTION LINE`
  - Example: `"act - āct[". Line could not be interpreted.`
  - What it means: The given entry (either in `data/orthography.txt` or `data/hidden.txt`) is incorrectly structured. An entry must be a line in the form `[original][modifiers] = [replace]`, such as `act[ = āct`.

Expanding the word key
----------------------
To incorporate a macronized text into the word key, i.e. to make it a source text:

1. Place the text (in a .txt file) into the `sources/` folder, or into a subfolder.
2. Run `exmacronize.bat` to rebuild the word key. For detailed results, see the log file created in `logs/`.
3. Most macronized texts are not perfect. To correct any errors introduced into the word key:
  1. Run `key - analyze.bat`. Possible errors are saved in `_repairs.txt` in the Maccer root folder.
  2. Correct `_repairs.txt`, according to the instructions therein.
  3. Run `key - repair.bat`. This applies the substitutions stored in `_repairs.txt` to both the key and the source texts. These substitutions are then saved in `data/repair-auto.txt` so that in the future they will appear in the "auto replace" sections of `_repairs.txt` (since they have already been confirmed as correct by the user). Likewise, possible errors that were ignored are saved in `data/repair-ok.txt` and will be ignored in the future.

If you have renamed or modified a source text, the word key must be re-built: run Clear Key, then Exmacronize.

To manually add words to the key, simply enter them into `data/key.txt`, one per line at the end of the list. The list will be alphabetized next time Exmacronize is run.

To manually correct a word in the key, change it in `key.txt` ONLY if it is a manually added word. If it is taken from a source text, enter it into `_repairs.txt` in the "Custom" section (according to that section's instructions) after running Analyze Key, then run Repair Key. This will correct the word in the key as well as in the source text(s) in which it occurs.

Customizing
-----------
The following files in the `data` folder may be expanded or changed, according to the instructions in each file. Note that text in C-style comments (// and /*...*/) is invisible to Maccer.
- `_CONFIG.txt`
- `enclitics.txt`
- `hidden.txt`
- `ignore.txt`
- `orthography.txt`
- `prefixes.txt`

Q & A
-----
### 1. A lot of words get "✖" flags instead of macrons. This program is stupid!
Maccer operates based on a list of Latin word forms, currently numbering over 35,000, generated from digital texts already marked with macrons. It does not generate inflected forms based on principal parts. The advantages of the former method are simplicity and expandability; the disadvantage is that the word list is limited by the corpus of already-macronized source texts, which so far is very small. Individual forms can be added manually to the word key, e.g. *abiēgnō*, but entire words in all their inflections cannot be added in one stroke, as in *abiēgnus*, *-a*, *-um*.

Consequently, Maccer inserts macrons were possible (i.e. for forms already in the key with no similar possibilities such as *hōc* and *hoc*), but **it is up to you to check the words Maccer has guessed, and to macronize those it does not know.** Even of words that are not flagged as problematic, care should be taken, as the source texts are great but not perfect.

The good news is that the more Maccer is used, the smarter it will become. After you have filled in the gaps by hand, Maccer can then analyze your hand-corrected text and add the previously unknown word forms to the key. Ideally the online version would allow anyone to improve the word key in this way, but as I'm not a web programmer, the only way to do this is by sending me texts with macrons (whether created with the help of Maccer or not), and I'll incorporate them into the word key.

### 2. So this word key is based on online texts? But those are full of errors!
Yes, the texts I have found that have vowel quantity marked range from almost perfect to worse than nothing (viz. OCR scans), and it would be impossible to correct every single mistake in them. However, with the help the scripts Analyze and Repair Key that detect and fix possible errors in the word key, along with some human input, this automated process becomes much less haphazard: for example, hidden long vowels, non-classical orthography, and words incorrectly marked where the correct form is known (e.g. *amicus* and *amīcus*) are all detected and corrected under the supervision of the user.

### 3. *Offline version:* What's all this about .txt files? Can't I use Maccer in Word?
No. See the answer to the next question for an imperfect solution.

### 4. *Web version:* I can't copy text from Word without losing all the formatting!
Web applications have trouble reading Word formatting, so here it is not supported. But some formatting can be preserved by following these steps:

1. Plug your Word file into the [Word to Markdown Converter](http://word-to-markdown.herokuapp.com/).
2. Copy the resulting Markdown-formatted text, paste it above, and macronize it.
3. Generate formatting via the preview button, or for more customizability, via [Pandoc](http://johnmacfarlane.net/pandoc/).

### 5. *Web version:* This program is really slow!
I'm not a programmer, least of all a web programmer, so I did not imagine Maccer running on a webpage until late in its development, when I found out [Lua](http://www.lua.org/) scripts could be run on the web via the [Lua VM](http://kripken.github.io/lua.vm.js/lua.vm.js.html). I thought it would be worth a try, and here is the result. The web version would be faster if it were ported to pure JavaScript, but it is what it is.

### 6. *Web version:* This program doesn't work on [insert book title here]!
The web version simply cannot macronize texts of about 2000 words or more. The offline version has no such limitation.

Thanks to the creators of:
--------------------------
- The source texts, chiefly:
  - Christopher Francese, William Turpin, Bret Mulligan — the [Dickinson College Commentaries](http://dcc.dickinson.edu/) (Caesar, Ovid, Nepos, and Severus)
  - [Laura Gibbs](http://bestlatin.blogspot.com/) — [*Ictibus Felicibus*](http://ictibus.blogspot.com/)
  - Johan Winge — [*Alatii Recitationes*](http://web.comhem.se/alatius/latin/)
  - Francis Ritchie & John Kirtland — [*Fabulae Faciles*](http://www.gutenberg.org/ebooks/8997)
  - Tyler Kirby, author of the [Prose Rhythm Project](https://github.com/TylerKirby/ScansionPublic): Cicero's Second Philippic, Aeneid I-II (using the text from Dr. Joseph Farrell's [Vergil project]( http://vergil.classics.upenn.edu/vergil/index.php/document/index/document_id/1))
- [Woordenboek Latijn/Nederlands](http://www.latijnnederlands.nl/), hosted at [Logeion](http://logeion.uchicago.edu/), and the [*TLL*](http://www.degruyter.com/databasecontent?dbid=tll&dbsource=%2Fdb%2Ftll) as invaluable aids regarding hidden long vowels
- [Lua](http://www.lua.org/)
- [luapower](http://luapower.com/)
- [Lua VM](http://kripken.github.io/lua.vm.js/lua.vm.js.html)
- [utf8.lua](https://github.com/alexander-yakushev/awesomerc/blob/master/awesompd/utf8.lua)
- [EpicEditor](http://epiceditor.com/) and [demos](http://epiceditor-demos.herokuapp.com/)
- [Slate theme](https://github.com/jasoncostello/slate)

S. D. G.