#!/bin/sh
BUILD_WORKSPACE_DIRECTORY=$(dirname $(readlink -f MODULE.bazel))
cd examples/$1
bazel test ... --test_output=errors --spawn_strategy=local --verbose_failures --override_module=rules_poetry=$BUILD_WORKSPACE_DIRECTORY
