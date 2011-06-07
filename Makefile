UNAME = $(shell (uname -o 2>/dev/null||uname -s 2>/dev/null)|tr 'A-Z/' 'a-z-')
include $(UNAME).mk

scratch/components/%:
	@test -f scratch/components/$* || (echo $* missing; exit 1)

scratch: ${ALL_OBJECTS}
	mkdir -p ${SCRATCH_PATH}/components ${SCRATCH_PATH}/content \
		${SCRATCH_PATH}/defaults/preferences  ${SCRATCH_PATH}/locale
	cp src/chrome.manifest src/install.rdf ${SCRATCH_PATH}
	cp src/content/* ${SCRATCH_PATH}/content
	cp -r src/locale/* ${SCRATCH_PATH}/locale
	cp src/defaults.js ${SCRATCH_PATH}/defaults/preferences
	cp idl/IDNSSD.xpt ${SCRATCH_PATH}/components
	cp src/DNSSDServiceTracker.js ${SCRATCH_PATH}/components
	@cp -v c_src/DNSSDService.dylib ${SCRATCH_PATH}/components || \
		echo "!! WARNING !! DNSSDService.dylib missing"
	@cp -v c_src/DNSSDService.dll ${SCRATCH_PATH}/components || \
		echo "!! WARNING !! DNSSDService.dll missing"
	@cp -v c_src/DNSSDService.so ${SCRATCH_PATH}/components || \
		echo "!! WARNING !! DNSSDService.so missing"
	@cp -v c_src/DNSSDService64.so ${SCRATCH_PATH}/components || \
		echo "!! WARNING !! DNSSDService64.so missing"

xpi: scratch/components/DNSSDService.dll scratch/components/DNSSDService.dylib
	cd scratch && \
	zip -r ../dnssd-$(shell sed -n 's/.*em:version="\(.*\)".*/\1/p' ${SCRATCH_PATH}/install.rdf).xpi *
