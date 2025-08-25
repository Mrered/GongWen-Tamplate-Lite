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
