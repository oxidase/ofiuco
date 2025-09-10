"""Shunting yard algorithm for parsing and evaluation "markers" grammar
defined in "PEP 508 – Dependency specification for Python Software Packages."

Ref: https://peps.python.org/pep-0508/#complete-grammar
"""

_WS = " \t"

_tokens = {
    "(": "LEFT_PARENTHESIS",
    ")": "RIGHT_PARENTHESIS",
    ",": "COMMA",
    "===": "OP_ARBITRARY",
    "==": "OP_EQUAL",
    "~=": "OP_COMPATIBLE",
    "!=": "OP_NOT_EQUAL",
    "<=": "OP_LESS_THAN_EQUAL",
    ">=": "OP_GREATER_THAN_EQUAL",
    "<": "OP_LESS_THAN",
    ">": "OP_GREATER_THAN",
    "or": "OP_LOGICAL_OR",
    "and": "OP_LOGICAL_AND",
    "not": "OP_LOGICAL_NOT",
    "in": "OP_IN",
    "python_version": "VARIABLE",
    "python_full_version": "VARIABLE",
    "os_name": "VARIABLE",
    "sys_platform": "VARIABLE",
    "platform_release": "VARIABLE",
    "platform_system": "VARIABLE",
    "platform_version": "VARIABLE",
    "platform_machine": "VARIABLE",
    "platform_python_implementation": "VARIABLE",
    "implementation_name": "VARIABLE",
    "implementation_version": "VARIABLE",
    "extra": "VARIABLE",
}

_op_precedences = {
    "OP_ARBITRARY": 5,
    "OP_EQUAL": 5,
    "OP_COMPATIBLE": 5,
    "OP_NOT_EQUAL": 5,
    "OP_LESS_THAN_EQUAL": 5,
    "OP_GREATER_THAN_EQUAL": 5,
    "OP_LESS_THAN": 5,
    "OP_GREATER_THAN": 5,
    "OP_LOGICAL_OR": 2,
    "OP_LOGICAL_AND": 3,
    "OP_LOGICAL_NOT": 4,
    "OP_IN": 5,
    "LEFT_PARENTHESIS": 1,
    "RIGHT_PARENTHESIS": 1,
}

def read_token(text, pos):
    """Tokenizer for the marker grammar.

    Ref: https://peps.python.org/pep-0508/#complete-grammar

    Arguments:
        text: str The marker text string to be tokenized.
        pos: int Starting position of a next token.

    Returns:
        A tuple with token type, token value and a string position of a next token.
    """

    if pos >= len(text):
        return ("END", pos)

    text = text[pos:]
    size = len(text)
    for token, name in _tokens.items():
        if text.startswith(token):
            return (name, pos + len(token))

    for quote in ['"', "'"]:
        if text[0] == quote:
            endpos = text.find(quote, 1)
            if endpos > 0:
                return ("QUOTED_STRING", pos + endpos + 1)

    if text[0] in _WS:
        endpos = 1
        for endpos in range(1, size):
            if text[endpos] not in _WS:
                break
        return ("WS", pos + endpos)

    if text[0].isalnum():
        for endpos in range(1, size):
            if not (text[endpos].isalnum() or text[endpos] in "-_."):
                break
        return ("IDENTIFIER", pos + endpos)

    return ("UNKNOWN", pos + size)

def parse(text, environment):
    """Shunting yard algorithm parser to convert markers infix notation to a post-fix notation.

    Arguments:
        text: str The marker text string to be parsed.
        environment: dict[str, str] The dictionary with variables to be substituted.
            If a value is ont in a dictionary then the value name will be used.

    Returns:
        The parsed tokens in a reversed Polish notation.
    """
    output_queue, operator_stack = [], []
    token, pos = None, 0
    for _ in range(len(text)):
        token, nextpos = read_token(text, pos)
        value, pos = text[pos:nextpos], nextpos
        if token == "END":
            break
        elif token == "VARIABLE":
            if value not in environment:
                fail("missing key '{}' in environment {}".format(value, environment) +
                     "\nPlease provide platforms attribute which contains the missing key to parse.lock function")
            output_queue.append(environment[value])
        elif token == "QUOTED_STRING":
            output_queue.append(value[1:-1])
        elif token.startswith("OP_"):
            op_precedence = _op_precedences[token]
            index = 0
            for index in range(len(operator_stack) - 1, -1, -1):
                if not (_op_precedences[operator_stack[-1]] >= op_precedence):
                    break
                output_queue.append(operator_stack.pop())
            operator_stack.append(token)
        elif token == "LEFT_PARENTHESIS":
            operator_stack.append(token)
        elif token == "RIGHT_PARENTHESIS":
            if not operator_stack:
                fail("unbalanced right parenthesis at {} in '{}'".format(pos, text))
            index = 0
            for index in range(len(operator_stack) - 1, -1, -1):
                if operator_stack[index] == "LEFT_PARENTHESIS":
                    break
                output_queue.append(operator_stack.pop())
            operator_stack = operator_stack[:index]
        pos = nextpos

    for index in range(len(operator_stack) - 1, -1, -1):
        if operator_stack[index] == "LEFT_PARENTHESIS":
            fail("unbalanced left parenthesis in '{}'".format(text))
        output_queue.append(operator_stack[index])

    return output_queue

def parse_version(version):
    parts = [int(part) if part.isdigit() else part for part in version.split(".")]
    if "*" in parts:
        return parts[:parts.index("*")]
    return parts

def compare_equal_major(lhs, rhs):
    lhs_parts = parse_version(lhs)
    rhs_parts = parse_version(rhs)
    return not lhs_parts or not rhs_parts or lhs_parts[0] == rhs_parts[0]

def compare_equal(lhs, rhs):
    lhs_parts = parse_version(lhs)
    rhs_parts = parse_version(rhs)
    to_compare = min(len(lhs_parts), len(rhs_parts))
    return lhs_parts[:to_compare] == rhs_parts[:to_compare]

def compare_less(lhs, rhs):
    lhs_parts = parse_version(lhs)
    rhs_parts = parse_version(rhs)
    all_parts_equal = True
    for index in range(min(len(lhs_parts), len(rhs_parts))):
        if type(lhs_parts[index]) != type(rhs_parts[index]):
            return False
        if lhs_parts[index] > rhs_parts[index]:
            return False
        all_parts_equal = all_parts_equal and lhs_parts[index] == rhs_parts[index]
    return not all_parts_equal

binary_operations = {
    "OP_ARBITRARY": lambda lhs, rhs: lhs == rhs,
    "OP_EQUAL": lambda lhs, rhs: compare_equal(lhs, rhs),
    "OP_COMPATIBLE": lambda lhs, rhs: not compare_less(lhs, rhs) and compare_equal_major(lhs, rhs),
    "OP_NOT_EQUAL": lambda lhs, rhs: not compare_equal(lhs, rhs),
    "OP_LESS_THAN_EQUAL": lambda lhs, rhs: not compare_less(rhs, lhs),
    "OP_GREATER_THAN_EQUAL": lambda lhs, rhs: not compare_less(lhs, rhs),
    "OP_LESS_THAN": lambda lhs, rhs: compare_less(lhs, rhs),
    "OP_GREATER_THAN": lambda lhs, rhs: compare_less(rhs, lhs),
    "OP_LOGICAL_OR": lambda lhs, rhs: lhs or rhs,
    "OP_LOGICAL_AND": lambda lhs, rhs: lhs and rhs,
}

def evaluate(rpn_queue):
    """Evaluator for a parsed text in the reverse Polish notation.

    Arguments:
        rpn_queue: A list of tokens in a reverse Polish notation to be evaluated.

    Returns:
        The evaluation result.
    """
    stack, varpos = [], 0
    for token in rpn_queue:
        if token == "OP_IN":
            stack, varargs = stack[:varpos], stack[varpos:]
            stack.append(varargs[0] in varargs[1:])
            varpos = len(stack)
        elif token == "OP_LOGICAL_NOT":
            stack.append(not stack.pop())
            varpos = len(stack)
        elif token.startswith("OP_"):
            rhs = stack.pop()
            lhs = stack.pop()
            stack.append(binary_operations[token](lhs, rhs))
            varpos = len(stack)
        else:
            stack.append(token)
    if len(stack) != 1:
        fail("evaluated stack must have a single value instead of {}".format(stack))

    return stack.pop()
