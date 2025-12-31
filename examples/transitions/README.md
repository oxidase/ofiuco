# Transitions example

This example shows how to use `ofiuco` to fetch external dependencies for different platforms and build Python artifacts.

The test asserts that `deploy_arm64.zip`,`deploy_win.zip`, and `deploy_x86_64.zip` contain dynamic libraries files that have corresponding to platform flags.
Some Windows packages are cross-platform and contain PE files for Intel 386 or later processors, x64_64, and ARM64 little endian processors.


Some build commands:

```
bazel build @bazel_tools//tools/zip:zipper --platforms=//:linux_x86_64
bazelisk build "@clang-windows-x86_64//..."
```
