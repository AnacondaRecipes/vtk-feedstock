setlocal EnableDelayedExpansion
echo on

echo "Testing %PKG_NAME%-%PKG_VERSION% ..."

:: e.g., PKG_VERSION_MINOR is 9.4
set PKG_VERSION_MINOR=%PKG_VERSION:~0,-2%

pip list | findstr "vtk"


if not exist %PREFIX%\\Library\\lib\\vtkGUISupportQt-%PKG_VERSION_MINOR%.lib exit 1
if not exist %PREFIX%\\Library\\bin\\vtkGUISupportQt-%PKG_VERSION_MINOR%.dll exit 1
if not exist %PREFIX%\\Library\\lib\\vtkRenderingQt-%PKG_VERSION_MINOR%.lib exit 1
if not exist %PREFIX%\\Library\\bin\\vtkRenderingQt-%PKG_VERSION_MINOR%.dll exit 1

%PYTHON% test_vtk.py
