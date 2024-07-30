#!/bin/bash

# The following directory strucutre is assumed
# The source repository 'llvm-project' resides in ${WORK_AREA}
# where WORK_AREA=${ROOT}/${USER_OR_ORG}
# ROOT has to be provided at all times and doesn't have a default value. e.g. On
# AMD machines, it'll typically be ROOT=$HOME/git.
# USER_OR_ORG can be specified by the user but the default value is 'bhandarkar-pranav'


# Here is a description of other relevant variables
# BUILD_ROOT -> ${WORK_AREA}/build - Cannot be overriden.
#               All builds are done inside ${WORK_AREA}/build.
# BUILD_DIR  ->  A specific build directory inside ${BUILD_ROOT}
#                being built or updated
# BUILD_TYPE -> 'Release' or 'Debug'

# Check if the environment variable ROOT has been set.
# Return true if set, else return false.
is_root_set_() {
    if [ -z "${ROOT+x}" ];
    then
	false
    else
	true
    fi
}
is_var_set_() {
    if [ -z ${!1+x} ];
    then
        false
    else
        true
    fi
}
# Check if the path specified by ${ROOT} is a valid path
is_root_valid_path_() {
    if [ -d ${ROOT} ];
    then
	true
    else
	false
    fi
}
# Check if the environment variable ${ROOT} is set
# and is set to a valid path.
# Hard fail (exit)  with a message if not set or
# the path is not valid
check_root_() {
    if is_root_set_
    then
	# var is set
	if  ! is_root_valid_path_ ;
	then
	    echo "Bad value for ROOT -> ${ROOT}. Exiting..." >&2
	    exit 1
	fi
    else
	# var is unset
	echo "Environment variable ROOT not set. Exiting..." >&2
	exit 1
    fi
}
check_user_or_org_() {
    export USER_OR_ORG=${USER_OR_ORG:-'bhandarkar-pranav'}
}
# clone git@github.com:bhandarkar-pranav/llvm-project.git at ${ROOT}/llvm-project
# ${ROOT} is not assumed; it needs to be set in the environment before calling
# ${ROOT}/llvm-project shouldn't already exist. Do nothing, if it already exists.
clone_repo_() {
    check_root_
    check_user_or_org_
    mkdir -p ${WORK_AREA}

    # Set this in an env. variable later
    if [ -d ${WORK_AREA}/llvm-project ];
    then
	echo "${WORK_AREA}/llvm-project already exists."
    else
	set -x
	git clone git@github.com:${USER_OR_ORG}/llvm-project.git ${WORK_AREA}/llvm-project
	set +x
    fi
}
set_up_env_global_vars_() {
    # Check if ROOT is set and is a valid path
    check_root_
    # check and set USER_OR_ORG if needed
    check_user_or_org_
    # We come here only if 'set_up' is called
    export WORK_AREA=${ROOT}/${USER_OR_ORG}
    # ********************************************************************************
    # To simplify things a little bit, we do not allow BUILD_ROOT to be user specified.
    # We always override it.
    # ********************************************************************************
    export BUILD_ROOT=${WORK_AREA}/build
}
are_required_globals_set() {
    if ! is_root_set_ || ! is_var_set_ "WORK_AREA" || ! is_var_set_ "BUILD_ROOT"
    then
	false
    else
	true
    fi
}
# Checks the following
# 1) if ${ROOT} is set to a valid path
# 2) if ${ROOT}/llvm-project exists
# 3) if ${ROOT}/build is valid
# Even if one condition fails, it calls `set_up`.
check_setup_() {
    # We purposely do not use ${WORK_AREA} because it is set up by set_up
    check_user_or_org_
    if ! is_root_set_ || ! is_root_valid_path_ || [[ ! -d ${ROOT}/${USER_OR_ORG}/llvm-project ]] || [[ ! -d ${ROOT}/${USER_OR_ORG}/build ]];
    then
	false
    else
	true
    fi
}
# Return a build id string that is based on the current date.
# Command line args:
# '-s' | 'short' | '--short' -> Short form: eg. 12Feb24
# "-l' | 'long' | '--long' -> Long form (adds time of day to short form: eg 12Feb24-1520 (3:20 pm on 12th Feb 2024)
get_default_build_id_() {
    case $1 in
	'-l' | 'long' | '--long')
	    d=$(date +"%d%h%y-%H%M")
	    echo $d
	    ;;
	'-s' | 'short' | '--short' | *)
	    d=$(date +"%d%h%y")
	    echo $d
	    ;;
    esac
}
setup_if_needed() {
    if ! check_setup_ || ! are_required_globals_set
    then
	set_up
    fi

}
set_up_vars_for_new_gh_build_() {

    setup_if_needed
    # Unless build_id is provided, it'll be a string based on the current date
    # '12Feb24'
    BUILD_ID=${BUILD_ID:-$(get_default_build_id_)}
    BUILD_TYPE=${BUILD_TYPE:-Release}

    BUILD_DIR=${BUILD_ROOT}/build-${BUILD_ID}
    INSTALL_DIR=${BUILD_ROOT}/install-${BUILD_ID}

    DO_TESTS=${DO_TESTS:-"-DLLVM_BUILD_TESTS=ON -DLLVM_INCLUDE_TESTS=ON -DCLANG_INCLUDE_TESTS=ON"}
    if [ "$BUILD_CUDA" == 0 ] ; then
	CUDA_PLUGIN="-DLIBOMPTARGET_BUILD_CUDA_PLUGIN=OFF"
	TARGETS_TO_BUILD="-DLLVM_TARGETS_TO_BUILD='X86;AMDGPU'"
    else
	CUDA_PLUGIN="-DLIBOMPTARGET_BUILD_CUDA_PLUGIN=ON"
	TARGETS_TO_BUILD="-DLLVM_TARGETS_TO_BUILD='X86;AMDGPU;NVPTX'"
    fi
    # Set these cmake variables to default values for now. Revisit later
    # because I dont know what they do.
    AOMP_GFXLIST_OPT=""
    AOMP_NVPTX_CAPS_OPT=""
    ENABLE_DEBUG_OPT="-DLIBOMP_OMPT_SUPPORT=OFF"
    # TODO: It'll be nice to turn on ccache at some point.
    AOMP_CCACHE_OPTS=""
}
# Delete the build directory passed as $1 and create a new one with the same name
set_up_build_dir_() {
    echo "Fresh clean build. Removing everything from the build directory $1"
    rm -rf $1
    mkdir -p $1
}
# Used to lower-case stringify the the build type. Defaults to 'release'
# if BUILD_TYPE == Debug, then "debug" else "release"
get_build_type_substr_() {
    if [ "$BUILD_TYPE" == "Debug" ]; then
	echo "debug"
    else
	echo "release"
    fi
}
# Returns "latest_build_dir" or latest_debug_build_dir"
# depending on the BUILD_TYPE
get_build_link_name_() {
    build_ty_substring=$(get_build_type_substr_)
    if [ "$build_ty_substring" == "debug" ]; then
	echo "latest_debug_build_dir"
    else
	echo "latest_build_dir"
    fi
}
# Create a link in the source directory to compile_commands.json in the build directory
set_up_compile_commands_json_() {
    BUILD_LINK_NAME=$(get_build_link_name_)
    ln -sf  ${BUILD_ROOT}/${BUILD_LINK_NAME}/compile_commands.json ${1}/compile_commands.json
}

# Perform set up actions which really should be needed only once on a new system.
# The only environment variable needed is ${ROOT}
# 1. clone git@github.com:bhandarkar-pranav/llvm-project.git at ${ROOT}/llvm-project
# 2. Set up the build root directory at ${ROOT}/build
# ${ROOT} is not assumed. It needs to be set in the environment before calling
set_up() {
    set_up_env_global_vars_
    clone_repo_
    mkdir -p ${BUILD_ROOT}
}

# Function to build and install github.com/bhandarkar-pranav/llvm-project
build_llvm_gh() {

    # Set up some variables for a new github build
    set_up_vars_for_new_gh_build_

    # Set up cmake options
    CMAKE_OPTIONS="\
    -DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=ON \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
    -DCLANG_DEFAULT_LINKER=lld \
    $DO_TESTS \
    $TARGETS_TO_BUILD \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DCOMPILER_RT_BUILD_ORC=OFF \
    -DCOMPILER_RT_BUILD_XRAY=OFF \
    -DCOMPILER_RT_BUILD_MEMPROF=OFF \
    -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
    -DCOMPILER_RT_BUILD_SANITIZERS=ON \
    $AOMP_CCACHE_OPTS \
    -DLLVM_ENABLE_PROJECTS='clang;lld;llvm;flang' \
    -DLLVM_INSTALL_UTILS=ON \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_CXX_STANDARD=17 \
    $CUDA_PLUGIN \
    -DCLANG_DEFAULT_PIE_ON_LINUX=OFF \
    $AOMP_GFXLIST_OPT \
    $AOMP_NVPTX_CAPS_OPT \
    $ENABLE_DEBUG_OPT \
    -DLLVM_ENABLE_RUNTIMES='openmp;compiler-rt;offload' \
    "

    # if [ "$BUILD_TYPE" == "Release" ]; then
    # 	CMAKE_LLVM_RUNTIMES="-DLLVM_ENABLE_RUNTIMES='openmp;compiler-rt'"
    # else
    # 	CMAKE_LLVM_RUNTIMES="-DLLVM_ENABLE_RUNTIMES='compiler-rt'"
    # fi
    set_up_build_dir_ $BUILD_DIR

    echo "----- Fresh LLVM build at $BUILD_DIR -----"

    pushd . >/dev/null
    cd ${BUILD_DIR}
    echo "-----Running cmake-----"
    echo "cmake -G Ninja $CMAKE_OPTIONS -DLLVM_LIT_ARGS=-vv --show-unsupported --show-xfail -j 32  ${WORK_AREA}/llvm-project/llvm"
    cmake -G Ninja $CMAKE_OPTIONS -DLLVM_LIT_ARGS="-vv --show-unsupported --show-xfail -j 32" ${WORK_AREA}/llvm-project/llvm

    if [ $? != 0 ] ; then
      echo "ERROR cmake failed. Cmake flags" >&2
      echo "      $MYCMAKEOPTS" >&2
      exit 1
    fi

    # build llvm and install
    echo "-----Running ninja------"
    echo "ninja -j64 $AOMP_JOB_THREADS"
    ninja -j 64
    echo "-----Installing-------"
    echo "ninja -j64 install"
    ninja -j 64 install
    ln -sf ${INSTALL_DIR} install
    ln -sf ${WORK_AREA}/llvm-project llvm_project_src_dir
    popd >/dev/null

    pushd . > /dev/null
    cd ${BUILD_ROOT}
    # Set up "latest" links to the build and install
    # directory to simplify access to the binaries.
    if [ "$BUILD_TYPE" == "Release" ]; then
	if [ -L latest ];
	then
	    rm latest
	fi
	if [ -L latest_build_dir ];
	then
	    rm latest_build_dir
	fi
	ln -sf ${INSTALL_DIR} latest
	ln -sf ${BUILD_DIR} latest_build_dir
    else
	if [ -L latest_debug_install ];
	then
	    rm latest_debug_install
	fi
	if [ -L latest_debug_build_dir ];
	then
	    rm latest_debug_build_dir
	fi

	ln -sf ${INSTALL_DIR} latest_debug_install
	ln -sf ${BUILD_DIR} latest_debug_build_dir
    fi

    # Create a link called compile_command.json in the source repository
    # to the compilation database, compile_commands.json in the build directory.
    set_up_compile_commands_json_ ${WORK_AREA}/llvm-project
    popd >/dev/null
}
get_build_dir_() {
    BUILD_LINK_NAME=$(get_build_link_name_)
    BUILD_DIR=${BUILD_DIR:-${BUILD_ROOT}/${BUILD_LINK_NAME}}
    echo $BUILD_DIR
}

update_llvm_gh() {
    set_up_env_global_vars_

    BUILD_DIR=${BUILD_DIR:-$(get_build_dir_)}
    echo "----- Updating build at $BUILD_DIR -----"
    pushd . >/dev/null
    cd ${BUILD_DIR}
    echo "-----Running ninja------"
    echo "ninja -j 64"
    ninja -j 64
    echo "-----Installing-------"
    echo "ninja -j 64"
    ninja -j 64 install
    popd >/dev/null
}
# Returns a string that can be used a suffix to identify
# an llvm test run such as ninja check-llvm or
# ninja check-llvm check-flang check-openmp
# Right now, the value returned is simply a formatted
# date string
get_suffix_for_llvm_test_results() {
    FORMATTED_DATE=$(date +"%d_%h_%y_%H_%M")
    echo ${FORMATTED_DATE}
}
get_branch_and_sha() {
    echo "$( cd ${WORK_AREA}/llvm-project && echo $(git rev-parse --abbrev-ref HEAD)-$(git rev-parse --short HEAD) && cd - >/dev/null )"
}
handle_llvm_check_error_() {
    echo "check-$1 failed. Results in $2"
}
llvm_check_() {
    SUFFIX=$(get_suffix_for_llvm_test_results)
    BRANCH_SHA=$(get_branch_and_sha llvm_project_src_dir)
    CMD_ARGS=""
    TESTS=""
    TESTS_BUILD_DIR=$(pwd)
    echo "---- Testing in ${TESTS_BUILD_DIR} ----"
    for arg in "$@"
    do
	CMD_ARGS="$CMD_ARGS check-$arg"
	TESTS="${TESTS}-${arg}"
	mkdir -p ninja_check_dir/${BRANCH_SHA}
	LOG_FILE="./ninja_check_dir/${BRANCH_SHA}/${arg}-${SUFFIX}.txt"
	LOG_FILE_FULL_PATH=$(readlink -f ${LOG_FILE})
	trap "handle_llvm_check_error_ ${arg} ${LOG_FILE_FULL_PATH}" ERR
	echo "----------- check-${arg} results --------" > ${LOG_FILE}
	echo "Date: ${SUFFIX}" >> ${LOG_FILE}
        ag "LLVM_REVISION"  ./include/llvm/Support/VCSRevision.h  | awk '{printf "%s:  %s\n", $2, $3}' >>  ${LOG_FILE}
	ninja -j 64 check-${arg} 2>&1 | tee -a ${LOG_FILE}
	if [ $? != 0 ];
	then
	    result="Result: Failed"
	else
	    result="Result: Passed"
	fi
	echo "------------------------------------------------------" >> ${LOG_FILE}
	echo "DONE::: $(echo ${arg} | tr 'a-z' 'A-Z') $(date +\"%H:%M::%d-%h-%y\") -> $result" >> ${LOG_FILE}
	echo "------------------------------------------------------" >> ${LOG_FILE}
	trap - ERR
    done
    for arg in "$@"
    do
	LOG_FILE="./ninja_check_dir/${BRANCH_SHA}/${arg}-${SUFFIX}.txt"
	LOG_FILE_FULL_PATH=$(readlink -f ${LOG_FILE})
	if [ -f ${LOG_FILE_FULL_PATH} ];
	then
	    COMPONENT=$(echo ${arg} | tr 'a-z' 'A-Z')
	    echo "----------------------------------------"
	    echo "          ${COMPONENT}"
	    echo "----------------------------------------"
	    tail -10 ${LOG_FILE_FULL_PATH}
	fi
    done
}
check_llvm() {
    setup_if_needed >/dev/null
    build_dir=$(get_build_dir_)
    pushd . >/dev/null
    cd $build_dir
    llvm_check_ llvm
    popd >/dev/null
}
check_all() {
    setup_if_needed >/dev/null
    build_dir=$(get_build_dir_)
    pushd .  >/dev/null
    cd $build_dir
    llvm_check_ llvm clang mlir flang openmp offload
    popd >/dev/null
}
check_some() {
    setup_if_needed >/dev/null
    build_dir=$(get_build_dir_)
    pushd .  >/dev/null
    cd $build_dir
    llvm_check_ $@
    popd > /dev/null
}
