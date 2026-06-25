# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

A collection of scripts to build, test, and manage LLVM-project builds. The repository is structured around two directories:
- `lib/`: Contains shared library code (primarily `build-utils.sh`)
- `bin/`: Contains executable scripts that use functionality from `lib/`

## Directory Structure & Environment Variables

The scripts assume a specific directory layout:

```
${ROOT}/
└── ${USER_OR_ORG}/              # Default: "bhandarkar-pranav"
    ├── llvm-project/            # Source repository
    └── build/                   # All builds happen here
        ├── build-<BUILD_ID>/
        ├── install-<BUILD_ID>/
        ├── latest               # Symlink to latest Release install
        └── latest_build_dir     # Symlink to latest Release build
```

**Required environment variables:**
- `ROOT`: Top-level directory (no default - MUST be set by user)
  - Example: `ROOT=$HOME/git` or `ROOT=/work2/prbhanda/git`

**Auto-configured variables:**
- `USER_OR_ORG`: Defaults to `bhandarkar-pranav`
- `WORK_AREA`: Set to `${ROOT}/${USER_OR_ORG}` (cannot be overridden)
- `BUILD_ROOT`: Set to `${WORK_AREA}/build` (cannot be overridden)
- `BUILD_TYPE`: `Release` or `Debug` (defaults to `Release`)
- `BUILD_ID`: Date-based suffix (e.g., `29Jul24`), auto-generated if not set

## Common Commands

### Initial Setup & Build
```bash
# First time setup - clones llvm-project and builds LLVM
ROOT=/path/to/root ./bin/build_gh.sh -c

# The above clones to ${ROOT}/bhandarkar-pranav/llvm-project
# and builds at ${ROOT}/bhandarkar-pranav/build/build-<date>
```

### Building LLVM
```bash
# Clean build (default)
ROOT=/path/to/root ./bin/build_gh.sh -c

# Incremental update (uses latest_build_dir)
ROOT=/path/to/root ./bin/build_gh.sh -u

# Custom build ID
ROOT=/path/to/root BUILD_ID=myCustomID ./bin/build_gh.sh -c

# Debug build
ROOT=/path/to/root BUILD_TYPE=Debug ./bin/build_gh.sh -c

# Skip test checks after build
ROOT=/path/to/root ./bin/build_gh.sh --no-check
```

### Running Tests
```bash
# Run check-llvm only
./bin/check_llvm.sh llvm

# Run all checks (llvm, clang, mlir, flang, openmp, flang-rt, offload)
./bin/check_llvm.sh all

# Run specific checks
./bin/check_llvm.sh some llvm flang openmp
```

### LLVM Test Suite (Fortran tests)
```bash
# Run gfortran test suite on default toolchain (latest)
./bin/run_llvm_testsuite.sh

# Run on specific toolchain
./bin/run_llvm_testsuite.sh /path/to/install
```

## Key Build Configuration

The build configuration in `build-utils.sh:build_llvm_gh()` includes:
- **Enabled projects**: clang, lld, llvm, flang
- **Enabled runtimes**: libcxx, libcxxabi, libunwind, openmp, offload, compiler-rt, flang-rt
- **Targets**: X86, AMDGPU (+ NVPTX if `BUILD_CUDA=1`)
- **Runtime targets**: default + amdgcn-amd-amdhsa
- Build type defaults to Release with assertions enabled
- Shared libraries (`BUILD_SHARED_LIBS=ON`)
- Sanitizers enabled, but XRay/ORC/MemProf/LibFuzzer disabled

## Build Parallelism

Number of build jobs is auto-detected (half of available cores, capped at 64). The function `num_jobs_()` handles this.

## Test Result Logging

Test results are logged to:
```
<build_dir>/ninja_check_dir/<YYYY-MM-DD>/<branch>-<sha>/
```

Each test run creates timestamped log files (e.g., `llvm-14-30-15.txt`) containing:
- LLVM revision
- Full test output
- Pass/Fail status

## Specialized Scripts

### build_llvm_flang_rt_hostdevice.sh
Builds the Flang runtime with host-device offload support for AMD GPU architectures. Creates a separate `flang-runtime-<BUILD_ID>` directory.

### build_asan_ubsan.sh
Builds LLVM with Address and Undefined Behavior sanitizers. This is a two-stage build:
1. Build libcxx/libcxxabi with ASan/UBSan
2. Build LLVM using the sanitized libcxx

Requires `STAGE1_TOOLS` to be set (defaults to `/COD/LATEST/trunk`).

## Working with the Code

### To modify build options:
Edit `lib/build-utils.sh`, specifically the `set_up_vars_for_new_gh_build_()` and `build_llvm_gh()` functions.

### To add new scripts:
1. Create in `bin/` directory
2. Source the build utilities: `source ${CURR_DIR}/../lib/build-utils.sh`
3. Use existing functions from `build-utils.sh`

### Important utility functions in build-utils.sh:
- `set_up()`: One-time setup (clone repo, create directories)
- `build_llvm_gh()`: Fresh LLVM build
- `update_llvm_gh()`: Incremental build
- `check_llvm()`, `check_all()`, `check_some()`: Run ninja checks
- `run_llvm_testsuite()`: Run LLVM test suite
- `clone_repo_()`: Clone llvm-project from github.com/${USER_OR_ORG}/llvm-project
