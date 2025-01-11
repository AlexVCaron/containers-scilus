# syntax=docker.io/docker/dockerfile:1.10.0

FROM alpine as mesa-stage

ARG MESA_VERSION

ENV MESA_VERSION=${MESA_VERSION:-19.0.8}

ADD --link https://archive.mesa3d.org/mesa-${MESA_VERSION}.tar.xz /mesa/mesa.tar.xz

WORKDIR /mesa
RUN tar -xJf mesa.tar.xz && \
    mv mesa-${MESA_VERSION}/* . && \
    rm -rf mesa.tar.xz mesa-${MESA_VERSION} && \
    mkdir build && \
    echo "[binaries]\nllvm-config = '/usr/bin/llvm-config'" >> llvm.ini


FROM alpine AS vtk-stage

ARG VTK_VERSION

ENV VTK_VERSION=${VTK_VERSION:-8.2.0}

ADD --chmod=644 --link https://gitlab.kitware.com/vtk/vtk/-/archive/v${VTK_VERSION}/vtk-v${VTK_VERSION}.tar.gz /vtk/vtk.tar.gz
ADD --chmod=644 --link patches/vtk-${VTK_VERSION}/ /vtk_patches/

WORKDIR /vtk
RUN tar -xzf vtk.tar.gz && \
    mv vtk-v${VTK_VERSION}/* vtk-v${VTK_VERSION}/.clang-tidy . && \
    cp /vtk_patches/vtkWheelPreparation.cmake CMake/. && \
    cp /vtk_patches/setup.py.in CMake/. && \
    rm -rf vtk.tar.gz vtk-v${VTK_VERSION}


FROM vtk-builder as mesa-build

ARG MESA_BUILD_NTHREADS
ARG MESA_INSTALL_PATH
ARG MESA_VERSION

ENV MESA_BUILD_NTHREADS=${MESA_BUILD_NTHREADS:-""}
ENV MESA_INSTALL_PATH=${MESA_INSTALL_PATH:-/mesa}
ENV MESA_VERSION=${MESA_VERSION:-19.0.8}

RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
        bison \
        build-essential \
        flex \
        gcc \
        git \
        glslang-tools \
        libclang-dev \
        libclc-dev \
        libdrm-dev \
        libexpat-dev \
        llvm-14 \
        llvm-14-dev \
        llvm-14-runtime \
        meson \
        python3-mako \
        zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /mesa_build
RUN --mount=type=bind,from=mesa-stage,source=/mesa,target=/mesa_source \
    meson setup \
        --native-file /mesa_source/llvm.ini \
        -Dprefix=${MESA_INSTALL_PATH} \
        -Dbuildtype=release \
        -Dshared-llvm=enabled \
        -Dopengl=true \
        -Dshared-glapi=enabled \
        -Ddri3=disabled \
        -Degl=disabled \
        -Dgbm=disabled \
        -Dgles1=disabled \
        -Dgles2=disabled \
        -Dglx=disabled \
        -Dglx-direct=false \
        -Dosmesa=true \
        -Dgallium-va=disabled \
        -Dgallium-vdpau=disabled \
        -Dgallium-xvmc=disabled \
        -Ddri-drivers=[] \
        -Dvulkan-drivers=[] \
        -Dplatforms=[] \
        -Dgallium-drivers=swrast \
        build /mesa_source || (cat build/meson-logs/meson-log.txt && exit 1) && \
    [ -z "$MESA_BUILD_NTHREADS" ] && \
        { ninja -C build/ -j $(nproc --all) install; } || \
        { ninja -C build/ -j ${MESA_BUILD_NTHREADS} install; }


FROM vtk-builder AS vtk-build

ARG MESA_INSTALL_PATH
ARG VTK_BUILD_NTHREADS
ARG VTK_BUILD_PATH
ARG VTK_INSTALL_PATH
ARG VTK_PYTHON_VERSION
ARG VTK_VERSION
ARG VTK_WHEEL_VERSION_LOCAL
ARG WHEELHOUSE_PATH

ENV MESA_INSTALL_PATH=${MESA_INSTALL_PATH:-/mesa}
ENV VTK_BUILD_NTHREADS=${VTK_BUILD_NTHREADS:-""}
ENV VTK_BUILD_PATH=${VTK_BUILD_PATH:-/vtk_build}
ENV VTK_INSTALL_PATH=${VTK_INSTALL_PATH:-/vtk}
ENV VTK_PYTHON_VERSION=${VTK_PYTHON_VERSION:-3.10}
ENV VTK_VERSION=${VTK_VERSION:-8.2.0}
ENV VTK_WHEEL_VERSION_LOCAL=${VTK_WHEEL_VERSION_LOCAL:-scilosmesa}
ENV WHEELHOUSE_PATH=${WHEELHOUSE_PATH:-/wheelhouse}

RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    if [ "${VTK_PYTHON_VERSION%%.*}" = "3" ]; then export PYTHON_MAJOR=3; fi && \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
        build-essential \
        gcc \
        git \
        llvm-14-runtime \
        libboost-all-dev \
        libopenmpi-dev \
        meson \
        ninja-build \
        pkg-config \
        python${PYTHON_MAJOR}-mako \
        python${PYTHON_MAJOR}-pip \
        python${PYTHON_MAJOR}-setuptools \
        python${VTK_PYTHON_VERSION} \
        python${VTK_PYTHON_VERSION}-dev \
        clang \
        wget \
        xorg-dev && \
    rm -rf /var/lib/apt/lists/*

ENV LD_LIBRARY_PATH=${MESA_INSTALL_PATH}/lib/x86_64-linux-gnu:${MESA_INSTALL_PATH}/lib:$LD_LIBRARY_PATH

WORKDIR /vtk_build
RUN --mount=type=bind,from=vtk-stage,source=/vtk,target=/vtk_source \
    --mount=type=bind,from=mesa-build,source=${MESA_INSTALL_PATH},target=${MESA_INSTALL_PATH} \
    mkdir ${VTK_INSTALL_PATH} ${WHEELHOUSE_PATH} && \
    if [ "${VTK_PYTHON_VERSION%%.*}" = "3" ]; then export PYTHON_MAJOR=3; fi && \
    cmake -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS:BOOL=ON \
        -DVTK_USE_CUDA:BOOL=OFF \
        -DVTK_USE_MPI:BOOL=ON \
        -DVTK_WRAP_PYTHON:BOOL=ON \
        -DVTK_PYTHON_VERSION:STRING=${PYTHON_MAJOR} \
        -DVTK_BUILD_EXAMPLES:BOOL=OFF \
        -DVTK_ENABLE_LOGGING:BOOL=ON \
        -DVTK_BUILD_TESTING:BOOL=OFF \
        -DVTK_ENABLE_KITS:BOOL=ON \
        -DVTK_ENABLE_WRAPPING:BOOL=ON \
        -DVTK_BUILD_DOCUMENTATION:BOOL=OFF \
        -DVTK_INSTALL_SDK:BOOL=OFF \
        -DVTK_RELOCATABLE_INSTALL:BOOL=ON \
        -DVTK_WHEEL_BUILD:BOOL=ON \
        -DVTK_DEBUG_LEAKS:BOOL=OFF \
        -DVTK_DEFAULT_RENDER_WINDOW_OFFSCREEN:BOOL=ON \
        -DVTK_GROUP_ENABLE_Qt:STRING=NO \
        -DVTK_GROUP_ENABLE_Views:STRING=NO \
        -DVTK_GROUP_ENABLE_Web:STRING=NO \
        -DVTK_ENABLE_REMOTE_MODULES:BOOL=OFF \
        -DVTK_MODULE_ENABLE_VTK_PythonInterpreter:STRING=NO \
        -DVTK_OPENGL_HAS_EGL:BOOL=OFF \
        -DVTK_OPENGL_HAS_OSMESA:BOOL=ON \
        -DVTK_OPENGL_USE_GLES:BOOL=OFF \
        -DVTK_REPORT_OPENGL_ERRORS:BOOL=OFF \
        -DVTK_REPORT_OPENGL_ERRORS_IN_RELEASE_BUILDS:BOOL=OFF \
        -DVTK_SMP_ENABLE_OPENMP:BOOL=ON \
        -DVTK_SMP_IMPLEMENTATION_TYPE:STRING=OpenMP \
        -DVTK_USE_SDL2:BOOL=OFF \
        -DVTK_USE_X:BOOL=OFF \
        -DVTK_PYTHON_OPTIONAL_LINK:BOOL=ON \
        -DVTK_BUILD_PYI_FILES:BOOL=ON \
        -DVTK_VERSION_SUFFIX= \
        -DVTK_DIST_NAME_SUFFIX= \
        -DVTK_VERSION_LOCAL=${VTK_WHEEL_VERSION_LOCAL} \
        -DPython{PYTHON_MAJOR}_EXECUTABLE:STRING=/usr/bin/python${VTK_PYTHON_VERSION} \
        -DPython${PYTHON_MAJOR}_INCLUDE_DIR:STRING=/usr/include/python${VTK_PYTHON_VERSION} \
        -DPython${PYTHON_MAJOR}_LIBRARY:STRING=/usr/lib/x86_64-linux-gnu/libpython${VTK_PYTHON_VERSION}.so \
        -DOSMESA_INCLUDE_DIR=${MESA_INSTALL_PATH}/include/ \
        -DOSMESA_LIBRARY=${MESA_INSTALL_PATH}/lib/x86_64-linux-gnu/libOSMesa.so \
        -DCMAKE_INSTALL_PREFIX=${VTK_INSTALL_PATH} \
        /vtk_source && \
    [ -z "$VTK_BUILD_NTHREADS" ] && \
        { ninja -j $(nproc --all); } || \
        { ninja -j ${VTK_BUILD_NTHREADS}; } && \
    ninja install && \
    python${PYTHON_MAJOR} setup.py bdist_wheel && \
    cp dist/vtk-${VTK_VERSION}+${VTK_WHEEL_VERSION_LOCAL}-cp310-cp310-linux_x86_64.whl ${WHEELHOUSE_PATH}/.

ENV VTK_DIR=${VTK_INSTALL_PATH}
ENV VTKPYTHONPATH=${VTK_DIR}/lib/python${VTK_PYTHON_VERSION}/site-packages:${VTK_DIR}/lib
ENV LD_LIBRARY_PATH=${VTK_DIR}/lib:$LD_LIBRARY_PATH
ENV PYTHONPATH=${PYTHONPATH}:${VTKPYTHONPATH}


FROM vtk-base as vtk-install

ARG CONTAINER_INSTALL_USER
ARG CONTAINER_RUN_USER
ARG MESA_INSTALL_PATH
ARG MESA_VERSION
ARG VTK_INSTALL_PATH
ARG VTK_PYTHON_VERSION
ARG VTK_VERSION
ARG WHEELHOUSE_PATH

ENV MESA_INSTALL_PATH=${MESA_INSTALL_PATH:-/mesa}
ENV MESA_VERSION=${MESA_VERSION:-19.0.8}
ENV VTK_INSTALL_PATH=${VTK_INSTALL_PATH:-/vtk}
ENV VTK_PYTHON_VERSION=${VTK_PYTHON_VERSION:-3.10}
ENV VTK_VERSION=${VTK_VERSION:-8.2.0}
ENV WHEELHOUSE_PATH=${WHEELHOUSE_PATH:-/wheelhouse}

ENV PYTHONNOUSERSITE=true
ENV VTK_DIR=${VTK_INSTALL_PATH}/build
ENV VTKPYTHONPATH=${VTK_DIR}/vtkmodules

ENV LD_LIBRARY_PATH=${VTK_DIR}/lib.linux-x86_64-${VTK_PYTHON_VERSION}/vtkmodules:${MESA_INSTALL_PATH}/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH 
ENV PYTHONPATH=${PYTHONPATH}:${VTKPYTHONPATH}

USER ${CONTAINER_INSTALL_USER:-0}

RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    if [ "${VTK_PYTHON_VERSION%%.*}" = "3" ]; then export PYTHON_MAJOR=3; fi && \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
        llvm-14-runtime \
        libopenmpi-dev \
        python${PYTHON_MAJOR}-mako \
        python${PYTHON_MAJOR}-pip \
        python${PYTHON_MAJOR}-setuptools \
        python${VTK_PYTHON_VERSION} \
        python${VTK_PYTHON_VERSION}-dev && \
    rm -rf /var/lib/apt/lists/*


FROM vtk-install as vtk

ARG MESA_INSTALL_PATH
ARG VTK_INSTALL_PATH
ARG VTK_PYTHON_VERSION
ARG VTK_VERSION
ARG MESA_VERSION
ARG WHEELHOUSE_PATH

ENV MESA_INSTALL_PATH=${MESA_INSTALL_PATH:-/mesa}
ENV VTK_INSTALL_PATH=${VTK_INSTALL_PATH:-/vtk}
ENV VTK_PYTHON_VERSION=${VTK_PYTHON_VERSION:-3.10}
ENV VTK_VERSION=${VTK_VERSION:-8.2.0}
ENV MESA_VERSION=${MESA_VERSION:-19.0.8}
ENV WHEELHOUSE_PATH=${WHEELHOUSE_PATH:-/wheelhouse}

WORKDIR /
RUN ( [ -f "VERSION" ] || touch VERSION ) && \
    echo "Mesa => ${MESA_VERSION}\n" >> VERSION && \
    echo "VTK => ${VTK_VERSION}\n" >> VERSION

COPY --from=mesa-build --link ${MESA_INSTALL_PATH} ${MESA_INSTALL_PATH}
COPY --from=vtk-build --link ${VTK_INSTALL_PATH} ${VTK_INSTALL_PATH}
COPY --from=vtk-build --link ${WHEELHOUSE_PATH} ${WHEELHOUSE_PATH}

WORKDIR /
RUN --mount=type=cache,sharing=locked,target=/root/.cache/pip \
    python${VTK_PYTHON_VERSION} -m pip config --global set install.find-links ${WHEELHOUSE_PATH} && \
    python${VTK_PYTHON_VERSION} -m pip install vtk==${VTK_VERSION}
