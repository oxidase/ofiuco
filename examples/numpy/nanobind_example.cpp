#include <nanobind/nanobind.h>
#include <nanobind/ndarray.h>
#include <nanobind/stl/string.h>
#include <fmt/format.h>

#include <iterator>
#include <string>

namespace nb = nanobind;

int add(int a, int b) { return a + b; }

NB_MODULE(nanobind_example, m) {
  m.def("add", &add);

  m.def("inspect", [](const nb::ndarray<>& a) {
    std::string str;
    fmt::format_to(std::back_inserter(str), "Array data pointer : {}\n", a.data());
    fmt::format_to(std::back_inserter(str), "Array dimension : {}\n", a.ndim());
    for (size_t i = 0; i < a.ndim(); ++i)
    {
      fmt::format_to(std::back_inserter(str), "Array dimension [{}] : {}\n", i, a.shape(i));
      fmt::format_to(std::back_inserter(str), "Array stride    [{}] : {}\n", i, a.stride(i));
    }
    fmt::format_to(
      std::back_inserter(str),
      "Device ID = {} (cpu={}, cuda={})\n",
      a.device_id(),
      a.device_type() == nb::device::cpu::value,
      a.device_type() == nb::device::cuda::value);
    fmt::format_to(
      std::back_inserter(str),
      "Array dtype: int16={}, uint32={}, float32={}\n",
      a.dtype() == nb::dtype<int16_t>(),
      a.dtype() == nb::dtype<uint32_t>(),
      a.dtype() == nb::dtype<float>());
    return str;
  });
}
