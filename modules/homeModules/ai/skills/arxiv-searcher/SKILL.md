---
name: arxiv-searcher
description: Extract and search academic papers from the ArXiv API using curl and xmllint.
---

# ArXiv Searcher

## Querying the API

Use the ArXiv API to search for papers. For example, to search for "quantum computing":

```bash
curl -s "http://export.arxiv.org/api/query?search_query=all:quantum+computing&start=0&max_results=3"
```

## Parsing Results

Since the API returns Atom XML, you should extract the `<id>` (which contains the URL to the PDF) and `<summary>`.

## Downloading PDFs

Once you have the PDF URL (replace `/abs/` with `/pdf/` in the ID):

```bash
curl -O <pdf_url>.pdf
```
