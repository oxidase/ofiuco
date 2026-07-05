from compression import make_pool
from network import get


def main():
    pool = make_pool()
    print(pool)
    print(get("https://example.com").status_code)


if __name__ == "__main__":
    main()
