---
name: arxiv-searcher
description: Search and download academic papers from the arXiv API. Use when finding or fetching papers by topic, author, or id.
---

# arXiv Searcher

## Query the API

```bash
curl -s "http://export.arxiv.org/api/query?search_query=all:quantum+computing&start=0&max_results=5"
```

Search fields: `all:`, `ti:` (title), `au:` (author), `abs:` (abstract), `cat:` (category, e.g. `cs.CR`). Combine with `+AND+`, `+OR+`.

## Parse results

The API returns Atom XML. Extract `<id>` (the abstract URL), `<title>`, `<summary>`, and `<author>`. `xmllint --xpath` or a small script works well.

## Download the PDF

Replace `/abs/` with `/pdf/` in the id:

```bash
curl -L -o paper.pdf "https://arxiv.org/pdf/2301.00001"
```

Then extract text with the `pdf` MCP server or hand off to the `academic-reader` agent.
