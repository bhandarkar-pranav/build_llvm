#!/bin/bash -x

get_suffix_() {
    FORMATTED_DATE=$(date +"%d%h%y_%H%M")
    echo ${FORMATTED_DATE}
}
setup_dirs() {
    mkdir -p ${BLD_DIR}
    mkdir -p ${INSTALL_PREFIX}
    mkdir -p ${LIBCXX_BLD_DIR}
    mkdir -p ${LIBCXX_INSTALL_DIR}
}
cmake_build_libcxx() {
    pushd . >/dev/null
    cd $BLD_ROOT
    cmake -B ${LIBCXX_BLD_DIR_NAME} \
	  -DLLVM_APPEND_VC_REV=OFF \
	  -G Ninja \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DLLVM_CCACHE_BUILD=ON \
	  -DLLVM_USE_LINKER=lld \
	  -DLLVM_ENABLE_ASSERTIONS=ON \
	  -DCMAKE_C_COMPILER=${STAGE1_C_COMPILER} \
	  -DCMAKE_CXX_COMPILER=${STAGE1_CXX_COMPILER} \
	  -DLIBCXXABI_USE_LLVM_UNWINDER=OFF \
	  -DCMAKE_INSTALL_PREFIX=${LIBCXX_INSTALL_DIR} \
	  -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi" \
	  -DLIBCXX_TEST_PARAMS=long_tests=False \
	  -DLIBCXX_INCLUDE_BENCHMARKS=OFF \
	  -DLLVM_USE_SANITIZER="Address;Undefined" \
	  -DCMAKE_C_FLAGS="-fsanitize=address,undefined -fno-sanitize-recover=all   -fno-sanitize=vptr" \
	  -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-sanitize-recover=all   -fno-sanitize=vptr" \
	  ${LLVM_PROJECT}/runtimes
    cd ${LIBCXX_BLD_DIR}
    ninja -j128 install
    popd > /dev/null
}
cmake_build_llvm() {
    pushd . >/dev/null
    cd $BLD_ROOT
    cmake -B ${BLD_DIR_NAME} \
	  -DLLVM_APPEND_VC_REV=OFF \
	  -G Ninja \
	  -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DLLVM_CCACHE_BUILD=ON \
	  -DLLVM_USE_LINKER=lld \
	  -DLLVM_ENABLE_ASSERTIONS=ON \
	  -DCMAKE_C_COMPILER=${STAGE1_C_COMPILER} \
	  -DCMAKE_CXX_COMPILER=${STAGE1_CXX_COMPILER} \
	  -DLLVM_ENABLE_PROJECTS="clang;lld;clang-tools-extra;mlir" \
	  -DLLVM_USE_SANITIZER="Address;Undefined" \
	  -DLLVM_ENABLE_LIBCXX=ON \
	  -DCMAKE_C_FLAGS="-nostdinc++ -isystem  %{LIBCXX_INSTALL_DIR}/include -isystem ${LIBCXX_INSTALL_DIR}/include/c++/v1 -fsanitize=address,undefined -fno-sanitize-recover=all -Wl,--rpath=${LIBCXX_INSTALL_DIR}/lib -L${LIBCXX_INSTALL_DIR}/lib -w" \
	  -DCMAKE_CXX_FLAGS="-nostdinc++ -isystem ${LIBCXX_INSTALL_DIR}/include -isystem ${LIBCXX_INSTALL_DIR}/include/c++/v1 -fsanitize=address,undefined -fno-sanitize-recover=all -Wl,--rpath=${LIBCXX_INSTALL_DIR}/lib -L${LIBCXX_INSTALL_DIR}/lib -w" \
	  -DCMAKE_EXE_LINKER_FLAGS="-Wl,--rpath=${LIBCXX_INSTALL_DIR}/lib -L${LIBCXX_INSTALL_DIR}/lib" \
	  ${LLVM_PROJECT}/llvm
    cd ${BLD_DIR}
    ninja -j128 install
    popd > /dev/null
}
export WORK_ROOT=${WORK_ROOT:-~/git/bhandarkar-pranav}
export LLVM_PROJECT=${SRCS:-${WORK_ROOT}/llvm-project}
export SRCS=${LLVM_PROJECT}
export BLD_ROOT=${BLD_ROOT:-${WORK_ROOT}/build/asan-ubsan_test}
export SUFFIX=$(get_suffix_)
export BLD_DIR_NAME=${BLD_DIR_NAME:-build-${SUFFIX}}
export BLD_DIR=${BLD_DIR:-${BLD_ROOT}/${BLD_DIR_NAME}}
export INSTALL_PREFIX=${INSTALL_PREFIX:-install-${SUFFIX}}
export LIBCXX_BLD_DIR_NAME=${LIBCXX_BLD_DIR_NAME:-build-libcxx-${SUFFIX}}
export LIBCXX_BLD_DIR=${LIBCXX_BLD_DIR:-${BLD_ROOT}/${LIBCXX_BLD_DIR_NAME}}
export LIBCXX_INSTALL_DIR=${LIBCXX_INSTALL_DIR:-${BLD_ROOT}/install-libcxx-${SUFFIX}}
export STAGE1_TOOLS=${STAGE1_TOOLS:-/COD/LATEST/trunk}
export STAGE1_C_COMPILER=${STAGE1_TOOLS}/bin/clang
export STAGE1_CXX_COMPILER=${STAGE1_TOOLS}/bin/clang++
export CMAKE_PREFIX_PATH=${STAGE1_TOOLS}
export LIBCXX_LOG=${BLD_ROOT}/libcxx-${SUFFIX}.log
export BLD_LOG=${BLD_ROOT}/build-${SUFFIX}.log
echo $LIBCXX_INSTALL_DIR
setup_dirs
cmake_build_libcxx 2>&1 | tee ${LIBCXX_LOG}
cmake_build_llvm 2>&1 | tee ${BLD_LOG}

