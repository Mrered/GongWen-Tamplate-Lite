-- 全局变量存储作者字符串
local authors_string = ""
-- 全局变量：是否已经遇到了标题
local has_seen_header = false

-- =================================================================================
-- 阶段 1: Normalize (标准化)
-- 功能：纯粹的属性解析。
-- 1. 将中文作者列表处理为 authors_string（元数据处理）。
-- 2. 解析文本中的 `{.noindent}` 和 `{indent}` 标记。
--    由于 Para/Plain 不支持 classes，我们将其包裹在 Div 中：
--    `Para` -> `Div(Para, .noindent)`
--    `Plain` -> `Div(Plain, .noindent)`
--    (注意：Typst 渲染时，这个 Div 会变成 #block，所以即使 Plain 也可以)
-- 3. 解析“冒号结尾问候语”，同样包裹在 Div 中。
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
  
  -- 通用 block 处理逻辑 (Para, Plain)
  Para = function(el)
    local explicit_indent = false
    local explicit_noindent = false
    
    -- 1. 检查 classes (Para 本身通常没有 classes，但如果 pandoc 以后支持呢？)
    -- 注意：Pandoc Lua Para 不支持 classes 属性，所以可以跳过检查 el.classes (即使有也拿不到)
    -- 但是为了逻辑完整性，如果 el 是通过 Div 降级来的？不管了，主要靠标记
    
    -- 2. 检查 content
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
    -- 几乎与 Para 相同，只是如果需要 noindent，也返回 Div(Plain)
    local explicit_indent = false
    local explicit_noindent = false
    
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
      -- 也可以转为 Para，或者保持 Plain
      return el
    end
    
    return el
  end
}

-- =================================================================================
-- 阶段 2: Structure (结构化)
-- 功能：处理列表层级的缩进抵消。
-- 逻辑：如果列表项或包含列表的容器被标记为 noindent，则对整个列表块应用 pad(left: -2em)。
-- =================================================================================
local structure = {
  BulletList = function(el)
    -- 检查第一项的第一个 Block 是否有 noindent class
    -- 现在 Normalize 阶段会把 noindent 的 Block 包裹在 Div 中
    if #el.content > 0 then
      local first_item = el.content[1]
      -- first_item 是 List of Blocks
      if #first_item > 0 then
        local first_block = first_item[1]
        
        -- 情况 1: Header (Header 有 classes)
        if first_block.t == 'Header' and first_block.classes and first_block.classes:includes('noindent') then
             return {
             pandoc.RawBlock('typst', '#pad(left: -2em)[\n'),
             el,
             pandoc.RawBlock('typst', ']\n')
           }
        end
        
        -- 情况 2: Div (Para/Plain 被包裹在 Div 中)
        if first_block.t == 'Div' and first_block.classes and first_block.classes:includes('noindent') then
           return {
             pandoc.RawBlock('typst', '#pad(left: -2em)[\n'),
             el,
             pandoc.RawBlock('typst', ']\n')
           }
        end
      end
    end
    return el
  end,
  
  OrderedList = function(el)
    -- 同 BulletList
    if #el.content > 0 then
      local first_item = el.content[1]
      if #first_item > 0 then
        local first_block = first_item[1]
        
        if first_block.t == 'Header' and first_block.classes and first_block.classes:includes('noindent') then
             return {
             pandoc.RawBlock('typst', '#pad(left: -2em)[\n'),
             el,
             pandoc.RawBlock('typst', ']\n')
           }
        end
        
        if first_block.t == 'Div' and first_block.classes and first_block.classes:includes('noindent') then
           return {
             pandoc.RawBlock('typst', '#pad(left: -2em)[\n'),
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
      -- Manual iteration over content blocks
      local new_content = pandoc.List()
      for i, b in ipairs(el.content) do
        local processed = false
        if b.t == 'BulletList' or b.t == 'OrderedList' then
           -- Wrap list in pad
           new_content:extend({
             pandoc.RawBlock('typst', '#pad(left: -2em)[\n'),
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
    -- Clear identifier to suppress auto-generated labels (moved from normalize)
    h.identifier = ""
    
    if h.classes and h.classes:includes('noindent') then
      if FORMAT:match 'typst' then
        return {
          pandoc.RawBlock('typst', '#block[#set par(first-line-indent: 0pt)\n'),
          h,
          pandoc.RawBlock('typst', ']\n\n') -- Add extra newline
        }
      elseif FORMAT:match 'docx' then
        h.attributes['custom-style'] = 'NoIndent'
        return h
      end
    else
        -- Standard header: append valid newline for Typst
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
        -- 这里的 Div 可能是我们自己包裹的 (Para/Plain)，也可能是 markdown 写的 Div
        -- 无论哪种，都直接渲染为 #block[...] 包裹内容
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
