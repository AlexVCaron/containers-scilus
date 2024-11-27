# ==============================================================================
# BASE IMAGES
# ==============================================================================

variable "base-install-image" { }

variable "base-build-image" { }

# ==============================================================================
# VERSIONS
# ==============================================================================

variable "mesa-version" { }

variable "vtk-version" { }

variable "python-version" { }

variable "cmake-revision" { }

variable "ants-revision" { }

# ==============================================================================
# CONTAINERS CONFIGURATION
# ==============================================================================

variable "python-wheels-local-version" {
    default = "scilus"
}

variable "wheelhouse-path" {
    default = "/wheelhouse"
}

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
    targets = ["vtk", "ants"]
}

target "vtk" {
    inherits = ["vtk-build"]
    target = "vtk"
    tags = ["vtk:local"]
    output = ["type=docker"]
}

target "ants" {
    inherits = ["ants-build"]
    target = "ants"
    tags = ["ants:local"]
    output = ["type=docker"]
}


# ==============================================================================
# BUILD TARGETS
# ==============================================================================


target "ants-build" {
    dockerfile = "ants.Dockerfile"
    context = "./containers"
    target = "ants-install"
    contexts = {
        ants-base = "docker-image://${base-install-image}"
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
    target = "vtk-install"
    contexts = {
        vtk-base = "docker-image://${base-install-image}"
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