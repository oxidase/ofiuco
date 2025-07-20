import sys

import nanobind_example as nb
import numpy as np
import pytest


def test_example():
    assert nb.add(1, 2) == 3

    array = np.array([[1, 2, 3], [3, 4, 5]], dtype=np.float32)
    assert "float32=true" in nb.inspect(array), nb.inspect(array)


if __name__ == "__main__":
    sys.exit(pytest.main(sys.argv))
