var dnssd = {
    _noServicesText: null,
    onLoad: function() {
        var prefs = Components.classes["@mozilla.org/preferences-service;1"]
	    .getService(Components.interfaces.nsIPrefService)
	    .getBranch("extensions.dnssd.");
	if (prefs.getBoolPref('firstLoad')) {
	    prefs.setBoolPref('firstLoad', false);
	    try {
		var firefoxnav = document.getElementById("nav-bar");
		var curSet = firefoxnav.currentSet;
		if (curSet.indexOf("dnssd-toolbarset") == -1)
		{
		    var set;
		    if (curSet.indexOf("urlbar-container") != -1) {
			var pattern = /urlbar-container/;
			var replacement = "dnssd-toolbarset,urlbar-container";
			set = curSet.replace(pattern, replacement);
		    } else {
			set = curSet + ",dnssd-toolbarset";
		    }
		    firefoxnav.setAttribute("currentset", set);
		    firefoxnav.currentSet = set;
		    document.persist("nav-bar", "currentset");
		    BrowserToolboxCustomizeDone(true);
		}
	    }
	    catch(e) {
		var title = "DNSSD for Firefox: Install Problem";
		var errbody = (e.name || e.message) ?
		    ["Please report the following error details:\n\n",
		     "Error Name:", e.name, "\n",
		     "Error Message:", e.message, "\n\n\n"].join("") : "";
		var body = ["DNSSD for Firefox was unable to automatically ",
			    "add it's toolbar button. ", errbody,
			    "You can manually add the toolbar ",
			    "button by going to the 'View' menu, selecting ",
			    "'Toolbars' and then 'Customize'.",
			   ].join("");
		window.setTimeout(function() { dnssd.dialog(title, body); }, 5);
	    }
	}
    },
    set_noServicesText: function() {
	var id = "dnssd-toolbar-popmenu-noservices";
	var el = document.getElementById(id);
	var label = el.getAttribute("label");
	dnssd._noServicesText = label;
    },
    renderMenu: function(ContainerId) {
	var container = document.getElementById(ContainerId);
	if (dnssd._noServicesText == null) {
	    dnssd.set_noServicesText();
	}
	while (container.hasChildNodes()) {
	    container.removeChild(container.firstChild);
	}
	var services = Components.classes["@dnssd.me/DNSSDServiceTracker;1"]
	    .getService(Components.interfaces.IDNSSDServiceTracker)
	    .getServices();
	var nsIArray = Components.interfaces.nsIArray;
	var nsIVariant = Components.interfaces.nsIVariant;
	if (services.length == 0) {
	    var newMenuItem = document.createElement("menuitem");
	    newMenuItem.setAttribute("label", dnssd._noServicesText);
	    newMenuItem.setAttribute("disabled", true);
	    container.appendChild(newMenuItem);
	} else {
	    for (var i = 0; i < services.length; i++) {
		var service = services.queryElementAt(i, nsIArray);
		var label = service.queryElementAt(0, nsIVariant);
		var name = service.queryElementAt(1, nsIVariant);
		var domain = service.queryElementAt(2, nsIVariant);
		var newMenuItem = document.createElement("menuitem");
		newMenuItem.setAttribute("label", label, null);
		newMenuItem.setUserData("name", name, null);
		newMenuItem.setUserData("domain", domain, null);
		var cmdFn = dnssd.buildResolver(container, label, name, domain);
		newMenuItem.addEventListener("mouseup", cmdFn, null);
		newMenuItem.addEventListener("command", cmdFn, null);
		container.appendChild(newMenuItem);
	    }
	}
    },
    buildResolver: function(menupopup, label, name, domain) {
	return function(event) {
	    menupopup.hidePopup();
	    var ctx = {"label": label,
		       "name": name,
		       "domain": domain,
		       "resolved": false};
	    var callbackFun = function(service, interfaceIndex, errorCode,
				       fullname, host, port, path) {
		if (ctx.resolved || errorCode) return;
		ctx.resolved = true;
		/*
		  trailing period is stripped for the benefit of broken
		  software (reportedly flash)
		*/
		var url = ["http://",
			   (host.charAt(host.length - 1) == "." ?
			    host.substr(0, host.length - 1) : host),
			   ":", port,
			   path.charAt(0) == "/" ? path : "/" + path
			  ].join("");
		Components.classes["@mozilla.org/appshell/window-mediator;1"]
		    .getService(Components.interfaces.nsIWindowMediator)
		    .getMostRecentWindow('navigator:browser')
		    .openUILinkIn(url, "current");
		try { service.stop }
		catch (Err) {};
	    };
	    ctx.resolver = Components.classes["@dnssd.me/DNSSDService;1"]
		.createInstance(Components.interfaces.IDNSSDService)
		.resolve(name, "_http._tcp", domain, callbackFun);
            window.setTimeout(function() {
		if (!ctx.resolved)    {
		    var title = "Timed out";
		    var body = "Timed out trying to resolve " + label;
		    dnssd.dialog(title, body);
		}
		try { ctx.resolver.stop(); }
		catch (e) {}
            }, 15000);
	};
    },
    dialog: function(title, body) {
	Components.classes["@mozilla.org/embedcomp/prompt-service;1"]
            .getService(Components.interfaces.nsIPromptService)
	    .alert(window, title, body)
    }
};
window.addEventListener("load", dnssd.onLoad, false);
