"""globstar matching algorithm"""

def globstar(pattern, text, path_separator = "/"):
    pattern_size = len(pattern)
    text_size = len(text)

    double_star = False
    prev_matches = [True] + [False for _ in range(text_size)]

    for pattern_index in range(pattern_size):
        symbol = pattern[pattern_index]
        if symbol == "*" and pattern_index + 1 < pattern_size and pattern[pattern_index + 1] == "*":
            double_star = True
            continue

        star = symbol == "*"
        mark = symbol == "?"
        next_matches = [(double_star or star) and prev_matches[0]] + [False for _ in range(text_size)]
        one_match = next_matches[0]

        for index in range(1, text_size + 1):
            if double_star or star and path_separator == None:
                match = prev_matches[index - 1] or next_matches[index - 1] or prev_matches[index]
            elif star:
                match = prev_matches[index - 1] or next_matches[index - 1] or prev_matches[index]
                match = match and text[index - 1] != path_separator
            elif mark and path_separator == None:
                match = prev_matches[index - 1]
            elif mark:
                match = prev_matches[index - 1] and text[index - 1] != path_separator
            else:
                match = prev_matches[index - 1] and text[index - 1] == symbol

            one_match = one_match or match
            next_matches[index] = match

        if not one_match:
            return False

        double_star = False
        prev_matches = next_matches

    return prev_matches.pop()
