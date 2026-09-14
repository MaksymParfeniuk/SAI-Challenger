ARG BASE_OS
FROM sc-base:${BASE_OS}

LABEL maintainer="maksym.parfeniuk@gmail.com"

ENV SC_PLATFORM=vpp
ENV SC_ASIC=vpp
ENV SC_TARGET=saivpp

WORKDIR /sai


# Dependencies
RUN mkdir -p /var/log/vpp /run/vpp



RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        sudo \
    && rm -rf /var/lib/apt/lists/*


COPY configs/get_vpp.sh /tmp/get_vpp.sh

RUN chmod +x /tmp/get_vpp.sh \
    && /tmp/get_vpp.sh

ENV VPP_INSTALL_SKIP_SYSCTL=1
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        /tmp/vpp-artifacts/*.deb; \
    ldconfig; \
    rm -rf /tmp/sonic-platform-vpp /tmp/vpp-artifacts; \
    rm -rf /var/lib/apt/lists/*
 

# Verify VPP libs
RUN set -eux; \
    vpp --version; \
    ldconfig -p | grep libvlib; \
    ldconfig -p | grep libvlibapi; \
    ldconfig -p | grep libvppapiclient; \
    ldconfig -p | grep libvlibmemoryclient; \
    ldconfig -p | grep libvppinfra; \
    test -f /usr/include/vpp_plugins/tunterm_acl/tunterm_acl.api_enum.h; \
    test -f /usr/include/vpp_plugins/tunterm_acl/tunterm_acl.api_types.h


# Clone sonic-sairedis / SAI
RUN git clone https://github.com/sonic-net/sonic-sairedis.git \
    && cd /sai/sonic-sairedis \
    && . /sai.env \
    && echo "SAIREDIS_ID=${SAIREDIS_ID}" \
    && echo "SAI_ID=${SAI_ID}" \
    && git checkout "${SAIREDIS_ID}" \
    && git submodule update --init --recursive \
    && cd SAI \
    && git fetch origin \
    && git checkout "${SAI_ID}" \
    && cd meta \
    && make saimetadata.h \
    && make saimetadata.c \
    && cp saimetadatautils.c /sai/gen_attr_list/ \
    && cp saimetadata.c /sai/gen_attr_list/ \
    && cp saiserialize.c /sai/gen_attr_list/ \
    && cd ../..


# Prepare sonic-sairedis
RUN cd /sai/sonic-sairedis \
    && find . -type f -name Makefile.am \
       | xargs sed -ri 's/^TESTS =/# TESTS =/' \
    && sed -i \
       's/^SUBDIRS = py2 py3/SUBDIRS = py3/' \
       pyext/Makefile.am \
    && ./autogen.sh


# Configure and build
RUN cd /sai/sonic-sairedis \
    && ./configure \
        --with-sai=vs \
        --disable-python2 \
    && grep -E \
        'checking for main in -lvlib|VPP_LIBS|USE_VPP' \
        config.log \
    && make -j"$(nproc)"


# Build Debian packages
RUN cd /sai/sonic-sairedis \
    && dpkg-buildpackage \
        -us \
        -uc \
        -b \
        -Psyncd,vs,nopython2 \
        --jobs=auto


# Install libsaivs + syncd-vs
RUN cd /sai \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ./libsaimetadata_1.0.0_amd64.deb \
        ./libsaimetadata-dev_1.0.0_amd64.deb \
        ./libsairedis_1.0.0_amd64.deb \
        ./libsaivs_1.0.0_amd64.deb \
        ./libsaivs-dev_1.0.0_amd64.deb \
        ./syncd-vs_1.0.0_amd64.deb \
    && ldconfig \
    && rm -f /sai/*.deb \
    && rm -rf /var/lib/apt/lists/*


RUN mkdir -p /etc/sai.d

COPY configs/sai.profile /etc/sai.d/sai.profile


# Verify libsaivs links against VPP
RUN set -eux; \
    LIBSAIVS="$(ldconfig -p | awk '/libsaivs\.so/{print $NF; exit}')"; \
    test -n "$LIBSAIVS"; \
    echo "libsaivs: $LIBSAIVS"; \
    ldd "$LIBSAIVS" | grep -E \
        'libvlib|libvlibapi|libvppapiclient|libvlibmemoryclient|libvppinfra'


# Build SAI attributes metadata JSON generator and generate /etc/sai/sai.json
RUN cd /sai/gen_attr_list \
    && mkdir -p build \
    && cd build \
    && cmake .. \
    && make -j"$(nproc)" \
    && mkdir -p /etc/sai \
    && ./attr_list_generator > /etc/sai/sai.json.tmp \
    && python3 -m json.tool /etc/sai/sai.json.tmp > /etc/sai/sai.json \
    && rm -f /etc/sai/sai.json.tmp


# Runtime
RUN mkdir -p /etc/vpp

COPY configs/vpp_veth_create.sh /usr/bin/vpp_veth_create.sh
COPY configs/startup.conf /etc/vpp/startup.conf
COPY configs/sai.profile       /etc/sai.d/sai.profile
COPY configs/lanemap.ini       /usr/share/sonic/hwsku/lanemap.ini
COPY configs/supervisord.conf  /etc/supervisor/conf.d/supervisord.conf

COPY configs/syncd_startup.sh /usr/bin/syncd_startup.sh
COPY configs/vpp_hostif_reset.sh /usr/bin/vpp_hostif_reset.sh


WORKDIR /sai-challenger/tests

CMD ["/usr/bin/supervisord"]