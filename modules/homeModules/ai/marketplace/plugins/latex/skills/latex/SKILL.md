---
name: latex
description: Build, structure, and debug LaTeX documents with latexmk and biblatex. Use when working with .tex files, bibliographies, or math/figure typesetting.
---

# LaTeX

## Building

```bash
latexmk -pdf main.tex          # pdflatex, correct number of passes
latexmk -xelatex main.tex      # custom fonts / unicode
latexmk -pdf -pvc main.tex     # continuous preview
latexmk -c                     # clean aux files
latexmk -C                     # clean everything incl. pdf
```

## Bibliography (biblatex + biber)

```latex
\usepackage[backend=biber,style=numeric]{biblatex}
\addbibresource{refs.bib}
% ...
\printbibliography
```

Undefined citations after edits usually mean a stale build: `latexmk -C && latexmk -pdf`.

## Debugging

Read the **first** error in the log. Common ones:

- `File 'foo.sty' not found` → missing package (on Nix add to the `texlive` set).
- `Undefined control sequence` → typo or missing `\usepackage`.
- Overfull/underfull `\hbox` are warnings.

## Math

```latex
\begin{align}
  f(x) &= x^2 + 2x + 1 \\
       &= (x+1)^2
\end{align}
```
