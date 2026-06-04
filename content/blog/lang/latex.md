---
title: "LaTeX"
tags: [programming-language]
---

## Distributions

- **TeX Live**: The most mainstream and versatile distribution, supporting Linux, macOS, and Windows. This is what the `texlive-*` packages in most Linux distributions provide. Suitable for servers, CI, Linux/macOS/cross-platform projects. The TeX Users Group also refers to MiKTeX as the other major free TeX distribution alongside TeX Live.
- **MacTeX**: The most recommended choice on macOS — essentially TeX Live packaged for Mac, bundled with Mac-related tools like TeXShop, BibDesk, and Ghostscript.
- **BasicTeX**: A slimmed-down version of MacTeX, also based on TeX Live. Ideal for those who don't want to install a multi-GB package and prefer to install missing components on demand.
- **MiKTeX**: Very popular among Windows users, also supports Linux/macOS. Key features include on-demand installation of missing packages and a relatively user-friendly GUI management experience. Best suited for Windows desktop users.
- **TinyTeX**: A lightweight LaTeX distribution based on TeX Live. Cross-platform, portable, and especially suited for R Markdown / Quarto / Pandoc / CI scenarios.
- **Tectonic**: A modern, single-binary TeX/LaTeX engine based on XeTeX and TeX Live resources. Focuses on automatic dependency downloads, reproducible builds, and minimal configuration. It's more of a "modern LaTeX build toolchain" rather than a traditional full-scale distribution.
- **ConTeXt Standalone / ConTeXt Suite**: Primarily aimed at ConTeXt users, not the first choice for traditional LaTeX users. It's a complete, independently updatable ConTeXt distribution that can coexist with an existing TeX Live installation.
- Historically there were also **teTeX, proTeXt, fpTeX, gwTeX**, etc., but these are generally not recommended for new installations today. For example, teTeX has ceased maintenance and has since been succeeded by TeX Live.

## Underlying Engines

- **pdfLaTeX**: Previously the most mainstream LaTeX engine. Advantages: stable, fast, best compatibility. Disadvantages: poor native Unicode and system font support. Chinese documents require packages like CJK and ctex, which are less natural compared to XeLaTeX / LuaLaTeX.
- **XeLaTeX**: Its biggest feature is native Unicode and system font support — you can directly use system fonts like Song, Source Han Sans, Times New Roman. Extremely common in Chinese documents.
- **LuaLaTeX**: A more modern direction, supporting Unicode, OpenType fonts, and also embedding Lua scripting capabilities for more complex typesetting automation. It's considered one of the recommended directions for the future, though template compatibility may sometimes lag behind pdfLaTeX / XeLaTeX.

## Installing TeX Live on Linux

```bash
cd /tmp

# Download the installer
wget https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
tar -xzf install-tl-unx.tar.gz
cd install-tl-2026 # year changes over time

# Install
sudo perl ./install-tl \
  --no-interaction \
  --scheme=small \
  --no-doc-install \
  --no-src-install

# Configure
TL_YEAR=$(ls /usr/local/texlive | sort -n | tail -1) # get the current installed year version
echo "export PATH=/usr/local/texlive/$TL_YEAR/bin/x86_64-linux:\$PATH" >> ~/.bashrc # add to PATH
source ~/.bashrc

# Verify
lualatex --version
tlmgr --version
```

## Recommended Must-Have Packages

### Math Formulas

| Package | Description | Install Command |
|---------|-------------|-----------------|
| `amsmath` | Core math environments such as `align`, `cases` — almost essential | `tlmgr install amsmath` |
| `mathtools` | Superset of `amsmath`, fixes known bugs and extends with more commands | `tlmgr install mathtools` |
| `amsfonts` / `amssymb` | Math symbols like ℝ ∀ ∈, `\mathbb` blackboard bold font family | `tlmgr install amsfonts` |
| `unicode-math` | Use Unicode math fonts under XeLaTeX/LuaLaTeX | `tlmgr install unicode-math` |
| `physics` | `\dv`, `\pdv` derivatives, Dirac brackets, and other physics convenience commands | `tlmgr install physics` |
| `bm` | `\bm{}` math bold, more robust than `\boldsymbol` | `tlmgr install bm` |

---

### Graphics & Drawing

| Package | Description | Install Command |
|---------|-------------|-----------------|
| `graphicx` | `\includegraphics` for inserting images — almost essential | `tlmgr install graphics` |
| `tikz` / `pgf` | Vector drawing language for flowcharts, circuit diagrams, mind maps, etc. | `tlmgr install pgf` |
| `pgfplots` | Scientific data charts based on TikZ (line/bar/polar plots) | `tlmgr install pgfplots` |
| `float` | The `H` option forces float placement — figures and tables stay put | `tlmgr install float` |
| `subcaption` | Side-by-side subfigures with independent numbering, replaces the legacy `subfig` | `tlmgr install caption` |
| `wrapfig` | Text-wrapped figure layouts | `tlmgr install wrapfig` |

---

### Tables

| Package | Description | Install Command |
|---------|-------------|-----------------|
| `booktabs` | Three-line tables (`\toprule \midrule \bottomrule`) — standard for academic papers | `tlmgr install booktabs` |
| `tabularx` | The `X` column auto-fills remaining width — no more manual column width calculations | `tlmgr install tabularx` |
| `multirow` | `\multirow` for cells spanning multiple rows | `tlmgr install multirow` |
| `longtable` | Multi-page tables with automatic page breaks | `tlmgr install longtable` |
| `array` | `>{}<{}` column pre/post hooks, extended `p`/`m`/`b` column types | `tlmgr install array` |
| `tabularray` | A new-generation table package with a more intuitive syntax — recommended for new projects | `tlmgr install tabularray` |

---

### Bibliographies & References

| Package | Description | Install Command |
|---------|-------------|-----------------|
| `biblatex` | Modern bibliography management, supports styles like GB/T, APA, Chicago | `tlmgr install biblatex` |
| `biber` | Recommended BibLaTeX backend, replacing the legacy BibTeX | `tlmgr install biber` |
| `natbib` | `\citet{}`, `\citep{}` for natural science citation formats | `tlmgr install natbib` |

---

### Chinese Language Support

| Package | Description | Install Command |
|---------|-------------|-----------------|
| `ctex` | All-in-one Chinese typesetting: fonts, punctuation, layout — one-stop configuration | `tlmgr install ctex` |
| `xeCJK` | Fine-grained control over Chinese/English mixed-line spacing under XeLaTeX | `tlmgr install xecjk` |
| `zhnumber` | Chinese numeral formatting: 一, 二, 三... automatic chapter number conversion | `tlmgr install zhnumber` |

---

### Code Typesetting

| Package | Description | Install Command |
|---------|-------------|-----------------|
| `listings` | Code syntax highlighting, supports 50+ languages, highly customizable | `tlmgr install listings` |
| `minted` | Beautiful code highlighting via Pygments (requires Python) | `tlmgr install minted` |
| `fancyvrb` | Enhanced verbatim environment with line numbers and frames | `tlmgr install fancyvrb` |

---

### Page Layout

| Package | Description | Install Command |
|---------|-------------|-----------------|
| `geometry` | Page dimensions and margin settings — safer than setting parameters manually | `tlmgr install geometry` |
| `fancyhdr` | Custom headers/footers with automatic chapter name insertion | `tlmgr install fancyhdr` |
| `titlesec` | Deep customization of section title fonts, colors, and spacing | `tlmgr install titlesec` |
| `setspace` | 1.5× / double line spacing — commonly used for thesis formatting | `tlmgr install setspace` |
| `parskip` | Paragraph spacing instead of first-line indentation — European typesetting style | `tlmgr install parskip` |

---

### Hyperlinks

| Package | Description | Install Command |
|---------|-------------|-----------------|
| `hyperref` | PDF hyperlinks, bookmarks, metadata — **must be loaded last** | `tlmgr install hyperref` |
| `cleveref` | `\cref{}` auto-adds prefixes like "fig.", "table", "section" — load after `hyperref` | `tlmgr install cleveref` |
| `xurl` | Line-break URLs at any character to prevent overflow beyond page boundaries | `tlmgr install xurl` |

---

### Fonts & Colors

| Package | Description | Install Command |
|---------|-------------|-----------------|
| `fontspec` | Load system OpenType fonts under XeLaTeX/LuaLaTeX | `tlmgr install fontspec` |
| `xcolor` | Color support; `[svgnames]` enables 147 standard color names | `tlmgr install xcolor` |
| `microtype` | Character protrusion and micro-spacing adjustments — significantly improves paragraph typesetting quality | `tlmgr install microtype` |

---

### Utility Packages

| Package | Description | Install Command |
|---------|-------------|-----------------|
| `enumitem` | Full list customization: spacing, label format, nesting levels | `tlmgr install enumitem` |
| `siunitx` | `\SI{9.8}{\metre\per\second\squared}` for physical unit typesetting | `tlmgr install siunitx` |
| `csquotes` | Language-aware smart quotes, essential companion to `biblatex` | `tlmgr install csquotes` |
| `tcolorbox` | Colored info boxes, theorem boxes, sidebar highlight decorations | `tlmgr install tcolorbox` |
| `todonotes` | `\todo{}` margin notes for to-dos — invaluable during the writing and revision phase | `tlmgr install todonotes` |
| `soul` | Text decoration effects like `\hl{highlight}`, `\st{strikethrough}` | `tlmgr install soul` |

---

### Important Notes

- **Load order**: `xcolor` → `graphicx` → `amsmath` → `hyperref` (last) → `cleveref` (after hyperref)
- **Chinese users**: Just install `ctex` directly — no need to separately install `xeCJK`
- **Bibliography**: Recommended combination is `biblatex + biber`, paired with the `gb7714-2015` style for Chinese-language references
- **Check installed packages**: `tlmgr info <package-name>`
