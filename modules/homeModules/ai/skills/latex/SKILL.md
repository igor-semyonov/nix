---
name: latex
description: Build, structure, and debug LaTeX documents with latexmk and biblatex. Use when working with .tex files, bibliographies, or math/figure typesetting.
---

# LaTeX

## Building

Always build with `latexmk` — it runs the right number of passes automatically:

```bash
latexmk -pdf main.tex          # pdflatex
latexmk -xelatex main.tex      # for custom fonts / unicode
latexmk -c                     # clean aux files (keep pdf)
latexmk -C                     # clean everything including pdf
```

For continuous preview while editing:

```bash
latexmk -pdf -pvc main.tex
```

## Bibliographies

Prefer `biblatex` + `biber`:

```latex
\usepackage[backend=biber,style=numeric]{biblatex}
\addbibresource{refs.bib}
...
\printbibliography
```

`latexmk` invokes `biber` automatically. Undefined citations usually mean a stale build — run a clean build (`latexmk -C && latexmk -pdf`).

## Debugging

- Read the **first** error in the log, not the last.
- `! LaTeX Error: File 'foo.sty' not found` → missing package; on Nix, add it to the `texlive` package set (e.g. `texliveFull` or a scoped `texlive.combine`).
- `Undefined control sequence` → typo or missing `\usepackage`.
- Overfull/underfull `\hbox` are warnings, not errors.

## Math

Use `amsmath`/`mathtools`. Align multi-line equations:

```latex
\begin{align}
  f(x) &= x^2 + 2x + 1 \\
       &= (x+1)^2
\end{align}
```

Factor repeated notation with `\newcommand` and operators with `\DeclareMathOperator`.
