-- Filtro de pandoc: el código en línea sin espacios (rutas, nombres de archivo, URLs) se compone con
-- \nolinkurl en LaTeX, para que pueda partirse al final de la línea (paquete xurl) en vez de salirse
-- del margen. Se deja como está si tiene caracteres que \nolinkurl no admite.
function Code(el)
  if FORMAT:match("latex") and #el.text > 10 and not el.text:find("[%s{}%%#\\%^~&$]") then
    return pandoc.RawInline("latex", "\\nolinkurl{" .. el.text .. "}")
  end
end
