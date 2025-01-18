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

local VERSION = '2025/01/17 v1.4.1' -- TODO(release)

-- libraries already available due to the use of texlua
-- lfs:
--  lua-filesystem: used for checking/creating/deleting files/directories
--  see https://lunarmodules.github.io/luafilesystem/manual.html#reference
--  and https://texdoc.org/serve/LuaTeX/0
--
-- pdfe:
--  interface to pdf files: used to get information about a pdf file
--  see https://texdoc.org/serve/LuaTeX/0


--TODO various error()/assert() calls now -- make functions adhere to proper error handling

---@param bp number
---@return number
local function bp2pt(bp)
	return bp / 72 * 72.27
end

local kpathsea

-- restricted function defined here
local mkdir
do
	-- safe the functions/libraries needed in this restricted area
	local lfs = lfs
	if not lfs then error("lfs is not available. This script needs to be executed with texlua") end

	---@param name string
	mkdir = function(name)
		if kpathsea:out_name_ok(name) then
			assert(lfs.mkdir(name))
		end
	end
end

-- restricted function defined here
local io_open_w
do
	-- safe the functions/libraries needed in this restricted area
	local io_open = io.open

	---@param name string
	io_open_w = function(name)
		if kpathsea:in_name_ok(name) then
			return io.open(name, "w")
		end
	end
end

-- restricted function defined here
local mv
do
	-- safe the functions/libraries needed in this restricted area
	local os_rename = os.rename

	---@param src string
	---@param dst string
	mv = function(src, dst)
		if not kpathsea:in_name_ok(src) then
			error("Moving from " .. src .. " not permitted.")
		elseif not kpathsea:out_name_ok(dst) then
			error("Moving to " .. dst .. " not permitted.")
		else
			return os_rename(src, dst)
		end
	end
end

-- restricted function defined here
local io_lines
do
	-- safe the functions/libraries needed in this restricted area
	local _io_lines = io.lines

	---@param name string
	io_lines = function(name)
		if kpathsea:in_name_ok(name) then
			return _io_lines(name)
		end
	end
end

-- restricted function defined here
local extract_pages
do
	-- safe the functions/libraries needed in this restricted area
	local lfs = lfs
	if not lfs then error("lfs is not available. This script needs to be executed with texlua") end
	local os_spawn = os.spawn
	local os_rm    = os.remove

	---@param src_pdf string
	---@param out_dir string
	---@param pages [integer]
	---@return integer|nil
	---@return string
	---@return function
	---@return string
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

		--TODO not portable for windows due to the path-sep
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

		-- removes generated files (in case they still exist)
		local cleanup = function()
			for i in ipairs(pages) do
				local fn = out_pat:format(i)
				if lfs.isfile(fn) then
					os_rm(fn)
				end
			end
		end

		return succ, err, cleanup, out_pat
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
	---@param tolerance number
	---@param force boolean
	---@return table, table
	check_dimensions = function(src_pdf, page_dimensions, tolerance, force)
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
				print("warning: page does not exist -> skip that page")
			else
				local mediabox = pdfe.getbox(page, "MediaBox")
				local w = bp2pt(mediabox[3] - mediabox[1])
				local h = bp2pt(mediabox[4] - mediabox[2])
				if math.abs(w - i.w) > tolerance or math.abs(h - i.h) and not force then
					print("Sizes do not match -> skip that page")
				else
					table.insert(succ, p)
				end
			end
		end

		pdfe.close(pdf)

		table.sort(succ)
		table.sort(failed)
		return succ, failed
	end
end

-- restrict the complete rest of the script by undefining security relevant libraries
io     = {}
fio    = {}
os     = {}
lfs    = {}
pdfe   = {}
socket = {}
sio    = {}
texio  = {}
tex    = {}
ffi    = {}
-- TODO is this missing something for further restricting?

----------------------------------
-- restricted area startes here --
----------------------------------

-- setup kpathsea
kpathsea = kpse.new("kpsewhich")

-- TODO functions for logging
local log = nil -- file to which should be logged (later)

local function parse_extern_path(path)
	-- Pattern for the directory prefix and name prefix
	local dir_prefix, name_prefix, remaining = path:match("^(.-)([^/]*)(.+)$")

	if not remaining then
		-- If the pattern didn't match, return nil
		return nil
	end

	-- Pattern for extracting MD5 hashes and suffix
	local code_md5sum, context_md5sum, suffix = remaining:match("^([0-9A-F]{32})%-([0-9A-F]{32})(%-[0-9]+)?.pdf$")

	if not code_md5sum or not context_md5sum then
		-- If the MD5 hash pattern didn't match, return nil
		return nil
	end

	-- Return the extracted components
	return dir_prefix, name_prefix, code_md5sum, context_md5sum, suffix
end

local function parse_args(as, defaults)
	local formats = {latex=true, plain=true, context=true}
	local args = defaults

	local i = 1
	while i <= #as-1 do
		local a = as[i]:match("^%-([a-zA-Z])$")
		if not a then
			a = as[i]:match("^%-%-([a-zA-Z]+)$")
		end

		if a == "h" then
			print("help") -- TODO write the help output
			os.exit(0)
		elseif a == "V" or a == "version" then
			print(("memoize-extract.py of Memoize %s"):format(VERSION))
			os.exit(0)

		elseif a == "P" or a == "pdf" then
			args.pdf = as[i+1]
			i = i+2

		elseif a == "p" or a == "prune" then
			args.prune = true

		elseif a == "k" or a == "keep" then
			args.keep = true

		elseif a == "f" or a == "format" then
			args.format = as[i+1]
			if not formats[args.format] then
				error("")
			end
			i = i+2

		elseif a == "f" or a == "force" then
			args.force = true

		elseif a == "q" or a == "quiet" then
			args.quiet = true

		elseif a == "m" or a == "mkdir" then
			args.mkdir = true

		else
			error("invalid token passed '"..as[i].."'")
		end
		i = i+1
	end
	args.mmz = as[#as-0]

	return args
end

local defaults = {
	pdf = nil,
	prune = false,
	keep = false,
	format = nil,
	force = false,
	quiet = false,
	mkdir = false,
	-- version,
	mmz = nil,
}

local args = parse_args(arg, defaults)

if not args.mmz then
	error("mmz needs to be provided")
end

-- --mkdir -> just create a directory named |mmz|
if args.mkdir then
	mkdir(args.mmz)
	os.exit(0)
end

-- Normalize the |mmz| argument into a |.mmz| filename
-- TODO how can we do this quickly in lua
assert(args.mmz:match("^.*%.mmz$"), "malformed mmz parameter provided")

-- infer the path to the pdf file
assert(args.pdf:match("^.*%.pdf$"), "malformed pdf parameter provided / inferred")

if args.format then
	local log_file = kpathsea:find_file(args.mmz..".log")
	-- info("Logging to", log_file) -- TODO
	log = assert(io_open_w(log_file))
end

local mmz = kpathsea:find_file(args.mmz, true)

local dirs_to_make = {}

-- collect data from file
local pages = {}

do
	local current_prefix = nil
	for line in io_lines(mmz) do
		-- match against NewExtern first as this is the most common case
		local extern_path, page_n, w, h = line:match("\\mmzNewExtern *{(.*)}{(%d+)}{([0-9.]*)pt}{([0-9.]*)pt}")
		if extern_path and page_n and w and h then
			-- Found \mmzNewExtern -> mark the page for extraction later

			-- TODO unquote extern_path

			local dir_prefix, name_prefix, code_md5sum, context_md5sum, suffix = parse_extern_path(extern_path)

			local extern_file_out = kpathsea:find_file(extern_path)

			-- check whether c-memo and cc-memo exist (in any input directory)
			-- TODO pathlib
			-- c_memo  = kpathsea:find_file(extern_path.with_name(name_prefix..code_md5sum..".memo"))
			-- cc_memo = kpathsea:find_fil(extern_path.with_name(name_prefix..code_md5sum.."-"..context_md5sum..".memo"))
			if not args.force and not c_memo and not cc_memo then
				-- warning()
				os.exit(-1) -- raise NotExtracted in python
			end

			table.insert(pages, {page=page_n, width=w, height=h, fn=extern_file_out, prefix=current_prefix})
			goto continue
		end

		local m_p = line:match("\\mmzPrefix *{(.-)}")
		if m_p then
			-- Found \mmzPrefix -> store what extern directory to create later when it's needed

			-- TODO unquote prefix?

			-- is the '.' optional? (-> need a second pattern)
			local name_prefix, dir_prefix = m_p:match("^(.*)%.(.*)$")
			if name_prefix and dir_prefix then
				dirs_to_make[dir_prefix] = function() mkdir(dir_prefix) end
				current_prefix = dir_prefix
			else
				-- warning("Cannot parse line", line)
			end
			goto continue
		end

		print(line)
		::continue::
	end
end

-- check the dimensions
local succ, _ = check_dimensions(args.pdf, pages, 0.01, args.force)
assert(#succ == #pages, "not all pages match the provided dimensions")
local req_pages = succ

-- until here nothing was changed in the filesystem (except if --mkdir was passed)

-- extract the requested pages
-- Note: "mmz/0.pdf" corresponds not to the first page, but to the first page requested in req_pages

-- TODO where to put the files generated by ghostscript? Should be an extra directory, but where?
local _, _, cleanup, page_pat = assert(extract_pages(args.pdf, "mmz", req_pages))

-- postprocess extracted pages -> rename/move them
for p, page in ipairs(pages) do
	local extract = page_pat:format(p)
	mv(extract, page.fn)
	-- info("Page ", page.page, " --> ", page.fn)
end

-- if for some reason files generated by ghostscript were not used, remove them now
cleanup()
