function Header(h)
  if h.level == 1 then
    return {}
  end
  h.identifier = ""
  return {h, pandoc.Para({})}
end