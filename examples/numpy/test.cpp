#include <Python.h>
#include <numpy/arrayobject.h>

#include <catch2/catch_test_macros.hpp>
#include <catch2/reporters/catch_reporter_event_listener.hpp>
#include <catch2/reporters/catch_reporter_registrars.hpp>
#include <catch2/matchers/catch_matchers_string.hpp>
#include <catch2/matchers/catch_matchers_floating_point.hpp>
#include <catch2/catch_approx.hpp>

#include <iostream>

#define WIDEN_(x) L##x
#define WIDEN(x) WIDEN_(x)


class PythonSetup : public Catch::EventListenerBase {
public:
    using Catch::EventListenerBase::EventListenerBase;

    void testRunStarting(Catch::TestRunInfo const& info) override {
      char cwd[PATH_MAX];
      printf("Current working directory: %s\n", getcwd(cwd, sizeof(cwd)));

      PyStatus status;

      PyConfig config;
      PyConfig_InitPythonConfig(&config);

      // Set the program name. Implicitly pre-initialize Python.
      status = PyConfig_SetString(&config, &config.program_name, WIDEN(PYTHON_PROGRAM_NAME));
      if (PyStatus_Exception(status)) {
        goto exception;
      }

      // Set the python path.
      status = PyConfig_SetString(&config, &config.pythonpath_env, WIDEN(PYTHON_PATH));
      if (PyStatus_Exception(status)) {
        goto exception;
      }

      status = Py_InitializeFromConfig(&config);
      if (PyStatus_Exception(status)) {
        goto exception;
      }
      PyConfig_Clear(&config);

      PyRun_SimpleString(
                         "import sys\n"
                         "print(f\"Python home      : {sys.prefix}\")\n"
                         "print(f\"Python executable: {sys.executable}\")\n"
                         "print(f\"Python version   : {sys.version}\")\n"
                         "print(f\"Python path      : {sys.path}\")");

      return;

exception:
      PyConfig_Clear(&config);
      Py_ExitStatusException(status);
      std::exit(EXIT_FAILURE);
    }

    void testRunEnded(Catch::TestRunStats const& stats) override {
      Py_Finalize();
    }
};

CATCH_REGISTER_LISTENER(PythonSetup)

TEST_CASE("Compute eigenvalues of a 2x2 matrix") {

  _import_array();  // Required to use NumPy C API

  // Create a 2x2 matrix: [[1, 2], [2, 1]]
  npy_intp dims[2] = {2, 2};
  PyObject* array = PyArray_SimpleNew(2, dims, NPY_DOUBLE);
  auto* data = static_cast<double*>(PyArray_DATA((PyArrayObject*)array));

  data[0] = 1; data[1] = 2;
  data[2] = 2; data[3] = 1;

  // Import numpy.linalg module
  PyObject* linalg = PyImport_ImportModule("numpy.linalg");
  REQUIRE(linalg != nullptr);

  // Get eig function
  PyObject* eig_func = PyObject_GetAttrString(linalg, "eig");
  REQUIRE(eig_func != nullptr);
  CHECK(PyCallable_Check(eig_func));

  // Call eig(array)
  PyObject* args = PyTuple_Pack(1, array);
  PyObject* result = PyObject_CallObject(eig_func, args);
  REQUIRE(result != nullptr);

  // Unpack (eigenvalues, eigenvectors)
  PyObject* eigenvalues = PyTuple_GetItem(result, 0);
  PyObject* eigenvectors = PyTuple_GetItem(result, 1);

  PyObject* val_str = PyObject_Repr(eigenvalues);
  PyObject* vec_str = PyObject_Repr(eigenvectors);

  CHECK_THAT(PyUnicode_AsUTF8(val_str), Catch::Matchers::Matches(".*[ *3., *-1.].*"));
  CHECK_THAT(PyUnicode_AsUTF8(vec_str), Catch::Matchers::Matches(R"([^\0]*0.70710678[^\0]*)"));

  PyArrayObject* eigenvalues_array = (PyArrayObject*) PyArray_FROM_OTF(eigenvalues, NPY_DOUBLE, NPY_ARRAY_IN_ARRAY);
  REQUIRE(eigenvalues_array != nullptr);
  REQUIRE(PyArray_DIM(eigenvalues_array, 0) == 2);

  auto* eigv = static_cast<double*>(PyArray_DATA(eigenvalues_array));
  CHECK(std::max(eigv[0], eigv[1]) == Catch::Approx(3));
  CHECK(std::min(eigv[0], eigv[1]) == Catch::Approx(-1));

  // Clean up
  Py_DECREF(val_str);
  Py_DECREF(vec_str);
  Py_DECREF(result);
  Py_DECREF(args);
  Py_DECREF(eig_func);
  Py_DECREF(linalg);
  Py_DECREF(array);
}
