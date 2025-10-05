#!/usr/bin/env texlua

-- Usage: pdfextractseveral.lua infile outfile_prefix page_number page_number ...

pdfw = require('pdfw')

infile = arg[1]
doc = pdfe.open(infile)
outfile_prefix = arg[2]

for i = 3, #arg do
   page_n = arg[i]
   pdf = pdfw.new()
   pdfw.append_page(pdf, doc, page_n)
   pdfw.save(pdf, outfile_prefix .. page_n .. '.pdf')
end
