# build_llvm

A repository of scripts to build LLVM and test it. This may also include
other scripts to simplify life inside my company.

## Basic Setup

The repository has two important directories `lib` and `bin`. The `bin` directory is meant to
house executable scripts that use functionality provided by code in the `lib` directory. The
main library inside `lib` is `build-utils.sh`.

## Usage
The scripts assume the following directory structure when building and testing LLVM.

The source repository `llvm-project` resides in `${WORK_AREA}` where

 `WORK_AREA=${ROOT}/${USER_OR_ORG}`

**`ROOT` has to be provided at all times and doesn't have a default value. e.g. On
 AMD machines, it'll typically be `ROOT=$HOME/git`.**
 `USER_OR_ORG` can be specified by the user but the default value is `bhandarkar-pranav`


 Here is a description of all environment variables


| Environment Variable | Description | Default |
| ---------------------|-------------|--------- |
| `ROOT`  | The toplevel directory inside which everything resides | No Defaults. Has to be provided by the user |
| `WORK_AREA` | Value is `${ROOT}/${USER_OR_ORG} | Cannot be overwritten but is configurable by setting the values of `ROOT` and `USER_OR_ORG` |
| `USER_OR_ORG` | First sub-directory of `${ROOT}` | `bhandarkar-pranav` |
| `BUILD_ROOT` | `${WORK_AREA}/build` - Cannot be overriden. All builds are done inside `${WORK_AREA}/build` |  |
| `BUILD_DIR`  |  A specific build directory inside `${BUILD_ROOT}` being built or updated | |
| `BUILD_TYPE` | `Release` or `Debug` | `Release` |

### Examples

To build LLVM for the first time
```
$> git clone git@github.com:bhandarkar-pranav/build_llvm.git
$> cd build_llvm
$> ROOT=<path/to/preferred/root/dir> ./bin/build_gh.sh -c
```

The above will clone ``llvm-project`` into `${ROOT}/bhandarkar-pranav/llvm-project` if not already present. It'll then build LLVM at `${WORK_AREA}/build/build-<suffix>`.
Once the build is done, it'll be installed at `${WORK_AREA}/builld/install-<suffix>`, where
`WORK_AREA = ${ROOT}/bhandarkar-pranav`
`suffix` is a string based on the date such as `29Jul24`
