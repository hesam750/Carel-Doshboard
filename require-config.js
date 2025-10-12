var cFieldRevision;
if (window) {
	cFieldRevision = window["cFieldRevision"];
}
var urlArgs = cFieldRevision ? "v=" + cFieldRevision : "";

require.config({
	paths: {
		"knockout": "lib/knockout-latest",
		"x2js": "lib/x2js",
		"text": "lib/text",
		"crossroads": "lib/crossroads.min",
        "signals": "lib/signals.min",
		"hammerjs": "lib/hammer.min", 
		"jquery-hammer": "lib/jquery.hammer",
		"i18next": "lib/i18next.min",
		"i18next-xhr-backend": "lib/i18nextXHRBackend.min",
		"i18next-browser-languagedetector": "lib/i18nextBrowserLanguageDetector.min",
		"pLan": "lib/pLan-min",
		"dygraphs": "lib/dygraph.min",
		"file-saver": "lib/filesaver.min",
		"resize-sensor": "lib/ResizeSensor",
		"ipaddr": "lib/ipaddr-edit",
		"md5": "lib/md5.min",
		"cfield.app": "lib/cfield.app"
	},
	urlArgs: urlArgs,
	shim: {
		"pLan": {
			/*deps: ["jquery"] but jquery is already loaded */
			exports: "pLan"
		},
		"ipaddr": { exports: "ipaddr"},
		"md5": { exports: "md5"}
	}
});

// Jquery is loaded using <script> tag into index.html. So export the module for requirejs
define("jquery", [], function() {
    return jQuery;
});

// Start app
requirejs(["cfield.app"], function(cFieldAppModule) {
	var baseUrl = "/proxy?url=http://169.254.61.68";
	var cFieldApp = new cFieldAppModule.CfieldApp.getInstance(baseUrl);
});


requirejs.onError = function (err) {
    if (err.requireType === 'timeout') {
        alert("error: "+err);
    } 
    else {
        throw err;
    }   
};