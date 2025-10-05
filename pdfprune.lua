#!/usr/bin/env texlua

-- Usage: pdfextract.lua infile page_number outfile

local pdfw = require('pdfw')
ref = pdfw.reference

infile = arg[1]

arg[1] = nil
pages = {}
for i, page_n in ipairs(arg) do
   pages[page_n] = true
end

doc = pdfe.open(infile)
pdf = pdfw.new(doc)

trailer = pdf.trailer

Catalog = trailer.Root()
trailer.Root = ref(Catalog)

Pages = Catalog.Pages()
Catalog.Pages = ref(Pages)

table.remove(Pages.Kids, 1)
Pages.Count = Pages.Count - 1

pdfw.update(pdf, infile)
