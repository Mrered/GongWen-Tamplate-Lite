# 📝 轻量公文模板

一个旨在快速生成公文格式 PDF 的简单模板，基于 [Pandoc](https://pandoc.org/) 和 [Typst](https://typst.app/) ，非常适合用于撰写个人报告、工作总结等。

> [!NOTE]
> 本项目目前主要根据个人需求实现，并未完全对齐国家标准，欢迎大家一起参与改进！

## ✨ 主要功能

**标准纸张与边距**：默认设置为 A4 纸张，并配置了公文常用的页边距。

**自动化标题样式**：自动为二级到五级标题添加 `一、`、`（一）`、`1.` 和 `（1）` 格式的编号。

**专业字体支持**：正文和各级标题自动应用仿宋、黑体、楷体等指定字体。

**页脚页码**：在页脚自动生成 — 1 — 格式的页码，并根据奇偶页左右对齐。

**简洁的 Markdown 语法**：你只需要专注于用 Markdown 编写内容，剩下的交给模板。

## 👀 效果预览

[Markdown to Typst to PDF](/dist/out.typ.pdf)

对照组

[Markdown to MS Word to PDF](/dist/out.docx.pdf)

## 🚀 快速上手

只需简单四步，即可生成你的公文格式 PDF。

### 第 1 步：准备环境

在开始之前，请确保你的电脑上已经安装了以下工具和字体：

🛠️ 工具:

- `Pandoc` 一个强大的文档格式转换工具。
- `Typst` 一个现代化的、基于标记语言的排版系统。

🖋️ 字体:

- 方正小标宋 (FZXiaoBiaoSong-B05)
- 黑体 (STHeiti)
- 仿宋 (STFangsong)
- 楷体 (STKaiti)
- 宋体 (STSong)

> [!TIP]
> 这些字体在 macOS 和 Windows 系统中比较常见。如果你的系统缺失这些字体，请先手动下载并安装。

### 第 2 步：下载模板

使用 git 将本仓库克隆到你的本地。

```sh
git clone https://github.com/Mrered/GongWen-Template-Lite.git
cd GongWen-Template-Lite
```

### 第 3 步：撰写你的文档

模板仓库中已经包含了一个示例文件 in.md。你可以直接修改它，或者参考它的格式创建自己的 Markdown 文件。最关键的是文件头部的 YAML front-matter 配置，请务必填写：

```markdown
---
title: "这里是你的文档主标题"
author: 
  - "作者一"
  - "作者二" # 如果只有一个作者，保留一个即可
---

## 这是一级标题（对应 Markdown 的 H2）

这是正文内容...

### 这是二级标题（对应 Markdown 的 H3）

这是更多的正文内容...
```

注意：模板会自动忽略 Markdown 文件中的一级标题 (#)，并使用 YAML 配置中的 title 作为文档的正式标题。

### 第 4 步：生成 PDF

打开终端，确保你位于项目目录下，然后运行以下命令：

```sh
pandoc -f markdown -t typst --template template.typ in.md -L filter.lua | typst compile - out.pdf
```

🎉 恭喜！现在你的文件夹里应该已经出现了一个名为 `out.pdf` 的文件，快打开看看吧！

🤔 这条命令做了什么？

`pandoc ...`: 启动 Pandoc。

`--template template.typ`: 指定使用我们的公文模板进行渲染。

`in.md`: 你撰写的输入文件。

`-L filter.lua`: 加载一个过滤器脚本，它能帮助我们优化标题格式，让转换更完美。

`| typst compile - out.pdf`: 将 Pandoc 生成的 Typst 内容通过管道传给 Typst，最终编译成 `out.pdf`。

## 🔧 更多用法

如果你想查看从 Markdown 转换到 Typst 的中间文件（`.typ`），方便进行调试或修改，可以使用下面的命令：

```sh
pandoc -f markdown -t typst --template template.typ in.md -L filter.lua -o out.typ
```

这会生成一个 `out.typ` 文件，你可以用文本编辑器打开它。

你可以进一步将其转换成 PDF 文件：

```sh
typst compile out.typ out.pdf
```

## 📄 Microsoft Word

如果你更熟悉 Microsoft Word，也可以将 `.md` 文档转换为 `.docx` 文档，并使用模板进行格式化。本模板使用的 [in.md](/in.md) 可以直接转换成 `docx` 文件，可以使用下面的命令：

```sh
pandoc -f markdown -t docx --reference-doc=template.dotx -L filter.lua in.md -o out.docx
```

当然，你可以直接打开 `template.dotx` 文件， Microsoft Word 会自动以此为模板创建空白 Word 文档，你只需要套用样式，就能生成一个美观的文档。

## 🤝 如何贡献

这个模板还有很多不完善的地方，非常欢迎你一起参与改进！

你可以通过以下方式做出贡献：

- 提交 Issue：发现 Bug 或者有任何建议，请随时提出 Issue。
- 发起 Pull Request：如果你修复了 Bug 或者增加了新功能，欢迎提交 PR。

一些可以改进的方向：使其更符合国家公文标准。增加对更多字体或系统的支持。优化 `template.typ` 和 `filter.lua` 脚本。

## 📄 许可证

本项目采用 [MIT License](/LICENSE)。
