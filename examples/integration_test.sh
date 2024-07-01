#!/bin/sh
BUILD_WORKSPACE_DIRECTORY=$(dirname $(readlink -f WORKSPACE))
if [ ! -z ${TEST_TMPDIR+x} -a $1 != "transitions" ]; then
  export TMPDIR=$TEST_TMPDIR
fi
export HOME=$TEST_TMPDIR

cd examples/$1

ARGS="--test_output=errors --spawn_strategy=local --verbose_failures"
ARGS="$ARGS --override_repository=rules_ophiuchus=$BUILD_WORKSPACE_DIRECTORY"
[ -f MODULE.bazel ] && ARGS="$ARGS --override_module=rules_ophiuchus=$BUILD_WORKSPACE_DIRECTORY"

echo "Using $(bazelisk version)"
bazelisk test ... $ARGS

