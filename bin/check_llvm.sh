#!/bin/bash

set -o pipefail

usage() {
    echo "Usage:"
    echo "$(basename ${BASH_SOURCE[0]}) [options]"
    echo "     ninja check for LLVM"
    echo "Options:"
    echo "     -h | --help     : Print this usage message"
    echo "     -l | --l | llvm : 'ninja check-llvm' only"
    echo "     -a | --a | all  : 'ninja check-llvm check-clang check-mlir check-flang'"
    echo "     -s | --s | some | these : Run ninja check using the specified list of targets. Eg. check_llvm.sh these llvm flang"
}

CURR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${CURR_DIR}/../lib/build-utils.sh

case "$1" in
    "-h" | "--help")
	usage
	exit 0
	;;
    "" | "llvm"| "-l" | "--l")
	echo "---- Checking only llvm ----"
	check_llvm
	;;
    "all" | "-a" | "--a")
	echo "---- Checking llvm, clang, flang and mlir----"
	check_all
	;;
    "some" | "these" | "-s" | "--s")
	shift
	echo "----Checking $@-----"
	check_some $@
	;;
esac







