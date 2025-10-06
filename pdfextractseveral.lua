#!/usr/bin/env texlua

-- Usage: pdfextractseveral.lua [-p] infile outfile_prefix page_number [page_number ...]

pdfw = require('pdfw')

if arg[1] == '-p' then
   prune = true
   table.remove(arg,1)
end

infile = arg[1]
outfile_prefix = arg[2]

table.remove(arg,1)
table.remove(arg,1)
--arg now contains only the page numbers

doc = pdfe.open(infile)

for i, page_n in ipairs(arg) do
   pdf = pdfw.new()
   pdfw.append_page(pdf, doc, page_n)
   pdfw.save(pdf, outfile_prefix .. page_n .. '.pdf')
end

if prune then
   pdf = pdfw.new(doc)

   pages = pdfw.get_pages(pdf)
   for i, page_n in ipairs(arg) do
      pdfw.remove_page(pdf, pages[tonumber(page_n)])
   end

   pdfw.update(pdf, infile, doc)
end
