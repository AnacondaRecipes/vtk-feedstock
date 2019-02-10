#!/bin/bash

BUILD_CONFIG=Release

declare -a CMAKE_PLATFORM_FLAGS
if [[ ${target_platform} =~ .*linux.* ]]; then
  CMAKE_PLATFORM_FLAGS+=(-DCMAKE_FIND_ROOT_PATH="${PREFIX};${BUILD_PREFIX}/${HOST}/sysroot")
  CMAKE_PLATFORM_FLAGS+=(-DCMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES:PATH="${BUILD_PREFIX}/${HOST}/sysroot/usr/include")
  CMAKE_PLATFORM_FLAGS+=(-DVTK_USE_X:BOOL=ON)
elif [[ ${target_platform} == osx-64 ]]; then
  CMAKE_PLATFORM_FLAGS+=(-DVTK_USE_X:BOOL=OFF)
  CMAKE_PLATFORM_FLAGS+=(-DVTK_USE_COCOA:BOOL=ON)
  CMAKE_PLATFORM_FLAGS+=(-DVTK_USE_CARBON:BOOL=OFF)
fi

declare -a WITH_OSMESA
if [[ -f "${PREFIX}"/lib/libOSMesa32.so ]]; then
  WITH_OSMESA+=(-DVTK_OPENGL_HAS_OSMESA:BOOL=ON)
  WITH_OSMESA+=(-DOSMESA_LIBRARY="${PREFIX}/lib/libOSMesa32.so")
fi

# now we can start configuring
cmake -H. -Bbuild -G"Ninja" \
    -DCMAKE_BUILD_TYPE=$BUILD_CONFIG \
    -DCMAKE_PREFIX_PATH:PATH="${PREFIX}" \
    -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
    -DCMAKE_INSTALL_RPATH:PATH="${PREFIX}/lib" \
    -DBUILD_DOCUMENTATION:BOOL=OFF \
    -DBUILD_TESTING:BOOL=OFF \
    -DBUILD_EXAMPLES:BOOL=OFF \
    -DBUILD_SHARED_LIBS:BOOL=ON \
    -DVTK_WRAP_PYTHON:BOOL=ON \
    -DModule_vtkPythonInterpreter:BOOL=OFF \
    -DVTK_PYTHON_VERSION:STRING="${PY_VER}" \
    -DVTK_INSTALL_PYTHON_MODULE_DIR:PATH="${SP_DIR}" \
    -DVTK_HAS_FEENABLEEXCEPT:BOOL=OFF \
    -DVTK_RENDERING_BACKEND=OpenGL2 \
    -DModule_vtkRenderingMatplotlib=ON \
    -DVTK_USE_SYSTEM_ZLIB:BOOL=ON \
    -DVTK_USE_SYSTEM_FREETYPE:BOOL=ON \
    -DVTK_USE_SYSTEM_LIBXML2:BOOL=ON \
    -DVTK_USE_SYSTEM_PNG:BOOL=ON \
    -DVTK_USE_SYSTEM_JPEG:BOOL=ON \
    -DVTK_USE_SYSTEM_TIFF:BOOL=ON \
    -DVTK_USE_SYSTEM_EXPAT:BOOL=ON \
    -DVTK_USE_SYSTEM_HDF5:BOOL=ON \
    -DVTK_EXTERNAL_HDF5_IS_SHARED:BOOL=ON \
    -DVTK_USE_SYSTEM_JSONCPP:BOOL=ON \
    -DVTK_SMP_IMPLEMENTATION_TYPE:STRING=TBB \
    -DVTK_USE_SYSTEM_NETCDF:BOOL=ON \
    -DVTK_USE_SYSTEM_LZ4:BOOL=ON \
    -DVTK_USE_SYSTEM_OGGTHEORA:BOOL=ON \
    -DModule_vtkIOXdmf2:INTERNAL=ON \
    "${SCREEN_ARGS[@]}" \
    "${CMAKE_PLATFORM_FLAGS[@]}" \
    "${WITH_OSMESA[@]}"

# compile & install!
cmake --build build/ -- -j${CPU_COUNT}
cmake --build build/ -- install

# The egg-info file is necessary because some packages,
# like mayavi, have a __requires__ in their __init__.py,
# which means pkg_resources needs to be able to find vtk.
# See https://setuptools.readthedocs.io/en/latest/pkg_resources.html#workingset-objects

cat > $SP_DIR/vtk-$PKG_VERSION.egg-info <<FAKE_EGG
Metadata-Version: 2.1
Name: vtk
Version: $PKG_VERSION
Summary: VTK is an open-source toolkit for 3D computer graphics, image processing, and visualization
Platform: UNKNOWN
FAKE_EGG
