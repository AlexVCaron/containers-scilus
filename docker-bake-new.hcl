# ==============================================================================
# BASE IMAGES
# ==============================================================================

variable "base-distribution-image" { }

variable "base-build-image" { }

# ==============================================================================
# VERSIONS
# ==============================================================================

variable "mrtrix-revision" { }

variable "dmriqcpy-revision" { }

variable "java-version" { }

variable "fsl-installer-version" { }

variable "fsl-version" { }

variable "nextflow-version" { }

variable "scilpy-revision" { }

variable "mesa-version" { }

variable "vtk-version" { }

variable "python-version" { }

variable "cmake-revision" { }

variable "ants-revision" { }

# ==============================================================================
# FLOWS VERSIONS
# ==============================================================================

variable "tractoflow-version" { }

variable "dmriqcflow-version" { }

variable "extractorflow-version" { }

variable "rbxflow-version" { }

variable "tractometryflow-version" { }

variable "registerflow-version" { }

variable "disconetsflow-version" { }

variable "freewaterflow-version" { }

variable "noddiflow-version" { }

variable "bstflow-version" { }

# ==============================================================================
# CONTAINERS CONFIGURATION
# ==============================================================================

variable "python-wheels-local-version" {
    default = "scilus"
}

variable "wheelhouse-path" {
    default = "/wheelhouse"
}

variable "itk-num-threads" { }

variable "blas-num-threads" { }

# ==============================================================================
# CACHE CONFIGURATION
# ==============================================================================

variable "cache-repository" {
    default = "scilus"
}

# ==============================================================================
# DISTRIBUTION TARGETS
# ==============================================================================

group "scilus" {
    targets = ["scilus"]
}

group "scilus-flows" {
    targets = ["scilus-flows"]
}

group "dmriqcpy" {
    targets = ["dmriqcpy"]
}

group "scilpy" {
    targets = ["scilpy"]
}

group "nextflow" {
    targets = ["nextflow"]
}

group "dependencies" {
    targets = ["vtk", "ants", "fsl", "mrtrix"]
}

target "scilus-flows" {
    inherits = ["scilus-flows-build"]
    target = "scilus-flows"
    tags = ["scilus-flows:local"]
    output = ["type=docker"]
}

target "nextflow" {
    inherits = ["nextflow-build"]
    target = "nextflow"
    tags = ["nextflow:local"]
    output = ["type=docker"]
}

target "scilus" {
    inherits = ["scilus-build"]
    target = "scilus"
    tags = ["scilus:local"]
    output = ["type=docker"]
}

target "scilpy" {
    inherits = ["scilpy-build"]
    contexts = {
        scilpy-base = "target:vtk"
    }
    target = "scilpy"
    tags = ["scilpy:local"]
    output = ["type=docker"]
}

target "dmriqcpy" {
    inherits = ["dmriqcpy-build"]
    contexts = {
        dmriqcpy-base = "target:vtk"
    }
    target = "dmriqcpy"
    tags = ["dmriqcpy:local"]
    output = ["type=docker"]
}

target "mrtrix" {
    inherits = ["mrtrix-build"]
    target = "mrtrix"
    tags = ["mrtrix:local"]
    output = ["type=docker"]
}

target "ants" {
    inherits = ["ants-build"]
    target = "ants"
    tags = ["ants:local"]
    output = ["type=docker"]
}

target "fsl" {
    inherits = ["fsl-build"]
    target = "fsl"
    tags = ["fsl:local"]
    output = ["type=docker"]
}

target "vtk" {
    inherits = ["vtk-build"]
    target = "vtk"
    tags = ["vtk:local"]
    output = ["type=docker"]
}


# ==============================================================================
# SCILUS COMPOSITE TARGETS
# ==============================================================================

target "scilus-flows-build" {
    dockerfile = "scilus-flows.Dockerfile"
    context = "./containers"
    target = "scilus-flows"
    contexts = {
        scilus-flows-base = "target:scilus-nextflow"
    }
    args = {
        TRACTOFLOW_VERSION = "${tractoflow-version}"
        DMRIQCFLOW_VERSION = "${dmriqcflow-version}"
        EXTRACTORFLOW_VERSION = "${extractorflow-version}"
        RBXFLOW_VERSION = "${rbxflow-version}"
        TRACTOMETRYFLOW_VERSION = "${tractometryflow-version}"
        REGISTERFLOW_VERSION = "${registerflow-version}"
        DISCONETSFLOW_VERSION = "${disconetsflow-version}"
        FREEWATERFLOW_VERSION = "${freewaterflow-version}"
        NODDIFLOW_VERSION = "${noddiflow-version}"
        BSTFLOW_VERSION = "${bstflow-version}"
    }
}

target "scilus-nextflow" {
    inherits = ["nextflow"]
    contexts = {
        nextflow-base = "target:scilus"
    }
}

target "scilus-build" {
    dockerfile = "scilus.Dockerfile"
    context = "./containers/scilus.context"
    target = "scilus-build"
    contexts = {
        scilus-base = "target:scilus-scilpy"
        vtk = "target:vtk"
        mrtrix = "target:mrtrix"
        ants = "target:ants"
        fsl = "target:fsl"
    }
    args = {
        PYTHON_VERSION = "${python-version}"
        SCILPY_REVISION = "${scilpy-revision}"
        BLAS_NUM_THREADS = "${blas-num-threads}"
        PYTHON_PACKAGE_DIR = "dist-packages"
    }
    output = ["type=cacheonly"]
}

target "scilus-scilpy" {
    inherits = ["scilpy-build"]
    contexts = {
        scilpy-base = "target:scilus-dmriqcpy"
    }
}

target "scilus-dmriqcpy" {
    inherits = ["dmriqcpy-build"]
    contexts = {
        dmriqcpy-base = "target:scilus-mrtrix"
    }
}

target "scilus-mrtrix"{
    inherits = ["mrtrix-build"]
    contexts = {
        mrtrix-base = "target:scilus-ants"
    }
    target = "mrtrix-install"
}

target "scilus-ants"{
    inherits = ["ants-build"]
    contexts = {
        ants-base = "target:scilus-fsl"
    }
    target = "ants-install"
}

target "scilus-fsl"{
    inherits = ["fsl-build"]
    contexts = {
        fsl-base = "target:scilus-vtk"
    }
    target = "fsl-install"
}

target "scilus-vtk"{
    inherits = ["vtk-build"]
    target = "vtk-install"
}

# ==============================================================================
# BUILD TARGETS
# ==============================================================================

target "nextflow-build" {
    dockerfile = "nextflow.Dockerfile"
    context = "./containers"
    target = "nextflow"
    contexts = {
        nextflow-base = "docker-image://${base-build-image}"
    }
    args = {
        NEXTFLOW_VERSION = "${nextflow-version}"
        JAVA_VERSION = "${java-version}"
    }
    output = ["type=cacheonly"]
}

target "scilpy-build" {
    dockerfile = "scilpy.Dockerfile"
    context = "./containers/scilpy.context"
    target = "scilpy"
    contexts = {
        scilpy-base = "target:distribution-build"
    }
    args = {
        PYTHON_VERSION = "${python-version}"
        SCILPY_REVISION = "${scilpy-revision}"
        BLAS_NUM_THREADS = "${blas-num-threads}"
        PYTHON_PACKAGE_DIR = "dist-packages"
    }
    output = ["type=cacheonly"]
}

target "dmriqcpy-build" {
    dockerfile = "dmriqcpy.Dockerfile"
    context = "./containers/dmriqcpy.context"
    target = "dmriqcpy"
    contexts = {
        dmriqcpy-base = "target:distribution-build"
    }
    args = {
        PYTHON_VERSION = "${python-version}"
        DMRIQCPY_REVISION = "${dmriqcpy-revision}"
        PYTHON_PACKAGE_DIR = "dist-packages"
    }
    output = ["type=cacheonly"]
}

target "mrtrix-build" {
    dockerfile = "mrtrix.Dockerfile"
    context = "./containers"
    target = "mrtrix"
    contexts = {
        mrtrix-base = "target:distribution-build"
        mrtrix-builder = "docker-image://${base-build-image}"
    }
    args = {
        MRTRIX_BUILD_NTHREADS = "6"
        MRTRIX_REVISION = "${mrtrix-revision}"
    }
    output = ["type=cacheonly"]
}

target "fsl-build" {
    dockerfile = "fsl.Dockerfile"
    context = "./containers/fsl.context"
    target = "fsl"
    contexts = {
        fsl-base = "target:distribution-build"
        fsl-builder = "docker-image://${base-build-image}"
    }
    args = {
        FSL_VERSION = "${fsl-version}"
        FSL_INSTALLER_VERSION = "${fsl-installer-version}"
    }
    output = ["type=cacheonly"]
}

target "ants-build" {
    dockerfile = "ants.Dockerfile"
    context = "./containers"
    target = "ants"
    contexts = {
        ants-base = "target:distribution-build"
        ants-builder = "target:cmake-build"
    }
    args = {
        ANTS_BUILD_NTHREADS = "6"
        ANTS_REVISION = "${ants-revision}"
    }
    output = ["type=cacheonly"]
}

target "vtk-build" {
    dockerfile = "vtk-omesa.Dockerfile"
    context = "./containers/vtk-omesa.context/"
    target = "vtk"
    contexts = {
        vtk-base = "target:distribution-build"
        vtk-builder = "target:cmake-build"
    }
    args = {
        MESA_BUILD_NTHREADS = "6"
        MESA_VERSION = "${mesa-version}"
        VTK_BUILD_NTHREADS = "6"
        VTK_PYTHON_VERSION = "${python-version}"
        VTK_VERSION = "${vtk-version}"
        VTK_WHEEL_VERSION_LOCAL = "${python-wheels-local-version}osmesa"
        WHEELHOUSE_PATH = "${wheelhouse-path}"
    }
    output = ["type=cacheonly"]
}

target "cmake-build" {
    dockerfile = "cmake.Dockerfile"
    context = "./containers"
    target = "cmake"
    contexts = {
        cmake-builder = "docker-image://${base-build-image}"
    }
    args = {
        CMAKE_BUILD_NTHREADS = "6"
        CMAKE_REVISION = "${cmake-revision}"
    }
    output = ["type=cacheonly"]
}

target "distribution-build" {
    dockerfile = "base.Dockerfile"
    context = "./containers"
    target = "base"
    contexts = {
        base-image = "docker-image://${base-distribution-image}"
    }
    args = {
        ITK_NUM_THREADS = "${itk-num-threads}"
        OPENBLAS_NUM_THREADS = "${blas-num-threads}"
        PYTHON_VERSION = "${python-version}"
    }
    output = ["type=cacheonly"]
}
