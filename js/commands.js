(function (window) {
	"use strict";

	function runLua(document, selection) {
		var oldtitle = window.name;
		window.name = selection;
		window.alert(window.name);
		var luacode = "local arg = js.global.name\njs.global:alert(arg)\nerror('hi--')";
		try {
			L.execute(luacode);
		} catch(e) {
			var range = selection.getRangeAt(0);
			var text = e.toString().substr(26)
			range.insertNode(document.createTextNode(text));
			range.collapse(false);
		}
		window.name = oldtitle
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
