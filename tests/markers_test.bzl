load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//python:markers.bzl", "parse", "evaluate", "binary_operations")


def _markers_test_impl(ctx):

    # Tests for markers adopted from https://peps.python.org/pep-0508/#complete-grammar
    tests = [
        ["platform_system == \"Windows\"", ["platform_system", "Windows", "OP_EQUAL"], [True, False, False]],
        ["sys_platform === 'win32'", ["sys_platform", "win32", "OP_ARBITRARY"], [True, False, False]],
        ["python_version~='2.7'", ["python_version", "2.7", "OP_COMPATIBLE"], [True, True, False]],
        ["python_version<'2.7' and platform_version=='2'", ['python_version', '2.7', 'OP_LESS_THAN', 'platform_version', '2', 'OP_EQUAL', 'OP_LOGICAL_AND'], [False, False, True]],
        ["os_name=='a' or os_name=='b'", ["os_name", "a", "OP_EQUAL", "os_name", "b", "OP_EQUAL", "OP_LOGICAL_OR"], [False, True, True]],
        # Should parse as (a and b) or c
        ["os_name=='a' and  os_name=='b' or os_name=='c' ", ["os_name", "a", "OP_EQUAL", "os_name", "b", "OP_EQUAL", "OP_LOGICAL_AND", "os_name", "c", "OP_EQUAL", "OP_LOGICAL_OR"], [True, False, False]],
        # Overriding precedence -> a and (b or c)
        ["os_name=='a' and (os_name=='b' or os_name=='c')", ["os_name", "a", "OP_EQUAL", "os_name", "b", "OP_EQUAL", "os_name", "c", "OP_EQUAL", "OP_LOGICAL_OR", "OP_LOGICAL_AND"], [False, False, False]],
        # should parse as a or (b and c)
        ["os_name=='a'  or  os_name=='b' and os_name=='c'", ["os_name", "a", "OP_EQUAL", "os_name", "b", "OP_EQUAL", "os_name", "c", "OP_EQUAL", "OP_LOGICAL_AND", "OP_LOGICAL_OR"], [False, False, True]],
        # Overriding precedence -> (a or b) and c
        ["(os_name=='a' or os_name=='b') and os_name=='c'", ["os_name", "a", "OP_EQUAL", "os_name", "b", "OP_EQUAL", "OP_LOGICAL_OR", "os_name", "c", "OP_EQUAL", "OP_LOGICAL_AND"], [False, False, False]],
        ["os_name in ('a', 'b', 'c')", ["os_name", "a", "b", "c", "OP_IN"], [True, True, True]],
        ["(os_name=='a' or os_name not in ('b', 'c', 'd')) and (platform_version in ('2','3'))", ["os_name", "a", "OP_EQUAL", "os_name", "b", "c", "d", "OP_IN", "OP_LOGICAL_NOT", "OP_LOGICAL_OR", "platform_version", "2", "3", "OP_IN", "OP_LOGICAL_AND"], [False, False, True]],
        ["(os_name=='a' or os_name not in ('d')) and (platform_version in ())", ["os_name", "a", "OP_EQUAL", "os_name", "d", "OP_IN", "OP_LOGICAL_NOT", "OP_LOGICAL_OR", "platform_version", "OP_IN", "OP_LOGICAL_AND"], [False, False, False]],
    ]

    test_environments = [
        {
            "platform_version": "2",
            "platform_system": "Windows",
            "sys_platform": "win32",
            "python_version": "2.99",
            "os_name": "c",
        },
        {
            "platform_version": "2",
            "platform_system": "Linux",
            "sys_platform": "linux",
            "python_version": "2.7",
            "os_name": "b",
        },
        {
            "platform_version": "2",
            "platform_system": "Linux",
            "sys_platform": "linux",
            "python_version": "2.5",
            "os_name": "a",
        },
    ]

    env = unittest.begin(ctx)
    for test, parsed, result in tests:
        asserts.equals(env, parsed, parse(test, {}))
        asserts.equals(env, False, evaluate(parse(test, {})))
        for env_index in range(len(test_environments)):
            asserts.equals(env, result[env_index], evaluate(parse(test, test_environments[env_index])))
    return unittest.end(env)


def _binary_operations_test_impl(ctx):
    env = unittest.begin(ctx)

    values = ["1", "2.*", "3", "2.5", "2.7", "2.8.*", "2.5.7", "2.7.1"]
    cmp_ops = {
        binary_operations["OP_LESS_THAN"]: [True, False, False, True, False, False, True, False],
        binary_operations["OP_LESS_THAN_EQUAL"]: [True, True, False, True, True, False, True, True],
        binary_operations["OP_GREATER_THAN"]: [False, False, True, False, False, True, False, False],
        binary_operations["OP_GREATER_THAN_EQUAL"]: [False, True, True, False, True, True, False, True],
        binary_operations["OP_COMPATIBLE"]: [False, True, False, False, True, True, False, True],
        binary_operations["OP_ARBITRARY"]: [False, False, False, False, True, False, False, False],
        binary_operations["OP_EQUAL"]: [False, True, False, False, True, False, False, True],
        binary_operations["OP_NOT_EQUAL"]: [True, False, True, True, False, True, True, False],
    }

    for op, expected in cmp_ops.items():
        for index in range(len(values)):
            asserts.equals(env, expected[index], op(values[index], "2.7"))

    logical_ops = {
        binary_operations["OP_LOGICAL_OR"]: lambda lhs, rhs: lhs or rhs,
        binary_operations["OP_LOGICAL_AND"]: lambda lhs, rhs: lhs and rhs,
    }
    for op, expected in logical_ops.items():
        for lhs in range(2):
            for rhs in range(2):
                asserts.equals(env, expected(lhs, rhs), op(lhs, rhs))

    return unittest.end(env)


def _extras_test_impl(ctx):
    env = unittest.begin(ctx)

    test = 'extra == "server"'
    asserts.equals(env, False, evaluate(parse(test, {})))
    asserts.equals(env, False, evaluate(parse(test, {"extra": "all"})))
    asserts.equals(env, True, evaluate(parse(test, {"extra": "server"})))
    asserts.equals(env, True, evaluate(parse(test, {"extra": "*"})))

    return unittest.end(env)

markers_test = unittest.make(_markers_test_impl)
binary_operations_test = unittest.make(_binary_operations_test_impl)
extras_test = unittest.make(_extras_test_impl)

def markers_test_suite(name):
    unittest.suite(name, markers_test, binary_operations_test, extras_test)
