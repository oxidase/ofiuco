#!/bin/sh
BUILD_WORKSPACE_DIRECTORY=$(readlink -f MODULE.bazel)/..
cd examples/$1
bazel test ... --test_output=errors --spawn_strategy=local --override_module=rules_poetry=$BUILD_WORKSPACE_DIRECTORY
