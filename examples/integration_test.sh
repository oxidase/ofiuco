cd examples/$1
bazel test ...  --test_output=errors --spawn_strategy=local
