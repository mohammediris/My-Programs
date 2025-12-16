#!/usr/bin/env python3
"""trending_news.py

Fetch and search trending news using RSS feeds (default: Google News Top Stories).

Usage examples:
  python trending_news.py --query AI --max 5
  python trending_news.py --feed "https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en" --json

This script uses requests and feedparser.
"""
from __future__ import annotations

import argparse
import json
from typing import List, Dict

import feedparser
import requests


DEFAULT_FEED = "https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en"


def fetch_news(feed_url: str = DEFAULT_FEED, timeout: int = 10) -> List[Dict]:
    """Fetch RSS feed and return a list of news items.

    Each item is a dict: title, link, published, summary, source
    """
    # Use requests to get raw feed (some environments block direct feedparser fetches)
    resp = requests.get(feed_url, timeout=timeout, headers={"User-Agent": "trending-news/1.0"})
    resp.raise_for_status()
    parsed = feedparser.parse(resp.content)

    items: List[Dict] = []
    for entry in parsed.entries:
        items.append(
            {
                "title": entry.get("title", ""),
                "link": entry.get("link", ""),
                "published": entry.get("published", entry.get("updated", "")),
                "summary": entry.get("summary", ""),
                "source": parsed.feed.get("title", ""),
            }
        )

    return items


def search_news(items: List[Dict], query: str) -> List[Dict]:
    """Return items matching query in title or summary (case-insensitive)."""
    q = query.lower().strip()
    if not q:
        return items
    out = []
    for it in items:
        if q in (it.get("title", "") or "").lower() or q in (it.get("summary", "") or "").lower():
            out.append(it)
    return out


def format_items(items: List[Dict], max_items: int | None = None) -> str:
    if max_items:
        items = items[:max_items]
    lines = []
    for i, it in enumerate(items, 1):
        lines.append(f"{i}. {it.get('title')}")
        if it.get("published"):
            lines.append(f"   Published: {it.get('published')}")
        if it.get("link"):
            lines.append(f"   Link: {it.get('link')}")
        lines.append("")
    return "\n".join(lines)


def main() -> None:
    p = argparse.ArgumentParser(description="Search trending news (via RSS)")
    p.add_argument("--query", "-q", help="Search query (filters titles and summaries)")
    p.add_argument("--feed", "-f", default=DEFAULT_FEED, help="RSS feed URL to fetch")
    p.add_argument("--max", "-m", type=int, default=10, help="Max number of results to display")
    p.add_argument("--json", action="store_true", help="Output raw JSON instead of pretty text")

    args = p.parse_args()

    try:
        items = fetch_news(args.feed)
    except Exception as e:
        print(f"Failed to fetch feed: {e}")
        raise

    if args.query:
        items = search_news(items, args.query)

    if args.json:
        print(json.dumps(items[: args.max], ensure_ascii=False, indent=2))
    else:
        out = format_items(items, args.max)
        if out.strip():
            print(out)
        else:
            print("No matching items found.")


if __name__ == "__main__":
    main()
