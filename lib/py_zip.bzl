load("//lib/private:py_zip.bzl", _with_transition = "with_transition")

py_zip = _with_transition("target")
py_zip_with_transition = _with_transition
