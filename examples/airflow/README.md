# airflow example

This example shows how to use `ofiuco` to fetch external dependencies from a pyproject.toml file
and than use in BUILD files as dependencies of Bazel targets.

The `uv.lock` file can be updated with
```
bazel run :lock
```


## Limitations of testing on Windows

Building abseil library fails as

```text
2026-01-03T17:12:13.1346563Z ERROR: D:/_bazel/execroot/_main/_tmp/b25a0347992b83195d2ed6a61a6012a7/_bazel_runneradmin/nhmdqkao/external/abseil-cpp+/absl/base/BUILD.bazel:247:11: Linking external/abseil-cpp+/absl/base/base_f8dfbca7.dll failed: (Exit 1120): link.exe failed: error executing CppLink command (from cc_library rule target @@abseil-cpp+//absl/base:base)
2026-01-03T17:12:13.1349024Z   cd /d D:/_bazel/execroot/_main/_tmp/b25a0347992b83195d2ed6a61a6012a7/_bazel_runneradmin/nhmdqkao/execroot/_main
2026-01-03T17:12:13.1353931Z   SET LIB=C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\MSVC\14.44.35207\ATLMFC\lib\x64;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\MSVC\14.44.35207\lib\x64;C:\Program Files (x86)\Windows Kits\NETFXSDK\4.8\lib\um\x64;C:\Program Files (x86)\Windows Kits\10\lib\10.0.26100.0\ucrt\x64;C:\Program Files (x86)\Windows Kits\10\\lib\10.0.26100.0\\um\x64
2026-01-03T17:12:13.1361211Z     SET PATH=C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\MSVC\14.44.35207\bin\HostX64\x64;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\VC\VCPackages;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TestWindow;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\bin\Roslyn;C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\x64\;C:\Program Files (x86)\HTML Help Workshop;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\CommonExtensions\Microsoft\FSharp\Tools;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Team Tools\DiagnosticsHub\Collector;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\Extensions\Microsoft\CodeCoverage.Console;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\Llvm\x64\bin;C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\\x64;C:\Program Files (x86)\Windows Kits\10\bin\\x64;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\\MSBuild\Current\Bin\amd64;C:\Windows\Microsoft.NET\Framework64\v4.0.30319;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\;;C:\Windows\system32;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\VC\Linux\bin\ConnectionManagerExe;C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\vcpkg
2026-01-03T17:12:13.1592575Z     SET ***
2026-01-03T17:12:13.1593195Z     SET RUNFILES_MANIFEST_ONLY=1
2026-01-03T17:12:13.1598168Z     SET TEMP=C:\Users\RUNNER~1\AppData\Local\Temp
2026-01-03T17:12:13.1598792Z     SET TMP=C:\Users\RUNNER~1\AppData\Local\Temp
2026-01-03T17:12:13.1599815Z   C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\MSVC\14.44.35207\bin\HostX64\x64\link.exe @bazel-out/x64_windows-fastbuild-ST-9d3588d462b9/bin/external/abseil-cpp+/absl/base/base_f8dfbca7.dll-0.params
2026-01-03T17:12:13.1605226Z # Configuration: 31546c98112b7b037b7fea7739d1abfeaba49bde7949841a4dc943d310adfb44
2026-01-03T17:12:13.1605748Z # Execution platform: @@platforms//host:host
2026-01-03T17:12:13.1606679Z    Creating library bazel-out/x64_windows-fastbuild-ST-9d3588d462b9/bin/external/abseil-cpp+/absl/base/base.if.lib and object bazel-out/x64_windows-fastbuild-ST-9d3588d462b9/bin/external/abseil-cpp+/absl/base/base.if.exp
2026-01-03T17:12:13.1642737Z spinlock.obj : error LNK2019: unresolved external symbol "void __cdecl absl::lts_20250814::raw_log_internal::RawLog(enum absl::lts_20250814::LogSeverity,char const *,int,char const *,...)" (?RawLog@raw_log_internal@lts_20250814@absl@@YAXW4LogSeverity@23@PEBDH1ZZ) referenced in function "void __cdecl absl::lts_20250814::base_internal::CallOnceImpl<class <lambda_8fd3b8010752636dc23623aff4d8d4c5> >(struct std::atomic<unsigned int> *,enum absl::lts_20250814::base_internal::SchedulingMode,class <lambda_8fd3b8010752636dc23623aff4d8d4c5> &&)" (??$CallOnceImpl@V<lambda_8fd3b8010752636dc23623aff4d8d4c5>@@$$V@base_internal@lts_20250814@absl@@YAXPEAU?$atomic@I@std@@W4SchedulingMode@012@$$QEAV<lambda_8fd3b8010752636dc23623aff4d8d4c5>@@@Z)
2026-01-03T17:12:13.1646823Z sysinfo.obj : error LNK2001: unresolved external symbol "void __cdecl absl::lts_20250814::raw_log_internal::RawLog(enum absl::lts_20250814::LogSeverity,char const *,int,char const *,...)" (?RawLog@raw_log_internal@lts_20250814@absl@@YAXW4LogSeverity@23@PEBDH1ZZ)
2026-01-03T17:12:13.1657170Z spinlock.obj : error LNK2019: unresolved external symbol "unsigned int __cdecl absl::lts_20250814::base_internal::SpinLockWait(struct std::atomic<unsigned int> *,int,struct absl::lts_20250814::base_internal::SpinLockWaitTransition const * const,enum absl::lts_20250814::base_internal::SchedulingMode)" (?SpinLockWait@base_internal@lts_20250814@absl@@YAIPEAU?$atomic@I@std@@HQEBUSpinLockWaitTransition@123@W4SchedulingMode@123@@Z) referenced in function "void __cdecl absl::lts_20250814::base_internal::CallOnceImpl<class <lambda_8fd3b8010752636dc23623aff4d8d4c5> >(struct std::atomic<unsigned int> *,enum absl::lts_20250814::base_internal::SchedulingMode,class <lambda_8fd3b8010752636dc23623aff4d8d4c5> &&)" (??$CallOnceImpl@V<lambda_8fd3b8010752636dc23623aff4d8d4c5>@@$$V@base_internal@lts_20250814@absl@@YAXPEAU?$atomic@I@std@@W4SchedulingMode@012@$$QEAV<lambda_8fd3b8010752636dc23623aff4d8d4c5>@@@Z)
2026-01-03T17:12:13.1662498Z sysinfo.obj : error LNK2001: unresolved external symbol "unsigned int __cdecl absl::lts_20250814::base_internal::SpinLockWait(struct std::atomic<unsigned int> *,int,struct absl::lts_20250814::base_internal::SpinLockWaitTransition const * const,enum absl::lts_20250814::base_internal::SchedulingMode)" (?SpinLockWait@base_internal@lts_20250814@absl@@YAIPEAU?$atomic@I@std@@HQEBUSpinLockWaitTransition@123@W4SchedulingMode@123@@Z)
2026-01-03T17:12:13.1669523Z spinlock.obj : error LNK2019: unresolved external symbol AbslInternalSpinLockWake_lts_20250814 referenced in function "void __cdecl absl::lts_20250814::base_internal::SpinLockWake(struct std::atomic<unsigned int> *,bool)" (?SpinLockWake@base_internal@lts_20250814@absl@@YAXPEAU?$atomic@I@std@@_N@Z)
2026-01-03T17:12:13.1671891Z sysinfo.obj : error LNK2001: unresolved external symbol AbslInternalSpinLockWake_lts_20250814
2026-01-03T17:12:13.1674492Z spinlock.obj : error LNK2019: unresolved external symbol AbslInternalSpinLockDelay_lts_20250814 referenced in function "void __cdecl absl::lts_20250814::base_internal::SpinLockDelay(struct std::atomic<unsigned int> *,unsigned int,int,enum absl::lts_20250814::base_internal::SchedulingMode)" (?SpinLockDelay@base_internal@lts_20250814@absl@@YAXPEAU?$atomic@I@std@@IHW4SchedulingMode@123@@Z)
2026-01-03T17:12:13.1685101Z bazel-out\x64_windows-fastbuild-ST-9d3588d462b9\bin\external\abseil-cpp+\absl\base\base_f8dfbca7.dll : fatal error LNK1120: 4 unresolved externals
```


Airflow package con not be fully tested on [Windows](https://github.com/apache/airflow/issues/10388) as
```
Airflow currently can be run on POSIX-compliant Operating Systems. For development, it is regularly tested on fairly modern Linux Distros and recent versions of macOS. On Windows you can run it via WSL2 (Windows Subsystem for Linux 2) or via Linux Containers. The work to add Windows support is tracked via https://github.com/apache/airflow/issues/10388, but it is not a high priority.
```
