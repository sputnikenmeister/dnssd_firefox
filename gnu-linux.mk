.PHONY: all clean idl scratch

CC = g++
CFLAGS = -fPIC -DXP_UNIX -DMOZ_NO_MOZALLOC
LDFLAGS = -Wl,-rpath-link,-fshort-wchar -lmozalloc
SCRATCH_PATH = scratch

# firefox/xulrunner versions
FF_VER = $(shell firefox -v | cut -d " " -f 3 | sed -e 's/,$$//g')
FF_VER_M = $(shell echo ${FF_VER}|cut -d "." -f1)
FF_VER_MM = $(shell echo ${FF_VER}|cut -d "." -f1,2)

# lib path
ifeq ($(shell uname -m),x86_64)
    SUFFIX = 64
else
    SUFFIX =
endif

ifndef LIBXUL
	ifeq ($(shell pkg-config --exists libxul-unstable; echo $$?),0)
		LIBXUL = libxul-unstable
	else
		LIBXUL = libxul
	endif
endif

# avahi includes
AVAHI_INC = $(shell pkg-config --cflags avahi-compat-libdns_sd)
AVAHI_LIB = $(shell pkg-config --libs avahi-compat-libdns_sd)

# xulrunner includes
XR_INC = $(shell pkg-config --cflags libxul ${LIBXUL})
XR_LIB = $(shell pkg-config --libs libxul ${LIBXUL})
XR_IDL_PATH = $(shell pkg-config --variable=idldir ${LIBXUL})
IDL_INC = -I ${XR_IDL_PATH}

#xpcom compiler path
XPIDL = $(shell pkg-config --variable=sdkdir ${LIBXUL})/bin/xpidl

# targets
IDL_TARGETS = idl/IDNSSD.h idl/IDNSSD.xpt
TMP_OBJECTS = c_src/DNSSDService${SUFFIX}.o c_src/DNSSDServiceModule${SUFFIX}.o
DLL_OBJECTS = c_src/DNSSDService${SUFFIX}.so
ALL_OBJECTS = ${IDL_TARGETS} ${TMP_OBJECTS} ${DLL_OBJECTS}

# destination
ifndef EXT_PATH
	ifeq ($(shell test -d /usr/lib/firefox-${FF_VER_M}/extensions/; echo $$?),0)
		EXT_PATH = /usr/lib/firefox-${FF_VER_M}/extensions
	else ifeq ($(shell test -d /usr/lib/firefox-${FF_VER_MM}/extensions/; echo $$?),0)
		EXT_PATH = /usr/lib/firefox-${FF_VER_MM}/extensions
	endif
endif
INSTALL_PATH = ${EXT_PATH}/bonjourfoxy\@bonjourfoxy.net

all: scratch

scratch: ${ALL_OBJECTS}
	mkdir -p ${SCRATCH_PATH}/components ${SCRATCH_PATH}/content \
		${SCRATCH_PATH}/defaults/preferences  ${SCRATCH_PATH}/locale
	cp src/chrome.manifest src/install.rdf ${SCRATCH_PATH}
	cp src/content/* ${SCRATCH_PATH}/content
	cp -r src/locale/* ${SCRATCH_PATH}/locale
	cp src/defaults.js ${SCRATCH_PATH}/defaults/preferences
	cp idl/IDNSSD.xpt ${SCRATCH_PATH}/components
	cp src/DNSSDServiceTracker.js ${SCRATCH_PATH}/components
	cp c_src/DNSSDService${SUFFIX}.so ${SCRATCH_PATH}/components

idl: ${IDL_TARGETS}

idl/%.h:
	${XPIDL} -m header ${IDL_INC} -o idl/$* idl/$*.idl

idl/%.xpt:
	${XPIDL} -m typelib ${IDL_INC} -o idl/$* idl/$*.idl

c_src/%${SUFFIX}.o: idl/IDNSSD.h
	${CC} ${CFLAGS} -w -c -o $@ -I idl ${XR_INC} ${XR_LIB} ${AVAHI_INC} c_src/$*.cpp

c_src/%${SUFFIX}.so: ${TMP_OBJECTS}
	${CC} -shared -Wl,-z,defs ${AVAHI_LIB} ${LDFLAGS} -dynamiclib -o $@ $^ ${XR_LIB}

ifndef EXT_PATH
install:

	@echo Unable to guess extension && false
else
install: scratch
	install -d ${DESTDIR}${INSTALL_PATH}/components
	install -d ${DESTDIR}${INSTALL_PATH}/content
	install -d ${DESTDIR}${INSTALL_PATH}/defaults
	install -d ${DESTDIR}${INSTALL_PATH}/defaults/preferences
	install -d ${DESTDIR}${INSTALL_PATH}/locale
	install -d ${DESTDIR}${INSTALL_PATH}/locale/en-US
	install -m644 ${SCRATCH_PATH}/chrome.manifest ${DESTDIR}${INSTALL_PATH}/chrome.manifest
	install -m644 ${SCRATCH_PATH}/components/DNSSDService.so ${DESTDIR}${INSTALL_PATH}/components/DNSSDService.so
	install -m644 ${SCRATCH_PATH}/components/DNSSDServiceTracker.js ${DESTDIR}${INSTALL_PATH}/components/DNSSDServiceTracker.js
	install -m644 ${SCRATCH_PATH}/components/IDNSSD.xpt ${DESTDIR}${INSTALL_PATH}/components/IDNSSD.xpt
	install -m644 ${SCRATCH_PATH}/content/browser.css ${DESTDIR}${INSTALL_PATH}/content/browser.css
	install -m644 ${SCRATCH_PATH}/content/browser.js ${DESTDIR}${INSTALL_PATH}/content/browser.js
	install -m644 ${SCRATCH_PATH}/content/browser.xul ${DESTDIR}${INSTALL_PATH}/content/browser.xul
	install -m644 ${SCRATCH_PATH}/content/options.xul ${DESTDIR}${INSTALL_PATH}/content/options.xul
	install -m644 ${SCRATCH_PATH}/defaults/preferences/defaults.js ${DESTDIR}${INSTALL_PATH}/defaults/preferences/defaults.js
	install -m644 ${SCRATCH_PATH}/install.rdf ${DESTDIR}${INSTALL_PATH}/install.rdf
	install -m644 ${SCRATCH_PATH}/locale/en-US/dnssd.dtd ${DESTDIR}${INSTALL_PATH}/locale/en-US/dnssd.dtd
endif

clean:
	rm -fr ${TMP_OBJECTS} ${ALL_OBJECTS} ${SCRATCH_PATH}