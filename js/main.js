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
	};
	var editor = new EpicEditor(options).load();
	var commands = window.DefaultCommands;
	var toolbar = new Toolbar('toolbar', editor, commands);

}(window));
