-- 全局变量存储作者字符串
local authors_string = ""
-- 全局变量：是否已经遇到了标题
local has_seen_header = false
-- 全局变量：图片计数器
local figure_counter = 0

-- =================================================================================
-- 辅助函数：处理垂直空白和分页标记
-- =================================================================================

-- 处理 {v} 和 {v:n} 标记，返回对应的 Typst 代码
-- {v} => #v(1lh)  （空一行，使用行高单位）
-- {v:n} => #v(nlh) （空n行）
-- 参考: https://typst.app/docs/reference/layout/v/
local function process_v_marker(text)
  -- 匹配 {v:数字}
  local n = text:match('^{v:(%d+)}$')
  if n then
    local count = tonumber(n)
    local result = {}
    -- 生成 count 个 #linebreak(justify: false)
    for i = 1, count do
      table.insert(result, "#linebreak(justify: false)")
    end
    -- 合并为一个字符串，每个换行符分隔
    return table.concat(result, "\n")
  elseif text == "{v}" then
    -- 默认一行
    return "#linebreak(justify: false)"
  end
  return nil
end

-- 处理分页标记
-- {pagebreak} => #pagebreak()
-- {pagebreak:weak} => #pagebreak(weak: true)
-- 参考: https://typst.app/docs/reference/layout/pagebreak/
local function process_pagebreak_marker(text)
  if text == '{pagebreak}' then
    return '#pagebreak()'
  elseif text == '{pagebreak:weak}' then
    return '#pagebreak(weak: true)'
  end
  return nil
end

-- =================================================================================
-- 阶段 1: Normalize (标准化)
-- 功能：纯粹的属性解析。
-- 1. 将中文作者列表处理为 authors_string（元数据处理）。
-- 2. 解析文本中的 `{.noindent}` 和 `{indent}` 标记。
--    由于 Para/Plain 不支持 classes，我们将其包裹在 Div 中：
--    `Para` -> `Div(Para, .noindent)`
--    `Plain` -> `Div(Plain, .noindent)`
-- 3. 解析"冒号结尾问候语"，同样包裹在 Div 中。
-- 4. 处理 {v}, {v:n}, {pagebreak}, {pagebreak:weak} 标记
-- =================================================================================
local normalize = {
  -- 处理元数据（保持原有逻辑）
  Meta = function(meta)
    if meta.author then
      local authors = {}
      if meta.author.t == "MetaList" then
        for i, author in ipairs(meta.author) do
          local author_text = pandoc.utils.stringify(author)
          if author_text ~= "" then table.insert(authors, author_text) end
        end
      elseif meta.author.t == "MetaInlines" or meta.author.t == "MetaString" then
        table.insert(authors, pandoc.utils.stringify(meta.author))
      else
        if type(meta.author) == "table" then
          for i, author in ipairs(meta.author) do
            table.insert(authors, pandoc.utils.stringify(author))
          end
        end
      end
      if #authors > 1 then
        authors_string = table.concat(authors, "、")
      elseif #authors == 1 then
        authors_string = authors[1]
      end
      if authors_string ~= "" then
        meta.author = pandoc.MetaInlines({pandoc.Str(authors_string)})
      end
    end
    
    if meta.signature == nil then
      meta.signature = pandoc.MetaBool(false)
    else
      local s = pandoc.utils.stringify(meta.signature)
      local lowered = string.lower(s or "")
      meta.signature = pandoc.MetaBool(lowered == "true" or lowered == "yes")
    end
    
    if meta.date then
      local date_str = pandoc.utils.stringify(meta.date)
      local y, m, d = string.match((date_str or ""), "%s*(%d%d%d%d)%-(%d%d)%-(%d%d)%s*")
      if y and m and d then
        local dt = string.format("datetime(\n  year: %d,\n  month: %d,\n  day: %d,\n)", tonumber(y), tonumber(m), tonumber(d))
        meta.date = pandoc.MetaInlines({pandoc.RawInline('typst', dt)})
      else
        local esc = date_str:gsub('"', '\\"')
        local quoted = '"' .. esc .. '"'
        meta.date = pandoc.MetaInlines({pandoc.RawInline('typst', quoted)})
      end
    end
    return meta
  end,

  Header = function(h)
    has_seen_header = true -- 只要遇到 Header 就标记
    
    local function parse_markers(content)
      if #content == 0 then return end
      local last = content[#content]
      if last.t == 'Str' then
        if last.text == '{.noindent}' then
          h.classes:insert('noindent')
          content:remove(#content)
          if #content > 0 and content[#content].t == 'Space' then content:remove(#content) end
        elseif last.text:match('{%.noindent}$') then
          h.classes:insert('noindent')
          last.text = last.text:gsub('%s*{%.noindent}$', '')
          if last.text == '' then content:remove(#content) end
        elseif last.text == '{indent}' then
          if h.classes and h.classes:includes('noindent') then
             h.classes = h.classes:filter(function(c) return c ~= 'noindent' end)
          end
          content:remove(#content)
          if #content > 0 and content[#content].t == 'Space' then content:remove(#content) end
        elseif last.text:match('{indent}$') then
          if h.classes and h.classes:includes('noindent') then
             h.classes = h.classes:filter(function(c) return c ~= 'noindent' end)
          end
          last.text = last.text:gsub('%s*{indent}$', '')
          if last.text == '' then content:remove(#content) end
        end
      end
    end
    
    parse_markers(h.content)
    
    -- Filter Level 1 headers (handled by metadata)
    if h.level == 1 then return {} end
    
    return h
  end,
  
  -- 处理 RawInline: 识别 {v}, {v:n}, {pagebreak}, {pagebreak:weak} 标记
  RawInline = function(el)
    if el.format == '' or el.format == 'html' then
      local text = el.text:match('^%s*(.-)%s*$') -- 去除首尾空白
      
      -- 处理 {v} 和 {v:n}
      local v_result = process_v_marker(text)
      if v_result then
        return pandoc.RawInline('typst', v_result)
      end
      
      -- 处理 {pagebreak} 和 {pagebreak:weak}
      local pb_result = process_pagebreak_marker(text)
      if pb_result then
        return pandoc.RawInline('typst', pb_result)
      end
    end
    return el
  end,
  
  -- 处理 RawBlock: 识别 {v}, {v:n}, {pagebreak}, {pagebreak:weak} 标记
  RawBlock = function(el)
    if el.format == '' or el.format == 'html' then
      local text = el.text:match('^%s*(.-)%s*$') -- 去除首尾空白
      
      -- 处理 {v} 和 {v:n}
      local v_result = process_v_marker(text)
      if v_result then
        return pandoc.RawBlock('typst', v_result .. '\n')
      end
      
      -- 处理 {pagebreak} 和 {pagebreak:weak}
      local pb_result = process_pagebreak_marker(text)
      if pb_result then
        return pandoc.RawBlock('typst', pb_result .. '\n')
      end
    end
    return el
  end,
  
  
  -- 处理图片元素
  -- 支持单图和多图（一行多图）两种情况
  Para = function(el)
    local explicit_indent = false
    local explicit_noindent = false
    
    -- 收集段落中所有的图片
    local images = {}
    for _, item in ipairs(el.content) do
      if item.t == 'Image' then
        table.insert(images, item)
      end
    end
    
    -- 如果没有图片，跳过图片处理
    if #images == 0 then
      -- 继续执行原有的段落处理逻辑
    elseif #images == 1 then
      -- 单图处理
      local img = images[1]
      figure_counter = figure_counter + 1
      
      local path = img.src
      local filename = path:match("([^/]+)$") or path
      local caption = filename:gsub("%.[^.]*$", "")
      
      local typst_code = string.format(
        '#figure(\n' ..
        '  context {\n' ..
        '    let img = image("%s")\n' ..
        '    let img-size = measure(img)\n' ..
        '    let x = img-size.width\n' ..
        '    let y = img-size.height\n' ..
        '    let max-size = 13.4cm\n' ..
        '    \n' ..
        '    let new-x = x\n' ..
        '    let new-y = y\n' ..
        '    \n' ..
        '    if x > max-size {\n' ..
        '      let scale = max-size / x\n' ..
        '      new-x = max-size\n' ..
        '      new-y = y * scale\n' ..
        '    }\n' ..
        '    \n' ..
        '    if new-y > max-size {\n' ..
        '      let scale = max-size / new-y\n' ..
        '      new-x = new-x * scale\n' ..
        '      new-y = max-size\n' ..
        '    }\n' ..
        '    \n' ..
        '    image("%s", width: new-x, height: new-y)\n' ..
        '  },\n' ..
        '  caption: [%s],\n' ..
        ') <fig-%%d>\n',
        path, path, caption
      )
      
      typst_code = typst_code:gsub('%%d', tostring(figure_counter))
      return pandoc.RawBlock('typst', typst_code)
      
    else
      -- 多图处理：一行多图
      -- 收集所有图片路径和标题
      local paths = {}
      local is_subfigure_mode = false
      
      -- 第一次遍历：检查是否应该启用子图模式
      -- 如果任何一个图片有 Alt Text (caption)，则启用子图模式
      for _, img in ipairs(images) do
        local alt = pandoc.utils.stringify(img.caption)
        if alt ~= "" then
          is_subfigure_mode = true
          break
        end
      end
      
      -- 如果是子图模式，figure_counter只增加1（为了大图号）
      local main_caption = ""
      if is_subfigure_mode then
        figure_counter = figure_counter + 1
      end
      
      for _, img in ipairs(images) do
        local path = img.src
        local filename = path:match("([^/]+)$") or path
        local caption = filename:gsub("%.[^.]*$", "")
        local alt = pandoc.utils.stringify(img.caption)
        
        -- 如果是独立模式，每张图计数器都要增加
        local current_fig_num = 0
        if not is_subfigure_mode then
          figure_counter = figure_counter + 1
          current_fig_num = figure_counter
        end
        
        table.insert(paths, {path = path, caption = caption, alt = alt, fig_num = current_fig_num})
      end
      
      -- 子图模式的总标题使用第一张图的Alt Text (img.caption)
      if is_subfigure_mode and #paths > 0 then
        -- 注意：paths[1].alt 存储的是 pandoc.utils.stringify(img.caption)
        main_caption = paths[1].alt
      end
      
      -- 生成图片路径数组字符串
      local paths_str = ""
      for i, p in ipairs(paths) do
        if i > 1 then paths_str = paths_str .. ", " end
        paths_str = paths_str .. '"' .. p.path .. '"'
      end
      
      -- 生成子图Alt Text列表
      local alts_str = ""
      for i, p in ipairs(paths) do
        if i > 1 then alts_str = alts_str .. ", " end
        alts_str = alts_str .. '"' .. p.alt .. '"'
      end
      
      -- 生成 Typst 代码来处理多图布局
      local typst_code = [[
#context {
  // 图片路径列表
  let paths = (]] .. paths_str .. [[)
  // 图片标题列表（对应 paths）
  let captions = (]] .. table.concat(
    (function() 
       local quote_captions = {}
       for _, p in ipairs(paths) do table.insert(quote_captions, '"' .. p.caption .. '"') end 
       return quote_captions 
     end)(), 
    ", "
  ) .. [[)
  // Alt Text 列表
  let alts = (]] .. alts_str .. [[)
  
  let is_subfigure = ]] .. tostring(is_subfigure_mode) .. [[ 
  let main_caption = "]] .. main_caption .. [["
  
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

]]
      
      return pandoc.RawBlock('typst', typst_code)
    end
    
    -- 检查整个段落是否只是 {v} 或 {v:n} 或 {pagebreak} 标记
    local para_text = pandoc.utils.stringify(el)
    local trimmed = para_text:match('^%s*(.-)%s*$')
    
    local v_result = process_v_marker(trimmed)
    if v_result then
      return pandoc.RawBlock('typst', v_result .. '\n')
    end
    
    local pb_result = process_pagebreak_marker(trimmed)
    if pb_result then
      return pandoc.RawBlock('typst', pb_result .. '\n')
    end
    
    -- 检查 content 中的缩进标记
    local content = el.content
    if #content > 0 then
      local last = content[#content]
      if last.t == 'Str' then
        if last.text == '{.noindent}' or last.text:match('{%.noindent}$') then
           explicit_noindent = true
           if last.text == '{.noindent}' then
             content:remove(#content)
             if #content > 0 and content[#content].t == 'Space' then content:remove(#content) end
           else
             last.text = last.text:gsub('%s*{%.noindent}$', '')
             if last.text == '' then content:remove(#content) end
           end
        elseif last.text == '{indent}' or last.text:match('{indent}$') then
           explicit_indent = true
           if last.text == '{indent}' then
             content:remove(#content)
             if #content > 0 and content[#content].t == 'Space' then content:remove(#content) end
           else
             last.text = last.text:gsub('%s*{indent}$', '')
             if last.text == '' then content:remove(#content) end
           end
        end
      end
    end
    
    if explicit_noindent then
       -- Wrap in Div with .noindent
       return pandoc.Div({el}, pandoc.Attr("", {"noindent"}))
    end
    
    if explicit_indent then
       -- Explicit indent, return Para as is (no wrapper)
       return el
    end
    
    -- 自动问候语逻辑：
    if not has_seen_header then
       -- 检查冒号结尾
       local function check_colon(content)
          if #content == 0 then return false end
          local last = content[#content]
          if last.t == 'Str' and last.text:match('[:：]$') then return true end
          return false
       end
       
       if check_colon(el.content) then
          return pandoc.Div({el}, pandoc.Attr("", {"noindent"}))
       end
    end
    
    return el
  end,
  
  Plain = function(el) 
    -- 与 Para 相同的逻辑
    local explicit_indent = false
    local explicit_noindent = false
    
    -- 检查整个段落是否只是 {v} 或 {v:n} 或 {pagebreak} 标记
    local para_text = pandoc.utils.stringify(el)
    local trimmed = para_text:match('^%s*(.-)%s*$')
    
    local v_result = process_v_marker(trimmed)
    if v_result then
      return pandoc.RawBlock('typst', v_result .. '\n')
    end
    
    local pb_result = process_pagebreak_marker(trimmed)
    if pb_result then
      return pandoc.RawBlock('typst', pb_result .. '\n')
    end
    
    local content = el.content
    if #content > 0 then
      local last = content[#content]
      if last.t == 'Str' then
        if last.text == '{.noindent}' or last.text:match('{%.noindent}$') then
           explicit_noindent = true
           if last.text == '{.noindent}' then
             content:remove(#content)
             if #content > 0 and content[#content].t == 'Space' then content:remove(#content) end
           else
             last.text = last.text:gsub('%s*{%.noindent}$', '')
             if last.text == '' then content:remove(#content) end
           end
        elseif last.text == '{indent}' or last.text:match('{indent}$') then
           explicit_indent = true
           if last.text == '{indent}' then
             content:remove(#content)
             if #content > 0 and content[#content].t == 'Space' then content:remove(#content) end
           else
             last.text = last.text:gsub('%s*{indent}$', '')
             if last.text == '' then content:remove(#content) end
           end
        end
      end
    end
    
    if explicit_noindent then
      -- Plain 需要包裹在 Div 中
      return pandoc.Div({el}, pandoc.Attr("", {"noindent"}))
    elseif explicit_indent then
      return el
    end
    
    return el
  end,
  
  -- 处理 Str 内联元素中的 {v}, {v:n}, {pagebreak} 标记
  Str = function(el)
    local text = el.text
    
    -- 处理 {v} 和 {v:n}
    local v_result = process_v_marker(text)
    if v_result then
      return pandoc.RawInline('typst', v_result)
    end
    
    -- 处理 {pagebreak} 和 {pagebreak:weak}
    local pb_result = process_pagebreak_marker(text)
    if pb_result then
      return pandoc.RawInline('typst', pb_result)
    end
    
    return el
  end
}

-- =================================================================================
-- 阶段 2: Structure (结构化)
-- 功能：处理列表层级的缩进抵消。
-- =================================================================================
local structure = {
  BulletList = function(el)
    if #el.content > 0 then
      local first_item = el.content[1]
      if #first_item > 0 then
        local first_block = first_item[1]
        
        if first_block.t == 'Header' and first_block.classes and first_block.classes:includes('noindent') then
             return {
             pandoc.RawBlock('typst', '#block[#set par(first-line-indent: 0pt)\n'),
             el,
             pandoc.RawBlock('typst', ']\n')
           }
        end
        
        if first_block.t == 'Div' and first_block.classes and first_block.classes:includes('noindent') then
           return {
             pandoc.RawBlock('typst', '#block[#set par(first-line-indent: 0pt)\n'),
             el,
             pandoc.RawBlock('typst', ']\n')
           }
        end
      end
    end
    return el
  end,
  
  OrderedList = function(el)
    if #el.content > 0 then
      local first_item = el.content[1]
      if #first_item > 0 then
        local first_block = first_item[1]
        
        if first_block.t == 'Header' and first_block.classes and first_block.classes:includes('noindent') then
             return {
             pandoc.RawBlock('typst', '#block[#set par(first-line-indent: 0pt)\n'),
             el,
             pandoc.RawBlock('typst', ']\n')
           }
        end
        
        if first_block.t == 'Div' and first_block.classes and first_block.classes:includes('noindent') then
           return {
             pandoc.RawBlock('typst', '#block[#set par(first-line-indent: 0pt)\n'),
             el,
             pandoc.RawBlock('typst', ']\n')
           }
        end
      end
    end
    return el
  end,
  
  -- 处理 Div 包裹的 List
  Div = function(el)
    if el.classes and el.classes:includes('noindent') then
      local new_content = pandoc.List()
      for i, b in ipairs(el.content) do
        local processed = false
        if b.t == 'BulletList' or b.t == 'OrderedList' then
           new_content:extend({
             pandoc.RawBlock('typst', '#block[#set par(first-line-indent: 0pt)\n'),
             b,
             pandoc.RawBlock('typst', ']\n')
           })
           processed = true
        end
        if not processed then
          new_content:insert(b)
        end
      end
      el.content = new_content
      
      return el
    end
    return el
  end
}

-- =================================================================================
-- 阶段 3: Render (渲染/注入)
-- 功能：将带有 noindent class 的具体 Block 转换为 Typst 的无首行缩进代码。
-- =================================================================================
local render = {
  Header = function(h)
    -- Clear identifier to suppress auto-generated labels
    h.identifier = ""
    
    if h.classes and h.classes:includes('noindent') then
      if FORMAT:match 'typst' then
        return {
          pandoc.RawBlock('typst', '#block[#set par(first-line-indent: 0pt)\n'),
          h,
          pandoc.RawBlock('typst', ']\n\n')
        }
      elseif FORMAT:match 'docx' then
        h.attributes['custom-style'] = 'NoIndent'
        return h
      end
    else
        if FORMAT:match 'typst' then
            return {
                h,
                pandoc.RawBlock('typst', '\n')
            }
        end
    end
    return h
  end,
  
  Div = function(el)
    if el.classes and el.classes:includes('noindent') then
      if FORMAT:match 'typst' then
        return {
          pandoc.RawBlock('typst', '#block[#set par(first-line-indent: 0pt)\n'),
          el,
          pandoc.RawBlock('typst', ']\n')
        }
      elseif FORMAT:match 'docx' then
        el.attributes['custom-style'] = 'NoIndent'
        return el
      end
    end
    return el
  end
}

return {normalize, structure, render}