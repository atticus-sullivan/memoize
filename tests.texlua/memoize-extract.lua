#!/usr/bin/env texlua

-- This file is a part of Memoize, a TeX package for externalization of
-- graphics and memoization of compilation results in general, available at
-- https://ctan.org/pkg/memoize and https://github.com/sasozivanovic/memoize.
--
-- Copyright (c) 2025- TODO(all)
--
-- This work may be distributed and/or modified under the conditions of the
-- LaTeX Project Public License, either version 1.3c of this license or (at
-- your option) any later version.  The latest version of this license is in
-- https://www.latex-project.org/lppl.txt and version 1.3c or later is part of
-- all distributions of LaTeX version 2008 or later.
--
-- This work has the LPPL maintenance status `maintained'.
-- The Current Maintainer of this work is . TODO(all)
-- 
-- The files belonging to this work and covered by LPPL are listed in
-- <texmf>/doc/generic/memoize/FILES.

-- local VERSION = '2025/01/17 v1.4.1' -- TODO(all)

-- libraries already available due to the use of texlua
-- lfs:
--  lua-filesystem: used for checking/creating/deleting files/directories
--  see https://lunarmodules.github.io/luafilesystem/manual.html#reference
--  and https://texdoc.org/serve/LuaTeX/0
--
-- pdfe:
--  interface to pdf files: used to get information about a pdf file
--  see https://texdoc.org/serve/LuaTeX/0


--TODO(atticus) various error() calls now -- make functions adhere to proper error handling

local kpathsea

-- restricted function defined here
local extract_pages
do
	-- safe the functions/libraries needed in this restricted area
	local lfs = lfs
	if not lfs then error("lfs is not available. This script needs to be executed with texlua") end
	local os_spawn = os.spawn

	---@param src_pdf string
	---@param out_dir string
	---@param pages [integer]
	---@return integer|nil, string
	extract_pages = function(src_pdf, out_dir, pages)
		if kpathsea:out_name_ok(out_dir) then
			if not lfs.isdir(out_dir) then
				assert(lfs.mkdir(out_dir))
			end
		else
			error("Writing to " .. out_dir .. " not permitted.")
		end

		if not kpathsea:in_name_ok(src_pdf) then
			error("Opening " .. src_pdf .. " not permitted.")
		end

		--TODO(atticus) not portable for windows due to the path-sep
		local out_pat = ("%s/%%d.pdf"):format(out_dir)
		if not kpathsea:out_name_ok(out_pat:format(0)) then
			error("Writing to " .. out_pat:format(0) .. " (and following) not permitted.")
		end

		-- Be aware that using the %d syntax for -sOutputFile=... does not reflect the
		-- page number in the original document. If you chose (for example) to process
		-- even pages by using -sPageList=even, then the output of -sOutputFile=out%d.png
		-- would still be out1.png, out2.png, out3.png etc.
		local succ, err = os_spawn(
			([[rungs -dSAFER -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -sPageList="%s" -sOutputFile="%s" "%s"]]):format(
				table.concat(pages, ","),
				out_pat,
				src_pdf
			)
		)
		return succ, err
	end
end

-- restricted function defined here
local check_dimensions
do
	-- safe the functions/libraries needed in this restricted area
	local pdfe = pdfe
	if not pdfe then error("pdfe library is not available. This script needs to be executed with texlua.") end

	---@param src_pdf string
	---@param page_dimensions table
	---@return table, table
	check_dimensions = function(src_pdf, page_dimensions)
		local pdf
		if kpathsea:in_name_ok(src_pdf) then
			pdf = pdfe.open(src_pdf)
		else
			error("Opening " .. src_pdf .. " not permitted.")
		end

		-- collect which pages succeded the dimension check
		local succ = {}
		-- collect which pages failed the dimension check
		local failed = {}
		for _, i in ipairs(page_dimensions) do
			local p = i.page
			local page = pdfe.getpage(pdf, p)
			if not page then
				print("warning page does not exist -> skipped")
			else
				local mediabox = pdfe.getbox(page, "MediaBox")
				-- TODO check this is the right interpretation of the mediabox
				print(("%sx%s +%s+%s"):format(mediabox[3], mediabox[4], mediabox[1], mediabox[2]))
				-- TODO check if this is the right size
				table.insert(succ, p)
			end
		end

		pdfe.close(pdf)

		table.sort(succ)
		table.sort(failed)
		return succ, failed
	end
end

-- restrict the complete rest of the script by undefining security relevant libraries
os.execute = nil
os.spawn   = nil
os.exec    = nil
socket     = nil
lfs        = nil
pdfe       = nil
-- TODO(atticus) am I missing something for further restricting?

----------------------------------
-- restricted area startes here --
----------------------------------

-- setup kpathsea
kpathsea = kpse.new("kpsewhich")

-- collect data from file
local pages = {}
for p,w,h in ("extract 1 20x10 extract 2 10x30 extract 4 100x3000"):gmatch("(%d+)%s(%d+)x(%d+)") do
	local p, w, h = assert(tonumber(p)), assert(tonumber(w)), assert(tonumber(h))
	table.insert(pages, {page=p, width=w, height=h})
end

-- check the dimensions
local succ, _ = check_dimensions("testing-source.pdf", pages)
assert(#succ == #pages, "not all pages match the provided dimensions")
local req_pages = succ

-- extract the requested pages
-- Note: "mmz/0.pdf" corresponds not to the first page, but to the first page requested in req_pages
assert(extract_pages("testing-source.pdf", "mmz", req_pages))
