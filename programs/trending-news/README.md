# Trending News (RSS-based)

Small CLI tool to fetch trending/top news via RSS (default: Google News Top Stories) and search/filter results.

Requirements
- Python 3.8+
- See `requirements.txt` (requests, feedparser)

Usage

PowerShell example:

```powershell
# install deps (optional virtualenv)
python -m pip install -r "programs - python/trending-news/requirements.txt"

# simple run, show top 5 stories matching 'AI'
python "programs - python/trending-news/trending_news.py" --query AI --max 5

# fetch the default Google News RSS and print JSON
python "programs - python/trending-news/trending_news.py" --json
```

Notes
- The script uses public RSS feeds (no API key required). You can swap `--feed` to other RSS sources.
- For broader searches, consider combining multiple feeds or integrating a news API (requires API key).
