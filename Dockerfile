ARG osdistro=ubuntu
ARG oscodename=bionic
FROM $osdistro:$oscodename
# FROM $(os):$(oscodename)
MAINTAINER Walter Doekes <wjdoekes+asterisk-deb@osso.nl>

ENV DEBIAN_FRONTEND noninteractive

# This time no "keeping the build small". We only use this container for
# building/testing and not for running, so we can keep files like apt
# cache.
RUN echo 'APT::Install-Recommends "0";' >/etc/apt/apt.conf.d/01norecommends
RUN sed -i -e 's://[^/]*/\(debian\|ubuntu\)://apt.osso.nl/\1:' \
    /etc/apt/sources.list
#RUN printf 'deb http://PPA/ubuntu xenial COMPONENT\n\
#deb-src http://PPA/ubuntu xenial COMPONENT\r\n' >/etc/apt/sources.list.d/osso-ppa.list
#RUN apt-key adv --keyserver pgp.mit.edu --recv-keys 0xBEAD51B6B36530F5
RUN apt-get update -q && apt-get install -y apt-utils && apt-get dist-upgrade -y
RUN apt-get update -q && apt-get install -y \
    bzip2 ca-certificates curl git \
    build-essential dh-autoreconf devscripts dpkg-dev equivs quilt

# Import ARGs
ARG osdistro=ubuntu
ARG oscodename=bionic
ARG upname=asterisk
ARG upversion=16.17.0
ARG debepoch=1:
ARG debversion=0atsip1

# Copy debian dir, check version
RUN mkdir -p /build/debian
COPY debian/changelog /build/debian/changelog
RUN . /etc/os-release && \
    osdistshort=$(echo "$osdistro" | sed -e 's/\(...\).*/\1/') && \
    fullversion="${upversion}-${debversion}+${osdistshort}${VERSION_ID}" && \
    expected="${upname} (${debepoch}${fullversion}) ${oscodename}; urgency=medium" && \
    head -n1 /build/debian/changelog && \
    if test "$(head -n1 /build/debian/changelog)" != "${expected}"; \
    then echo "${expected}  <-- mismatch" >&2; false; fi

# Set up upstream source, move debian dir and jump into dir.
#
# Trick to allow caching of asterisk*.tar.gz files. Download them
# once using the curl command below into .cache/* if you want. The COPY
# is made conditional by the "[2]" "wildcard". (We need one existing
# file (README.rst) so the COPY doesn't fail.)
COPY README.rst .cache/${upname}_${upversion}.orig.tar.g[z] /build/
RUN test -s /build/${upname}_${upversion}.orig.tar.gz || \
    curl --fail "http://downloads.asterisk.org/pub/telephony/asterisk/old-releases/${upname}-${upversion}.tar.gz" \
    >/build/${upname}_${upversion}.orig.tar.gz
RUN cd /build && tar zxf "${upname}_${upversion}.orig.tar.gz" && \
    mv debian "${upname}-${upversion}/"
WORKDIR "/build/${upname}-${upversion}"

# Apt-get prerequisites according to control file.
COPY debian/compat debian/control debian/
RUN apt-get update -q && \
    mk-build-deps --install --remove --tool "apt-get -y" debian/control

# Hacks to fix d-shlibs problems, which are fixed in stretch/bionic.
#COPY d-shlibs.patch /build/
#RUN patch -p0 --directory=/ </build/d-shlibs.patch && apt-get update

# Build!
COPY debian debian
RUN DEB_BUILD_OPTIONS=parallel=6 dpkg-buildpackage -us -uc -sa

# Do linker checks:
# (debian/tmp holds everything, debian/asterisk-modules only the modules
# selected for that package)
# - check that we're not using both openssl 1.0 and 1.1:
RUN echo "Check that all required openssl versions are equal:" && \
    vals=$(\
      find /build/asterisk-${upversion}/debian/tmp -name '*.so' -o -name asterisk -type f | \
      sort | while read f; do ldd "$f" | \
      sed -ne "s/^[[:blank:]]*\\(libssl[^ ]*\\) =>.*/  \\1 - $(basename $f)/p"; done); \
    echo "$vals"; \
    if test $(echo "$vals" | awk '{print $1}' | sort -u | wc -l) -ne 1; then \
      echo "Has differing openssl versions.." >&2; exit 1; fi
RUN echo "Check that chan_pjsip is linked against a dynamic lib:" && \
    if find /build/asterisk-${upversion}/debian/tmp -name 'chan_pjsip.so' -type f | \
        xargs ldd | grep -C10 libpj; then \
      dpkg -l libpjproject2 && echo "(dynamic lib)" >&2; \
    else \
      find /build/asterisk-${upversion}/debian/tmp -name 'libasteriskpj.so' | \
        xargs nm -D | grep ' T pj_get_version$' && echo "(is embedded)" >&2; \
    fi

# Install checks:
RUN echo "Install checks:" && cd .. && . /etc/os-release && \
    osdistshort=$(echo "$osdistro" | sed -e 's/\(...\).*/\1/') && \
    fullversion=${upversion}-${debversion}+${osdistshort}${VERSION_ID} && \
    apt-get update -q && apt-get install -y asterisk-core-sounds-en && \
    dpkg -i \
      asterisk_${fullversion}_*.deb \
      # asterisk-config OR asterisk-config-empty
      asterisk-config_${fullversion}_*.deb  \
      asterisk-dbgsym_${fullversion}_*.d*eb \
      asterisk-modules_${fullversion}_*.deb \
      asterisk-modules-dbgsym_${fullversion}_*.d*eb

# Application and library version checks:
RUN asterisk -V | grep -F "${upversion}" && asterisk -V | grep -F "${debversion}"
RUN objdump -T /usr/lib/libasteriskpj.so.2 | \
    grep '[[:blank:]][.]text[[:blank:]].*[[:blank:]]pj_init$' && \
    # Only if we have asterisk-config (not asterisk-config-empty) can we
    # start asterisk and get info from it.
    if test -f /etc/asterisk/asterisk.conf; then \
    asterisk -cn >/dev/null 2>&1 & p=$!; sleep 2; \
    asterisk -nrx 'pjsip show version'; asterisk -nrx 'core stop now'; wait; \
    fi
RUN echo '#include <stdio.h>\nvoid __ast_repl_malloc() {} void __ast_free() {} \
      void ast_pjproject_max_log_level() {} void ast_option_pjproject_log_level() {} \
      char const *pj_get_version(void); \
      int main() { fprintf(stderr, "libasteriskpj: %s\\n", pj_get_version()); return 0; }' \
      >/tmp/test.c && gcc /tmp/test.c -lasteriskpj -o /tmp/test && /tmp/test

# Write output files (store build args in ENV first).
ENV oscodename=$oscodename osdistro=$osdistro \
    upname=$upname upversion=$upversion debversion=$debversion
CMD . /etc/os-release && \
    osdistshort=$(echo "$osdistro" | sed -e 's/\(...\).*/\1/') && \
    fullversion=${upversion}-${debversion}+${osdistshort}${VERSION_ID} && \
    if ! test -d /dist; then echo "Please mount ./dist for output" >&2; false; fi && \
    echo && . /etc/os-release && mkdir /dist/${oscodename}/${upname}_${fullversion} && \
    mv /build/*${fullversion}* /dist/${oscodename}/${upname}_${fullversion}/ && \
    mv /build/${upname}_${upversion}.orig.tar.gz /dist/${oscodename}/${upname}_${fullversion}/ && \
    chown -R ${UID}:root /dist/${oscodename} && \
    cd / && find dist/${oscodename}/${upname}_${fullversion} -type f && \
    echo && echo 'Output files created succesfully'
