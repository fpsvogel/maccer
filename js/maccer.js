(function (window) {
	"use strict";
	function macronize(text) {
		try {
			var ret = L.execute(luacode, text);
			return "lols";
		} catch(e) { window.alert(e); }
	}
	
	var luacode = [
	"return 1"
	]
}(window));
