(function (window) {
	"use strict";

	function runLua(document, selection) {
		var luacode = "error('prefix-')";
		try {
			L.execute(luacode);
		} catch(e) {
			var range = selection.getRangeAt(0);
			range.insertNode(document.createTextNode(e.toString()));
			range.collapse(false);
		}
	}

	var Commands = Object.create(null);
	Commands = {
		macronize: function (editor, selection) {
			
		},

		hyphens: function (editor, selection) {
			
		},

		colors: function (editor, selection) {
			runLua(editor.editorIframeDocument, selection);
		}
	};

	window.DefaultCommands = Commands;
}(window));
