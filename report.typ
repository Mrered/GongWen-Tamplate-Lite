// 中文字号转换函数
#import "@preview/pointless-size:0.1.2": zh

// 定义常用字体名称
#let FONT_XBS = ("FZXiaoBiaoSong-B05") // 方正小标宋
#let FONT_HEI = ("STHeiti") // 黑体
#let FONT_FS = ("STFangsong") // 仿宋
#let FONT_KAI = ("STKaiti") // 楷体
#let FONT_SONG = ("STSong") // 宋体

// 设置页面、页边距、页脚
#set page(
  paper: "a4",
  margin: (
    inside: 28mm,
    outside: 26mm,
    top: 37mm,
    bottom: 35mm,
  ),

  // 将页脚基线放到"版心下边缘之下 7mm"
  footer-descent: 7mm,

  // 使用更稳定的奇偶页判断和页码格式
  footer: context {
    let page-num = here().page()
    let is-even = calc.even(page-num)
    let num = str(page-num)
    let pm = text(font: FONT_SONG, size: zh(4))[— #num —] // 4 号宋体

    if is-even {
      align(left, [#h(1em) #pm])    // 偶数页：居左
    } else {
      align(right, [#pm #h(1em)])   // 奇数页：居右
    }
  },
)

// 设置文档默认语言和正文字体
#set text(
  lang: "zh",
  font: FONT_FS,
  size: zh(3),
  hyphenate: false,
  tracking: -0.3pt,
  cjk-latin-spacing: auto
)

// 设置段落样式，以满足"每行28字符，每页22行"的网格标准，首行缩进2字符
#set par(
  first-line-indent: (amount: 2em, all: true),
  justify: true,
  leading: (15.6pt), // 行间距
  spacing: (15.6pt)  // 段间距
)

// 计数器设置
#let h2-counter = counter("h2")
#let h3-counter = counter("h3") 
#let h4-counter = counter("h4")
#let h5-counter = counter("h5")

// 自定义标题函数
#let custom-heading(level, body, numbering: auto) = {
  if level == 1 {
    // 一级标题：当作 title 方便从 Markdown 转换
    // 居中，段前 0 行段后 28.7 磅，行距固定值 35 磅，字体 FZXiaoBiaoSong-B05 字号 zh(2)，无序号，无首行缩进
    v(0pt) // 段前0行
    align(center)[
      #text(
        font: FONT_XBS,
        size: zh(2),
        weight: "bold"
      )[
        #set par(leading: 35pt - zh(2)) // 行距固定值35磅
        #body
      ]
    ]
    v(28.7pt) // 段后28.7磅
  } else if level == 2 {
    // 二级标题：首行缩进2字符，STHeiti 字号 zh(3)，使用 `一、` 作为序号
    h2-counter.step()
    h3-counter.update(0)
    h4-counter.update(1)
    h5-counter.update(1)
    text(
      font: FONT_HEI,
      size: zh(3),
    )[#context h2-counter.display("一、")#body]
  } else if level == 3 {
    // 三级标题：首行缩进2字符，STKaiti 字号 zh(3)，使用 `（一）` 作为序号
    h3-counter.step()
    h4-counter.update(1)
    h5-counter.update(1)
    
    let number = h3-counter.get().first()
    text(
      font: FONT_KAI,
      size: zh(3),
    )[#context h3-counter.display("（一）")#body]
  } else if level == 4 {
    // 四级标题：首行缩进2字符，STFangsong 字号 zh(3)，使用 `1.` 作为序号
    h4-counter.step()
    h5-counter.update(1)
    
    let number = h4-counter.get().first()
    text(
      size: zh(3),
    )[#number. #body]
  } else if level == 5 {
    // 五级标题：首行缩进2字符，STFangsong 字号 zh(3)，使用 `（1）` 作为序号
    h5-counter.step()
    
    let number = h5-counter.get().first()
    text(
      size: zh(3),
    )[（#number）#body]
  }
}

// 应用自定义标题样式
#show heading: it => {
  if it.level != 1{
    block(
  sticky: true,
      above: 13.9pt,
      below: 13.9pt
    )[it]
  }
  else {
    it
  }
}

#show heading: it => {
  [#custom-heading(it.level, it.body, numbering: it.numbering)]
}

// 重置计数器在文档开始时
#h2-counter.update(0)
#h3-counter.update(0) 
#h4-counter.update(0)
#h5-counter.update(0)

// 定义作者名称显示样式
#let name(name) = align(center, pad(bottom: 0.8em)[
  #text(font: FONT_KAI, size: zh(3))[#name]
])

#let autoTitle = "报告"

#let autoAuthor = "Mrered Cio、Gemini、ChatGPT"

#let autoDate = datetime(
  year: 2025,
  month: 12,
  day: 16,
)

#set document(
  title: autoTitle, 
  author: autoAuthor,
  keywords: "工作总结, 年终报告",
  date: auto,
)

= #autoTitle


#block[#set par(first-line-indent: 0pt)
各位领导：

]
为了解放公文写作的负担，我们推出了
`GongWen-Template-Lite`（公文模版青春版），下面将详细介绍这个项目。

== 项目概述

=== 项目背景与定位

开源项目 `GongWen-Template-Lite`（公文模版青春版） 近日在 GitHub
上完成更新，面向个人报告与工作总结等应用场景，提供了一套轻量级的公文排版解决方案。项目以“降低写作负担、提高成稿效率”为目标，强调作者只需专注内容本身，版式与样式交由模板自动完成。

=== 技术路线与核心理念

项目基于 #strong[Pandoc + Typst] 的工具组合，实现从 Markdown 到 PDF
的一站式转换流程。在保持 Markdown
简洁书写体验的同时，引入专业排版引擎，兼顾效率与成文质量，适合日常总结、阶段性汇报等场景快速使用。

== 功能特点与排版规范

=== 标准化排版能力

模板内置标准纸张与页边距设置，自动处理标题样式、页脚与页码格式，整体排版风格贴近国内常见公文习惯。页码采用“---
1 ---”样式，并按奇偶页进行对齐，增强正式文档的规范感。

=== 标题结构与编号规则

==== 标题层级处理

在文档头部通过 YAML front-matter 填写标题与作者信息，模板将自动忽略
Markdown 一级标题，以 `title` 作为正式文档标题。

==== 自动编号机制

对 Markdown
二至五级标题，模板依次施加“一、（一）1.（1）”的编号规则，实现多级标题的自动编号与统一样式，避免手工调整带来的错误与重复劳动。

=== 字体与样式支持

模板内置仿宋、黑体、楷体、宋体、小标宋等常用中文字体样式，满足常见公文与报告的排版需求，在字体选择上兼顾规范性与可读性。

=== 段落缩进控制

文档自动全局缩进 2 个字符宽度，以符合公文排版规范。

==== 首行缩进

首行若以冒号开头，则不缩进，也可以强制使用标签`{indent}`使其强制缩进。

==== 其他行缩进

===== 无缩进段落

通过使用 `::: {.noindent}` 标签，可以实现段落的无缩进效果。

#block[#set par(first-line-indent: 0pt)
#block[
这是一段无缩进的段落。

]
]
===== 无缩进行内文本

通过使用 `{.noindent}`
标签，可以实现行内文本的无缩进效果。标题也可以使用 `{.noindent}`
标签强制取消缩进。

#block[#set par(first-line-indent: 0pt)
这是一段无缩进的行内文本。

]
#block[#set par(first-line-indent: 0pt)
===== 这是一个无缩进的标题
]

== 扩展能力与使用方式

=== 中间文件调试机制

项目支持先输出中间的 `.typ` 文件，用户可在此基础上进行细节微调，再使用
Typst 编译生成最终 PDF，为有定制需求的用户预留了扩展空间。

=== Word 工作流支持

针对偏好 Word 编辑的用户，仓库提供了 `reference`
模板（`template.dotx`），可将 Markdown 一键转换为 `.docx` 文件，并在
Word 中套用既定样式，兼顾不同使用习惯。

=== Lua 过滤器增强

近期更新的 `filter.lua`
对元数据处理与段落缩进控制进行了强化，新增并完善了对 `signature` 与
`date`
字段的支持；示例文档中也加入了无缩进段落与标签写法，显著提升了排版灵活度。

== 项目现状与发展方向

=== 适用场景与局限性

项目明确定位为“轻量模板”，目前尚未完全对齐国家公文标准，更适合个人报告与团队内部总结等快速成稿场景，而非严格意义上的正式公文定稿。

=== 社区协作与维护状态

维护者欢迎通过工单与拉取请求参与改进，重点方向包括国标适配细化、字体与系统兼容性扩展，以及
Typst 模板与 Lua 脚本的进一步优化。从更新节奏来看，项目在 2025
年末仍保持活跃提交，体现出持续维护的态度。

== 总体评价

总体而言，`GongWen-Template-Lite`（公文模版青春版）
以低门槛的工具链，将原本繁琐的公文样式配置高度自动化，兼顾 Markdown
的写作效率与成稿质量。对于需要在较短时间内生成规范化 PDF 或 Word
文档的个人与小团队而言，该项目提供了一种轻便而务实的解决方案。随着社区参与度提升与国标适配的逐步完善，其在中文文档工作流中的实用价值有望进一步增强。

#v(18pt)
#align(right, block[
  #set align(center)
  #autoAuthor \
  #autoDate.display(
    "[year]年[month padding:none]月[day padding:none]日"
  )
])
