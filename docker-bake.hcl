# docker-bake.hcl

variable "base-install-image" {
    default = "nvidia/cuda:9.2-runtime-ubuntu18.04"
}

variable "base-build-image" {
    default = "ubuntu:18.04"
}

variable "base-python-image" {
    default = "python:3.7.15-buster"
}

group "scilus" {
    targets = ["scilus"]
}

group "scilus-base" {
    targets = ["scilus-base"]
}

group "scilpy" {
    targets = ["scilpy"]
}

group "dmriqcpy" {
    targets = ["dmriqcpy"]
}

target "scilus" {
    dockerfile = "scilus.Dockerfile"
    context = "./containers/scilus.context/"
    target = "scilus"
    contexts = {
        scilus-base = "target:scilus-scilpy"
    }
    output = ["type=image"]
}

target "scilus-scilpy" {
    inherits = ["scilpy"]
    contexts = {
        scilpy-base = "target:scilus-base"
    }
    output = ["type=cacheonly"]
}

target "scilpy" {
    dockerfile = "scilpy.Dockerfile"
    context = "./containers"
    contexts = {
        scilpy-base = "docker-image://${base-python-image}"
    }
    output = ["type=image"]
}

target "scilus-base" {
    inherits = ["dmriqcpy"]
    contexts = {
        dmriqcpy-base = "target:scilus-vtk"
    }
    tags = ["docker.io/avcaron/scilus-base:dev"]
    cache-from = ["avcaron/scilus-base:dev"]
    pull = true
}

target "scilus-vtk" {
    inherits = ["vtk"]
    contexts = {
        vtk-base = "target:scilus-python"
    }
    output = ["type=cacheonly"]
}

target "scilus-python" {
    dockerfile = "scilus-python.Dockerfile"
    context = "./containers"
    contexts = {
        python-base = "target:fsl"
    }
    output = ["type=cacheonly"]
}

target "dmriqcpy" {
    dockerfile = "dmriqcpy.Dockerfile"
    context = "./containers"
    contexts = {
        dmriqcpy-base = "target:vtk"
    }
    output = ["type=image"]
}

target "fsl" {
    dockerfile = "fsl.Dockerfile"
    context = "./containers"
    target = "fsl-install"
    contexts = {
        fsl-base = "target:mrtrix"
        fsl-builder = "docker-image://${base-build-image}"
    }
    output = ["type=cacheonly"]
}

target "mrtrix" {
    dockerfile = "mrtrix.Dockerfile"
    context = "./containers"
    target = "mrtrix-install"
    contexts = {
        mrtrix-base = "target:ants"
        mrtrix-builder = "docker-image://${base-build-image}"
    }
    output = ["type=cacheonly"]
}

target "ants" {
    dockerfile = "ants.Dockerfile"
    context = "./containers"
    target = "ants-install"
    contexts = {
        ants-base = "docker-image://${base-install-image}"
        ants-builder = "target:cmake"
    }
    output = ["type=cacheonly"]
}

target "vtk" {
    dockerfile = "vtk-omesa.Dockerfile"
    context = "./containers/vtk-omesa.context/"
    target = "vtk-install"
    contexts = {
        vtk-base = "docker-image://${base-python-image}"
        vtk-builder = "target:cmake"
    }
    output = ["type=cacheonly"]
}

target "cmake" {
    dockerfile = "cmake.Dockerfile"
    context = "./containers"
    target = "cmake"
    contexts = {
        cmake-builder = "docker-image://${base-build-image}"
    }
    output = ["type=cacheonly"]
}