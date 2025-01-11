# syntax=docker.io/docker/dockerfile:1.7-labs

FROM scratch as mrtrix-stage

ADD --exclude=testing/* --link https://github.com/MRtrix3/mrtrix3.git#${MRTRIX_REVISION} /mrtrix


FROM mrtrix-builder as mrtrix-build

ARG MRTRIX_BUILD_NTHREADS
ARG MRTRIX_REVISION
ARG MRTRIX_INSTALL_PATH

ENV MRTRIX_INSTALL_PATH=${MRTRIX_INSTALL_PATH:-/mrtrix}
ENV MRTRIX_BUILD_NTHREADS=${MRTRIX_BUILD_NTHREADS:-""}
ENV MRTRIX_REVISION=${MRTRIX_REVISION:-3.0_RC3}

RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    apt-get update && apt-get -y install \
        build-essential \
        clang \
        git \
        libeigen3-dev \
        libfftw3-dev \
        libomp-dev \
        libpng-dev \
        libtiff5-dev \
        python-is-python3 \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

ADD --exclude=testing/* --link https://github.com/MRtrix3/mrtrix3.git#${MRTRIX_REVISION} /mrtrix_source

WORKDIR /mrtrix_source
RUN ./configure -nogui && \
    [ -z "$MRTRIX_BUILD_NTHREADS" ] && \
        { NUMBER_OF_PROCESSORS=$(nproc --all) ./build; } || \
        { NUMBER_OF_PROCESSORS=${MRTRIX_BUILD_NTHREADS} ./build; }

WORKDIR ${MRTRIX_INSTALL_PATH}/bin
RUN cp -r /mrtrix_source/bin/* .

WORKDIR ${MRTRIX_INSTALL_PATH}/lib
RUN cp -r /mrtrix_source/lib/* .

WORKDIR ${MRTRIX_INSTALL_PATH}/share
RUN cp -r /mrtrix_source/share/* .

FROM mrtrix-base as mrtrix-install

RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    apt-get update && apt-get -y install \
        libeigen3-dev \
        libfftw3-dev \
        libomp-dev \
        libpng-dev \
        libtiff5-dev \
        python-is-python3 \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*


FROM mrtrix-install as mrtrix

ARG MRTRIX_INSTALL_PATH
ARG MRTRIX_REVISION

ENV MRTRIX_INSTALL_PATH=${MRTRIX_INSTALL_PATH:-/mrtrix}
ENV MRTRIX_REVISION=${MRTRIX_REVISION:-3.0_RC3}

ENV PATH=${MRTRIX_INSTALL_PATH}/bin:$PATH

WORKDIR /
RUN ( [ -f "VERSION" ] || touch VERSION ) && \
    echo "Mrtrix => ${MRTRIX_REVISION}\n" >> VERSION

COPY --from=mrtrix-build --link ${MRTRIX_INSTALL_PATH} ${MRTRIX_INSTALL_PATH}
