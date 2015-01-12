var luatools = "return 'haha'";	// given a proper value in lua.js (whose loading is deferred due to size)
var luamac = "";
var test = "empty!";

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
		var uri = "mailto:felipe.vogel@uky.edu?subject=" + encodeURIComponent(subject);
		if (problemText != null) {
			var d = new Date();
			var body = d.yyyymmdd() + ":\r\n\r\n<<" + problemText + ">>";
			uri += "&body=" + encodeURIComponent(body);
		}
		window.open(uri);
	};
	
	function replaceSelection(document, selection, newText) {

		if (document === null || document === undefined) {
			document = window.document;
		}
		if (selection.rangeCount === 0) {
			return;
		}
		var range = selection.getRangeAt(0);
		range.deleteContents();
		range.collapse(false);
		if (!newText) {
			return;
		}
		var fragment = document.createDocumentFragment();
		fragment.appendChild(document.createTextNode(newText));
		range.insertNode(fragment.cloneNode(true));
	}
	
	var Commands = Object.create(null);
	Commands = {
		macronize: function (editor, selection) {
			// editor.save();	// tried this with less frequent autosaving, but recent characters were left out of macronize
			undoState = editor.exportFile();
			console.log(selection.toString().length);
			try {
				if (selection.toString().length === 0) {
					var rets = L.execute(luamac, editor.exportFile());
					editor.importFile("mac", rets[0]);
				} else {
					var rets = L.execute(luamac, selection.toString());
					replaceSelection(editor.editorIframeDocument, selection, rets[0]);
				}
			} catch(e) { }
		},
		hyphens: function (editor, selection) {
			console.log(test);
			// editor.save();
			undoState = editor.exportFile();
			try {
				if (selection.toString().length === 0) {
					var rets = L.execute(luatools, "hyphens", editor.exportFile());
					editor.importFile("mac", rets[0]);
				} else {
					var rets = L.execute(luatools, "hyphens", selection.toString());
					replaceSelection(editor.editorIframeDocument, selection, rets[0]);
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
					replaceSelection(editor.editorIframeDocument, selection, rets[0]);
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
					replaceSelection(editor.editorIframeDocument, selection, rets[0]);
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
