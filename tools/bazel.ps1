Set-PSDebug -Trace 1

& $env:BAZEL_REAL --output_base=$(if ($env:CACHE_DIR) { $env:CACHE_DIR } else { "$env:USERPROFILE\.cache\bazel" }) @args
