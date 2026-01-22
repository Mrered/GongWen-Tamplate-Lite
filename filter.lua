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
  -- 由于 Image 是内联元素，我们需要返回一个包含 RawInline 的列表
  -- 但为了更好地处理图片，我们将其转换为块级元素
  Para = function(el)
    local explicit_indent = false
    local explicit_noindent = false
    
    -- 检查段落是否只包含一个图片
    if #el.content == 1 and el.content[1].t == 'Image' then
      local img = el.content[1]
      
      -- 递增计数器
      figure_counter = figure_counter + 1
      
      -- 提取文件名（不含路径和扩展名）
      local path = img.src
      local filename = path:match("([^/]+)$") or path  -- 提取文件名
      local caption = filename:gsub("%.[^.]*$", "")     -- 去除扩展名
      
      -- 生成 Typst figure 代码
      -- 在 Typst 中测量图片尺寸并应用等比例缩放算法
      -- caption 不包含编号，由 Typst 自动添加
      local typst_code = string.format(
        '#figure(\n' ..
        '  context {\n' ..
        '    let img = image("%s")\n' ..
        '    let img-size = measure(img)\n' ..
        '    let x = img-size.width\n' ..
        '    let y = img-size.height\n' ..
        '    let max-size = 13.4cm\n' ..
        '    \n' ..
        '    // 应用缩放算法：计算缩放比例，保持图片比例\n' ..
        '    let new-x = x\n' ..
        '    let new-y = y\n' ..
        '    \n' ..
        '    // 如果宽度超过限制，按宽度缩放\n' ..
        '    if x > max-size {\n' ..
        '      let scale = max-size / x\n' ..
        '      new-x = max-size\n' ..
        '      new-y = y * scale\n' ..
        '    }\n' ..
        '    \n' ..
        '    // 如果高度仍然超过限制，再按高度缩放\n' ..
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
        path,
        path,
        caption
      )
      
      -- 替换 %%d 为实际的 figure_counter
      typst_code = typst_code:gsub('%%d', tostring(figure_counter))
      
      -- 返回 RawBlock 以插入 Typst 代码
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