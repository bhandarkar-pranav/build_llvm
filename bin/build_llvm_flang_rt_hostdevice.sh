#!/bin/bash

# CURR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# source ${CURR_DIR}/../lib/build-utils.sh

# build_llvm_flang_rt_hostdevice ~/git/bhandarkar-pranav/build/latest_build_dir ~/git/bhandarkar-pranav/build/latest
AOMP_DIR=aomp${AOMP_MAJOR_VERSION}.${AOMP_MINOR_VERSION}
AOMP_PATH=${HOME}/git/${AOMP_DIR}
if [ ! -d ${AOMP_PATH} ]; then
    echo "${AOMP_PATH} does not exist. Exiting .."
    return 1
fi



     #SUFFIX=_gfx90a GFXLIST=gfx90a ~/git/aomp22.0/aomp/bin/build_llvm-flang-rt-host-dev.sh
