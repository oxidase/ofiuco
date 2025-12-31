def pathsep(ctx):
    """Get context-based path separator."""
    is_windows = type(ctx) == "ctx" and 'windows' in ctx.var.get("TARGET_CPU").lower() or type(ctx) == "repository_ctx" and ctx.os.name == "windows"
    return ";" if is_windows else ":"
