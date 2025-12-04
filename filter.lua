-- 全局变量存储作者字符串
local authors_string = ""

-- 处理元数据（YAML front matter）
function Meta(meta)
  -- 调试：输出所有元数据键
  -- io.stderr:write("Available meta keys: ")
  for k, v in pairs(meta) do
    -- io.stderr:write(k .. " ")
  end
  -- io.stderr:write("\n")
  
  if meta.author then
    local authors = {}
    -- io.stderr:write("Author type: " .. tostring(meta.author.t) .. "\n")
    
    -- 处理作者列表
    if meta.author.t == "MetaList" then
      -- 对于 MetaList，遍历其内容
      for i, author in ipairs(meta.author) do
        local author_text = ""
        if author.t == "MetaInlines" then
          author_text = pandoc.utils.stringify(author)
        elseif author.t == "MetaString" then
          author_text = author.c or tostring(author)
        elseif type(author) == "string" then
          author_text = author
        else
          -- 尝试直接转换为字符串
          author_text = pandoc.utils.stringify(author)
        end
        if author_text ~= "" then
          table.insert(authors, author_text)
        end
        io.stderr:write("Author " .. i .. ": " .. author_text .. "\n")
      end
    elseif meta.author.t == "MetaInlines" then
      -- 单个作者的 MetaInlines
      local author_text = pandoc.utils.stringify(meta.author)
      table.insert(authors, author_text)
      -- io.stderr:write("Single author (MetaInlines): " .. author_text .. "\n")
    elseif meta.author.t == "MetaString" then
      -- 单个作者的 MetaString
      local author_text = meta.author.c or tostring(meta.author)
      table.insert(authors, author_text)
      -- io.stderr:write("Single author (MetaString): " .. author_text .. "\n")
    else
      -- 尝试作为普通表处理（旧版本兼容性）
      if type(meta.author) == "table" then
        for i, author in ipairs(meta.author) do
          local author_text = pandoc.utils.stringify(author)
          table.insert(authors, author_text)
          -- io.stderr:write("Author (table) " .. i .. ": " .. author_text .. "\n")
        end
      end
    end
    
    -- 用顿号连接作者
    if #authors > 1 then
      authors_string = table.concat(authors, "、")
    elseif #authors == 1 then
      authors_string = authors[1]
    end
    
    -- io.stderr:write("Final authors string: " .. authors_string .. "\n")
    
    -- 将连接后的作者字符串设置回元数据
    if authors_string ~= "" then
      -- 创建 MetaInlines 对象包含连接后的作者字符串
      meta.author = pandoc.MetaInlines({pandoc.Str(authors_string)})
      -- io.stderr:write("Set meta.author to: " .. authors_string .. "\n")
    end
  else
    -- io.stderr:write("No author field found in metadata\n")
  end
  
    -- 处理 signature 字段：支持 MetaBool、MetaString、MetaInlines 等类型
    if meta.signature == nil then
      -- 默认值为 false
      meta.signature = pandoc.MetaBool(false)
    else
      -- 将可能的字符串或 inlines 转换为布尔值
      local sig_val = nil
      if type(meta.signature) == "table" and meta.signature.t == "MetaBool" then
        sig_val = meta.signature.c
      else
        -- 尝试把任意类型 stringify 后判断是否为 "true"/"yes"
        local s = pandoc.utils.stringify(meta.signature)
        local lowered = string.lower(s or "")
        if lowered == "true" or lowered == "yes" then
          sig_val = true
        else
          sig_val = false
        end
      end
      meta.signature = pandoc.MetaBool( (sig_val == true) )
    end

    -- 将 date 字段（如 "2025-11-19"）转换为 typst 的 datetime(...) 形式
    if meta.date then
      local date_str = pandoc.utils.stringify(meta.date)
      -- 匹配 YYYY-MM-DD（支持前后有空白）
      local y, m, d = string.match((date_str or ""), "%s*(%d%d%d%d)%-(%d%d)%-(%d%d)%s*")
      if y and m and d then
        local dt = string.format("datetime(\n  year: %d,\n  month: %d,\n  day: %d,\n)", tonumber(y), tonumber(m), tonumber(d))
        -- 以 RawInline('typst', ...) 形式传递，这样在模板中直接插入为 typst 代码
        meta.date = pandoc.MetaInlines({pandoc.RawInline('typst', dt)})
      else
        -- 如果无法解析为 YYYY-MM-DD，传递为 typst 字符串字面量（带引号）
        local esc = date_str:gsub('"', '\\"')
        local quoted = '"' .. esc .. '"'
        meta.date = pandoc.MetaInlines({pandoc.RawInline('typst', quoted)})
      end
    end

  return meta
end

-- 原有的 Header 处理函数
function Header(h)
  if h.level == 1 then
    return {}
  end
  h.identifier = ""
  return {h, pandoc.Para({})}
end
