#!/bin/bash

CURR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${CURR_DIR}/../lib/build-utils.sh

build_llvm_flang_rt_hostdevice ~/git/bhandarkar-pranav/build/latest_build_dir ~/git/bhandarkar-pranav/build/latest
