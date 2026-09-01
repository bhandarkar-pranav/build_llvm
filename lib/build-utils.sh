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
num_jobs_() {
    num_cores=$(nproc 2>/dev/null)
    if [[ -z "$num_cores" ]]; then
	num_cores=$(grep -c ^process /proc/cpuinfo 2>/dev/null)
    fi
    if [[ -z "$num_cores" ]]; then
	num_cores=64
    fi
    num_cores=$((num_cores / 2))
    echo "$num_cores"
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

	# Set up git hooks after successful clone
	if [ $? -eq 0 ]; then
	    echo "Setting up git hooks for ${WORK_AREA}/llvm-project"
	    setup_hooks_ ${WORK_AREA}/llvm-project
	fi
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

# Set up git hooks for LLVM development
# Configures the pre-commit hook to use LLVM's code-format-helper.py
# Arguments:
#   $1 - Path to the llvm-project repository
setup_hooks_() {
    local llvm_src_dir=$1

    # Validate that the path exists and is a git repository
    if [ ! -d "${llvm_src_dir}" ]; then
        echo "ERROR: LLVM source directory not found: ${llvm_src_dir}" >&2
        return 1
    fi

    if [ ! -d "${llvm_src_dir}/.git" ]; then
        echo "ERROR: ${llvm_src_dir} is not a git repository" >&2
        return 1
    fi

    # Validate that the code-format-helper.py exists
    local format_helper="${llvm_src_dir}/llvm/utils/git/code-format-helper.py"
    if [ ! -f "${format_helper}" ]; then
        echo "ERROR: code-format-helper.py not found at ${format_helper}" >&2
        return 1
    fi

    # Create .git/hooks directory if it doesn't exist
    local hooks_dir="${llvm_src_dir}/.git/hooks"
    mkdir -p "${hooks_dir}"

    # Set up the pre-commit hook symlink
    local pre_commit_hook="${hooks_dir}/pre-commit"

    # Remove existing hook if it's a symlink or regular file
    if [ -L "${pre_commit_hook}" ] || [ -f "${pre_commit_hook}" ]; then
        echo "Removing existing pre-commit hook at ${pre_commit_hook}"
        rm "${pre_commit_hook}"
    fi

    # Create the symlink
    echo "Creating pre-commit hook symlink: ${pre_commit_hook} -> ${format_helper}"
    ln -s "${format_helper}" "${pre_commit_hook}"

    # Make sure the hook is executable
    chmod +x "${pre_commit_hook}"

    # Configure git to use the hooks directory
    echo "Configuring git core.hooksPath for ${llvm_src_dir}"
    (
        cd "${llvm_src_dir}"
        git config core.hooksPath .git/hooks
    )

    echo "Git hooks successfully configured for ${llvm_src_dir}"
    return 0
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
build_llvm_flang_rt_hostdevice() {
    BLD_DIR=$1
    INSTALL_DIR=$2
#    GFXLIST=${GFXLIST:-"gfx700 gfx701 gfx801 gfx803 gfx900 gfx902 gfx906 gfx908 gfx90a gfx90c gfx942 gfx950 gfx1030 gfx1031 gfx1035 gfx1036 gfx1100 gfx1101 gfx1102 gfx1103 gfx1150 gfx1151 gfx1152 gfx1153 gfx1200 gfx1201 gfx9-generic gfx9-4-generic gfx10-1-generic gfx10-3-generic gfx11-generic gfx12-generic"}
#    GFXLIST=${GFXLIST:-"gfx700 gfx701 gfx801 gfx803 gfx900 gfx902 gfx906 gfx908 gfx90a gfx90c gfx940 gfx941 gfx942 gfx1030 gfx1031 gfx1035 gfx1036 gfx1100 gfx1101 gfx1102 gfx1103 gfx1150 gfx1151 gfx1152 gfx1153 gfx1200 gfx1201 gfx9-generic gfx9-4-generic gfx10-1-generic gfx10-3-generic gfx11-generic gfx12-generic"}
    ARCH_LIST=$(echo $GFXLIST | tr " " ",")
    CMAKE_C_COMPILER=${INSTALL_DIR}/bin/clang
    CMAKE_CXX_COMPILER=${INSTALL_DIR}/bin/clang++

    INSTALL_DIR_NAME=$(basename $(readlink -f ${BLD_DIR}))
    FRT_BLD_DIR=$BLD_DIR/../flang-runtime-${INSTALL_DIR_NAME}
    OMPRUNTIME_DIR=${BLD_DIR}/runtimes/runtimes-bins/openmp/runtime/src
    echo "BLD_DIR           = ${BLD_DIR}"
    echo "FRT_BLD_DIR       = ${FRT_BLD_DIR}"
    echo "INSTALL_DIR       = ${INSTALL_DIR}"
    echo "OMPRUNTIME_DIR    = ${OMPRUNTIME_DIR}"

    echo "sleeping for 5 s"
    sleep 5
    mkdir -p $FRT_BLD_DIR
    cd $FRT_BLD_DIR
    cmake -G Ninja \
	  -DLLVM_ENABLE_RUNTIMES=flang-rt \
	  -DFLANG_RT_EXPERIMENTAL_OFFLOAD_SUPPORT="OpenMP" \
	  -DFLANG_RT_INCLUDE_TESTS=OFF \
	  -DFLANG_EXPERIMENTAL_OMP_OFFLOAD_BUILD="host_device" \
	  -DCMAKE_C_COMPILER=$CMAKE_C_COMPILER \
	  -DCMAKE_CXX_COMPILER=$CMAKE_CXX_COMPILER \
	  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
	  -DFLANG_RT_DEVICE_ARCHITECTURES="$ARCH_LIST" \
	  ~/git/bhandarkar-pranav/llvm-project/runtimes
    ninja -j128 flang-rt

}
# Function to build and install github.com/bhandarkar-pranav/llvm-project
build_llvm_gh() {

    # Set up some variables for a new github build
    set_up_vars_for_new_gh_build_

    NUM_JOBS_FOR_BUILD=$(num_jobs_)
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
    -DLIBOMPTARGET_PLUGINS_TO_BUILD='amdgpu;host' \
    $CUDA_PLUGIN \
    -DCLANG_DEFAULT_PIE_ON_LINUX=OFF \
    $AOMP_GFXLIST_OPT \
    $AOMP_NVPTX_CAPS_OPT \
    $ENABLE_DEBUG_OPT \
    -DLLVM_ENABLE_RUNTIMES='libcxx;libcxxabi;libunwind;openmp;offload;compiler-rt;flang-rt' \
    -DLIBCXXABI_ENABLE_STATIC=ON \
    -DLLVM_RUNTIME_TARGETS='default;amdgcn-amd-amdhsa' \
    -DRUNTIMES_default_LLVM_ENABLE_WERROR=ON \
    -DRUNTIMES_amdgcn-amd-amdhsa_LLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
    -DRUNTIMES_amdgcn-amd-amdhsa_LLVM_ENABLE_RUNTIMES='compiler-rt;libc;libcxx;libcxxabi;flang-rt;openmp'  \
    -DRUNTIMES_amdgcn-amd-amdhsa_LLVM_ENABLE_WERROR=ON \
    -DRUNTIMES_amdgcn-amd-amdhsa_FLANG_RT_LIBC_PROVIDER=llvm \
    -DRUNTIMES_amdgcn-amd-amdhsa_FLANG_RT_LIBCXX_PROVIDER=llvm \
    -DRUNTIMES_amdgcn-amd-amdhsa_CACHE_FILES='${WORK_AREA}/llvm-project/compiler-rt/cmake/caches/AMDGPU.cmake;${WORK_AREA}/llvm-project/libcxx/cmake/caches/AMDGPU.cmake'
    "

    set_up_build_dir_ $BUILD_DIR

    echo "----- Fresh LLVM build at $BUILD_DIR -----"

    pushd . >/dev/null
    cd ${BUILD_DIR}
    echo "-----Running cmake-----"
    echo "cmake -G Ninja $CMAKE_OPTIONS -DLLVM_LIT_ARGS=-vv --show-unsupported --show-xfail -j 32  ${WORK_AREA}/llvm-project/llvm"
    echo "cmake -G Ninja $CMAKE_OPTIONS -DLLVM_LIT_ARGS=-vv --show-unsupported --show-xfail -j 32  ${WORK_AREA}/llvm-project/llvm"   |   sed -e 's/^+ //'  | tr ' ' '\n' | sed -e '/bin\/cmake/!s/^/        /' -e '$!s/$/ \\/' >> ${BUILD_DIR}/../${BUILD_ID}.cmake
    cmake -G Ninja $CMAKE_OPTIONS -DLLVM_LIT_ARGS="-vv --show-unsupported --show-xfail -j 32" ${WORK_AREA}/llvm-project/llvm
    if [ $? != 0 ] ; then
      echo "ERROR cmake failed. Cmake flags" >&2
      echo "      $MYCMAKEOPTS" >&2
      exit 1
    fi

    # build llvm and install
    echo "-----Running ninja------"
    echo "ninja -j64 $AOMP_JOB_THREADS"
    ninja -j ${NUM_JOBS_FOR_BUILD}
    echo "-----Installing-------"
    echo "ninja -j64 install"
    ninja -j ${NUM_JOBS_FOR_BUILD} install
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

    REALPATH_INSTALL_DIR=$(realpath ${INSTALL_DIR})
    cat <<EOD > ${REALPATH_INSTALL_DIR}/bin/rpath.cfg
-Wl,-rpath=<CFGDIR>/../lib
-Wl,-rpath=<CFGDIR>/../lib/x86_64-unknown-linux-gnu
-L<CFGDIR>/../lib
-L<CFGDIR>/../lib/x86_64-unknown-linux-gnu
EOD
    ln -sf rpath.cfg  ${REALPATH_INSTALL_DIR}/bin/clang++.cfg
    ln -sf rpath.cfg  ${REALPATH_INSTALL_DIR}/bin/clang.cfg
    
    ln -sf rpath.cfg ${REALPATH_INSTALL_DIR}/bin/flang.cfg
    ln -sf flang.cfg ${TRUNK_INSTALL_DIR}/bin/flang-new.cfg
   (
       # workaround for issue with triple subdir and shared builds
       # problem with libomptarget.so finding dependent libLLVM* libs
       cd ${REALPATH_INSTALL_DIR}/lib
       ln -sf x86_64-unknown-linux-gnu/*{.bc,.so,git} .
   )
   LATEST_LINK=$(ls -l ${BUILD_ROOT}/latest)
   echo
   echo "SUCCESSFUL INSTALL at $REALPATH_INSTALL_DIR"
   echo "Link setup : ${LATEST_LINK}"

   # Create a two-level link structure to handle shared home directories across machines:
   # 1. Machine-local link: /work/prbhanda/${USER_OR_ORG} -> actual install directory
   # 2. Shared home link: ${HOME}/${USER_OR_ORG} -> /work/prbhanda/${USER_OR_ORG}
   #
   # This ensures the home link works on all machines, even though installations
   # are on machine-local drives (e.g., /work2)

   # Step 1: Create machine-local link at /work/prbhanda/${USER_OR_ORG}
   LOCAL_LINK_DIR="/work/prbhanda"
   LOCAL_LINK="${LOCAL_LINK_DIR}/${USER_OR_ORG}"

   # Ensure /work/prbhanda exists (create if needed)
   if [ ! -d "${LOCAL_LINK_DIR}" ]; then
       echo "Creating directory: ${LOCAL_LINK_DIR}"
       mkdir -p "${LOCAL_LINK_DIR}"
   fi

   # Remove old link if it exists
   if [ -L "${LOCAL_LINK}" ] || [ -e "${LOCAL_LINK}" ]; then
       rm -f "${LOCAL_LINK}"
   fi

   # Create machine-local link to actual install
   ln -sf "${REALPATH_INSTALL_DIR}" "${LOCAL_LINK}"
   echo "Machine-local link: ${LOCAL_LINK} -> ${REALPATH_INSTALL_DIR}"

   # Step 2: Create home directory link pointing to machine-local link
   HOME_LINK="${HOME}/${USER_OR_ORG}"

   # Remove old link if it exists
   if [ -L "${HOME_LINK}" ] || [ -e "${HOME_LINK}" ]; then
       rm -f "${HOME_LINK}"
   fi

   # Create home link to machine-local link
   ln -sf "${LOCAL_LINK}" "${HOME_LINK}"
   echo "Home directory link: ${HOME_LINK} -> ${LOCAL_LINK}"
   echo
   popd >/dev/null
}
get_build_dir_() {
    BUILD_LINK_NAME=$(get_build_link_name_)
    BUILD_DIR=${BUILD_DIR:-${BUILD_ROOT}/${BUILD_LINK_NAME}}
    echo $(readlink -f ${BUILD_DIR})
}

update_llvm_gh() {
    set_up_env_global_vars_
    NUM_JOBS_FOR_BUILD=$(num_jobs_)

    BUILD_DIR=${BUILD_DIR:-$(get_build_dir_)}
    echo "----- Updating build at $BUILD_DIR -----"
    pushd . >/dev/null
    cd ${BUILD_DIR}
    echo "-----Running ninja------"
    echo "ninja -j ${NUM_JOBS_FOR_BUILD}"
    ninja -j ${NUM_JOBS_FOR_BUILD}
    echo "-----Installing-------"
    echo "ninja -j ${NUM_JOBS_FOR_BUILD}"
    ninja -j ${NUM_JOBS_FOR_BUILD} install
    popd >/dev/null
}
# Returns a string that can be used a suffix to identify
# an llvm test run such as ninja check-llvm or
# ninja check-llvm check-flang check-openmp
# Right now, the value returned is simply a formatted
# date string
get_suffix_for_llvm_test_results() {
    FORMATTED_DATE=$(date +"%H-%M-%S")
    echo ${FORMATTED_DATE}
}
get_subdir_for_llvm_test_results() {
    FORMATTED_DATE=$(date +"%Y-%m-%d")
    echo ${FORMATTED_DATE}
}
get_branch_and_sha() {
    local src_dir=$1
    echo "$( cd ${src_dir} && echo $(git rev-parse --abbrev-ref HEAD)-$(git rev-parse --short HEAD) && cd - >/dev/null )"
}
handle_llvm_check_error_() {
    echo "check-$1 failed. Results in $2"
}
llvm_check_() {
    local build_dir=$1
    local src_dir=$2
    shift 2

    LOG_SUBDIR=$(get_subdir_for_llvm_test_results)
    SUFFIX=$(get_suffix_for_llvm_test_results)
    BRANCH_SHA=$(get_branch_and_sha ${src_dir})

    pushd . >/dev/null
    cd ${build_dir}

    LOG_DIR=./ninja_check_dir/${LOG_SUBDIR}/${BRANCH_SHA}
    CMD_ARGS=""
    TESTS=""
    TESTS_BUILD_DIR=$(pwd)
    NUM_JOBS_FOR_BUILD=$(num_jobs_)
    declare -A RESULTS
    echo "---- Testing in ${TESTS_BUILD_DIR} ----"
    for arg in "$@"
    do
	CMD_ARGS="$CMD_ARGS check-$arg"
	TESTS="${TESTS}-${arg}"
	COMPONENT=$(echo ${arg} | tr 'a-z' 'A-Z')
	mkdir -p ${LOG_DIR}
	LOG_FILE="${LOG_DIR}/${arg}-${SUFFIX}.txt"
	LOG_FILE_FULL_PATH=$(readlink -f ${LOG_FILE})
	trap "handle_llvm_check_error_ ${arg} ${LOG_FILE_FULL_PATH}" ERR
	echo "----------- check-${arg} results --------" > ${LOG_FILE}
	echo "Date: ${SUFFIX}" >> ${LOG_FILE}
        ag "LLVM_REVISION"  ./include/llvm/Support/VCSRevision.h  | awk '{printf "%s:  %s\n", $2, $3}' >>  ${LOG_FILE}
	ninja -j ${NUM_JOBS_FOR_BUILD} check-${arg} 2>&1 | tee -a ${LOG_FILE}
	if [ $? != 0 ];
	then
	    result="Result: Failed"
	    RESULTS["${COMPONENT}"]="Failed"
	else
	    result="Result: Passed"
	    RESULTS["${COMPONENT}"]="Passed"
	fi
	echo "------------------------------------------------------" >> ${LOG_FILE}
	echo "DONE::: $(echo ${arg} | tr 'a-z' 'A-Z') $(date +\"%H:%M::%d-%h-%y\") -> $result" >> ${LOG_FILE}
	echo "------------------------------------------------------" >> ${LOG_FILE}
	trap - ERR
    done
    for arg in "$@"
    do
	LOG_FILE="${LOG_DIR}/${arg}-${SUFFIX}.txt"
	LOG_FILE_FULL_PATH=$(readlink -f ${LOG_FILE})
	COMPONENT=$(echo ${arg} | tr 'a-z' 'A-Z')
	echo "${COMPONENT} : ${RESULTS[${COMPONENT}]} : ${LOG_FILE_FULL_PATH}"
	# LOG_DIR=./ninja_check_dir/${LOG_SUBDIR}/${BRANCH_SHA}
	# mkdir -p ${LOG_DIR}
	# LOG_FILE="${LOG_DIR}/${arg}-${SUFFIX}.txt"
	# LOG_FILE_FULL_PATH=$(readlink -f ${LOG_FILE})
	# if [ -f ${LOG_FILE_FULL_PATH} ];
	# then
	#     echo "----------------------------------------"
	#     echo "          ${COMPONENT}"
	#     echo "----------------------------------------"
	#     tail -10 ${LOG_FILE_FULL_PATH}
	# fi
    done

    popd >/dev/null
}

check_llvm() {
    setup_if_needed >/dev/null
    build_dir=$(get_build_dir_)
    src_dir=${WORK_AREA}/llvm-project
    llvm_check_ ${build_dir} ${src_dir} llvm
}
check_all() {
    setup_if_needed >/dev/null
    build_dir=$(get_build_dir_)
    src_dir=${WORK_AREA}/llvm-project
    llvm_check_ ${build_dir} ${src_dir} llvm clang mlir flang openmp flang-rt offload
}
check_some() {
    setup_if_needed >/dev/null
    build_dir=$(get_build_dir_)
    src_dir=${WORK_AREA}/llvm-project
    llvm_check_ ${build_dir} ${src_dir} $@
}
# AOMP helper functions
get_aomp_build_dir() {
    # Default AOMP build directory
    local default_aomp_build_dir="${HOME}/git/aomp${AOMP_MAJOR_VERSION}.${AOMP_MINOR_VERSION}/build/llvm-project"

    # Use AOMP_BUILD_DIR if set, otherwise use default
    local aomp_build_dir=${AOMP_BUILD_DIR:-${default_aomp_build_dir}}

    # Check if version variables are needed but not set
    if [ -z "${AOMP_BUILD_DIR}" ]; then
        if [ -z "${AOMP_MAJOR_VERSION}" ] || [ -z "${AOMP_MINOR_VERSION}" ]; then
            echo "ERROR: AOMP version not set. Please set AOMP_MAJOR_VERSION and AOMP_MINOR_VERSION" >&2
            echo "       or set AOMP_BUILD_DIR explicitly to the AOMP build directory" >&2
            return 1
        fi
    fi

    # Validate that directory exists
    if [ ! -d "${aomp_build_dir}" ]; then
        echo "ERROR: AOMP build directory not found: ${aomp_build_dir}" >&2
        return 1
    fi

    # Validate that it looks like an LLVM build directory
    if [ ! -f "${aomp_build_dir}/build.ninja" ]; then
        echo "ERROR: ${aomp_build_dir} does not appear to be a valid LLVM build directory" >&2
        echo "       (build.ninja not found)" >&2
        return 1
    fi

    echo "${aomp_build_dir}"
}

get_aomp_src_dir() {
    # Default AOMP source directory
    local default_aomp_src_dir="${HOME}/git/aomp${AOMP_MAJOR_VERSION}.${AOMP_MINOR_VERSION}/llvm-project"

    # Use AOMP_SRC_DIR if set, otherwise use default
    local aomp_src_dir=${AOMP_SRC_DIR:-${default_aomp_src_dir}}

    # Check if version variables are needed but not set
    if [ -z "${AOMP_SRC_DIR}" ]; then
        if [ -z "${AOMP_MAJOR_VERSION}" ] || [ -z "${AOMP_MINOR_VERSION}" ]; then
            echo "ERROR: AOMP version not set. Please set AOMP_MAJOR_VERSION and AOMP_MINOR_VERSION" >&2
            echo "       or set AOMP_SRC_DIR explicitly to the AOMP source directory" >&2
            return 1
        fi
    fi

    # Validate that directory exists
    if [ ! -d "${aomp_src_dir}" ]; then
        echo "ERROR: AOMP source directory not found: ${aomp_src_dir}" >&2
        return 1
    fi

    # Validate that it looks like a git repository
    if [ ! -d "${aomp_src_dir}/.git" ]; then
        echo "ERROR: ${aomp_src_dir} does not appear to be a git repository" >&2
        return 1
    fi

    echo "${aomp_src_dir}"
}

# AOMP testing functions
check_aomp() {
    build_dir=$(get_aomp_build_dir) || return 1
    src_dir=$(get_aomp_src_dir) || return 1
    llvm_check_ ${build_dir} ${src_dir} llvm
}

check_aomp_all() {
    build_dir=$(get_aomp_build_dir) || return 1
    src_dir=$(get_aomp_src_dir) || return 1
    llvm_check_ ${build_dir} ${src_dir} llvm clang mlir flang openmp flang-rt offload
}

check_aomp_some() {
    build_dir=$(get_aomp_build_dir) || return 1
    src_dir=$(get_aomp_src_dir) || return 1
    llvm_check_ ${build_dir} ${src_dir} $@
}

clone_llvm_testsuite() {
    if [ ! -d ${WORK_AREA}/llvm-test-suite ];
    then
	set -x
	echo "Cloning the LLVM  testuite at ${WORK_AREA}/test-suite"
	git clone git@github.com:llvm/llvm-test-suite.git
	set +x
    else
	echo "Using LLVM testsuite at ${WORK_AREA}/llvm-test-suite"
    fi
}
setenv_llvm_testsuite() {
    echo "Setting up the environment for running the LLVM testsuite"
    export LLVM_PREFIX=$1
    export CXX=${LLVM_PREFIX}/bin/clang++
    export CC=${LLVM_PREFIX}/bin/clang
    export FC=${LLVM_PREFIX}/bin/flang-new
    export TESTSUITE=${TESTSUITE:-${WORK_AREA}/llvm-test-suite}
    export LLVM_LIT=${LLVM_LIT:-${BUILD_ROOT}/latest_build_dir/bin/llvm-lit}
}
# unsetenv_llvm_testsuite() {
#     echo "Resetting the environment"
#     unset LLVM_PREFIX
#     unset CXX
#     unset CC
#     unset FC
#     unset TESTSUITE
#     unset LLVM_LIT
# }
cmake_build_llvm_testsuite() {
    #    export PATH=/home/prbhanda/git/bhandarkar-pranav/build/cmake_for_testsuite/cmake-3.29.3-linux-x86_64/bin:$PATH
    local saved_dir="$PWD"
    cd $1
    export PATH=${HOME}/local/cmake/bin:${PATH}
    echo "---------- CONFIGURATION ------------------------"
    echo "CMAKE=$(command -v cmake)"
    echo "CMAKE_VERSION=$(command cmake --version)"
    echo "CC=${CC}"
    echo "CXX=${CXX}"
    echo "FC=${FC}"
    echo "LLVM_LIT=${LLVM_LIT}"
    echo "Using cmake as follows"
    echo   "
     cmake -G \"Ninja\" \
      -DCMAKE_C_COMPILER=${CC} \
      -DCMAKE_CXX_COMPILER=${CXX} \
      -DCMAKE_Fortran_COMPILER=${FC} \
      -DTEST_SUITE_COLLECT_CODE_SIZE:STRING=OFF \
      -DTEST_SUITE_SUBDIRS:STRING="Fortran" \
      -DTEST_SUITE_FORTRAN:STRING=ON \
      -DTEST_SUITE_LIT=${LLVM_LIT} \
      ${HOME}/git/bhandarkar-pranav/llvm-test-suite
      "

    echo "------------------------- ------------------------"

    #------
    sleep 5
    #------

    cmake -G "Ninja" \
	  -DCMAKE_C_COMPILER=${CC} \
	  -DCMAKE_CXX_COMPILER=${CXX} \
	  -DCMAKE_Fortran_COMPILER=${FC} \
	  -DTEST_SUITE_COLLECT_CODE_SIZE:STRING=OFF \
	  -DTEST_SUITE_SUBDIRS:STRING="Fortran" \
	  -DTEST_SUITE_FORTRAN:STRING=ON \
	  -DTEST_SUITE_LIT=${LLVM_LIT} \
	  ${TESTSUITE}

    # Capture the exit status of the CMake command
    cmake_status=$?

    if [ $cmake_status -ne 0 ]; then
	echo "Error: CMake configuration failed with exit code $cmake_status." >&2
	cd ${save_dir} >/dev/null
	exit $cmake_status
    fi

    echo "==> CMake configuration successful. Starting Ninja build..."
    echo "--------------------------------------------------------"

    #------
    sleep 2
    #------

    ninja

    ninja_status=$?

    if [ $ninja_status -ne 0 ]; then
	echo "Error: Ninja build failed with exit code $ninja_status." >&2
	cd ${saved_dir} >/dev/null
	exit $ninja_status
    fi
    cd ${saved_dir} >/dev/null
}
run_llvm_testsuite_tests() {
    saved_dir="$PWD"
    cd $1
    ninja check
    cd ${saved_dir} >/dev/null
}
run_llvm_testsuite() {
    setup_if_needed >/dev/null
    TOOLS=${1:-${WORK_AREA}/build/latest}
    clone_llvm_testsuite
    setenv_llvm_testsuite ${TOOLS}
    #    trap unsetenv_llvm_testsuite ERR INT EXIT

    BUILD_ID=${BUILD_ID:-$(get_default_build_id_ -l)}
    BUILD_DIR=${BUILD_ROOT}/llvm-test-suite/build-${BUILD_ID}

    mkdir -p ${BUILD_DIR} && cd "$_" >/dev/null
    pushd . >/dev/null
    cd ${BUILD_DIR}
    echo "Fresh llvm testsuite build"
    #------
    sleep 2
    #------

    cmake_build_llvm_testsuite ${BUILD_DIR}

    #------
    sleep 2
    #------

    run_llvm_testsuite_tests ${BUILD_DIR}

    popd >/dev/null
}
