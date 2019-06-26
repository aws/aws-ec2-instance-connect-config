VERSION_FILE=./VERSION
pkgver=$(shell cat $(VERSION_FILE))
version = $(firstword $(subst -, ,$(pkgver)))
release = $(lastword $(subst -, ,$(pkgver)))

default: clean ;

deb:
	./bin/make_deb.sh $(version) $(release)

rpm:
	./bin/make_rpm.sh $(version) $(release)

clean:
	$(shell rm -rf ec2-instance-connect*)
	$(shell rm -rf ./rpmbuild/SOURCES)
	$(shell rm -rf ./deb-src)
	$(shell rm -rf ./srpm_results)
	$(shell rm -rf ./rpm_results)
