"""Simple smoke test for trending_news functions.

This test will attempt a live fetch. It is a smoke test and may fail offline.
"""
from trending_news import fetch_news, search_news


def test_fetch_and_search():
    items = fetch_news()
    assert isinstance(items, list)
    # run a search for a common short word to avoid empty set - 'the'
    s = search_news(items, "the")
    assert isinstance(s, list)


if __name__ == "__main__":
    test_fetch_and_search()
    print("Smoke test passed (fetched and searched feed).")
