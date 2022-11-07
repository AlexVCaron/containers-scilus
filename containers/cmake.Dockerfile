# syntax=docker/dockerfile:1.4

FROM cmake-builder AS cmake

ARG CMAKE_BUILD_NTHREADS
ARG CMAKE_VERSION

ENV CMAKE_BUILD_NTHREADS=${CMAKE_BUILD_NTHREADS:-""}
ENV CMAKE_VERSION=${CMAKE_VERSION:-3.16.3}

RUN apt-get update && \
    apt-get -y install \
        build-essential \
        libssl-dev \
        linux-headers-generic \
        wget && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN mkdir -p cmake

WORKDIR /tmp/cmake
RUN wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz && \
    tar -xzf cmake-${CMAKE_VERSION}.tar.gz

WORKDIR /tmp/cmake/cmake-${CMAKE_VERSION}
RUN if [ "$CMAKE_BUILD_NTHREADS" = "" ]; then export CMAKE_BUILD_NTHREADS="$(nproc --all)"; fi && \
    ./bootstrap && \
    make -j ${CMAKE_BUILD_NTHREADS} && \
    make install

WORKDIR /tmp
RUN rm -rf cmake

WORKDIR /
RUN touch VERSION && \
    echo "CMake => ${CMAKE_VERSION}\n" >> VERSION
