# Build the pytz libraries
#

MAKE=make
PYTHON=/usr/bin/python
PYTHON3=/usr/bin/python3
OLSON=./elsie.nci.nih.gov
TESTARGS=-vv
TARGET=
#TARGET=Europe/Amsterdam Europe/Moscow W-SU Etc/GMT+2 Atlantic/South_Georgia Europe/Warsaw Europe/Vilnius
#Mideast/Riyadh87
STYLESHEET=/usr/share/python-docutils/stylesheets/default.css

all: dist

check: test_tzinfo test_docs

build: build/dist/locales/pytz.pot

dist: build/dist/locales/pytz.pot .stamp-dist
.stamp-dist: .stamp-tzinfo
	cd build/dist && mkdir -p ../tarballs && \
	${PYTHON} setup.py sdist --dist-dir ../tarballs \
	    --formats=bztar,gztar,zip && \
	${PYTHON} setup.py bdist_egg --dist-dir=../tarballs && \
	${PYTHON3} setup.py bdist_egg --dist-dir=../tarballs
	touch $@

wheels:
	cd build/dist && mkdir -p ../tarballs
	cd build/dist && ${PYTHON} setup.py -q bdist_wheel --universal --dist-dir=../tarballs
	cd build/dist && ${PYTHON3} setup.py -q bdist_wheel --universal --dist-dir=../tarballs

upload: dist build/dist/locales/pytz.pot .stamp-upload
.stamp-upload: .stamp-tzinfo
	cd build/dist && \
	${PYTHON} setup.py register sdist \
	    --formats=bztar,gztar,zip --dist-dir=../tarballs \
	    upload --sign && \
	${PYTHON3} setup.py register bdist_egg --dist-dir=../tarballs \
	    upload --sign && \
	touch $@

test: test_tzinfo test_docs test_zdump

clean:
	rm -f .stamp-*
	rm -rf build/*/*
	make -C ${OLSON}/src clean
	find . -name \*.pyc | xargs rm -f

test_tzinfo: .stamp-tzinfo
	cd build/dist/pytz/tests \
	    && ${PYTHON} test_tzinfo.py ${TESTARGS} \
	    && ${PYTHON3} test_tzinfo.py ${TESTARGS}

test_docs: .stamp-tzinfo
	cd build/dist/pytz/tests \
	    && ${PYTHON} test_docs.py ${TESTARGS} \
	    && ${PYTHON3} test_docs.py ${TESTARGS}

test_zdump: dist
	${PYTHON} gen_tests.py ${TARGET} && \
	${PYTHON} test_zdump.py ${TESTARGS} && \
	${PYTHON3} test_zdump.py ${TESTARGS}

build/dist/test_zdump.py: .stamp-zoneinfo


docs: dist
	mkdir -p build/docs/source/.static
	mkdir -p build/docs/built
	cp src/README.txt build/docs/source/index.txt
	cp conf.py build/docs/source/conf.py
	sphinx-build build/docs/source build/docs/built
	chmod -R og-w build/docs/built
	chmod -R a+rX build/docs/built

upload_docs: docs
	rsync -e ssh -ravP build/docs/built/ \
	    web.sourceforge.net:/home/project-web/pytz/htdocs/

.stamp-tzinfo: .stamp-zoneinfo gen_tzinfo.py build/etc/zoneinfo/GMT
	${PYTHON} gen_tzinfo.py ${TARGET}
	rm -rf build/dist/pytz/zoneinfo
	cp -a build/etc/zoneinfo build/dist/pytz/zoneinfo
	touch $@

.stamp-zoneinfo:
	${MAKE} -C ${OLSON}/src TOPDIR=`pwd`/build install
	# Break hard links, working around http://bugs.python.org/issue8876.
	for d in zoneinfo zoneinfo-leaps zoneinfo-posix; do \
	    rm -rf `pwd`/build/etc/$$d.tmp; \
	    rsync -a `pwd`/build/etc/$$d/ `pwd`/build/etc/$$d.tmp; \
	    rm -rf `pwd`/build/etc/$$d; \
	    mv `pwd`/build/etc/$$d.tmp `pwd`/build/etc/$$d; \
	done
	touch $@

build/dist/locales/pytz.pot: .stamp-tzinfo
	@: #${PYTHON} gen_pot.py build/dist/pytz/locales/pytz.pot

#	cd build/dist; mkdir locales; \
#	pygettext --extract-all --no-location \
#	    --default-domain=pytz --output-dir=locales



.PHONY: all check dist test test_tzinfo test_docs test_zdump
