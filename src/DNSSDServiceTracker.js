Components.utils.import("resource://gre/modules/Services.jsm");
Components.utils.import("resource://gre/modules/XPCOMUtils.jsm");

function DNSSDServiceTracker() {};

DNSSDServiceTracker.prototype = {
    classDescription: "DNSSDServiceTracker",
    classID:          Components.ID("2a0884a8-40d8-4e12-afd6-26530b2e47c2"),
    contractID:       "@dnssd.me/DNSSDServiceTracker;1",
    _xpcom_categories: [
        {category: "xpcom-startup"},
        {category: "profile-after-change"},
    ],
    QueryInterface: XPCOMUtils.generateQI([
        Components.interfaces.nsISupports,
        Components.interfaces.nsIObserver,
        Components.interfaces.nsISupportsWeakReference,
        Components.interfaces.IDNSSDServiceTracker,
    ]),
    _dnssdSvc: null,
    _alertsService: null,
    _prefs: null,
    _dnssdSvcBrowser: null,
    _initCalled: false,
    _initTimer: null,
    _browseDomains: Object(),
    _services: Object(),
    _serviceListCache: null,
    callInContext: function(fn) {
        var context = this;
        return function() { fn.apply(context, arguments); }
    },
    alertsService: function() {
        if (!this._alertsService)   {
            this._alertsService = Components
		.classes["@mozilla.org/alerts-service;1"]
                .getService(Components.interfaces.nsIAlertsService);
        }
        return this._alertsService;
    },
    prefs: function() {
        if (!this._prefs)    {
            this._prefs = Services.prefs.getBranch("extensions.dnssd.");
        }
        return this._prefs;
    },
    dnssdSvc: function()   {
        if (!this._dnssdSvc) {
            try {
                this._dnssdSvc = Components.classes["@dnssd.me/DNSSDService;1"]
                                .createInstance(Components.interfaces
						.IDNSSDService);
                this.log("Created instance of DNSSDService");
            }
            catch (Err) {
                this.log("Error creating DNSSDService instance: " + Err);
            }
        }
        return this._dnssdSvc;
    },
    getTmrInst: function()  {
        return Components.classes["@mozilla.org/timer;1"]
	    .createInstance(Components.interfaces.nsITimer);
    },
    log: function(text) {
        if (this.prefs().getBoolPref("log") == true) {
	    var logtext = "[DNSSDServiceTracker] " + text;
	    Services.console.logStringMessage(logtext);
        }
    },
    _alertsPref: false,
    _updateAlertsPref: function(update)  {
        this._alertPref = this.prefs().getBoolPref("alerts");
    },
    _sendAlerts: function()  {
        if (!this._alertPref)   {
            this._updateAlertsPref();
        }
        return this._alertPref;
    },
    alert: function(title, body) {
        this.alertsService().showAlertNotification(null, title, body, null,
						   null, null);
    },
    _newWritable: function() {
        return Components.classes["@mozilla.org/variant;1"]
               .createInstance(Components.interfaces.nsIWritableVariant);
    },
    _newArray: function() {
        return Components.classes["@mozilla.org/array;1"]
               .createInstance(Components.interfaces.nsIMutableArray);
    },
    observe: function(subject, topic, data) {
        switch(topic)   {
            case "profile-after-change":
                if (!this._initCalled)  {
                    this._initCalled = true;
                    this._initTimer = this.getTmrInst();
                    var tCallback = this.callInContext(function()    {
                        var dnssdSvc = this.dnssdSvc();
			var browseCallback = this.callInContext(this.bListener);
			this._dnssdSvcBrowser = dnssdSvc.browse(browseCallback);
			this._updateAlertsPref();
			this.log("init finished - browsing for services");
                    });
                    this._initTimer.initWithCallback({notify: tCallback}, 500,
						     Components.interfaces
						     .nsITimer.TYPE_ONE_SHOT);
                }
            break;
        }
    },
    getServices: function() {
	if (this._serviceListCache == null) {
	    var services = [];
	    var i = null;
	    for (i in this._services) {
		var service = this._services[i];
		services.push([service.label, service.name, service.domain]);
	    }
            var sortFn = function(a, b) {
		return a[0] == b[0] ? 0 : (a[0] < b[0] ? -1 : 1);
	    }
	    services.sort(sortFn);
	    var servicesOut = this._newArray();
	    for (i = 0; i < services.length; i++) {
		var service = services[i];
		var label = this._newWritable();
		label.setFromVariant(service[0]);
		var name = this._newWritable();
		name.setFromVariant(service[1]);
		var domain = this._newWritable();
		domain.setFromVariant(service[2]);
		var triplet = this._newArray();
		triplet.appendElement(label, 0);
		triplet.appendElement(name, 0);
		triplet.appendElement(domain, 0);
		servicesOut.appendElement(triplet, 0);
	    }
	    this._serviceListCache = servicesOut;
	}
        return this._serviceListCache;
    },
    bListener: function(service, add, interfaceIndex, error, serviceName,
			regtype, domain) {
        if (error) {
            this.log(["Browse called back with error #", error, "(",
                      serviceName, "/", regtype, "/", domain, ")"].join(" "));
            return;
        }
	var displayDomain = domain.charAt(domain.length - 1) == "." ?
	    domain.substr(0, domain.length - 1) : domain;
	var label = serviceName + " (" + displayDomain + ")";
	if (typeof(this._services[label]) == "undefined") {
	    this._services[label] = {"count": 0,
				     "name": serviceName,
				     "domain": domain,
				     "label": label};
	}
	if (add) {
	    this._services[label].count++;
	} else {
	    this._services[label].count--;
	}
	if (add && this._services[label].count == 1) {
	    this.log("Service " + label + " now available");
	    if (this._sendAlerts()) {
		this.alert('Service Discovered', label);
	    }
	    reorganise = true;
	}
	if (this._services[label].count == 0) {
	    this.log("Service " + label + " no longer available");
	    delete this._services[label];
	    reorganise = true;
	}
        if (reorganise) {
	    this._serviceListCache = null;
        }
    }
}

var components =[DNSSDServiceTracker];

const NSGetFactory = XPCOMUtils.generateNSGetFactory(components);
