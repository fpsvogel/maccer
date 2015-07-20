var luatools = "";	// these are given proper values in lua.js and key.js (whose loading is deferred due to size)
var luamacfirst = "";
var luamackey = "";
var luamacfreq = "";
var luamaclast = "";
var luamac = null; 	// the above three combined (taken from two different files, editability's sake)


(function (window) {
	"use strict";
	
	var undoState = "";
	
	Date.prototype.yyyymmdd = function() {
	   var yyyy = this.getFullYear().toString();
	   var mm = (this.getMonth()+1).toString(); // getMonth() is zero-based
	   var dd  = this.getDate().toString();
	   return yyyy + "-" + (mm[1]?mm:"0"+mm[0]) + "-" + (dd[1]?dd:"0"+dd[0]); // padding
	 };
	
	function contactMe(subject, problemText) {
		var uri = "mailto:fps.vogel@gmail.com?subject=" + encodeURIComponent(subject);
		if (problemText != null) {
			var d = new Date();
			var body = d.yyyymmdd() + ":\r\n\r\n<<" + problemText + ">>";
			uri += "&body=" + encodeURIComponent(body);
		}
		window.open(uri);
	};
	
	function getLines(selection) {
		var lines = selection.toString();
		if (!lines) {
			return [];
		}
		return lines.split('\n');
	}
	
	function replaceLines(document, selection, lines) {
		if (document === null || document === undefined) {
			document = window.document;
		}
		if (selection.rangeCount === 0) {
			return;
		}
		var range = selection.getRangeAt(0);
		range.deleteContents();
		range.collapse(false);
		if (!lines) {
			return;
		}
		var fragment = document.createDocumentFragment();
		lines.forEach(function (line) {
			console.log("'" + line + "'")
			fragment.appendChild(document.createTextNode(line));
			fragment.appendChild(document.createElement('br'));
		});
		range.insertNode(fragment.cloneNode(true));
	}
	
	var Commands = Object.create(null);
	Commands = {
		macronize: function (editor, selection) {
			if (luamac === null) {
				luamac = luamacfirst + luamackey + luamacfreq + luamaclast;
				luamacfirst = null;
				luamackey = null;
				luamacfreq = null;
				luamaclast = null;
			}
			// editor.save();	// tried this with less frequent autosaving, but recent characters were left out of macronize
			undoState = editor.exportFile();
			console.log(selection.toString().length);
			try {
				if (selection.toString().length === 0) {
					var rets = L.execute(luamac, editor.exportFile());
					editor.importFile("mac", rets[0]);
				} else {
					var rets = L.execute(luamac, selection.toString());
					replaceLines(editor.editorIframeDocument, selection, getLines(rets[0]));
				}
			} catch(e) { }
		},
		hyphens: function (editor, selection) {
			// editor.save();
			undoState = editor.exportFile();
			try {
				if (selection.toString().length === 0) {
					console.log(editor.exportFile());
					var rets = L.execute(luatools, "hyphens", editor.exportFile());
					editor.importFile("mac", rets[0]);
				} else {
					var rets = L.execute(luatools, "hyphens", selection.toString());
					replaceLines(editor.editorIframeDocument, selection, getLines(rets[0]));
				}
			} catch(e) { }
		},
		clearflags: function (editor, selection) {
			// editor.save();
			undoState = editor.exportFile();
			try {
				if (selection.toString().length === 0) {
					var rets = L.execute(luatools, "clearflags", editor.exportFile());
					editor.importFile("mac", rets[0]);
				} else {
					var rets = L.execute(luatools, "clearflags", selection.toString());
					replaceLines(editor.editorIframeDocument, selection, getLines(rets[0]));
				}
			} catch(e) { }
		},
		clearmacs: function (editor, selection) {
			// editor.save();
			undoState = editor.exportFile();
			try {
				if (selection.toString().length === 0) {
					var rets = L.execute(luatools, "clearmacs", editor.exportFile());
					editor.importFile("mac", rets[0]);
				} else {
					var rets = L.execute(luatools, "clearmacs", selection.toString());
					replaceLines(editor.editorIframeDocument, selection, getLines(rets[0]));
				}
			} catch(e) { }
		},
		undo: function (editor, selection) {
			// editor.save();
			var temp = undoState;
			undoState = editor.exportFile();
			editor.importFile("mac", temp);
		},
		email: function (editor, selection) {
			editor.save();
			if (selection.toString().length > 0) {
				contactMe("Maccer bug report", selection.toString());
			} else {
				contactMe("Maccer: ");
			}
		}
	};

	window.DefaultCommands = Commands;
}(window));