-- 全局变量存储作者字符串
local authors_string = ""
-- 全局变量：是否已经遇到了标题
local has_seen_header = false

-- 辅助函数：应用不缩进样式
local function apply_noindent(el_or_content)
  -- 能够处理 Para/Div 元素 或者 content list
  local content = el_or_content
  if el_or_content.content then
    content = el_or_content.content
  end
  
  -- 如果是 Div，需要保留其 attributes 吗？通常 Para 转 Div 丢失原 attr 没关系，因为 Para 本身没什么 attr
  -- 但如果是 Div 转 Div，最好保留
  
  if FORMAT:match 'typst' then
      local blocks = {
        pandoc.RawBlock('typst', '#block[#set par(first-line-indent: 0pt)'),
      }
      if el_or_content.t == 'Div' then
        table.insert(blocks, el_or_content)
      elseif el_or_content.t == 'Para' then
        table.insert(blocks, pandoc.Para(el_or_content.content))
      else
        -- 纯 content list
        table.insert(blocks, pandoc.Para(content))
      end
      table.insert(blocks, pandoc.RawBlock('typst', ']'))
      return blocks -- 返回 block list
  elseif FORMAT:match 'docx' then
      local div
      if el_or_content.t == 'Div' then
        div = el_or_content
      else
        div = pandoc.Div(content)
      end
      div.attributes['custom-style'] = 'NoIndent'
      return div
  end
  return el_or_content
end

-- 辅助函数：检查并清理 content 中的 {.noindent} 标记
local function check_and_clean_noindent(content)
  if #content == 0 then return false end
  local last = content[#content]
  local is_noindent = false
  
  if last.t == 'Str' then
     if last.text == '{.noindent}' then
        is_noindent = true
        content:remove(#content)
        if #content > 0 and content[#content].t == 'Space' then
           content:remove(#content)
        end
     elseif last.text:match('{%.noindent}$') then
        is_noindent = true
        last.text = last.text:gsub('%s*{%.noindent}$', '')
        if last.text == '' then
           content:remove(#content)
        end
     end
  end
  return is_noindent
end

-- 辅助函数：检查并清理 content 中的 {indent} 标记
local function check_and_clean_indent_marker(content)
  if #content == 0 then return false end
  local last = content[#content]
  local is_indent = false
  
  if last.t == 'Str' then
     if last.text == '{indent}' then
        is_indent = true
        content:remove(#content)
        if #content > 0 and content[#content].t == 'Space' then
           content:remove(#content)
        end
     elseif last.text:match('{indent}$') then
        is_indent = true
        last.text = last.text:gsub('%s*{indent}$', '')
        if last.text == '' then
           content:remove(#content)
        end
     end
  end
  return is_indent
end

-- 辅助函数：检查 content 是否以冒号结尾 (全角或半角)
-- 不修改 content
local function check_ends_with_colon(content)
  if #content == 0 then return false end
  local last = content[#content]
  if last.t == 'Str' then
    -- 检查是否以 : 或 ： 结尾
    if last.text:match('[:：]$') then
      return true
    end
  end
  return false
end

-- 处理元数据（YAML front matter）
function Meta(meta)
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
end

-- Header 处理函数
function Header(h)
  -- 只要遇到 Header，就标记已见过 Header
  has_seen_header = true

  local is_noindent = false

  -- 1. 检查 Pandoc 解析出的 classes
  if h.classes:includes('noindent') then
    is_noindent = true
    h.classes = h.classes:filter(function(c) return c ~= 'noindent' end)
  end

  -- 2. 检查内容末尾的文本标记
  if not is_noindent then
    is_noindent = check_and_clean_noindent(h.content)
  end

  -- 清理可能存在的 {indent} 标记（虽然 Header 默认就不缩进或者有自己样式，但为了不显示出来）
  check_and_clean_indent_marker(h.content)

  if h.level == 1 then
    return {}
  end
  h.identifier = ""
  
  if is_noindent then
    -- 重用 apply_noindent 逻辑 ? Header 比较特殊，apply_noindent 可能会把它转为 Div
    -- 文档中 Header 返回 {Block} list 比较安全
    if FORMAT:match 'typst' then
       return {
         pandoc.RawBlock('typst', '#block[#set par(first-line-indent: 0pt)'),
         h,
         pandoc.RawBlock('typst', ']'),
         pandoc.Para({}) -- 添加空段落防止粘连？原逻辑是有的
       }
    elseif FORMAT:match 'docx' then
       h.attributes['custom-style'] = 'NoIndent'
    end
  end

  return {h, pandoc.Para({})}
end

-- Para 处理函数
function Para(el)
  local force_noindent = false
  
  -- 1. 检查 {.noindent}
  -- 检查 classes
  if el.classes and el.classes:includes('noindent') then
      force_noindent = true
      el.classes = el.classes:filter(function(c) return c ~= 'noindent' end)
  end
  -- 检查内容
  if not force_noindent then
    force_noindent = check_and_clean_noindent(el.content)
  end
  
  if force_noindent then
    return apply_noindent(el)
  end

  -- 2. 检查 {indent} (强制缩进)
  local force_indent = check_and_clean_indent_marker(el.content)
  if force_indent then
    -- 显式要求缩进，则不做处理，保留默认（即缩进）
    return el
  end

  -- 3. 检查是否为问候语 (未见标题且以冒号结尾)
  if not has_seen_header then
    if check_ends_with_colon(el.content) then
      return apply_noindent(el)
    end
  end

  return el
end

-- Div 处理函数
function Div(el)
  -- Div 不受问候语逻辑影响，只看 classes
  if el.classes:includes('noindent') then
    el.classes = el.classes:filter(function(c) return c ~= 'noindent' end)
    return apply_noindent(el)
  end
  return el
end
