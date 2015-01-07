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
		}
		theme: {
			preview: '/themes/preview/preview-light.css',
			editor: '/themes/editor/epic-light.css'
		},
		button: {
			fullscreen: false,
		},
	};
	var editor = new EpicEditor(options).load();
	var commands = window.DefaultCommands;
	var toolbar = new Toolbar('toolbar', editor, commands);

}(window));
