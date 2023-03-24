import os
import pkg_resources
import subprocess
import sys
import vtk

import vtk.vtkChartsCore
import vtk.vtkCommonCore
import vtk.vtkFiltersCore
import vtk.vtkFiltersGeneric
import vtk.vtkGeovisCore
import vtk.vtkFiltersHybrid
import vtk.vtkIOCore
import vtk.vtkImagingCore
import vtk.vtkInfovisCore
import vtk.vtkRenderingCore
import vtk.vtkViewsCore
import vtk.vtkRenderingVolume
import vtk.vtkInteractionWidgets
if sys.platform == 'linux' or sys.platform == 'darwin':
    import vtk.vtkWebGLExporter
import vtk.tk.vtkTkRenderWidget
import vtkmodules
import vtkmodules.vtkChartsCore
import vtkmodules.vtkCommonCore
import vtkmodules.vtkFiltersCore
import vtkmodules.vtkFiltersGeneric
import vtkmodules.vtkGeovisCore
import vtkmodules.vtkFiltersHybrid
import vtkmodules.vtkIOCore
import vtkmodules.vtkImagingCore
import vtkmodules.vtkInfovisCore
import vtkmodules.vtkRenderingCore
import vtkmodules.vtkViewsCore
import vtkmodules.vtkRenderingVolume
import vtkmodules.vtkInteractionWidgets

def render_enabled():
    # The test hangs with VTK_WITH_OSMESA enabled.
    if os.environ.get('VTK_WITH_OSMESA') == 'True':
        return False

    # If glewinfo fails, there is not OpenGL context.
    proc = subprocess.run(
        "glewinfo",
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    if proc.returncode != 0:
        return False

    # On Linux, look for a display.
    if sys.platform == 'linux' and not 'DISPLAY' in os.environ:
        return False

    # we need to turn it off on Windows ... as our builders come with an
    # incomplete setup ...
    if sys.platform.startswith("win"): 
        return False

    return True

# If this fails it raises a DistributionNotFound exception
pkg_resources.get_distribution('vtk')

# test libpng, since this was causing trouble in OSX previously
source = vtk.vtkCubeSource()

mapper = vtk.vtkPolyDataMapper()
mapper.SetInputConnection(source.GetOutputPort())

actor = vtk.vtkActor()
actor.SetMapper(mapper)

renderer = vtk.vtkRenderer()
renderer.AddActor(actor)

window = vtk.vtkRenderWindow()
window.AddRenderer(renderer)
window.SetSize(500, 500)

if render_enabled():
    window.Render()

window_filter = vtk.vtkWindowToImageFilter()
window_filter.SetInput(window)

if render_enabled():
    window_filter.Update()

writer = vtk.vtkPNGWriter()
writer.SetFileName('cube.png')
writer.SetInputData(window_filter.GetOutput())
writer.Write()
