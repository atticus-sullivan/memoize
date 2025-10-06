#!/usr/bin/env texlua

-- Usage: pdfextract.lua infile1 page_number infile2 page_number outfile

pdf = require('luapdfrw')

infile1, page1, infile2, page2, outfile = table.unpack(arg)

indoc1 = pdf.open(infile1)
indoc2 = pdf.open(infile2)

outdoc = pdf.new()
outdoc:append_page(indoc1, page1)
outdoc:append_page(indoc2, page2)
outdoc:save(outfile)
