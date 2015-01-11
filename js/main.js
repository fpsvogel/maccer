(function (window) {
	"use strict";

// Default content to display to EpicEditor
	var text = [
		"Enter Latin text here."
	].join('\n');


	var options = {
		file: {
			name: 'maccer',
			defaultContent: text
		},
		theme: {
			preview: '/themes/preview/bartik.css',
			editor: '/themes/editor/epic-light.css'
		},
		button: {
			fullscreen: false
		},
		autogrow: {
			minHeight: 60,
			maxHeight: 350
		}
	};
	var editor = new EpicEditor(options).load();
	var commands = window.DefaultCommands;
	var toolbar = new Toolbar('toolbar', editor, commands);

}(window));
