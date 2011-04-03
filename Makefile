UNAME = $(shell (uname -o 2>/dev/null||uname -s 2>/dev/null)|tr 'A-Z' 'a-z')
include $(UNAME).mk

scratch/components/%:
	@test -f scratch/components/$* || (echo $* missing; exit 1)

xpi: scratch/components/DNSSDService.dll scratch/components/DNSSDService.dylib
	cd scratch && \
	zip -r ../dnssd-$(shell sed -n 's/.*em:version="\(.*\)".*/\1/p' ${SCRATCH_PATH}/install.rdf).xpi *
