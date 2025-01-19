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

-- global variable STAGE is used as indicator whether this is loaded as library for testing or executed directly
-- variable is "testing" if exactly this string and "production" in all other cases
STAGE = STAGE == "testing" and "testing" or "production"


--TODO various error()/assert() calls now -- make functions adhere to proper error handling
-- only needed because the logfile needs to be cleaned up
-- -> maybe write my own error+assert which does logging + cleanup + exit


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
		if not lfs.isdir(name) then
			if kpathsea:out_name_ok(name) then
				assert(name and name ~= "", "name: " .. name)
				assert(lfs.mkdir(name))
			else
				-- TODO
			end
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
		if kpathsea:out_name_ok(name) then
			return io_open(name, "w")
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
	---@param out_prefix string
	---@param pages [integer]
	---@return integer|nil
	---@return string
	---@return function
	---@return string
	extract_pages = function(src_pdf, out_prefix, pages)
		if not kpathsea:in_name_ok(src_pdf) then
			error("Opening " .. src_pdf .. " not permitted.")
		end

		local out_pat = ("%s%%d.pdf.tmp"):format(out_prefix)
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
				if math.abs(w - i.width) > tolerance or math.abs(h - i.height) > tolerance and not force then
					print("Sizes do not match -> skip that page", w, "vs", i.width "|", h, "vs", i.height)
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
-- this defines an allow-list what functions of these libraries still should be accessible
if STAGE == "production" then
	io     = nil
	fio    = nil
	os     = {exit=os.exit}
	lfs    = {isfile=lfs.isfile}
	pdfe   = nil
	socket = nil
	sio    = nil
	texio  = nil
	tex    = nil
	ffi    = nil
	-- TODO is this missing something for further restricting?
end

----------------------------------
-- restricted area startes here --
----------------------------------

-- setup kpathsea
kpathsea = kpse.new("kpsewhich")

local logging = {
	file      = nil,
	header    = "memoize-extract.lua: ",
	indent    = "",
	texindent = "",
}
do
	local package_name = "memoize (texlua-based extraction)"
	local ERROR   = {
		latex     = function(a) return ("\\PackageError{%s}{%s}{%s}"):format(a.package_name or "", a.short or "", a.long or "") end,
		plain     = function(a) return ("\\errhelp{%s}\\errmessage{%s: %s}"):format(a.long or "", a.package_name or "", a.short or "") end,
		context   = function(a) return ("\\errhelp{%s}\\errmessage{%s: %s}"):format(a.long or "", a.package_name or "", a.short or "") end,
		None      = function(a) return ("%s%s.\n%s"):format(a.header or "", a.short or "", a.long or "") end,
	}

	local WARNING = {
		latex     = function(a) return ("\\PackageWarning{%s}{%s%s}"):format(a.package_name or "", a.texindent or "", a.text or "") end,
		plain     = function(a) return ("\\message{%s: %s%s}"):format(a.package_name or "", a.texindent or "", a.text or "") end,
		context   = function(a) return ("\\message{%s: %s%s}"):format(a.package_name or "", a.texindent or "", a.text or "") end,
		None      = function(a) return ("%s%s%s."):format(a.header or "", a.indent or "", a.text or "") end,
	}

	local INFO    = {
		latex     = function(a) return ("\\PackageInfo{%s}{%s%s}"):format(a.package_name or "", a.texindent or "", a.text or "") end,
		plain     = function(a) return ("\\message{%s: %s%s}"):format(a.package_name or "", a.texindent or "", a.text or "") end,
		context   = function(a) return ("\\message{%s: %s%s}"):format(a.package_name or "", a.texindent or "", a.text or "") end,
		None      = function(a) return ("%s%s%s."):format(a.header or "", a.indent or "", a.text or "") end,
	}

	---Marks the log as complete
	function logging:close()
		if self.file then
			self.file:write("\\endinput")
			self.file:close()

			-- avoid working with the closed file at all cost
			self.file = nil
		end
	end

	---@param short string
	---@param long string
	---@param quiet boolean
	---@param format string
	function logging:error(short, long, quiet, format)
		format = format or "None"
		if not quiet then
			print(ERROR.None{short=short, long=long, header=self.header})
		end
		if self.file then
			short = short:gsub("\\", "\\string\\")
			long  = long:gsub("\\", "\\string\\")
			self.file:write(ERROR[format]{short=short, long=long, package_name=package_name})
		end
	end

	---@param text string
	---@param quiet boolean
	---@param format string
	function logging:warn(text, quiet, format)
		format = format or "None"
		if not quiet then
			print(WARNING.None{text=text, header=self.header, indent=self.indent})
		end
		if self.file then
			text = text:gsub("\\", "\\")
			self.file:write(WARNING[format]{text=text, texindent=self.texindent, package_name=self.package_name})
		end
	end

	---@param text string
	---@param quiet boolean
	---@param format string
	function logging:info(text, quiet, format)
		format = format or "None"
		if not quiet then
			print(INFO.None{text=text, header=self.header, indent=self.indent})
		end
		if self.file then
			text = text:gsub("\\", "\\")
			self.file:write(INFO[format]{text=text, texindent=self.texindent, package_name=self.package_name})
		end
	end
end

local exit = {
	error = function() os.exit(11) end,
	warn  = function() os.exit(10) end,
	succ  = function() os.exit(0) end,
}

---comment
---@param fn string quoted filename
---@return string
local function unquote(fn)
	local r = fn:gsub("\"(.-)\"", "%1")
	return r
end

--- Parses the extern_path
-- in python this is a simple regex, but lua patterns cannot do the same things,
-- so we need multiple ones
---@param path string
---@return string|nil dir_prefix
---@return string|nil name_prefix
---@return string|nil code_md5sum
---@return string|nil context_md5sum
---@return string|nil suffix
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
			exit.succ()
		elseif a == "V" or a == "version" then
			print(("memoize-extract.py of Memoize %s"):format(VERSION))
			exit.succ()

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

-------------------------
-- temporary pathutils --
-- only works on unix  --
-------------------------
local pathlib = {}
---@param path string
---@return string name
---@return string remainder
function pathlib.name(path)
	local r, name = path:match("^(.*)/([^/]+)/?$")
	return name or path, r
end
---@param path string
---@param name string
---@return string
function pathlib.with_name(path, name)
	local _, r = pathlib.name(path)
	if r then
		return r.."/"..name
	end
	return name
end
---@param path string
---@return string suffix
---@return string remainder
function pathlib.suffix(path)
	local r, suffix = path:match("^(.*)%.([^./]*)$")
	return suffix or "", r or path
end
---@param path string
---@param suffix string
---@return string
function pathlib.with_suffix(path, suffix)
	local _, r = pathlib.suffix(path)
	return r.."."..suffix
end


-----------------------------------------------
-- parsing + validating + deriving arguments --
-----------------------------------------------

if STAGE == "production" then
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
		exit.succ()
	end

	-- Normalize the |mmz| argument into a |.mmz| filename
	if pathlib.suffix(args.mmz) == "tex" then
		args.mmz = pathlib.with_suffix(args.mmz, "mmz")
	elseif pathlib.suffix(args.mmz) ~= "mmz" then
		args.mmz = pathlib.with_name(args.mmz, pathlib.name(args.mmz)..".mmz")
	end
	assert(args.mmz:match("^.*%.mmz$"), "malformed mmz parameter provided")

	if args.format then
		local log_file = kpathsea:find_file(args.mmz..".log")
		logging:info("Logging to "..log_file, args.quiet, args.format)
		logging.file = assert(io_open_w(log_file))
	end

	-- infer the path to the pdf file
	args.pdf = kpathsea:find_file(args.pdf or pathlib.with_suffix(args.mmz, "pdf"))
	assert(args.pdf:match("^.*%.pdf$"), "malformed pdf parameter provided / inferred")

	local mmz = kpathsea:find_file(args.mmz, true)

	local dirs_to_make = {}

	----------------------------
	-- collect data from file --
	----------------------------

	local pages     = {}
	local new_mmz   = {}
	local gs_prefix = nil

	do
		local current_prefix = nil
		for line in io_lines(mmz) do
			-- match against NewExtern first as this is the most common case
			local extern_path, page_n, w, h = line:match("\\mmzNewExtern *{(.*)}{(%d+)}{([0-9.]*)pt}{([0-9.]*)pt}")
			if extern_path and page_n and w and h then
				-- Found \mmzNewExtern -> mark the page for extraction later
				extern_path = unquote(extern_path)
				local dir_prefix, name_prefix, code_md5sum, context_md5sum, suffix = parse_extern_path(extern_path)
				if not dir_prefix or not name_prefix or not code_md5sum or not context_md5sum or not suffix then
					logging:warn("Cannot parse line "..line, args.quiet, args.format)
				end

				local extern_file_out = kpathsea:find_file(extern_path)

				-- check whether c-memo and cc-memo exist (in any input directory)
				-- TODO pathlib
				-- c_memo  = kpathsea:find_file(extern_path.with_name(name_prefix..code_md5sum..".memo"))
				-- cc_memo = kpathsea:find_fil(extern_path.with_name(name_prefix..code_md5sum.."-"..context_md5sum..".memo"))
				if not args.force and not c_memo and not cc_memo then
					logging:warn(([[I refuse to extract page %d into extern 
	'%s', because the associated c-memo 
	'%s' and/or cc-memo '%s' 
	does not exist]]):format(page_n+1, extern_path, c_memo, cc_memo), args.quiet, args.format)
					-- raises NotExtracted in python
				end

				if not args.keep then
					line = "%"..line
				end
				assert(current_prefix, "no prefix was parsed before this extern")
				table.insert(pages, {page=page_n, width=w, height=h, fn=extern_file_out, prefix=current_prefix})
				goto continue
			end

			local m_p = line:match("\\mmzPrefix *{(.-)}")
			if m_p then
				-- Found \mmzPrefix -> store what extern directory to create later when it's needed
				m_p = unquote(m_p)
				-- TODO is the '.' optional? (-> need a second pattern)
				local name_prefix, dir_prefix = m_p:match("^(.*)%.(.*)$")
				if name_prefix and dir_prefix then
					dirs_to_make[dir_prefix] = function() mkdir(dir_prefix) end
					current_prefix = dir_prefix
					-- save the first prefix that occurs
					gs_prefix = gs_prefix or current_prefix
				else
					logging:warn("Cannot parse line "..line, args.quiet, args.format)
				end
				goto continue
			end
			-- nothing matched

			::continue::
			if not args.keep then
				table.insert(new_mmz, line)
			end
		end
	end

	if #pages == 0 then
		-- nothing to be processed -> terminate
		logging:close()
		exit.succ()
	end

	assert(gs_prefix, "at least one prefix needs to be read")
	assert(dirs_to_make[gs_prefix], "nothing registered to create directory for the prefix")

	-- write new |.mmz| file with |\mmzNewExtern| lines commented out.
	if not args.keep then
		local file = io_open_w(mmz)
		local first = true
		for line in ipairs(new_mmz) do
			file:write(line, not first and "\n" or "")
			first = false
		end
		file:close()
	end

	-- check the dimensions
	local succ, failed = check_dimensions(args.pdf, pages, 0.01, args.force)
	assert(#succ == #pages, "not all pages match the provided dimensions")
	local req_pages = succ

	for _, p in ipairs(failed) do
		logging:warn(([[I refuse to extract page %d from '%d' 
	because its size is not what I expected]]):format(p, args.pdf), args.quiet, args.format)
	end

	-------------------------------------------------------------------------
	--          until here nothing was changed in the filesystem           --
	-- (except if --mkdir was passed, in which case we immediately exited) --
	-- (also the logfile was opened previously)                            --
	-------------------------------------------------------------------------

	-- extract the requested pages
	-- Note: "mmz/0.pdf" corresponds not to the first page, but to the first page requested in req_pages

	dirs_to_make[gs_prefix]()
	dirs_to_make[gs_prefix] = nil
	local _, _, cleanup, page_pat = assert(extract_pages(args.pdf, gs_prefix, req_pages))

	-- postprocess extracted pages -> rename/move them
	for p, page in ipairs(pages) do
		-- make directory if necessary
		if dirs_to_make[page.prefix] then
			dirs_to_make[page.prefix]()
			dirs_to_make[page.prefix] = nil
		end

		local extract = page_pat:format(p)
		if lfs.isfile(extract) then
			mv(extract, page.fn)
		else
			-- make sure to skip non-existant files
			logging:warn(("file '%s' was not found -> will still be missing in the next compilation step"):format(extract), args.quiet, args.format)
		end
		logging:info(("Page %d --> %d"):format(page.page, page.fn), args.quiet, args.format)
	end

	-- if for some reason files generated by ghostscript were not used, remove them now
	cleanup()

	logging:close()
	exit.succ()
else
	-- expose functions for tests
	return {
		parse_extern_path = parse_extern_path,
	}
end
