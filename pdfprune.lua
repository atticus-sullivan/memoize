#!/usr/bin/env texlua

-- Usage: pdfextract.lua infile page_number outfile

local pdfw = require('pdfw')
ref = pdfw.reference

infile = arg[1]

doc = pdfe.open(infile)
pdf = pdfw.new(doc)

trailer = pdf.trailer

Catalog = trailer.Root()
trailer.Root = ref(Catalog)

Pages = Catalog.Pages()
Catalog.Pages = ref(Pages)

table.remove(arg,1)
table.sort(arg, function(a,b) return a > b end)
for i, page_n in ipairs(arg) do
   table.remove(Pages.Kids, page_n)
end
Pages.Count = Pages.Count - #arg

pdfw.update(pdf, infile)
