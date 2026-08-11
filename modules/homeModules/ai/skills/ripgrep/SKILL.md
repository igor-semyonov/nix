---
name: ripgrep
description: Search code fast with ripgrep (rg). Use when searching file contents, filtering by file type, or feeding matches into other tools.
---

# ripgrep (rg)

`rg` recursively searches directories, respects `.gitignore`, and is fast.

## Basics

```bash
rg 'pattern'                 # search cwd recursively
rg -i 'pattern'              # case-insensitive
rg -w 'word'                 # whole word
rg -F 'literal.string'       # fixed string, no regex
rg 'pat' path/to/dir         # scope to a path
```

## Filtering by type

```bash
rg 'fn main' -t rust         # only Rust files
rg 'def ' -t py              # only Python
rg 'foo' -g '*.nix'          # glob include
rg 'foo' -g '!target/'       # glob exclude
rg --type-list               # see known types
```

## Context and output

```bash
rg -n 'pat'                  # show line numbers (default in a terminal)
rg -C 3 'pat'                # 3 lines of context around each match
rg -l 'pat'                  # only file names with matches
rg -c 'pat'                  # count matches per file
rg --json 'pat'              # machine-readable output
```

## Replace (preview) and hidden files

```bash
rg 'foo' -r 'bar'            # show replacement (does NOT write files)
rg -uu 'pat'                 # search hidden + ignored files
```

## Regex

Uses Rust regex syntax. Capture groups work in `-r` with `$1`. Use `-P` (PCRE2) only when you need lookaround.
