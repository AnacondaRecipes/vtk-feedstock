#!/bin/bash
echo "Building ${PKG_NAME}."

set -ex

BUILD_CONFIG=Release

# Use bash "Remove Largest Suffix Pattern" to get rid of all but major version number
PYTHON_MAJOR_VERSION=${PY_VER%%.*}

if [[ "${target_platform}" =~ osx-arm64 && "${target_platform}" != "${build_platform}" ]]; then
    rm -f "${PREFIX}/lib/qt6/moc"
    ln -s "${BUILD_PREFIX}/lib/qt6/moc" "${PREFIX}/lib/qt6/moc"

    # Additional debugging information
    echo "Adjusted Qt tools for osx-arm64 with build variant qt6"
    echo "Removed: ${PREFIX}/lib/qt6/moc"
    echo "Linked to: ${BUILD_PREFIX}/lib/qt6/moc"
else
    echo "Skipping Qt tools adjustment. Target platform: ${target_platform}"
fi

VTK_ARGS=()


VTK_ARGS+=(
    "-DVTK_DEFAULT_RENDER_WINDOW_OFFSCREEN:BOOL=OFF"
    "-DVTK_USE_TK:BOOL=ON"
)
if [[ "${target_platform}" == linux-* ]]; then
    # Make sure libEGL can be found during both build and runtime
    if [[ -d "${PREFIX}/lib" ]]; then
        export LD_LIBRARY_PATH="${PREFIX}/lib:${LD_LIBRARY_PATH}"
    fi

    # Try to locate libGL.so and libEGL.so
    find $PREFIX -name "libGL.so*" || echo "libGL.so not found in PREFIX"
    find $BUILD_PREFIX -name "libGL.so*" || echo "libGL.so not found in BUILD_PREFIX"
    find $PREFIX -name "libEGL.so*" || echo "libEGL.so not found in PREFIX"
    
    # For all Linux platforms
    VTK_ARGS+=(
        "-DVTK_USE_X:BOOL=ON"
        "-DVTK_OPENGL_HAS_EGL:BOOL=ON"
    )

    # Set GL and EGL paths explicitly if found
    if [ -f "$PREFIX/lib/libGL.so.1" ]; then
        VTK_ARGS+=("-DOPENGL_opengl_LIBRARY:FILEPATH=$PREFIX/lib/libGL.so.1")
    fi
    # Make sure GL libraries are available
    if [ ! -f "$PREFIX/lib/libGL.so.1" ]; then
        SYSTEM_LIBGL=$(find /usr/lib* -name "libGL.so.1" | head -1)
        if [ -n "$SYSTEM_LIBGL" ]; then
            echo "Found system libGL.so.1 at $SYSTEM_LIBGL"
            VTK_ARGS+=("-DOPENGL_opengl_LIBRARY:FILEPATH=$SYSTEM_LIBGL")
            # Add the directory to LD_LIBRARY_PATH
            export LD_LIBRARY_PATH="$(dirname $SYSTEM_LIBGL):$LD_LIBRARY_PATH"
        fi
    fi
    

    if [ -f "$PREFIX/lib/libEGL.so.1" ]; then
        VTK_ARGS+=("-DOPENGL_egl_LIBRARY:FILEPATH=$PREFIX/lib/libEGL.so.1")
    fi
    # Make sure EGL libraries are available
    if [ ! -f "${PREFIX}/lib/libEGL.so.1" ]; then
        # Try to find libEGL.so in system locations
        SYSTEM_LIBEGL=$(find /usr/lib* -name "libEGL.so.1" | head -1)

        if [ -n "$SYSTEM_LIBEGL" ]; then
            echo "Found system libEGL.so.1 at $SYSTEM_LIBEGL"
            VTK_ARGS+=("-DOPENGL_egl_LIBRARY:FILEPATH=$SYSTEM_LIBEGL")
            # Add the directory to LD_LIBRARY_PATH
            export LD_LIBRARY_PATH="$(dirname $SYSTEM_LIBEGL):$LD_LIBRARY_PATH"
        elif [ -n "${BUILD_PREFIX}/${HOST}/sysroot/usr/lib64/libEGL.so.1" ]; then
            echo "Found libEGL.so.1 at ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib64/libEGL.so.1"
            VTK_ARGS+=("-DOPENGL_egl_LIBRARY:FILEPATH=${BUILD_PREFIX}/${HOST}/sysroot/usr/lib64/libEGL.so.1")
            # Hack to help the build tool find CDT pkgconfig and libraries during build. LD_LIBRARY_PATH is used rather than
            # LIBRARY_PATH because we need to run during the build and require libs from
            # our CDT packages.
            export LD_LIBRARY_PATH="${BUILD_PREFIX}/${HOST}/sysroot/usr/lib64:${PREFIX}/lib:${LD_LIBRARY_PATH}"
        else
            echo "WARNING: Couldn't find libEGL.so.1"
        fi
    fi

    # Make sure all required Mesa libraries are in LD_LIBRARY_PATH
    echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

    # TODO: generation of vtkmodules/vtkCommonCore.pyi causes an error on linux-64 and linux-aarch64:
    # FAILED: lib/python3.9/site-packages/vtkmodules/vtkCommonCore.pyi lib/python3.9/site-packages/vtkmodules/vtkWebCore.pyi
    # ImportError: libEGL.so.1: cannot open shared object file: No such file or directory.
    # 2025/2/25: The patch 'patches/11929_disable_class_overrides_pyi.patch' seems doesn't fix it for that pyi file.
    CMAKE_ARGS="${CMAKE_ARGS} -DVTK_BUILD_PYI_FILES:BOOL=ON"

elif [[ "${target_platform}" == osx-* ]]; then
    VTK_ARGS+=(
        "-DVTK_USE_COCOA:BOOL=ON"
        "-DCMAKE_OSX_SYSROOT:PATH=${CONDA_BUILD_SYSROOT}"
        "-DVTK_MODULE_USE_EXTERNAL_VTK_gl2ps:BOOL=OFF"
    )
    # incompatible function pointers become errors in clang >=16
    export CFLAGS="${CFLAGS} -Wno-incompatible-pointer-types"
    export CXXFLAGS="${CXXFLAGS} -Wno-incompatible-pointer-types"

    CMAKE_ARGS="${CMAKE_ARGS} -DVTK_BUILD_PYI_FILES:BOOL=ON"
fi

if [[ "$target_platform" != "linux-ppc64le" ]]; then
    VTK_ARGS+=(
        "-DVTK_MODULE_ENABLE_VTK_GUISupportQt:STRING=YES"
        "-DVTK_MODULE_ENABLE_VTK_RenderingQt:STRING=YES"
    )
fi


if [[ "$CONDA_BUILD_CROSS_COMPILATION" == "1" ]]; then
  (
    mkdir build-native
    cd build-native
    export CC=$CC_FOR_BUILD
    export CXX=$CXX_FOR_BUILD
    unset CFLAGS
    unset CXXFLAGS
    unset CPPFLAGS
    export LDFLAGS=${LDFLAGS//$PREFIX/$BUILD_PREFIX}
    cmake -G Ninja -DCMAKE_INSTALL_PREFIX=$SRC_DIR/vtk-compile-tools \
       -DCMAKE_PREFIX_PATH=$BUILD_PREFIX \
       -DCMAKE_INSTALL_LIBDIR=lib \
       -DVTK_BUILD_COMPILE_TOOLS_ONLY=ON ..
    ninja -j${CPU_COUNT}
    ninja install
    cd ..
  )
  MAJ_MIN=$(echo $PKG_VERSION | rev | cut -d"." -f2- | rev)
  CMAKE_ARGS="${CMAKE_ARGS} -DVTKCompileTools_DIR=$SRC_DIR/vtk-compile-tools/lib/cmake/vtkcompiletools-${MAJ_MIN}/"
  CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_REQUIRE_LARGE_FILE_SUPPORT=1 -DCMAKE_REQUIRE_LARGE_FILE_SUPPORT__TRYRUN_OUTPUT="
  CMAKE_ARGS="${CMAKE_ARGS} -DVTK_REQUIRE_LARGE_FILE_SUPPORT_EXITCODE=0 -DVTK_REQUIRE_LARGE_FILE_SUPPORT_EXITCODE__TRYRUN_OUTPUT="
  CMAKE_ARGS="${CMAKE_ARGS} -DXDMF_REQUIRE_LARGE_FILE_SUPPORT_EXITCODE=0 -DXDMF_REQUIRE_LARGE_FILE_SUPPORT_EXITCODE__TRYRUN_OUTPUT="
fi

mkdir build
cd build || exit

echo "VTK_ARGS:" "${VTK_ARGS[@]}"

# now we can start configuring
cmake .. -G "Ninja" ${CMAKE_ARGS} \
    -Wno-dev \
    -DCMAKE_BUILD_TYPE=$BUILD_CONFIG \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH:BOOL=ON \
    -DCMAKE_PREFIX_PATH:PATH="${PREFIX}" \
    -DCMAKE_FIND_FRAMEWORK=LAST \
    -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
    -DCMAKE_INSTALL_RPATH:PATH="${PREFIX}/lib" \
    -DCMAKE_INSTALL_LIBDIR:PATH=lib \
    -DVTK_BUILD_DOCUMENTATION:BOOL=OFF \
    -DVTK_BUILD_TESTING:BOOL=OFF \
    -DVTK_BUILD_EXAMPLES:BOOL=OFF \
    -DBUILD_SHARED_LIBS:BOOL=ON \
    -DVTK_LEGACY_SILENT:BOOL=OFF \
    -DVTK_HAS_FEENABLEEXCEPT:BOOL=OFF \
    -DVTK_WRAP_PYTHON:BOOL=ON \
    -DVTK_PYTHON_VERSION:STRING="${PYTHON_MAJOR_VERSION}" \
    -DPython3_FIND_STRATEGY=LOCATION \
    -DPython3_ROOT_DIR=${PREFIX} \
    -DPython3_EXECUTABLE=${PREFIX}/bin/python \
    -DVTK_MODULE_ENABLE_VTK_PythonInterpreter:STRING=NO \
    -DVTK_MODULE_ENABLE_VTK_RenderingFreeType:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_RenderingMatplotlib:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_FiltersParallelDIY2:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_IOFFMPEG:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_IOXdmf2:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_IOXdmf3:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_ViewsCore:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_ViewsContext2D:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_PythonContext2D:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_RenderingContext2D:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_RenderingContextOpenGL2:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_RenderingCore:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_RenderingOpenGL2:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_WebCore:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_WebGLExporter:STRING=YES \
    -DVTK_MODULE_ENABLE_VTK_WebPython:STRING=YES \
    -DVTK_USE_EXTERNAL:BOOL=ON \
    -DVTK_MODULE_USE_EXTERNAL_VTK_cgns:BOOL=OFF \
    -DVTK_MODULE_USE_EXTERNAL_VTK_exprtk:BOOL=OFF \
    -DVTK_MODULE_USE_EXTERNAL_VTK_fast_float:BOOL=OFF \
    -DVTK_MODULE_USE_EXTERNAL_VTK_ioss:BOOL=OFF \
    -DVTK_MODULE_USE_EXTERNAL_VTK_libharu:BOOL=OFF \
    -DVTK_MODULE_USE_EXTERNAL_VTK_pegtl:BOOL=OFF \
    -DVTK_MODULE_USE_EXTERNAL_VTK_token:BOOL=OFF \
    -DVTK_MODULE_USE_EXTERNAL_VTK_verdict:BOOL=OFF \
    -DQT_HOST_PATH:STRING="${PREFIX}" \
    "${VTK_ARGS[@]}"

# compile & install!
ninja install -j$CPU_COUNT -v || exit 1

# Create a directory for the vtk-io-ffmpeg package
# and find the ffmpeg-related files and process each of them
FFMPEG_DIR="$(dirname $PREFIX)/ffmpeg_dir"
mkdir -p "$FFMPEG_DIR"
find $PREFIX -name "*vtkIOFFMPEG*" -print0 | while IFS= read -r -d '' file; do
    dest_dir="$FFMPEG_DIR/${file#$PREFIX/}"
    mkdir -p "$(dirname "$dest_dir")"
    mv "$file" "$dest_dir"
done


# The egg-info file is necessary because some packages,
# like mayavi, have a __requires__ in their __invtkRenderWindow::New()it__.py,
# which means pkg_resources needs to be able to find vtk.
# See https://setuptools.readthedocs.io/en/latest/pkg_resources.html#workingset-objects

cat > $SP_DIR/vtk-$PKG_VERSION.egg-info <<FAKE_EGG
Metadata-Version: 2.1
Name: vtk
Version: $PKG_VERSION
Summary: VTK is an open-source toolkit for 3D computer graphics, image processing, and visualization
Platform: UNKNOWN
FAKE_EGG

# The METADATA file is necessary to ensure that pip list shows the pip package installed by conda
# The INSTALLER file is necessary to ensure that pip list shows that the package is installed by conda
# See https://packaging.python.org/specifications/recording-installed-packages/
# and https://packaging.python.org/en/latest/specifications/core-metadata/#core-metadata

mkdir $SP_DIR/vtk-$PKG_VERSION.dist-info

cat > $SP_DIR/vtk-$PKG_VERSION.dist-info/METADATA <<METADATA_FILE
Metadata-Version: 2.1
Name: vtk
Version: $PKG_VERSION
Summary: VTK is an open-source toolkit for 3D computer graphics, image processing, and visualization
METADATA_FILE

cat > $SP_DIR/vtk-$PKG_VERSION.dist-info/INSTALLER <<INSTALLER_FILE
conda
INSTALLER_FILE
