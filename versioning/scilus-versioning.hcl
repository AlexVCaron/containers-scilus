# scilus-versioning.hcl

base-scilus-image="nvidia/cuda:9.2-runtime-ubuntu18.04"
base-build-image="ubuntu:18.04"

ants-version="2.3.4"
cmake-version="3.16.3"
dmriqcpy-version="0.1.6"
fsl-version="6.0.5.2"
mrtrix-version="3.0_RC3"
scilpy-version="1.4.0"
scilpy-requirements="requirements.1.4.0.frozen"
mesa-version="19.0.8"
vtk-version="8.2.0"
python-version="3.7"

dmriqcpy-test-base="scilus-base"
scilpy-test-base="scilus-scilpy"
vtk-test-base="scilus-vtk"