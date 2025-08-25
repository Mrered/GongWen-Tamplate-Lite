# 轻量公文模板

一个公文格式的简单模板，并未完全适配国标，个人报告之用

## 依赖

- `pandoc`
- `typst`
- `FZXiaoBiaoSong-B05` 方正小标宋
- `STHeiti` 黑体
- `STFangsong` 仿宋
- `STKaiti` 楷体
- `STSong` 宋体

## 使用说明

### 直接生成 PDF

本模板需配合以下命令使用

> 下面的 lua 脚本实现了删除 Markdown 文档转换时多余的<锚点标签>，当然也可以不删，直接增加空行。

```sh
pandoc -f markdown -t typst --template template.typ in.md \
  -L <(cat <<'LUA'
function Header(h)
  if h.level == 1 then
    return {}
  end
  h.identifier = ""
  return {h, pandoc.Para({})}
end
LUA
) | typst compile - out.pdf
```

或

```sh
git clone https://github.com/Mrered/GongWen-Template-Lite.git
pandoc -f markdown -t typst --template template.typ in.md -L filter.lua | typst compile - out.pdf
```

### 生成 typ


```sh
pandoc -f markdown -t typst --template template.typ in.md -o out.typ \
  -L <(cat <<'LUA'
function Header(h)
  if h.level == 1 then
    return {}
  end
  h.identifier = ""
  return {h, pandoc.Para({})}
end
LUA
) 
```

或

```sh
git clone https://github.com/Mrered/GongWen-Template-Lite.git
pandoc -f markdown -t typst --template template.typ in.md -L filter.lua -o out.typ
```


Markdown 文件建议添加 YAML-front-matter 配置信息，且包含下面的变量，其中作者姓名可以只有一个。

```yaml
---
title: "轻量公文模板"
author: 
  - "Mrered"
  - "Uijxmug"
---
```

## 功能

### 标题

Markdown 文件中二级标题到五级标题会自动转换为对应的样式，一级标题会被忽略，改为使用 YAML-front-matter 中的 title 变量。生成的标题会自动添加编号，样式如下：

```typst
=       标题，居中，段前 0 行段后 28.7 磅，行距固定值 35 磅，字体 FZXiaoBiaoSong-B05 字号 zh(2)，无序号，无首行缩进
==      文章一级标题，首行缩进2字符，黑体，三号字号，使用 `一、` 作为序号
===     文章二级标题，首行缩进2字符，楷体，三号字号，使用 `（一）` 作为序号
====    文章三级标题，首行缩进2字符，仿宋，三号字号，使用 `1.` 作为序号
=====   文章四级标题，首行缩进2字符，仿宋，三号字号，使用 `（1）` 作为序号
```

### 页码

模板还实现了页脚页码的显示，偶数页居左，奇数页居右，格式为 `— 1 —`，字号为 4 号宋体。

### 纸张

模板页面设置为 A4 纸，页边距为：内侧 28mm，外侧 26mm，上 37mm，下 35mm，页脚基线放到"版心下边缘之下 10mm"。
