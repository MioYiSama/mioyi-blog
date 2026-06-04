---
title: "LaTeX"
tags: [编程语言]
---

## 发行版

- **TeX Live**：最主流、最通用的发行版，支持 Linux、macOS、Windows。大多数 Linux 发行版里的 `texlive-*` 包就是它。适合服务器、CI、Linux/macOS/跨平台项目。TeX Users Group 也把 MiKTeX 称为 TeX Live 之外另一个主要免费 TeX 发行版。
- **MacTeX**：macOS 上最推荐的选择，本质上是给 Mac 打包好的 TeX Live，附带 TeXShop、BibDesk、Ghostscript 等 Mac 相关工具。
- **BasicTeX**：MacTeX 的精简版，也基于 TeX Live。适合不想装几个 GB 大包、愿意缺什么补什么的人。
- **MiKTeX**：Windows 用户很常见，也支持 Linux/macOS。特点是可以按需安装缺失包，GUI 管理体验相对友好。适合 Windows 桌面用户。
- **TinyTeX**：轻量版 LaTeX 发行版，基于 TeX Live，跨平台、便携，尤其适合 R Markdown / Quarto / Pandoc / CI 场景。
- **Tectonic**：现代化的单文件 TeX/LaTeX 引擎，基于 XeTeX 和 TeX Live 资源，主打自动下载依赖、可复现构建、少配置。更像“现代 LaTeX 编译工具链”，不完全是传统意义的大型发行版。
- **ConTeXt Standalone / ConTeXt Suite**：主要面向 ConTeXt 用户，不是传统 LaTeX 用户的首选。它是完整、可独立更新的 ConTeXt 发行版，可以和已有 TeX Live 并存。
- 历史上还有 **teTeX、proTeXt、fpTeX、gwTeX** 等，但现在基本不推荐新装。比如 teTeX 已停止维护，后来由 TeX Live 接替。

## 底层引擎

- **pdfLaTeX**：这是以前最主流的 LaTeX 引擎。优点是稳定、快、兼容性最好；缺点是原生 Unicode 和系统字体支持差。中文要靠 CJK、ctex 等宏包处理，不如 XeLaTeX / LuaLaTeX 自然。
- **XeLaTeX**：最大特点是原生支持 Unicode 和系统字体，可以直接用系统里的字体，比如宋体、思源黑体、Times New Roman。中文文档里非常常用。
- **LuaLaTeX**：LuaLaTeX 是更现代的路线，支持 Unicode、OpenType 字体，还内置 Lua 脚本能力，可以做更复杂的排版自动化。它被认为是未来更推荐的方向之一，但有时模板兼容性不如 pdfLaTeX / XeLaTeX。

## Linux 安装 TexLive

```bash
cd /tmp

# 下载安装包
wget https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
tar -xzf install-tl-unx.tar.gz
cd install-tl-2026 # 年份随时间变化

# 安装
sudo perl ./install-tl \
  --no-interaction \
  --scheme=small \
  --no-doc-install \
  --no-src-install

# 配置
TL_YEAR=$(ls /usr/local/texlive | sort -n | tail -1) # 获取当前安装的年份版本
echo "export PATH=/usr/local/texlive/$TL_YEAR/bin/x86_64-linux:\$PATH" >> ~/.bashrc # 加入PATH
source ~/.bashrc

# 检查
lualatex --version
tlmgr --version
```

## 必装包推荐

### 数学公式

| 宏包 | 说明 | 安装命令 |
|------|------|----------|
| `amsmath` | `align`、`cases` 等核心数学环境，几乎必装 | `tlmgr install amsmath` |
| `mathtools` | `amsmath` 超集，修复已知 bug 并扩展更多命令 | `tlmgr install mathtools` |
| `amsfonts` / `amssymb` | ℝ ∀ ∈ 等数学符号，`\mathbb` 黑板粗体字族 | `tlmgr install amsfonts` |
| `unicode-math` | XeLaTeX/LuaLaTeX 下使用 Unicode 数学字体 | `tlmgr install unicode-math` |
| `physics` | `\dv`、`\pdv` 导数，Dirac 括号等物理学快捷命令 | `tlmgr install physics` |
| `bm` | `\bm{}` 数学粗体，比 `\boldsymbol` 更健壮 | `tlmgr install bm` |

---

### 图形绘图

| 宏包 | 说明 | 安装命令 |
|------|------|----------|
| `graphicx` | `\includegraphics` 插入图片，几乎必装 | `tlmgr install graphics` |
| `tikz` / `pgf` | 矢量绘图语言，流程图、电路图、脑图均可 | `tlmgr install pgf` |
| `pgfplots` | 基于 TikZ 的科学数据图表（折线/柱状/极坐标） | `tlmgr install pgfplots` |
| `float` | `H` 选项强制浮动体位置，图表不再乱跑 | `tlmgr install float` |
| `subcaption` | 子图并排与独立编号，替代旧版 `subfig` | `tlmgr install caption` |
| `wrapfig` | 文字环绕图片布局 | `tlmgr install wrapfig` |

---

### 表格

| 宏包 | 说明 | 安装命令 |
|------|------|----------|
| `booktabs` | 三线表（`\toprule \midrule \bottomrule`），学术论文标配 | `tlmgr install booktabs` |
| `tabularx` | `X` 列自动撑满剩余宽度，告别手算列宽 | `tlmgr install tabularx` |
| `multirow` | `\multirow` 单元格跨行合并 | `tlmgr install multirow` |
| `longtable` | 自动断页的跨页长表格 | `tlmgr install longtable` |
| `array` | `>{}<{}` 列前后钩子，`p`/`m`/`b` 列类型扩展 | `tlmgr install array` |
| `tabularray` | 新一代表格宏包，语法更直观，推荐新项目使用 | `tlmgr install tabularray` |

---

### 参考文献

| 宏包 | 说明 | 安装命令 |
|------|------|----------|
| `biblatex` | 现代参考文献管理，支持国标/APA/Chicago 等风格 | `tlmgr install biblatex` |
| `biber` | BibLaTeX 推荐后端，替代老旧的 BibTeX | `tlmgr install biber` |
| `natbib` | `\citet{}`、`\citep{}` 自然科学引用格式 | `tlmgr install natbib` |

---

### 中文支持

| 宏包 | 说明 | 安装命令 |
|------|------|----------|
| `ctex` | 中文排版全家桶：字体、标点、版式一站式配置 | `tlmgr install ctex` |
| `xeCJK` | XeLaTeX 下细粒度控制中英文混排间距 | `tlmgr install xecjk` |
| `zhnumber` | 中文数字格式：一、二、三……章节自动转换 | `tlmgr install zhnumber` |

---

### 代码排版

| 宏包 | 说明 | 安装命令 |
|------|------|----------|
| `listings` | 代码语法高亮，支持 50+ 语言，高度可定制 | `tlmgr install listings` |
| `minted` | 基于 Pygments 的精美代码高亮（需安装 Python） | `tlmgr install minted` |
| `fancyvrb` | 增强 verbatim 环境，支持行号和帧线 | `tlmgr install fancyvrb` |

---

### 页面布局

| 宏包 | 说明 | 安装命令 |
|------|------|----------|
| `geometry` | 页面尺寸与页边距设置，比手动设参数安全 | `tlmgr install geometry` |
| `fancyhdr` | 页眉页脚自定义，可自动填入章节名 | `tlmgr install fancyhdr` |
| `titlesec` | 章节标题字体、颜色、间距深度定制 | `tlmgr install titlesec` |
| `setspace` | 1.5 倍/双倍行距，毕业论文格式常用 | `tlmgr install setspace` |
| `parskip` | 以段间距代替首行缩进，欧式排版风格 | `tlmgr install parskip` |

---

### 超链接

| 宏包 | 说明 | 安装命令 |
|------|------|----------|
| `hyperref` | PDF 超链接、书签、元数据，**务必最后加载** | `tlmgr install hyperref` |
| `cleveref` | `\cref{}` 自动加"图""表""节"等前缀，加载在 `hyperref` 之后 | `tlmgr install cleveref` |
| `xurl` | URL 在任意字符处断行，防止溢出页面边界 | `tlmgr install xurl` |

---

### 字体与颜色

| 宏包 | 说明 | 安装命令 |
|------|------|----------|
| `fontspec` | XeLaTeX/LuaLaTeX 下加载系统 OpenType 字体 | `tlmgr install fontspec` |
| `xcolor` | 颜色支持，`[svgnames]` 启用 147 种标准色名 | `tlmgr install xcolor` |
| `microtype` | 字符微突出和间距微调，显著提升段落排版质量 | `tlmgr install microtype` |

---

### 实用工具

| 宏包 | 说明 | 安装命令 |
|------|------|----------|
| `enumitem` | 列表完全定制：间距、标签格式、嵌套层级 | `tlmgr install enumitem` |
| `siunitx` | `\SI{9.8}{\metre\per\second\squared}` 物理单位排版 | `tlmgr install siunitx` |
| `csquotes` | 语言感知智能引号，与 `biblatex` 配合必备 | `tlmgr install csquotes` |
| `tcolorbox` | 彩色信息框、定理框、侧边栏高亮装饰 | `tlmgr install tcolorbox` |
| `todonotes` | `\todo{}` 边注待办，写作修改阶段的利器 | `tlmgr install todonotes` |
| `soul` | `\hl{高亮}`、`\st{删除线}` 等文字装饰效果 | `tlmgr install soul` |

---

### 注意事项

- **加载顺序**：`xcolor` → `graphicx` → `amsmath` → `hyperref`（最后）→ `cleveref`（hyperref 之后）
- **中文用户**：直接装 `ctex` 即可，无需再单独装 `xeCJK`
- **参考文献**：推荐 `biblatex + biber` 组合，搭配 `gb7714-2015` 风格支持中文文献
- **查询已安装**：`tlmgr info <package-name>`
