#!/bin/bash

set -o pipefail

usage() {
    echo "Usage:"
    echo "  $(basename ${BASH_SOURCE[0]}) [options] [targets]"
    echo ""
    echo "Options:"
    echo "  -h | --help           : Print this usage message"
    echo "  -r | --repo <name>    : Specify repo (github or aomp, default: github)"
    echo "  --more-help           : Show detailed help with environment variables"
    echo ""
    echo "Examples:"
    echo "  $(basename ${BASH_SOURCE[0]}) llvm                    # test github llvm only"
    echo "  $(basename ${BASH_SOURCE[0]}) all                     # test all github components"
    echo "  $(basename ${BASH_SOURCE[0]}) --repo aomp llvm        # test aomp llvm only"
    echo "  $(basename ${BASH_SOURCE[0]}) -r aomp some llvm flang # test specific aomp components"
}

detailed_usage() {
    echo "Usage:"
    echo "  $(basename ${BASH_SOURCE[0]}) [options] [targets]"
    echo ""
    echo "Description:"
    echo "  Run ninja check-* tests on LLVM builds. Supports both github and aomp repositories."
    echo ""
    echo "Options:"
    echo "  -h | --help           : Print concise usage message"
    echo "  -r | --repo <name>    : Specify repo (github or aomp, default: github)"
    echo "  --more-help           : Show this detailed help"
    echo ""
    echo "Test Target Arguments:"
    echo "  llvm | -l | --l       : Run 'ninja check-llvm' only"
    echo "  all  | -a | --a       : Run checks for all components (llvm, clang, mlir, flang, openmp, flang-rt, offload)"
    echo "  some | these | -s | --s <list> : Run checks for specified components"
    echo "                          Example: $(basename ${BASH_SOURCE[0]}) some llvm flang"
    echo ""
    echo "Environment Variables (github):"
    echo "  ROOT                  : Top-level directory (required for github)"
    echo "  USER_OR_ORG           : GitHub org/user (default: bhandarkar-pranav)"
    echo "  BUILD_DIR             : Specific build directory to test"
    echo "                          (default: \${ROOT}/\${USER_OR_ORG}/build/latest_build_dir)"
    echo ""
    echo "Environment Variables (aomp):"
    echo "  AOMP_MAJOR_VERSION    : AOMP major version (e.g., 23)"
    echo "  AOMP_MINOR_VERSION    : AOMP minor version (e.g., 0)"
    echo "  AOMP_BUILD_DIR        : AOMP build directory"
    echo "                          (default: \${HOME}/git/aomp\${AOMP_MAJOR_VERSION}.\${AOMP_MINOR_VERSION}/build/llvm-project)"
    echo "  AOMP_SRC_DIR          : AOMP source directory"
    echo "                          (default: \${HOME}/git/aomp\${AOMP_MAJOR_VERSION}.\${AOMP_MINOR_VERSION}/llvm-project)"
    echo ""
    echo "Examples:"
    echo "  # Test github llvm with default settings"
    echo "  $(basename ${BASH_SOURCE[0]}) llvm"
    echo ""
    echo "  # Test all github components"
    echo "  $(basename ${BASH_SOURCE[0]}) all"
    echo ""
    echo "  # Test specific github components"
    echo "  $(basename ${BASH_SOURCE[0]}) some llvm flang openmp"
    echo ""
    echo "  # Test aomp llvm (requires AOMP_MAJOR_VERSION and AOMP_MINOR_VERSION)"
    echo "  $(basename ${BASH_SOURCE[0]}) --repo aomp llvm"
    echo ""
    echo "  # Test all aomp components with explicit build directory"
    echo "  AOMP_BUILD_DIR=/custom/path/build $(basename ${BASH_SOURCE[0]}) -r aomp all"
    echo ""
    echo "Test Results:"
    echo "  Results are logged to: <build_dir>/ninja_check_dir/<date>/<branch-sha>/"
}

CURR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${CURR_DIR}/../lib/build-utils.sh

# Default repo is github
REPO="github"

# Parse --repo flag first
while [[ $# -gt 0 ]];
do
    case $1 in
        "-h" | "--help")
            usage
            exit 0
            ;;
        "--more-help")
            detailed_usage
            exit 0
            ;;
        "-r" | "--repo")
            shift
            if [[ -z "$1" ]]; then
                echo "ERROR: --repo requires an argument" >&2
                echo "" >&2
                usage
                exit 1
            fi
            REPO="$1"
            if [[ "$REPO" != "github" && "$REPO" != "aomp" ]]; then
                echo "ERROR: Unknown repo: $REPO. Valid options: github, aomp" >&2
                echo "" >&2
                usage
                exit 1
            fi
            shift
            ;;
        *)
            # Not a flag we recognize, stop parsing
            break
            ;;
    esac
done

# Now handle the test target arguments
if [[ $# -eq 0 ]]; then
    echo "ERROR: No test target specified" >&2
    echo "" >&2
    usage
    exit 1
fi

case "$1" in
    "" | "llvm"| "-l" | "--l")
        echo "---- Checking only llvm (repo: $REPO) ----"
        if [[ "$REPO" == "aomp" ]]; then
            check_aomp
        else
            check_llvm
        fi
        ;;
    "all" | "-a" | "--a")
        echo "---- Checking llvm, clang, mlir, flang, openmp, flang-rt, offload (repo: $REPO) ----"
        if [[ "$REPO" == "aomp" ]]; then
            check_aomp_all
        else
            check_all
        fi
        ;;
    "some" | "these" | "-s" | "--s")
        shift
        echo "---- Checking $@ (repo: $REPO) ----"
        if [[ "$REPO" == "aomp" ]]; then
            check_aomp_some $@
        else
            check_some $@
        fi
        ;;
    *)
        echo "ERROR: Unknown test target: $1" >&2
        echo "" >&2
        usage
        exit 1
        ;;
esac
