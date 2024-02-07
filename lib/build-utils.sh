#!/bin/bash

# The following directory strucutre is assumed
# The source repository 'llvm-project' resides in $ROOT
# All builds will be inside $ROOT/build. This is $BUILD_ROOT
# A value for ROOT will not be assumed. It has to be provided.
# A specific build directory inside $BUILD_ROOT being built or updated
# will be held by the $BUILD_DIR variable
# $BUILD_TYPE is either Release or Debug.

# Check if the environment variable ROOT has been set.
# exit with a message if not set.
# if set, make sure the path is valid and accessible
check_root() {
if [ -z "${ROOT+x}" ];
then
    # var is unset
    echo "Environment variable ROOT not set. Exiting..."
    exit 1
else
    # var is set
    if [ ! -d ${ROOT} ];
    then
	echo "Bad value for ROOT -> ${ROOT}. Exiting..."
	exit 1
    fi
fi
    
}

# clone git@github.com:bhandarkar-pranav/llvm-project.git at ${ROOT}/llvm-project
# ${ROOT} is not assumed. It needs to be set in the environment before calling
# ${ROOT}/llvm-project shouldn't already exist. Do nothing, if it already exists.
clone_repo() {
    check_root
    # Set this in an env. variable later
    if [ -d ${ROOT}/llvm-project ];
    then
	echo "${ROOT}/llvm-project already exists."
    else
	git clone git@github.com:bhandarkar-pranav/llvm-project.git ${ROOT}/llvm-project
    fi
}

# Perform set up actions which really should be needed only once on a new system.
# The only environment variable needed is ${ROOT}
# 1. clone git@github.com:bhandarkar-pranav/llvm-project.git at ${ROOT}/llvm-project
# 2. Set up the build root directory at ${ROOT}/build
# ${ROOT} is not assumed. It needs to be set in the environment before calling
set_up() {
    check_root
    clone_repo
    mkdir -p ${ROOT}/build
}
