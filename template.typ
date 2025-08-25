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

  // 将页脚基线放到"版心下边缘之下 10mm"
  footer-descent: 10mm,

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

$if(title)$
#let autoTitle = "$title$"
$else$
#let autoTitle = "这是一级标题"
$endif$

$if(author)$
#let autoAuthor = "$for(author)$$author$$sep$, $endfor$"
$else$
#let autoAuthor = "张三"
$endif$

#set document(
  title: autoTitle, 
  author: autoAuthor,
  keywords: "工作总结, 年终报告",
  date: auto,
)

= #autoTitle

#name(autoAuthor)

$body$