#!/bin/sh

BUILD_WORKSPACE_DIRECTORY=$(dirname $(readlink -f WORKSPACE))
if [ ! -z ${TEST_TMPDIR+x} -a $1 != "transitions" ]; then
  export TMPDIR=$TEST_TMPDIR
fi
export HOME="$TEST_TMPDIR"
export LOCALAPPDATA="$TEST_TMPDIR"

cd examples/$1

if [[ -n "$WINDIR" ]] && ! grep -qE "^startup --(no)?windows_enable_symlinks$" .bazelrc; then
    echo "Skip $1 test on Windows"
    exit 0
fi

ARGS="--subcommands --test_output=errors --spawn_strategy=local --verbose_failures"
ARGS="$ARGS --override_repository=ofiuco=$BUILD_WORKSPACE_DIRECTORY"
ARGS="$ARGS --incompatible_autoload_externally="
[ -f MODULE.bazel ] && ARGS="$ARGS --override_module=ofiuco=$BUILD_WORKSPACE_DIRECTORY"

echo "Using $(bazelisk version)"
bazelisk test ... $ARGS
