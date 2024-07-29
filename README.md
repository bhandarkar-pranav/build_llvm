# build_llvm

A repository of scripts to build LLVM and test it. This may also include
other scripts to simplify life inside my company.

## Basic Setup

The repository has two important directorys `lib` and `bin`. The `bin` directory is meant to
house executable scripts that use functionality provided by code in the `lib` directory. The
main library inside `lib` is `build-utils.sh`.

## Usage
The scripts assume the following directory structure when building and testing LLVM.

The source repository `llvm-project` resides in `${WORK_AREA}` where

 `WORK_AREA=${ROOT}/${USER_OR_ORG}`

`ROOT` has to be provided at all times and doesn't have a default value. e.g. On
 AMD machines, it'll typically be `ROOT=$HOME/git`.
 `USER_OR_ORG` can be specified by the user but the default value is `bhandarkar-pranav`


 Here is a description of other relevant variables

| Environment Variable | Description | Default |
| `BUILD_ROOT` | `${WORK_AREA}/build` - Cannot be overriden. All builds are done inside ${WORK_AREA}/build | |
| `BUILD_DIR`  |  A specific build directory inside ${BUILD_ROOT} being built or updated | |
| ` BUILD_TYPE` | `Release` or `Debug` | `Release` |
