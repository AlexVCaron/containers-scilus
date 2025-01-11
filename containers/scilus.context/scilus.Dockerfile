# syntax=docker.io/docker/dockerfile:1.7-labs

FROM scilus-base as scilus-build

RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    apt-get update && apt-get -y install \
        bc \
        git \
        locales \
        unzip \
        wget \
    && rm -rf /var/lib/apt/lists/*

ENV LC_CTYPE="en_US.UTF-8"
ENV LC_ALL="en_US.UTF-8"
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US.UTF-8"

WORKDIR /
RUN mkdir -p /etc/OpenCL/vendors && \
    echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd


FROM scilus-build as scilus-patch-scilpy

ARG SCILPY_REVISION
ARG PYTHON_VERSION
ARG WHEELHOUSE_PATH

ENV SCILPY_REVISION=${SCILPY_REVISION:-master}
ENV PYTHON_VERSION=${PYTHON_VERSION:-3.10}
ENV WHEELHOUSE_PATH=${WHEELHOUSE_PATH:-/wheelhouse}

WORKDIR /tmp
RUN wget https://github.com/scilus/scilpy/releases/download/${SCILPY_REVISION}/requirements.${SCILPY_REVISION}.frozen; \
    exit 0
RUN --mount=type=cache,sharing=locked,target=/root/.cache/pip \
    --mount=type=bind,from=vtk,source=${WHEELHOUSE_PATH},target=${WHEELHOUSE_PATH} \
    echo "en_US.UTF-8 UTF-8" | tee -a /etc/locale.gen && locale-gen && \
    python${PYTHON_VERSION} -m pip config --global set install.find-links ${WHEELHOUSE_PATH} && \
    if [ -f requirements.${SCILPY_REVISION}.frozen ]; \
    then \
        python${PYTHON_VERSION} -m pip install "packaging<22.0" "setuptools<=70.0" && \
        python${PYTHON_VERSION} -m pip install -r requirements.${SCILPY_REVISION}.frozen && \
        rm requirements.${SCILPY_REVISION}.frozen; \
    fi


FROM scilus-patch-scilpy as scilus

ARG FSL_INSTALL_PATH
ARG MRTRIX_INSTALL_PATH
ARG ANTS_INSTALL_PATH
ARG VTK_INSTALL_PATH
ARG MESA_INSTALL_PATH

ENV FSL_INSTALL_PATH=${FSL_INSTALL_PATH:-/fsl}
ENV MRTRIX_INSTALL_PATH=${MRTRIX_INSTALL_PATH:-/mrtrix}
ENV ANTS_INSTALL_PATH=${ANTS_INSTALL_PATH:-/ants}
ENV VTK_INSTALL_PATH=${VTK_INSTALL_PATH:-/vtk}
ENV MESA_INSTALL_PATH=${MESA_INSTALL_PATH:-/mesa}

ENV PATH=${MRTRIX_INSTALL_PATH}/bin:$PATH
ENV ANTSPATH=${ANTS_INSTALL_PATH}/bin/
ENV PATH=$PATH:$ANTSPATH

WORKDIR /
RUN ( [ -f "VERSION" ] || touch VERSION ) && \
    echo "Mesa => ${MESA_VERSION}\n" >> VERSION && \
    echo "VTK => ${VTK_VERSION}\n" >> VERSION && \
    echo "Mrtrix => ${MRTRIX_REVISION}\n" >> VERSION && \
    echo "ANTs => ${ANTS_REVISION}\n" >> VERSION && \
    echo "FSL => ${FSL_VERSION}\n" >> VERSION

ADD --link --chmod=666 human-data_master_1d3abfb.tar.bz2 /human-data

COPY --from=vtk --link ${MESA_INSTALL_PATH} ${MESA_INSTALL_PATH}
COPY --from=vtk --link ${VTK_INSTALL_PATH} ${VTK_INSTALL_PATH}
COPY --from=mrtrix --link ${MRTRIX_INSTALL_PATH} ${MRTRIX_INSTALL_PATH}
COPY --from=ants --link ${ANTS_INSTALL_PATH} ${ANTS_INSTALL_PATH}
COPY --from=fsl --link ${FSL_INSTALL_PATH} ${FSL_INSTALL_PATH}

WORKDIR /
RUN --mount=type=bind,from=vtk,source=/,target=/version_vtk \
    --mount=type=bind,from=mrtrix,source=/,target=/version_mrtrix \
    --mount=type=bind,from=ants,source=/,target=/version_ants \
    --mount=type=bind,from=fsl,source=/,target=/version_fsl \
    cat /version_vtk/VERSION >> VERSION && \
    cat /version_mrtrix/VERSION >> VERSION && \
    cat /version_ants/VERSION >> VERSION && \
    cat /version_fsl/VERSION >> VERSION
