# syntax=docker/dockerfile:1.4

FROM mrtrix-builder as mrtrix

ARG MRTRIX_BUILD_NTHREADS
ARG MRTRIX_VERSION

ENV MRTRIX_BUILD_NTHREADS=${MRTRIX_BUILD_NTHREADS:-""}
ENV MRTRIX_VERSION=${MRTRIX_VERSION:-3.0_RC3}

RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    apt-get update && apt-get -y install \
        build-essential \
        clang \
        git \
        libeigen3-dev \
        libfftw3-dev \
        libpng-dev \
        libtiff5-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /
RUN git clone https://github.com/MRtrix3/mrtrix3.git

WORKDIR /mrtrix3
RUN git fetch --tags && \
    git checkout tags/${MRTRIX_VERSION} -b ${MRTRIX_VERSION}

RUN ./configure -nogui -openmp && \
    [ -z "$MRTRIX_BUILD_NTHREADS" ] && \
        { NUMBER_OF_PROCESSORS=$(nproc --all) ./build; } || \
        { NUMBER_OF_PROCESSORS=${MRTRIX_BUILD_NTHREADS} ./build; }

FROM mrtrix-base as mrtrix-install

ARG MRTRIX_INSTALL_PATH
ARG MRTRIX_VERSION

ENV MRTRIX_INSTALL_PATH=${MRTRIX_INSTALL_PATH:-/mrtrix3_install}
ENV MRTRIX_VERSION=${MRTRIX_VERSION:-3.0_RC3}

ENV PATH=${MRTRIX_INSTALL_PATH}/bin:$PATH

RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    apt-get update && apt-get -y install \
        libeigen3-dev \
        libfftw3-dev \
        libomp-dev \
        libpng-dev \
        libtiff5-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /
COPY --from=mrtrix --link /mrtrix3 ${MRTRIX_INSTALL_PATH}
RUN touch VERSION && \
    echo "Mrtrix => ${MRTRIX_VERSION}\n" >> VERSION