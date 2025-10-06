#!/usr/bin/env texlua

-- Usage: pdfextract.lua infile1 page_number infile2 page_number outfile

pdfw = require('pdfw')

infile1 = arg[1]
page1 = arg[2]
infile2 = arg[3]
page2 = arg[4]
outfile = arg[5]

indoc1 = pdfe.open(infile1)
indoc2 = pdfe.open(infile2)

outdoc = pdfw.new()
pdfw.append_page(outdoc, indoc1, page1)
pdfw.append_page(outdoc, indoc2, page2)
pdfw.save(outdoc, outfile)
