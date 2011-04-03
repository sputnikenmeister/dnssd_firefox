.PHONY: all clean idl scratch vctmp

CC = cl
XR_SDK_PATH_PRE = sdk
SDK_PATH = ${XR_SDK_PATH_PRE}/win32/xulrunner-sdk
SCRATCH_PATH = scratch
XPIDL = ${SDK_PATH}/bin/xpidl
IDL_INCLUDES = -I ${SDK_PATH}/idl
IDL_TARGETS = idl/IDNSSD.h idl/IDNSSD.xpt
OBJECTS = c_src/DNSSDService.obj c_src/DNSSDServiceModule.obj
TMP_OBJECTS = c_src/DNSSDService.lib DNSSDService.exp
DLL_OBJECTS = c_src/DNSSDService.dll
ALL_OBJECTS = ${IDL_TARGETS} ${OBJECTS} ${DLL_OBJECTS}

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
	cp c_src/DNSSDService.dylib c_src/DNSSDService.dll ${SCRATCH_PATH}/components

idl: ${IDL_TARGETS}

idl/%.h:
	${XPIDL} -m header ${IDL_INCLUDES} -o idl/$* idl/$*.idl

idl/%.xpt:
	${XPIDL} -m typelib ${IDL_INCLUDES} -o idl/$* idl/$*.idl

c_src/%.obj: c_src/%.cpp
	cl c_src/$*.cpp /Od \
		/I "${PWD}\idl" \
		/I "${SDK_PATH}\include" \
		/I "${SDK_PATH}\sdk\include" \
		/I "${SDK_PATH}\include\xpcom" \
		/I "${BONJOUR_SDK_HOME}Include" \
		/D "WIN32" /D "_WINDOWS" /D "_USRDLL" \
		/D "DNSSDSERVICE_EXPORTS" /D "XP_WIN" /D "XP_WIN32" \
		/D "MOZ_NO_MOZALLOC" /D "_WINDLL" /D "_MBCS" /EHsc /RTC1 \
		/MT /Zc:wchar_t- /W3 /c /TP \
		/Foc_src/$*.obj

c_src/DNSSDService.dll: c_src/DNSSDService.obj c_src/DNSSDServiceModule.obj
	link /OUT:"c_src\DNSSDService.dll" \
		/LIBPATH:"$(SDK_PATH)\sdk\lib" /LIBPATH:"$(SDK_PATH)\lib" \
		/LIBPATH:"${BONJOUR_SDK_HOME}\lib\win32" /DLL \
		/DYNAMICBASE:NO /MACHINE:X86 \
		nspr4.lib xpcom.lib xpcomglue_s.lib mozalloc.lib ws2_32.lib \
		dnssd.lib  kernel32.lib user32.lib gdi32.lib winspool.lib \
		comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib \
		uuid.lib odbc32.lib odbccp32.lib $^

clean:
	rm -fr ${TMP_OBJECTS} ${ALL_OBJECTS} ${SCRATCH_PATH}