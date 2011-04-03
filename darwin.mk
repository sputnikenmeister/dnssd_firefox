.PHONY: all clean idl scratch

export MACOSX_DEPLOYMENT_TARGET="10.5"

CC = g++
XR_SDK_PATH_PRE = sdk
SDK_PATH = ${XR_SDK_PATH_PRE}/maci386/xulrunner-sdk
SCRATCH_PATH = scratch
XPIDL = ${SDK_PATH}/host/bin/host_xpidl
IDL_INCLUDES = -I ${SDK_PATH}/idl
IDL_TARGETS = idl/IDNSSD.h idl/IDNSSD.xpt
IMP_OBJECTS = c_src/DNSSDService-i386.o c_src/DNSSDService-x86_64.o
MOD_OBJECTS = c_src/DNSSDServiceModule-i386.o c_src/DNSSDServiceModule-x86_64.o
DLL_OBJECTS = c_src/DNSSDService.dylib c_src/DNSSDService-i386.dylib c_src/DNSSDService-x86_64.dylib
ALL_OBJECTS = ${IDL_TARGETS} ${IMP_OBJECTS} ${MOD_OBJECTS} ${DLL_OBJECTS}
COMPILE = ${CC} \
		-arch $* \
		-mmacosx-version-min=10.5 \
		-isysroot /Developer/SDKs/MacOSX10.5.sdk \
		-fshort-wchar -w -c -o $@ -I . \
		-I ${PWD}/idl \
		-I ${XR_SDK_PATH_PRE}/mac$(*)/xulrunner-sdk/include \
		-I ${XR_SDK_PATH_PRE}/mac$(*)/xulrunner-sdk/sdk/include \
		-I ${XR_SDK_PATH_PRE}/mac$(*)/xulrunner-sdk/include/xpcom \
		-DXP_UNIX -DXP_MACOSX -DMOZ_NO_MOZALLOC

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

c_src/DNSSDService-%.o:
	${COMPILE} c_src/DNSSDService.cpp

c_src/DNSSDServiceModule-%.o:
	${COMPILE} c_src/DNSSDServiceModule.cpp

c_src/DNSSDService.dylib: c_src/DNSSDService-i386.dylib c_src/DNSSDService-x86_64.dylib
	lipo -create c_src/DNSSDService-i386.dylib c_src/DNSSDService-x86_64.dylib -output c_src/DNSSDService.dylib

c_src/DNSSDService-%.dylib: c_src/DNSSDService-%.o c_src/DNSSDServiceModule-%.o
	${CC} \
		-arch $* \
		-mmacosx-version-min=10.5 \
		-isysroot /Developer/SDKs/MacOSX10.5.sdk \
		-L${XR_SDK_PATH_PRE}/mac$(*)/xulrunner-sdk/lib \
		-L${XR_SDK_PATH_PRE}/mac$(*)/xulrunner-sdk/bin \
		-Wl,-executable_path, -fshort-wchar -dynamiclib \
		-lxpcomglue_s -lxpcom -lnspr4 -lmozalloc \
		-o c_src/DNSSDService-$*.dylib \
		c_src/DNSSDService-$*.o c_src/DNSSDServiceModule-$*.o

clean:
	rm -fr ${ALL_OBJECTS} ${SCRATCH_PATH}