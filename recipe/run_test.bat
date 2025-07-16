setlocal EnableDelayedExpansion
echo on

echo "Testing %PKG_NAME%-%PKG_VERSION% ..."

:: e.g., PKG_VERSION_MINOR is 9.4
set PKG_VERSION_MINOR=%PKG_VERSION:~0,-2%

pip list | findstr "vtk"

REM Verify that pkg_resources can find VTK with the correct version (not "base")
echo "Verifying VTK package metadata..."
for /f %%i in ('python -c "import pkg_resources; print(pkg_resources.get_distribution('vtk').version)"') do set VTK_DETECTED_VERSION=%%i
echo "pkg_resources detected VTK version: %VTK_DETECTED_VERSION%"
if not "%VTK_DETECTED_VERSION%"=="%PKG_VERSION%" (
    echo "ERROR: pkg_resources detected wrong VTK version!"
    echo "Expected: %PKG_VERSION%"
    echo "Got: %VTK_DETECTED_VERSION%"
    exit 1
)
echo "OK: pkg_resources correctly detects VTK version %VTK_DETECTED_VERSION%"

if not exist %PREFIX%\\Library\\lib\\vtkGUISupportQt-%PKG_VERSION_MINOR%.lib exit 1
if not exist %PREFIX%\\Library\\bin\\vtkGUISupportQt-%PKG_VERSION_MINOR%.dll exit 1
if not exist %PREFIX%\\Library\\lib\\vtkRenderingQt-%PKG_VERSION_MINOR%.lib exit 1
if not exist %PREFIX%\\Library\\bin\\vtkRenderingQt-%PKG_VERSION_MINOR%.dll exit 1

python test_vtk.py
