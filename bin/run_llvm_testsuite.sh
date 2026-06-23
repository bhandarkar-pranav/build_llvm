#!/bin/bash

set -o pipefail

usage() {
    echo "Usage:"
    echo "$(basename ${BASH_SOURCE[0]}) <optional: Path to toolchain to test>"
}

CURR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${CURR_DIR}/../lib/build-utils.sh


run_llvm_testsuite $1
