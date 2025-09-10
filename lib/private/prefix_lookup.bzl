def prefix_lookup(d, key, default = None):
    """Return value from dict by longest prefix match."""
    best_k, best_v = None, default
    for k, v in d.items():
        if key.startswith(k) and (best_k == None or len(k) > len(best_k)):
            best_k, best_v = k, v
    return best_k, best_v
