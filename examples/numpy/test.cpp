//#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <numpy/arrayobject.h>
#include <iostream>

int main() {
  Py_Initialize();
    // import_array();  // Required to use NumPy C API

    // // Create a 2x2 matrix: [[1, 2], [2, 1]]
    // npy_intp dims[2] = {2, 2};
    // PyObject* array = PyArray_SimpleNew(2, dims, NPY_DOUBLE);
    // double* data = static_cast<double*>(PyArray_DATA((PyArrayObject*)array));

    // data[0] = 1; data[1] = 2;
    // data[2] = 2; data[3] = 1;

    // // Import numpy.linalg module
    // PyObject* linalg = PyImport_ImportModule("numpy.linalg");
    // if (!linalg) {
    //     PyErr_Print();
    //     std::cerr << "Failed to import numpy.linalg\n";
    //     return 1;
    // }

    // // Get eig function
    // PyObject* eig_func = PyObject_GetAttrString(linalg, "eig");
    // if (!eig_func || !PyCallable_Check(eig_func)) {
    //     PyErr_Print();
    //     std::cerr << "Failed to get eig function\n";
    //     return 1;
    // }

    // // Call eig(array)
    // PyObject* args = PyTuple_Pack(1, array);
    // PyObject* result = PyObject_CallObject(eig_func, args);

    // if (!result) {
    //     PyErr_Print();
    //     std::cerr << "eig() call failed\n";
    //     return 1;
    // }

    // // Unpack (eigenvalues, eigenvectors)
    // PyObject* eigenvalues = PyTuple_GetItem(result, 0);
    // PyObject* eigenvectors = PyTuple_GetItem(result, 1);

    // PyObject* val_str = PyObject_Repr(eigenvalues);
    // PyObject* vec_str = PyObject_Repr(eigenvectors);

    // std::cout << "Eigenvalues: " << PyUnicode_AsUTF8(val_str) << std::endl;
    // std::cout << "Eigenvectors:\n" << PyUnicode_AsUTF8(vec_str) << std::endl;

    // // Clean up
    // Py_DECREF(val_str);
    // Py_DECREF(vec_str);
    // Py_DECREF(result);
    // Py_DECREF(args);
    // Py_DECREF(eig_func);
    // Py_DECREF(linalg);
    // Py_DECREF(array);

  //Py_Finalize();
    return 0;
}
