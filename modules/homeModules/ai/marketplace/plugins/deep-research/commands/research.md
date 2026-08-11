---
description: Run a structured deep-research pass on a topic or question
argument-hint: [topic or question]
---

# Deep Research

Research the topic in $ARGUMENTS thoroughly and produce a structured report.

## Process

1. **Scope** — restate the question, list sub-questions and key terms.
2. **Gather** — search multiple independent sources. Use the `fetch` MCP server for web pages, the `arxiv-searcher` skill for papers, and `context7` for library/API docs. Prefer primary sources.
3. **Read** — for each strong source, extract claims, methods, and evidence. For papers, delegate to the `academic-reader` agent.
4. **Synthesize** — reconcile agreements and conflicts; distinguish established fact from speculation.
5. **Report** — output:
   - **Answer** — direct, up front.
   - **Key findings** — bulleted, each with a source.
   - **Open questions / caveats.**
   - **Sources** — list with URLs or citations.

Be skeptical: flag weak evidence and note when sources disagree. Format math in LaTeX.
