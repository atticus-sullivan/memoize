#!/usr/bin/env texlua

-- Usage: pdfprune.lua infile page_number [page_number ...]

local pdfw = require('pdfw')
ref = pdfw.reference

infile = arg[1]
table.remove(arg,1) --arg now contains only the page numbers

doc = pdfe.open(infile)
pdf = pdfw.new(doc)

pages = pdfw.get_pages(pdf)
for i, page_n in ipairs(arg) do
   pdfw.remove_page(pdf, pages[tonumber(page_n)])
end

pdfw.update(pdf, infile, doc)
