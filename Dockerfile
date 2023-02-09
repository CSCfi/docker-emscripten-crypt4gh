ARG EMSCRIPTEN_VERSION=3.1.31

# Build libsodium
FROM emscripten/emsdk:$EMSCRIPTEN_VERSION AS SODIUM

ARG LIBSODIUM_VERSION=1.0.18-stable

ADD https://download.libsodium.org/libsodium/releases/libsodium-${LIBSODIUM_VERSION}.tar.gz .

RUN tar xvf libsodium-${LIBSODIUM_VERSION}.tar.gz \
    && cd libsodium-stable \
    && dist-build/emscripten.sh --sumo

# Build openssl
FROM emscripten/emsdk:$EMSCRIPTEN_VERSION AS OPENSSL

ARG OPENSSL_VERSION=1.1.1t

ADD https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz .
ADD https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz.sha256 .

RUN bash -c 'if [[ $(sha256sum < openssl-${OPENSSL_VERSION}.tar.gz) != *$(cat openssl-${OPENSSL_VERSION}.tar.gz.sha256)* ]]; then echo $(sha256sum < openssl-${OPENSSL_VERSION}.tar.gz) $(curl https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz.sha256); echo Downloaded file checksum does not match. ; exit 1; fi' \
    && tar xvf openssl-${OPENSSL_VERSION}.tar.gz \
    && cd openssl-${OPENSSL_VERSION} \
    && emconfigure ./Configure linux-generic64 no-asm no-threads no-engine no-hw no-weak-ssl-ciphers no-dtls no-shared no-dso --prefix=/emsdk/upstream \
    && sed -i 's|^CROSS_COMPILE.*$|CROSS_COMPILE=|g' Makefile \
    && sed -i '/^CFLAGS/ s/$/ -D__STDC_NO_ATOMICS__=1/' Makefile \
    && sed -i '/^CXXFLAGS/ s/$/ -D__STDC_NO_ATOMICS__=1/' Makefile \
    && emmake make -j 2 all \
    && emmake make install

# Build libcrypt4gh
FROM emscripten/emsdk:$EMSCRIPTEN_VERSION AS LIBCRYPT4GH

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt \
    apt-get update -q \
    && apt-get upgrade -yq -o Dpkg::Options::="--force-confold" \
    && apt-get install -yq autoconf

COPY --from=SODIUM /src/libsodium-stable/libsodium-js-sumo/include/ /emsdk/upstream/include/
COPY --from=SODIUM /src/libsodium-stable/libsodium-js-sumo/lib/ /emsdk/upstream/lib/

ADD https://api.github.com/repos/cscfi/libcrypt4gh/compare/main...HEAD /dev/null
RUN git clone https://github.com/CSCfi/libcrypt4gh

# We'll skip linking libraries since emcc only produces static libraries
# Linking sodium at this point causes a linker conflict – thus cutting out $(LIBS)
RUN  export EMCC_CFLAGS="-I/emsdk/upstream/include -L/emsdk/upstream/lib" \
    && export LDFLAGS="-L/emsdk/upstream/lib" \
    && cd libcrypt4gh \
    && autoreconf --install \
    && sed -i 's/$(LIBS) //' Makefile.in \
    && emconfigure ./configure --prefix=/emsdk/upstream \
    && emmake make \
    && emmake make install

# Build libcrypt4gh-keys
FROM emscripten/emsdk:$EMSCRIPTEN_VERSION AS LIBCRYPT4GHKEYS

COPY --from=SODIUM /src/libsodium-stable/libsodium-js-sumo/include/ /emsdk/upstream/include/
COPY --from=SODIUM /src/libsodium-stable/libsodium-js-sumo/lib/ /emsdk/upstream/lib/

COPY --from=OPENSSL /emsdk/upstream/include/ /emsdk/upstream/include/
COPY --from=OPENSSL /emsdk/upstream/lib/ /emsdk/upstream/lib/

RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt \
    apt-get update -q \
    && apt-get upgrade -yq -o Dpkg::Options::="--force-confold" \
    && apt-get install -yq autoconf build-essential

ADD https://api.github.com/repos/cscfi/libcrypt4gh-keys/compare/main...HEAD /dev/null
RUN git clone https://github.com/CSCfi/libcrypt4gh-keys.git

# We'll skip linking libraries since emcc only produces static libraries
# Linking sodium at this point causes a linker conflict – thus cutting out $(LIBS)
RUN export EMCC_CFLAGS="-I/emsdk/upstream/include -L/emsdk/upstream/lib" \
    && export LDFLAGS="-L/emsdk/upstream/lib" \
    && cd libcrypt4gh-keys \
    && autoreconf --install \
    && sed -i 's/$(LIBS) //' Makefile.in \
    && emconfigure ./configure --prefix=/emsdk/upstream --with-openssl=/emsdk/upstream \
    && emmake make \
    && emmake make install

# Build wasm application
FROM emscripten/emsdk:$EMSCRIPTEN_VERSION AS WASMCRYPT

LABEL maintainer="CSC Developers"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-url="https://github.com/CSCfi/docker-emscripten-crypt4gh"

COPY --from=SODIUM /src/libsodium-stable/libsodium-js-sumo/include/ /emsdk/upstream/include/
COPY --from=SODIUM /src/libsodium-stable/libsodium-js-sumo/lib/ /emsdk/upstream/lib/

COPY --from=LIBCRYPT4GH /emsdk/upstream/include/ /emsdk/upstream/include/
COPY --from=LIBCRYPT4GH /emsdk/upstream/lib/ /emsdk/upstream/lib/

COPY --from=LIBCRYPT4GHKEYS /emsdk/upstream/include/ /emsdk/upstream/include/
COPY --from=LIBCRYPT4GHKEYS /emsdk/upstream/lib/ /emsdk/upstream/lib/

COPY build_wasm.sh /bin/build_wasm.sh

ENTRYPOINT ["/bin/build_wasm.sh"]
CMD ["all"]
