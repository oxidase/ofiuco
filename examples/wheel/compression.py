import urllib3


def make_pool():
    return urllib3.PoolManager()
