#!/usr/bin/env texlua

-- Usage: pdfextract.lua infile page_number outfile

local pdf = require('luapdfrw')

infile, page_n, outfile = table.unpack(arg)

indoc = pdfe.open(infile)
outdoc = pdf.new()

outdoc:append_page(indoc, page_n)
outdoc:save(outfile)
