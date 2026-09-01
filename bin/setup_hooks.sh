#!/bin/bash

set -o pipefail

usage() {
    echo "Usage:"
    echo "$(basename ${BASH_SOURCE[0]}) [llvm-project-path]"
    echo "     Set up git hooks for LLVM development"
    echo ""
    echo "Arguments:"
    echo "     llvm-project-path  : Path to llvm-project repository (optional)"
    echo "                          Defaults to \${WORK_AREA}/llvm-project"
    echo ""
    echo "Options:"
    echo "     -h | --help        : Print this usage message"
    echo ""
    echo "Description:"
    echo "     Configures the pre-commit hook to use LLVM's code-format-helper.py"
    echo "     This ensures code formatting standards are enforced before commits."
    echo ""
    echo "Example:"
    echo "     # Use default location"
    echo "     ROOT=/path/to/root $(basename ${BASH_SOURCE[0]})"
    echo ""
    echo "     # Specify custom path"
    echo "     $(basename ${BASH_SOURCE[0]}) /path/to/llvm-project"
}

# Get the directory where this script is located
CURR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Source the build utilities
if [ ! -f "${CURR_DIR}/../lib/build-utils.sh" ]; then
    echo "ERROR: Cannot find build-utils.sh at ${CURR_DIR}/../lib/build-utils.sh" >&2
    exit 1
fi

source ${CURR_DIR}/../lib/build-utils.sh

# Parse command line arguments
while [[ $# -gt 0 ]];
do
    case $1 in
        "-h" | "--help")
            usage
            exit 0
            ;;
        -*)
            echo "ERROR: Unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            # Assume it's the llvm-project path
            LLVM_PROJECT_PATH="$1"
            shift
            ;;
    esac
done

# Determine the llvm-project path
if [ -n "${LLVM_PROJECT_PATH}" ]; then
    # User provided a path, use it directly
    llvm_src_dir="${LLVM_PROJECT_PATH}"
else
    # Use default location based on ROOT and USER_OR_ORG
    if ! is_root_set_; then
        echo "ERROR: Environment variable ROOT not set and no path provided." >&2
        echo "       Either set ROOT or provide llvm-project path as argument." >&2
        echo "" >&2
        usage
        exit 1
    fi

    if ! is_root_valid_path_; then
        echo "ERROR: ROOT is set to '${ROOT}' but this is not a valid directory." >&2
        exit 1
    fi

    check_user_or_org_
    llvm_src_dir="${ROOT}/${USER_OR_ORG}/llvm-project"
fi

# Validate and normalize the path
llvm_src_dir=$(readlink -f "${llvm_src_dir}" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "${llvm_src_dir}" ]; then
    echo "ERROR: Invalid path provided: ${LLVM_PROJECT_PATH:-${ROOT}/${USER_OR_ORG}/llvm-project}" >&2
    exit 1
fi

# Display what we're about to do
echo "==========================================="
echo "Setting up git hooks for LLVM development"
echo "==========================================="
echo "LLVM source directory: ${llvm_src_dir}"
echo ""

# Call the setup_hooks_ function
setup_hooks_ "${llvm_src_dir}"
exit_status=$?

if [ $exit_status -eq 0 ]; then
    echo ""
    echo "==========================================="
    echo "SUCCESS: Git hooks configured"
    echo "==========================================="
    echo "Pre-commit hook will now enforce code formatting standards."
    echo "To bypass the hook temporarily (not recommended), use:"
    echo "    git commit --no-verify"
else
    echo ""
    echo "==========================================="
    echo "FAILED: Git hooks setup failed"
    echo "==========================================="
    echo "Exit code: $exit_status"
    exit $exit_status
fi

exit 0
