

def test_vtk_is_installed():
    import vtk


def test_vtk_version_matches():
    import os
    import vtk

    version = vtk.vtkVersion()
    env_version = os.environ['VTK_VERSION']

    assert version.GetVTKVersion() == env_version, \
        "Installed VTK python package version ({}) "
        "does not match installed binaries ({})".format(
            version, env_version
        )
