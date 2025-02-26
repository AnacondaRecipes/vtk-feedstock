#!/bin/bash

set -ex

echo "Testing ${PKG_NAME}."

# Add runtime path of libEGL.so.1 so Qt libraries can find it as they're loaded in.
# This must be done before the python interpreter starts up.
if [[ "$(uname)" == "Linux" ]]; then
	export QT_XCB_GL_INTEGRATION=none
	for loc in $PREFIX/lib $PREFIX/x86_64-conda-linux-gnu/sysroot/usr/lib64; do
		if [ -d "$loc" ]; then
		export LD_LIBRARY_PATH="$loc:$LD_LIBRARY_PATH"
		fi
	done
	echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

	echo "Looking for libEGL.so.1:"
	find $PREFIX -name "libEGL.so*" || echo "No libEGL.so found in PREFIX"

fi


${PYTHON} -m pip check
test $(pip list | grep vtk | tr -s " " | grep $PKG_VERSION | wc -l) -eq 1

test -f $PREFIX/lib/libvtkGUISupportQt-${PKG_VERSION}${SHLIB_EXT}

test -f $PREFIX/lib/libvtkRenderingQt-${PKG_VERSION}${SHLIB_EXT}

${PYTHON} ${RECIPE_DIR}/test_vtk.py
