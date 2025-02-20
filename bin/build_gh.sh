#!/bin/bash

set -o pipefail
usage() {
    echo "Usage:"
    echo "$(basename ${BASH_SOURCE[0]}) [options]"
    echo "     Builds a github repository"
    echo "Options:"
    echo "     -h | --help     : Print this usage message"
    echo "     -c | --clean    : Do a clean build. Default"
    echo "     -u | --update   : Not a fresh build. Updates BUILD_DIR from the environment. Default BUILD_DIR is $ROOT/$USER_OR_ORG/build/latest_build_dir"
}

CURR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${CURR_DIR}/../lib/build-utils.sh
check="yes"
clean="yes"
while [[ $# -gt 0 ]];
do
    case $1 in
	"-h" | "--help")
	    usage
	    exit 0
	    ;;
	"-c" | "--clean")
	    clean="yes"
	    ;;
	"-u" | "--update")
	    clean="no"
	    ;;
	"--no-check")
	    check="no"
	    ;;
	*)
	    build_llvm_gh
	    ;;
    esac
    shift
done
if [[ "$clean" == "yes" ]];
then
    build_llvm_gh
else
    update_llvm_gh
fi

if [[ "$check" == "yes" ]];
then
    check_all
fi

exit 0
