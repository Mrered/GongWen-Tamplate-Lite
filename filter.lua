-- 全局变量存储作者字符串
local authors_string = ""

-- 辅助函数：检查并清理内容中的 {.noindent} 标记
local function check_and_clean_noindent(content)
  if #content == 0 then return false end
  local last = content[#content]
  local is_noindent = false
  
  if last.t == 'Str' then
     if last.text == '{.noindent}' then
        -- 情况1：作为独立的 Str 存在（通常前面有空格）
        is_noindent = true
        content:remove(#content)
        -- 移除前面的空格
        if #content > 0 and content[#content].t == 'Space' then
           content:remove(#content)
        end
     elseif last.text:match('{%.noindent}$') then
        -- 情况2：作为后缀附在字符串末尾 (例如 text{.noindent})
        is_noindent = true
        -- 移除匹配的部分（包括可能的内部空白）
        last.text = last.text:gsub('%s*{%.noindent}$', '')
        -- 如果移除后变成空字符串，则删除该元素
        if last.text == '' then
           content:remove(#content)
        end
     end
  end
  return is_noindent
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
  local is_noindent = false

  -- 1. 检查 Pandoc 解析出的 classes
  if h.classes:includes('noindent') then
    is_noindent = true
    h.classes = h.classes:filter(function(c) return c ~= 'noindent' end)
  end

  -- 2. 检查内容末尾的文本标记（如果未被解析为属性）
  if not is_noindent then
    is_noindent = check_and_clean_noindent(h.content)
  end

  if h.level == 1 then
    return {}
  end
  h.identifier = ""
  
  if is_noindent then
    if FORMAT:match 'typst' then
       -- 对于 Typst，将 Header 包裹在设置了缩进为 0 的 block 中
       -- 这样 Header 内部的样式由模板处理，但外部容器限制了缩进
       return {
         pandoc.RawBlock('typst', '#block[#set par(first-line-indent: 0pt)'),
         h,
         pandoc.RawBlock('typst', ']'),
         pandoc.Para({})
       }
    elseif FORMAT:match 'docx' then
       h.attributes['custom-style'] = 'NoIndent'
    end
  end

  return {h, pandoc.Para({})}
end

-- Para 处理函数
function Para(el)
  local is_noindent = false
  
  -- 1. 检查 classes
  if el.classes and el.classes:includes('noindent') then -- Para 通常没有 classes，除非 Div 包裹？
      -- 修正：Para 对象在 AST 中通常不支持属性。但如果是 Div 包裹的 Para...
      -- 这里为了鲁棒性还是保留，但主要依赖 content 检查
  end
  
  -- 2. 检查内容
  is_noindent = check_and_clean_noindent(el.content)
  
  if is_noindent then
    if FORMAT:match 'typst' then
      return {
        pandoc.RawBlock('typst', '#block[#set par(first-line-indent: 0pt)'),
        pandoc.Para(el.content),
        pandoc.RawBlock('typst', ']')
      }
    elseif FORMAT:match 'docx' then
      -- Para 无法直接设置 custom-style，转为 Div
      local div = pandoc.Div(el.content)
      div.attributes['custom-style'] = 'NoIndent'
      return div
    end
  end
  return el
end

-- Div 处理函数
function Div(el)
  if el.classes:includes('noindent') then
    el.classes = el.classes:filter(function(c) return c ~= 'noindent' end)
    
    if FORMAT:match 'typst' then
      return {
        pandoc.RawBlock('typst', '#block[#set par(first-line-indent: 0pt)'),
        el,
        pandoc.RawBlock('typst', ']')
      }
    elseif FORMAT:match 'docx' then
      el.attributes['custom-style'] = 'NoIndent'
      return el
    end
  end
  return el
end
