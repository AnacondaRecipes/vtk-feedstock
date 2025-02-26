
pip list | findstr "vtk"

if not exist %PREFIX%\\Library\\lib\\vtkGUISupportQt-{{ minor_version }}.lib exit 1
if not exist %PREFIX%\\Library\\bin\\vtkGUISupportQt-{{ minor_version }}.dll exit 1
if not exist %PREFIX%\\Library\\lib\\vtkRenderingQt-{{ minor_version }}.lib exit 1
if not exist %PREFIX%\\Library\\bin\\vtkRenderingQt-{{ minor_version }}.dll exit 1

%PYTHON% %RECIPE_DIR%/test_vtk.py