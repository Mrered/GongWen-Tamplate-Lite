// 中文字号转换函数
#import "@preview/pointless-size:0.1.2": zh

// 定义常用字体名称
#let FONT_XBS = "FZXiaoBiaoSong-B05" // 方正小标宋
#let FONT_HEI = "STHeiti" // 黑体
#let FONT_FS = "STFangsong" // 仿宋
#let FONT_KAI = "STKaiti" // 楷体
#let FONT_SONG = "STSong" // 宋体

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
      align(left, [#h(1em) #pm]) // 偶数页：居左
    } else {
      align(right, [#pm #h(1em)]) // 奇数页：居右
    }
  },
)

// 设置文档默认语言和正文字体
#set text(
  lang: "zh",
  font: FONT_FS,
  size: zh(3),
  hyphenate: false,
  cjk-latin-spacing: auto,
)

// 设置段落样式，以满足"每行28字符，每页22行"的网格标准，首行缩进2字符
#set par(
  first-line-indent: (amount: 2em, all: true),
  justify: true,
  leading: 15.6pt, // 行间距
  spacing: 15.6pt, // 段间距
)

// 计数器设置
#let h2-counter = counter("h2")
#let h3-counter = counter("h3")
#let h4-counter = counter("h4")
#let h5-counter = counter("h5")

// 图片样式设置
#show figure: it => {
  // 居中对齐，无首行缩进
  set par(first-line-indent: 0pt)
  align(center, block({
    // 图片尺寸由 Lua filter 控制
    it.body

    // 图注样式：3号仿宋，格式为"图1 标题"
    text(
      font: FONT_FS,
      size: zh(3),
      it.caption,
    )
  }))
}

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
        weight: "bold",
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
  if it.level != 1 {
    block(
      sticky: true,
      above: 13.9pt,
      below: 13.9pt,
    )[it]
  } else {
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

// 将列表项转换为普通段落以实现"续行顶格"
// 列表层级计数器，用于处理嵌套缩进
#let list-depth = state("list-depth", 0)

// 将列表项转换为普通段落以实现"续行顶格"
#let flush-left-list(it) = {
  // 1. 更新层级深度
  list-depth.update(d => d + 1)

  let is-enum = (it.func() == enum)
  let children = it.children

  // 2. 获取当前缩进状态（普通列表继承 2em，noindent 列表继承 0pt）
  //    并根据层级计算额外的块级缩进 (Left Padding)
  context {
    let depth = list-depth.get()
    // 第一层(depth=1)不需要额外padding，第二层(depth=2)需要 2em，以此类推
    let block-indent = if depth > 1 { 2em } else { 0pt }

    // 3. 计算枚举项数量，用于编号
    pad(left: block-indent, block({
      for (count, item) in children.enumerate(start: 1) {
        if item.func() == list.item or item.func() == enum.item {
          let marker = if is-enum {
            let pattern = if it.has("numbering") and it.numbering != auto { it.numbering } else { "1." }
            numbering(pattern, count)
          } else {
            if it.has("marker") and it.marker.len() > 0 { it.marker.at(0) } else { [•] }
          }

          // 4. 生成段落
          //    继承 first-line-indent（由外部环境决定，如 2em 或 0pt）
          //    强制 hanging-indent 为 0pt（实现续行左对齐）
          par(
            first-line-indent: par.first-line-indent,
            hanging-indent: 0pt,
          )[#marker#h(0.25em)#item.body]
        } else {
          item
        }
      }
    }))

    // 5. 恢复层级深度
    list-depth.update(d => d - 1)
  }
}

// 应用规则
#show list: flush-left-list
#show enum: flush-left-list

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
#block[
各位领导：

]
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

==== 列表缩进

+ 有序列表缩进，这里这些文字是为了展示有序列表换行的情况，可以看到，文字能够自动对齐左侧版芯边缘，而不是跟随原来的缩进方式进行缩进；
+ 有序列表缩进示例。

- 无序列表缩进，同上，这里这些文字是为了展示无序列表换行的情况，可以看到，文字能够自动对齐左侧版芯边缘，而不是跟随原来的缩进方式进行缩进；
- 目前，暂时无法正常显示多层级无序列表。

#block[#set par(first-line-indent: 0pt)
#block[
#block[#set par(first-line-indent: 0pt)
+ 有序列表无缩进，这里这些文字是为了展示有序列表换行的情况，可以看到，文字能够自动对齐左侧版芯边缘，而不是跟随原来的缩进方式进行缩进；
+ 有序列表无缩进。

]
#block[#set par(first-line-indent: 0pt)
- 无序列表无缩进，同上，这里这些文字是为了展示无序列表换行的情况，可以看到，文字能够自动对齐左侧版芯边缘，而不是跟随原来的缩进方式进行缩进；
- 无序列表无缩进。

]
]
]
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
#block[
这是一段无缩进的行内文本。

]
]
#block[#set par(first-line-indent: 0pt)
===== 这是一个无缩进的标题
]

=== 换行和分页

==== 换行

标记`{v}`的行，会自动换行。

#linebreak(justify: false)

这是另一段内容，和上面的内容空出来1行。

标记`{v:3}`的行，会隔3行。

#linebreak(justify: false)
#linebreak(justify: false)
#linebreak(justify: false)

这是另一段内容，和上面的内容空出来3行。

==== 分页

标记`{pagebreak}`的行，会自动分页。

#pagebreak()

== 图片排版功能展示

本模板支持强大的图片自动排版功能，以下是实际效果展示：

=== 单张图片展示

单张图片会自动居中，最大宽度或高度限制为
13.4cm，并自动提取文件名作为图注：

#figure(
  context {
    let img = image("风景.webp")
    let img-size = measure(img)
    let x = img-size.width
    let y = img-size.height
    let max-size = 13.4cm
    
    let new-x = x
    let new-y = y
    
    if x > max-size {
      let scale = max-size / x
      new-x = max-size
      new-y = y * scale
    }
    
    if new-y > max-size {
      let scale = max-size / new-y
      new-x = new-x * scale
      new-y = max-size
    }
    
    image("风景.webp", width: new-x, height: new-y)
  },
  caption: [风景],
) <fig-1>
#figure(
  context {
    let img = image("AI人像.jpg")
    let img-size = measure(img)
    let x = img-size.width
    let y = img-size.height
    let max-size = 13.4cm
    
    let new-x = x
    let new-y = y
    
    if x > max-size {
      let scale = max-size / x
      new-x = max-size
      new-y = y * scale
    }
    
    if new-y > max-size {
      let scale = max-size / new-y
      new-x = new-x * scale
      new-y = max-size
    }
    
    image("AI人像.jpg", width: new-x, height: new-y)
  },
  caption: [AI人像],
) <fig-2>
=== 多图并排（独立模式）

在同一行只需连续放置图片，即可自动并排。系统会自动计算高度以保持对齐。即便是比例差异巨大的图片（如横屏风景图
vs 竖屏人像图），也能完美对齐：

#context {
  // 图片路径列表
  let paths = ("风景.webp", "AI人像.jpg")
  // 图片标题列表（对应 paths）
  let captions = ("风景", "AI人像")
  // Alt Text 列表
  let alts = ("", "")
  
  let is_subfigure = false 
  let main_caption = ""
  
  let gap = 0.3cm  // 图片间隙
  let max-width = 13.4cm
  let min-height = 6cm
  
  // 测量所有图片的原始尺寸
  let sizes = paths.zip(captions).zip(alts).map(item => {
    let p = item.at(0).at(0)
    let c = item.at(0).at(1)
    let alt = item.at(1)
    let img = image(p)
    let s = measure(img)
    (width: s.width, height: s.height, path: p, caption: c, alt: alt, ratio: s.width / s.height)
  })
  
  // 函数：计算一组图片等高排列时的高度
  let calc-row-height(imgs, total-width) = {
    // 计算所有图片宽高比之和
    let ratio-sum = imgs.map(i => i.ratio).sum()
    // 等高时的高度 = 总宽度 / 宽高比之和
    total-width / ratio-sum
  }
  
  // 分行算法
  let rows = ()
  
  if is_subfigure {
    // 方案一（子图模式）：强制所有图片在同一行
    rows.push(sizes)
  } else {
    // 方案二（独立模式）：自动换行逻辑
    let remaining = sizes
    
    while remaining.len() > 0 {
      let row = ()
      let found = false
      
      // 尝试放入尽可能多的图片
      for n in range(1, remaining.len() + 1) {
        let candidate = remaining.slice(0, n)
        let gaps = (n - 1) * gap
        let available-width = max-width - gaps
        let row-h = calc-row-height(candidate, available-width)
        
        if row-h < min-height and n > 1 {
          // 高度不够，使用前一个数量
          row = remaining.slice(0, n - 1)
          remaining = remaining.slice(n - 1)
          found = true
          break
        }
      }
      
      if not found {
        // 所有图片都能放，或者只有一张图片
        row = remaining
        remaining = ()
      }
      
      rows.push(row)
    }
  }
  
  // 渲染函数
  let render-rows(rows) = {
    for row in rows {
      let n = row.len()
      let gaps = (n - 1) * gap
      let available-width = max-width - gaps
      let row-height = calc-row-height(row, available-width)
      
      // 限制最大高度
      if row-height > max-width {
        row-height = max-width
      }
      
      align(center, grid(
        columns: n,
        gutter: gap,
        ..row.enumerate().map(item => {
          let i = item.at(0)
          let img-data = item.at(1)
          // 使用比例计算宽度：w = row-height * ratio
          let w = row-height * img-data.ratio
          
          if is_subfigure {
             // 子图模式：上面是图，下面是 (a) 文件名
             // 使用文件名(img-data.caption)作为子图注，忽略其他 Alt
             let sub-label = numbering("a", i + 1)
             let sub-text = [ (#sub-label) #img-data.caption ]
             
             v(0.5em)
             align(center, block({
               image(img-data.path, width: w, height: row-height)
               // 子图注样式：与大图注一致 (FONT_FS, zh(3))
               align(center, text(font: FONT_FS, size: zh(3))[#sub-text])
             }))
          } else {
             // 独立模式：完整的 figure
             figure(
               image(img-data.path, width: w, height: row-height),
               caption: [ #img-data.caption ]
             )
          }
        })
      ))
      if is_subfigure { v(0.5em) } else { v(0.3em) }
    }
  }
  
  // 根据模式输出
  if is_subfigure {
    figure(
      context { render-rows(rows) },
      caption: [ #main_caption ]
    )
  } else {
    render-rows(rows)
  }
}

=== 子图组合模式（推荐）

如果需要展示对比图或关联图，只需在第一张图片中添加说明（Alt
Text），系统自动将其作为一组子图处理，生成 `(a)`、`(b)` 编号：

#context {
  // 图片路径列表
  let paths = ("风景.webp", "猫猫.png", "AI人像.jpg")
  // 图片标题列表（对应 paths）
  let captions = ("风景", "猫猫", "AI人像")
  // Alt Text 列表
  let alts = ("不同主体的视觉表现", "", "")
  
  let is_subfigure = true 
  let main_caption = "不同主体的视觉表现"
  
  let gap = 0.3cm  // 图片间隙
  let max-width = 13.4cm
  let min-height = 6cm
  
  // 测量所有图片的原始尺寸
  let sizes = paths.zip(captions).zip(alts).map(item => {
    let p = item.at(0).at(0)
    let c = item.at(0).at(1)
    let alt = item.at(1)
    let img = image(p)
    let s = measure(img)
    (width: s.width, height: s.height, path: p, caption: c, alt: alt, ratio: s.width / s.height)
  })
  
  // 函数：计算一组图片等高排列时的高度
  let calc-row-height(imgs, total-width) = {
    // 计算所有图片宽高比之和
    let ratio-sum = imgs.map(i => i.ratio).sum()
    // 等高时的高度 = 总宽度 / 宽高比之和
    total-width / ratio-sum
  }
  
  // 分行算法
  let rows = ()
  
  if is_subfigure {
    // 方案一（子图模式）：强制所有图片在同一行
    rows.push(sizes)
  } else {
    // 方案二（独立模式）：自动换行逻辑
    let remaining = sizes
    
    while remaining.len() > 0 {
      let row = ()
      let found = false
      
      // 尝试放入尽可能多的图片
      for n in range(1, remaining.len() + 1) {
        let candidate = remaining.slice(0, n)
        let gaps = (n - 1) * gap
        let available-width = max-width - gaps
        let row-h = calc-row-height(candidate, available-width)
        
        if row-h < min-height and n > 1 {
          // 高度不够，使用前一个数量
          row = remaining.slice(0, n - 1)
          remaining = remaining.slice(n - 1)
          found = true
          break
        }
      }
      
      if not found {
        // 所有图片都能放，或者只有一张图片
        row = remaining
        remaining = ()
      }
      
      rows.push(row)
    }
  }
  
  // 渲染函数
  let render-rows(rows) = {
    for row in rows {
      let n = row.len()
      let gaps = (n - 1) * gap
      let available-width = max-width - gaps
      let row-height = calc-row-height(row, available-width)
      
      // 限制最大高度
      if row-height > max-width {
        row-height = max-width
      }
      
      align(center, grid(
        columns: n,
        gutter: gap,
        ..row.enumerate().map(item => {
          let i = item.at(0)
          let img-data = item.at(1)
          // 使用比例计算宽度：w = row-height * ratio
          let w = row-height * img-data.ratio
          
          if is_subfigure {
             // 子图模式：上面是图，下面是 (a) 文件名
             // 使用文件名(img-data.caption)作为子图注，忽略其他 Alt
             let sub-label = numbering("a", i + 1)
             let sub-text = [ (#sub-label) #img-data.caption ]
             
             v(0.5em)
             align(center, block({
               image(img-data.path, width: w, height: row-height)
               // 子图注样式：与大图注一致 (FONT_FS, zh(3))
               align(center, text(font: FONT_FS, size: zh(3))[#sub-text])
             }))
          } else {
             // 独立模式：完整的 figure
             figure(
               image(img-data.path, width: w, height: row-height),
               caption: [ #img-data.caption ]
             )
          }
        })
      ))
      if is_subfigure { v(0.5em) } else { v(0.3em) }
    }
  }
  
  // 根据模式输出
  if is_subfigure {
    figure(
      context { render-rows(rows) },
      caption: [ #main_caption ]
    )
  } else {
    render-rows(rows)
  }
}

这里展示了风景、动物与人像在同一组图中的排版效果，注意所有子图注字体均已自动调整为规范样式。

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
    "[year]年[month padding:none]月[day padding:none]日",
  )
])
