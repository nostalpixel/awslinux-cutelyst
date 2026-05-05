ARG QT_VERSION=6.8.3
ARG CUTELEE_REF=v6.2.0
ARG CUTELYST_REF=v5.0.1

# Qt is installed to this fixed path in every stage
ARG QT_PREFIX=/opt/qt6

###############################################################################
# Stage 1 – build Qt 6 from source (qtbase + qttools)
#
# Cutelyst v5 requires C++23; GCC 14 is the only C++23-capable compiler
# shipped by Amazon Linux 2023 (default is GCC 11).
###############################################################################
FROM amazonlinux:2023 AS qt-builder
ARG QT_VERSION
ARG QT_PREFIX

ENV CC=gcc14-gcc \
    CXX=gcc14-g++

RUN dnf install -y \
        gcc14 gcc14-c++ \
        cmake ninja-build \
        perl python3 \
        tar xz \
        openssl-devel \
        zlib-devel \
        libzstd-devel \
        libicu-devel \
        freetype-devel \
        harfbuzz-devel \
        libpng-devel \
        libjpeg-turbo-devel \
        mesa-libGL-devel \
    && dnf clean all

# Fetch qtbase, qtdeclarative, and qttools source archives
RUN mkdir -p /src && \
    curl -fsSL "https://download.qt.io/official_releases/qt/6.8/${QT_VERSION}/submodules/qtbase-everywhere-src-${QT_VERSION}.tar.xz" \
         -o /tmp/qtbase.tar.xz && \
    tar -xf /tmp/qtbase.tar.xz -C /src && rm /tmp/qtbase.tar.xz && \
    curl -fsSL "https://download.qt.io/official_releases/qt/6.8/${QT_VERSION}/submodules/qtdeclarative-everywhere-src-${QT_VERSION}.tar.xz" \
         -o /tmp/qtdeclarative.tar.xz && \
    tar -xf /tmp/qtdeclarative.tar.xz -C /src && rm /tmp/qtdeclarative.tar.xz && \
    curl -fsSL "https://download.qt.io/official_releases/qt/6.8/${QT_VERSION}/submodules/qttools-everywhere-src-${QT_VERSION}.tar.xz" \
         -o /tmp/qttools.tar.xz && \
    tar -xf /tmp/qttools.tar.xz -C /src && rm /tmp/qttools.tar.xz

# ── qtbase ───────────────────────────────────────────────────────────────────
RUN cmake -S /src/qtbase-everywhere-src-${QT_VERSION} -B /build/qtbase -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${QT_PREFIX} \
        -DQT_BUILD_EXAMPLES=OFF \
        -DQT_BUILD_TESTS=OFF \
        -DFEATURE_dbus=OFF \
        -DFEATURE_xcb=OFF \
        -DFEATURE_opengl=OFF \
        -DFEATURE_egl=OFF \
        -DFEATURE_vulkan=OFF \
        -DFEATURE_icu=ON \
        -DFEATURE_openssl=ON \
        -DFEATURE_system_pcre2=OFF \
    && cmake --build /build/qtbase -j"$(nproc)" \
    && cmake --install /build/qtbase \
    && rm -rf /build/qtbase /src/qtbase-everywhere-src-${QT_VERSION}

# ── qtdeclarative (QJSEngine required by Cutelee template engine) ────────────
RUN cmake -S /src/qtdeclarative-everywhere-src-${QT_VERSION} -B /build/qtdeclarative -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${QT_PREFIX} \
        -DCMAKE_PREFIX_PATH=${QT_PREFIX} \
        -DQT_BUILD_EXAMPLES=OFF \
        -DQT_BUILD_TESTS=OFF \
        -DFEATURE_qml_debug=OFF \
        -DFEATURE_quick=OFF \
        -DFEATURE_quickcontrols2=OFF \
        -DFEATURE_quicktemplates2=OFF \
    && cmake --build /build/qtdeclarative -j"$(nproc)" \
    && cmake --install /build/qtdeclarative \
    && rm -rf /build/qtdeclarative /src/qtdeclarative-everywhere-src-${QT_VERSION}

# ── qttools (only lrelease/lupdate/lconvert needed by Cutelyst cmake) ────────
RUN cmake -S /src/qttools-everywhere-src-${QT_VERSION} -B /build/qttools -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${QT_PREFIX} \
        -DCMAKE_PREFIX_PATH=${QT_PREFIX} \
        -DQT_BUILD_EXAMPLES=OFF \
        -DQT_BUILD_TESTS=OFF \
        -DFEATURE_assistant=OFF \
        -DFEATURE_designer=OFF \
        -DFEATURE_distancefieldgenerator=OFF \
        -DFEATURE_kmap2qmap=OFF \
        -DFEATURE_pixeltool=OFF \
        -DFEATURE_qdbus=OFF \
        -DFEATURE_qdoc=OFF \
        -DFEATURE_qtattributionsscanner=OFF \
        -DFEATURE_qtdiag=OFF \
        -DFEATURE_qtplugininfo=OFF \
    && cmake --build /build/qttools -j"$(nproc)" \
    && cmake --install /build/qttools \
    && rm -rf /build/qttools /src/qttools-everywhere-src-${QT_VERSION}

###############################################################################
# Stage 2 – build Cutelee and Cutelyst against the Qt we just compiled
###############################################################################
FROM amazonlinux:2023 AS builder
ARG QT_VERSION
ARG QT_PREFIX
ARG CUTELEE_REF
ARG CUTELYST_REF

ENV CC=gcc14-gcc \
    CXX=gcc14-g++ \
    PATH="${QT_PREFIX}/bin:${PATH}" \
    CMAKE_PREFIX_PATH="${QT_PREFIX}" \
    LD_LIBRARY_PATH="${QT_PREFIX}/lib"

RUN dnf install -y \
        gcc14 gcc14-c++ \
        ninja-build git \
        openssl-devel \
        zlib-devel \
        libzstd-devel \
        libicu-devel \
        brotli-devel \
        perl \
        python3 python3-pip \
    && pip3 install --quiet cmake \
    && dnf clean all

COPY --from=qt-builder ${QT_PREFIX} ${QT_PREFIX}

# ── Cutelee ──────────────────────────────────────────────────────────────────
RUN git clone --depth 1 --branch "${CUTELEE_REF}" \
        https://github.com/cutelyst/cutelee /src/cutelee && \
    cmake -S /src/cutelee -B /build/cutelee -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_TESTS=OFF && \
    cmake --build /build/cutelee -j"$(nproc)" && \
    cmake --install /build/cutelee && \
    rm -rf /src/cutelee /build/cutelee

# ── Cutelyst ─────────────────────────────────────────────────────────────────
RUN git clone --depth 1 --branch "${CUTELYST_REF}" \
        https://github.com/cutelyst/cutelyst /src/cutelyst && \
    cmake -S /src/cutelyst -B /build/cutelyst -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_PREFIX_PATH="${QT_PREFIX};/usr/local" \
        -DPLUGIN_VIEW_CUTELEE=ON \
        -DBUILD_TESTS=OFF && \
    cmake --build /build/cutelyst -j"$(nproc)" && \
    cmake --install /build/cutelyst && \
    rm -rf /src/cutelyst /build/cutelyst

###############################################################################
# Stage 3 – dev / build-base  (FROM this to compile your Cutelyst app)
###############################################################################
FROM builder AS dev
# Inherits full toolchain + Qt headers + Cutelee/Cutelyst headers & cmake files

###############################################################################
# Stage 4 – lean runtime image
###############################################################################
FROM amazonlinux:2023 AS runtime
ARG QT_PREFIX

# gcc14 provides the libstdc++ version that our GCC-14-compiled .so files need
RUN dnf install -y \
        gcc14 \
        openssl-libs \
        zlib \
        libicu \
        libzstd \
        freetype \
        harfbuzz \
        libpng \
        libjpeg-turbo \
        mesa-libGL \
        brotli \
    && dnf clean all

# Qt shared libraries + plugins (structure kept intact for plugin discovery)
COPY --from=builder ${QT_PREFIX}/lib     ${QT_PREFIX}/lib
COPY --from=builder ${QT_PREFIX}/plugins ${QT_PREFIX}/plugins

# Cutelee + Cutelyst shared libraries
COPY --from=builder /usr/local/lib   /usr/local/lib
COPY --from=builder /usr/local/lib64 /usr/local/lib64

ENV QT_ROOT=${QT_PREFIX}
ENV LD_LIBRARY_PATH="${QT_PREFIX}/lib:/usr/local/lib:/usr/local/lib64"
ENV QT_PLUGIN_PATH="${QT_PREFIX}/plugins"
# No display available in a container; offscreen is the safe default
ENV QT_QPA_PLATFORM=offscreen

RUN printf '%s\n' "${QT_PREFIX}/lib" '/usr/local/lib' '/usr/local/lib64' \
        > /etc/ld.so.conf.d/qt6-cutelyst.conf && \
    ldconfig

CMD ["/bin/bash"]
