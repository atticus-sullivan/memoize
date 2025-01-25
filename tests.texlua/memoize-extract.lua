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


---@param bp number
---@return number
local function bp2pt(bp)
	return bp / 72 * 72.27
end

local escape_pattern
do
	-- use concatenation to make the pattern easier readable
	local p = "[".."%(".."%)".."%.".."%%".."%+".."%-".."%*".."%?".."%[".."%]".."%^".."%$".."]"
	---make an arbitrary string safe for use in a lua pattern
	---@param pat string
	---@return string
	escape_pattern = function(pat)
		local r = pat:gsub(p, "%%%0")
		return r
	end
end

-- restricted function defined here
local mkdir
do
	-- safe the functions/libraries needed in this restricted area
	local lfs = lfs
	if not lfs then error("lfs is not available. This script needs to be executed with texlua") end

	---safely make new directory (non-recursive)
	---Note: this is a nop if the directory already exists
	---@param name string
	mkdir = function(name)
		if lfs.isdir(name) then
			return true
		end

		-- TODO https://gitlab.lisn.upsaclay.fr/texlive/luatex/-/blob/master/source/texk/web2c/luatexdir/lua/luatex-core.lua#L269
		-- why also checking for `in`? isn't mkdir only about output?
		if kpse.out_name_ok_silent_extended(name) and kpse.in_name_ok_silent_extended(name) then
			return lfs.mkdir(name)
		else
			error("Mkdir "..name.." not permitted")
		end
	end
end

-- restricted function defined here
local io_open_w
do
	-- safe the functions/libraries needed in this restricted area
	local io_open = io.open

	---safely open a file in write mode
	---@param name string
	io_open_w = function(name)
		if kpse.out_name_ok_silent_extended(name) then
			return io_open(name, "w")
		else
			error("Opening (write) "..name.." not permitted")
		end
	end
end

-- restricted function defined here
local mv
do
	-- safe the functions/libraries needed in this restricted area
	local os_rename = os.rename

	---safely rename a file aka moving it
	---@param src string
	---@param dst string
	mv = function(src, dst)
		if not kpse.in_name_ok_silent_extended(src) then
			error("Moving from " .. src .. " not permitted.")
		elseif not kpse.out_name_ok_silent_extended(dst) then
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

	---safely get an iterator over the lines of a file
	---@param name string
	io_lines = function(name)
		if kpse.in_name_ok_silent_extended(name) then
			return _io_lines(name)
		else
			error("Opening (read) "..name.." not permitted")
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

	---extract all pages specified in `pages` from `src_pdf` to dedicated files specified via `out_prefix`
	---@param src_pdf string
	---@param out_prefix string
	---@param pages [integer]
	---@param pdf_version string
	---@return integer|nil return_code of the underlying os.execute
	---@return string|nil error returned by os.execute
	---@return function cleanup clean up all files created in the process
	---@return string out_pat pattern to which the pages were written to
	extract_pages = function(src_pdf, out_prefix, pages, pdf_version)
		if not kpse.in_name_ok_silent_extended(src_pdf) then
			error("Opening " .. src_pdf .. " not permitted.")
		end

		local out_pat = ("%s%%d.pdf.tmp"):format(escape_pattern(out_prefix))
		if not kpse.out_name_ok_silent_extended(out_pat:format(0)) then
			error("Writing to " .. out_pat:format(0) .. " (and following) not permitted.")
		end

		if not pdf_version:find("^%d%.%d$") then
			error("Invalid pdf_version provided: "..pdf_version)
		end

		-- Be aware that using the %d syntax for -sOutputFile=... does not reflect the
		-- page number in the original document. If you chose (for example) to process
		-- even pages by using -sPageList=even, then the output of -sOutputFile=out%d.png
		-- would still be out1.png, out2.png, out3.png etc.
		local cmd = ([[rungs -dSAFER -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -dCompatibilityLevel="%s" -sPageList="%s" -sOutputFile="%s" "%s"]]):format(
			pdf_version,
			table.concat(pages, ","),
			out_pat,
			src_pdf
		)
		local succ, err = os_spawn(cmd)

		-- removes generated files (in case they still exist)
		local cleanup = function()
			for i in ipairs(pages) do
				local fn = out_pat:format(i)
				-- this is cleanup -> fail silently, not throwing errors
				if kpse.out_name_ok_silent_extended(fn) then
					if lfs.isfile(fn) then
						return os_rm(fn)
					end
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

	---check the dimensions of the pages in `src_pdf` specified in `page_dimensions`. Reports back which dimensions match (with `tolerance`) an which don't
	---@param src_pdf string
	---@param page_dimensions table
	---@param tolerance number
	---@param force boolean
	---@return integer[] matching_pages
	---@return integer[] failed_pages
	---@return string pdf_version
	check_dimensions = function(src_pdf, page_dimensions, tolerance, force)
		local pdf
		if kpse.in_name_ok_silent_extended(src_pdf) then
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
				-- page not found -> skip it
				table.insert(failed, {page=i, reason="not found"})
			else
				local mediabox = pdfe.getbox(page, "MediaBox")
				local w = bp2pt(mediabox[3] - mediabox[1])
				local h = bp2pt(mediabox[4] - mediabox[2])
				if math.abs(w - i.width) > tolerance or math.abs(h - i.height) > tolerance and not force then
					table.insert(failed, {page=i, reason="dimension", real_width=w, real_height=h})
				else
					table.insert(succ, p)
				end
			end
		end

		local v_major, v_minor = pdfe.getversion(pdf)
		local pdf_version = ("%d.%d"):format(v_major, v_minor)

		pdfe.close(pdf)

		table.sort(succ)
		table.sort(failed, function(a,b) return a.i.page < b.i.page end)
		return succ, failed, pdf_version
	end
end

-- restrict the complete rest of the script by undefining security relevant libraries
-- this defines an allow-list what functions of these libraries still should be accessible
local env = {
	-- lua libraries
	arg      = arg,
	ipairs   = ipairs,
	math     = math,
	os       = { exit = os.exit, },
	pairs    = pairs,
	print    = print,
	table    = table,
	tonumber = tonumber,
	tostring = tostring,
	select   = select,

	-- TODO this way or own version with logging?
	error    = error,
	assert   = assert,

	-- luatex specific libraries
	lfs      = {isfile=lfs.isfile},
	kpse     = kpse,

	-- memoize-extract specific global
	STAGE    = STAGE,
}
do
	-- Prevent trying to change the environment.
	local function bad_index(...)
		local msg = "Attempt to access an undefined index:"
		for i = 2, select("#", ...) do
			msg = msg ..tostring(select(i, ...)).." "
		end
		env.error(msg)
	end
	setmetatable(env, {
		__index     = bad_index,
		__metatable = false,
		__newindex  = bad_index,
	})
end

_ENV = env
----------------------------------
-- restricted area startes here --
----------------------------------

-- setup kpse
kpse.set_program_name("texlua", "memoize-extract.lua")

-- TODO this probably needs to be extended or we find something luatex native
---@param fname string
---@return string
local function find_out(fname)
	return fname
end

local exit = {
	error = function() os.exit(11) end,
	warn  = function() os.exit(10) end,
	succ  = function() os.exit(0) end,
}

-- setup something like a logging library
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

	---Setup logging with specific arguments to avoid needing to pass quiet and format arguments to each logging call
	---@param args table
	function logging:set_args(args)
		self.error = function(self, short, long) return self:_error(short, long, args.quiet, args.format) end
		self.info  = function(self, text) return self:_info(text, args.quiet, args.format) end
		self.warn  = function(self, text) return self:_warn(text, args.quiet, args.format) end
	end

	---Log an error
	---@param short string
	---@param long string
	---@param quiet boolean
	---@param format string
	function logging:_error(short, long, quiet, format)
		format = format or "None"
		if not quiet then
			print(ERROR.None{short=short, long=long, header=self.header})
		end
		if self.file then
			short = short:gsub("\\", "\\string\\")
			long  = long:gsub("\\", "\\string\\")
			self.file:write(ERROR[format]{short=short, long=long, package_name=package_name})
		end
		-- set the exitcode this way
		exit.succ = exit.error
	end
	logging.error = logging._error

	---Log a warning
	---@param text string
	---@param quiet boolean
	---@param format string
	function logging:_warn(text, quiet, format)
		format = format or "None"
		if not quiet then
			print(WARNING.None{text=text, header=self.header, indent=self.indent})
		end
		if self.file then
			text = text:gsub("\\", "\\")
			self.file:write(WARNING[format]{text=text, texindent=self.texindent, package_name=self.package_name})
		end
		-- set the exitcode this way
		exit.succ = exit.warn
	end
	logging.warn = logging._warn

	---Log info message
	---@param text string
	---@param quiet boolean
	---@param format string
	function logging:_info(text, quiet, format)
		format = format or "None"
		if not quiet then
			print(INFO.None{text=text, header=self.header, indent=self.indent})
		end
		if self.file then
			text = text:gsub("\\", "\\")
			self.file:write(INFO[format]{text=text, texindent=self.texindent, package_name=self.package_name})
		end
	end
	logging.info = logging._info
end

-- -- redefine assert
-- assert = function(cond, msg)
-- 	if not cond then
-- 		logging:error("", msg)
-- 		logging:close()
-- 		exit.error()
-- 	end
-- end
--
-- -- redefine error
-- error = function(msg)
-- 	logging:error("", msg)
-- 	logging:close()
-- 	exit.error()
-- end

---Unquote a quoted string
---@param fn string quoted filename
---@return string
local function unquote(fn)
	local r = fn:gsub("\"(.-)\"", "%1")
	return r
end

local md5pat = ("%x"):rep(32)
--- Parses the extern_path
-- in python this is a simple regex, but lua patterns cannot do the same things,
-- so we need multiple ones
---@param path string
---@return string|nil dir_prefix
---@return string|nil name_prefix
---@return string|nil code_md5sum
---@return string|nil context_md5sum
local function parse_extern_path(path)
	-- TODO maybe lpeg would be better suited for parsing this
	-- first split into d_prefix, name_prefix and rest
	local dir_prefix, name_prefix, code_md5sum, context_md5sum, remaining = path:match("^(.*/)(.-)("..md5pat..")%-("..md5pat..")(.-).pdf$")

	if not remaining then
		-- pattern did not match -> maybe the optional dir_prefix was not given
		dir_prefix = ""
		name_prefix, code_md5sum, context_md5sum, remaining = path:match("^(.-)("..md5pat..")%-("..md5pat..")(.-).pdf$")
	end

	if not remaining then
		-- If the pattern didn't match, return nil
		return nil
	end

	-- check if remaining fits the scheme
	if remaining ~= "" and not remaining:find("^%-%d+$") then
		return nil
	end

	-- Return the extracted components
	return dir_prefix, name_prefix, code_md5sum, context_md5sum
end

---Split a mmz prefix
-- in python this is a simple regex, but lua patterns cannot do the same things,
-- so we need multiple ones
---@param prefix string
---@return string|nil dir_prefix
---@return string|nil name_prefix
local function split_prefix(prefix)
	-- try with dir_prefix and name_prefix
	local dir_prefix, name_prefix = prefix:match("^(.*/)(.-)$")
	if not name_prefix then
		-- pattern did not match -> maybe the optional dir_prefix was not given
		dir_prefix = ""
		name_prefix = prefix:match("^(.-)$")
	end

	if not name_prefix then
		return nil
	end

	return dir_prefix, name_prefix
end

local parse_args
do
	local formats = {latex=true, plain=true, context=true}
	---Parse some CLI arguments
	---@param as string[] array of arguments
	---@param defaults table default values for the parameters
	---@return table updated_parameters
	parse_args = function(as, defaults)
		local args = defaults

		local i = 1
		local len = #as
		while i <= len do
			if as[i] == "--" then break end

			local a = as[i]:match("^%-([a-zA-Z])$")
			if not a then
				a = as[i]:match("^%-%-([a-zA-Z]+)$")
			end

			-- positional argument reached
			if not a then
				-- no flags are parsed after the first positional
				i = i - 1 -- "unparse" that argument
				break
			end

			if a == "h" then
				print("help") -- TODO write the help output
				exit.succ()
			elseif a == "V" or a == "version" then
				print(("memoize-extract.py of Memoize %s"):format(VERSION))
				exit.succ()

			elseif a == "P" or a == "pdf" then
				assert(len >= i+1, "argument P/pdf needs an argument")
				args.pdf = as[i+1]
				i = i+1

			elseif a == "p" or a == "prune" then
				args.prune = true

			elseif a == "k" or a == "keep" then
				args.keep = true

			elseif a == "f" or a == "format" then
				assert(len >= i+1, "argument f/format needs an argument")
				args.format = as[i+1]
				if not formats[args.format] then
					error("invalid format passed")
				end
				i = i+1

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

		assert(i+1 == #as, "wrong number of arguments passed, exactly one positional needs to be given")
		args.mmz = as[#as]

		return args
	end
end

-------------------------
-- temporary pathutils --
-- only works on unix  --
-------------------------
local pathlib = {}
do
	local pathsep="/" -- normal string
	if os.type == "windows" then
		pathsep="\\"
	end

	---check for weird characters in the path
	---@param path string
	---@return string path
	function pathlib.sanitize_path(path)
		if path:match("[%c%%\t\r\n><*|]") then
			error("Path contains invalid characters: "..path)
		end
		return path
	end
	---check for weird characters in the path
	---same as sanitize_path but includes / and \
	---@param name string
	---@return string name
	function pathlib.sanitize_name(name)
		if name:match("[%c%%\t\r\n><*|/\\]") then
			error("File has an invalid name: "..name)
		end
		return name
	end
	---check for invalid suffixes
	---@param suffix string
	---@return string suffix
	function pathlib.sanitize_suffix(suffix)
		if suffix:match("[%c%%\t\r\n><*|/\\]") then
			error("Suffix contains invalid characters: "..suffix)
		end
		if suffix:match("^%.") then
			error("Suffix should not start with a dot: "..suffix)
		end
		if suffix == "" then
			error("suffix must not be empty")
		end
		return suffix
	end

	local name_pat = "^(.*)"..pathsep.."([^"..pathsep.."]+)["..pathsep.."]?$"
	---@param path string
	---@return string name
	---@return string remainder
	function pathlib.name(path)
		path = pathlib.sanitize_path(path)
		local r, name = path:match(name_pat)
		return name or path, name and r or nil
	end
	---@param path string
	---@param name string
	---@return string
	function pathlib.with_name(path, name)
		path = pathlib.sanitize_path(path)
		name = pathlib.sanitize_name(name)
		local _, r = pathlib.name(path)
		if r then
			return r..pathsep..name
		end
		return name
	end

	---@param path string
	---@return string suffix
	---@return string remainder
	function pathlib.suffix(path)
		path = pathlib.sanitize_path(path)
		local r, suffix = path:match("^(.*)%.([^./]*)$")
		if not suffix and path:match("^%.") then
			-- handle hidden files
			return "", path
		end
		return suffix or "", r or path
	end
	---@param path string
	---@param suffix string
	---@return string
	function pathlib.with_suffix(path, suffix)
		path = pathlib.sanitize_path(path)
		suffix = pathlib.sanitize_suffix(suffix)
		local _, r = pathlib.suffix(path)
		return r.."."..suffix
	end
end

---Normalizes the mmz argument into a .mmz filename
---@param mmz string
---@return string
local function normalize_mmz(mmz)
	if pathlib.suffix(mmz) == "tex" then
		mmz = pathlib.with_suffix(mmz, "mmz")
	elseif pathlib.suffix(mmz) ~= "mmz" then
		mmz = pathlib.with_name(mmz, pathlib.name(mmz)..".mmz")
	end
	return mmz
end

---@class Page
---@field page integer
---@field width number
---@field height number
---@field fn string
---@field prefix string
---@field line_tab LineTab

---@alias LineTab [string,integer|nil]
---@alias DirsToMake table<string, fun()>

---@param line string
---@param current_prefix string|nil
---@param pages Page[]
---@param force boolean
---@param check_for_memo fun(c:string, cc:string):boolean checks if memo files are available
---@param line_tab LineTab
---@return boolean continue signals whether the line was identified as new_extern
local function handle_mmz_new_extern(line, current_prefix, pages, force, check_for_memo, line_tab)
	local extern_path, page_n, w, h = line:match("\\mmzNewExtern *{(.*)}{(%d+)}{([0-9.]*)pt}{([0-9.]*)pt}")

	if extern_path and page_n and w and h then
		-- Found \mmzNewExtern -> mark the page for extraction later
		extern_path = unquote(extern_path)
		local dir_prefix, name_prefix, code_md5sum, context_md5sum = parse_extern_path(extern_path)
		if not dir_prefix or not name_prefix or not code_md5sum or not context_md5sum then
			logging:warn("Cannot parse line "..line.." properly")
			-- returning true as the line was matched
			-- don't add to pages array -> page gets skipped
			-- line_tab will be not modifiable -> line won't get somehow commented out
			return true
		end

		page_n = assert(tonumber(page_n))
		local extern_file_out = find_out(extern_path)

		-- check whether c-memo and cc-memo exist (in any input directory)
		local c_memo_file  = pathlib.with_name(extern_path, name_prefix..code_md5sum..".memo")
		local cc_memo_file = pathlib.with_name(extern_path, name_prefix..code_md5sum.."-"..context_md5sum..".memo")

		if not force and not check_for_memo(c_memo_file, cc_memo_file) then
			logging:warn(([[I refuse to extract page %d into extern 
'%s', because the associated c-memo 
'%s' and/or cc-memo '%s' 
does not exist]]):format(page_n+1, extern_path, c_memo_file, cc_memo_file))
			-- returning true as the line was matched
			-- don't add to pages array -> page gets skipped
			-- line_tab will be not modifiable -> line won't get somehow commented out
			return true
		end

		assert(current_prefix, "no prefix was parsed before this extern")
		line_tab[2] = #pages
		table.insert(pages, {page=page_n, width=w, height=h, fn=extern_file_out, prefix=current_prefix, line_tab=line_tab})
		return true
	end
	return false
end

---@param line string
---@param dirs_to_make DirsToMake
---@param current_prefix string|nil
---@param gs_prefix string|nil
---@return boolean continue signals whether the line was identified as new_extern
---@return string|nil current_prefix
---@return string|nil gs_prefix
local function handle_mmz_prefix(line, dirs_to_make, current_prefix, gs_prefix)
	local m_p = line:match("\\mmzPrefix *{(.-)}")

	if m_p then
		-- Found \mmzPrefix -> store what extern directory to create later when it's needed
		m_p = unquote(m_p)
		local dir_prefix, name_prefix = split_prefix(m_p)
		if name_prefix and dir_prefix then
			dirs_to_make[dir_prefix] = function() if dir_prefix ~= "" then mkdir(dir_prefix) end end
			current_prefix = dir_prefix
			-- save the first prefix that occurs
			gs_prefix = gs_prefix or current_prefix
		else
			logging:warn("Cannot parse line "..line)
		end
		return true, current_prefix, gs_prefix
	end
	return false, current_prefix, gs_prefix
end

---Fully parses the mmz file
---@param mmz_lines fun(): any iterator over the lines of the mmz file. Usually the value returned by io.lines(mmz)
---@param keep boolean
---@param force boolean
---@return Page[] pages information about the pages to be extracted
---@return [string, integer|nil][] new_mmz data to be inserted later into the new mmz file (elements are also referenced by pages elements -> might change
---@return string|nil gs_prefix first mmz prefix parsed -> might be used as prefix for the files generated by ghostscript
---@return DirsToMake dirs_to_make contains a function to mkdir the directory for each encountered prefix 
local function parse_mmz(mmz_lines, force, keep)
	---@type Page[]
	local pages          = {}

	---@type [string,integer|nil][]
	local new_mmz        = {}

	local gs_prefix      = nil
	local current_prefix = nil
	local dirs_to_make   = {}

	for line in mmz_lines do
		---@type [string]
		local line_tab = {line} -- store the line in a table as this allows us to reference it (-> can be changed) instead of copying it

		local continue = false
		-- local succ, err

		-- match against NewExtern first as this is the most common case
		continue = handle_mmz_new_extern(line, current_prefix, pages, force, function(c, cc) return kpse.find_file(c) and kpse.find_file(cc) end, line_tab)
		if continue then goto continue end

		continue, current_prefix, gs_prefix = handle_mmz_prefix(line, dirs_to_make, current_prefix, gs_prefix)
		if continue then goto continue end

		-- nothing matched

		::continue::
		if not keep then
			table.insert(new_mmz, line_tab)
		end
	end
	return pages, new_mmz, gs_prefix, dirs_to_make
end

---Postprocess extracted pages
---renames the files resulting from the extraction like it was specified in the .mmz
---@param pages Page[] information about the pages to be extracted
---@param dirs_to_make DirsToMake contains a function to mkdir the directory for each encountered prefix 
---@param page_pat string pattern with on %d to obtain the src paths of the pdfs containing page page contents
---@param keep boolean
local function postprocess_pages(pages, dirs_to_make, page_pat, keep)
	for p, page in ipairs(pages) do
		-- make directory if necessary
		if dirs_to_make[page.prefix] then
			dirs_to_make[page.prefix]()
			dirs_to_make[page.prefix] = nil
		end

		local extract = page_pat:format(p)
		if lfs.isfile(extract) then
			local succ, err = mv(extract, page.fn)
			if succ then
				if not keep then
					-- wait until here to comment out the line in the .mmz so that only successfully extracted pages are uncommented
					page.line_tab[1] = "%"..page.line_tab[1]
				end
			else
				logging:warn("Finalizing page "..page.page.." failed: "..err)
			end
		else
			-- make sure to skip non-existant files
			logging:warn(("file '%s' was not found -> will still be missing in the next compilation step"):format(extract))
		end
		logging:info(("Page %d --> %s"):format(page.page, page.fn))
	end
end

---Function to write the new (probably updated) contents of the mmz file
---@param mmz file* file handle to which the content of the new mmz file should be written to
---@param new_mmz [string, integer|nil][] data to be inserted later into the new mmz file (elements are also referenced by pages elements -> might change
local function write_new_mmz(mmz, new_mmz)
	local first = true
	for _, line in ipairs(new_mmz) do
		mmz:write(not first and "\n" or "", line[1])
		first = false
	end
end

local function main(args)
	if not args.mmz then
		error("mmz needs to be provided")
	end

	-- --mkdir -> just create a directory named |mmz|
	if args.mkdir then
		mkdir(args.mmz)
		exit.succ()
	end

	args.mmz = normalize_mmz(args.mmz)
	assert(args.mmz:match("^.*%.mmz$"), "malformed mmz parameter provided")
	assert(lfs.isfile(args.mmz), ".mmz file was not found")

	-- setup logging to file
	if args.format then
		local log_file = find_out(args.mmz..".log")
		logging:info("Logging to "..log_file)
		logging.file = assert(io_open_w(log_file))
	end

	-- infer the path to the pdf file
	args.pdf = kpse.find_file(args.pdf or pathlib.with_suffix(args.mmz, "pdf"))
	assert(args.pdf:match("^.*%.pdf$"), "malformed pdf parameter provided / inferred")
	assert(lfs.isfile(args.pdf), ".pdf file was not found")

	-- collect data from file
	local mmz = kpse.find_file(args.mmz, true)
	local pages, new_mmz, gs_prefix, dirs_to_make = parse_mmz(io_lines(mmz), args.force, args.keep)

	if #pages == 0 then
		-- nothing to be processed -> terminate
		logging:info("No externs found that need processing")
		logging:close()
		exit.succ()
	end

	assert(gs_prefix, "at least one prefix needs to be read")
	assert(dirs_to_make[gs_prefix], "nothing registered to create directory for the prefix")

	-- check the dimensions
	local succ, failed, pdf_version = check_dimensions(args.pdf, pages, 0.01, args.force)
	assert(#succ + #failed == #pages, "Internal error: amount of pages for which the check succeded + failed does not match amount of requested pages")
	local req_pages = succ

	for _, p in ipairs(failed) do
		if p.reason == "dimension" then
			logging:warn(([[I refuse to extract page %d from '%d' 
because its size is not what I expected]]):format(p.i.page, args.pdf))
		elseif p.reason == "not found" then
			logging:warn(([[I refuse to extract page %d from '%d' 
that page was not found in the pdf file]]):format(p.i.page, args.pdf))
		end
	end

	-----------------------------------------------------------------------
	-- until here nothing was changed in the filesystem in this function --
	-- => no above this no cleanup (except opened logfile needed)        --
	-----------------------------------------------------------------------

	-- extract the requested pages
	-- Note: "mmz/0.pdf" corresponds not to the first page, but to the first page requested in req_pages

	dirs_to_make[gs_prefix]()
	dirs_to_make[gs_prefix] = nil
	local succ, err, cleanup, page_pat = extract_pages(args.pdf, gs_prefix, req_pages, pdf_version)
	assert(succ == 0, err)

	-- postprocess extracted pages -> rename/move them
	postprocess_pages(pages, dirs_to_make, page_pat, args.keep)

	-- write new |.mmz| file with |\mmzNewExtern| lines commented out.
	if not args.keep then
		local file = io_open_w(mmz)
		write_new_mmz(file, new_mmz)
		file:close()
	end

	-- if for some reason files generated by ghostscript were not used, remove them now
	cleanup()

	logging:close()
	exit.succ()
end

if STAGE == "production" then
	-----------------------------------------------
	-- parsing + validating + deriving arguments --
	-----------------------------------------------
	local defaults = {
		pdf = nil,
		prune = false,
		keep = false,
		format = nil,
		force = false,
		quiet = false,
		mkdir = false,
		mmz = nil,
	}

	local args = parse_args(arg, defaults)
	logging:set_args(args)
	main(args)
elseif STAGE == "LIBRARY" then
	-- theoretically allows this to be loaded as library in LuaLaTeX via require
	return main
else
	-- don't exit when testing
	exit = {
		-- TODO needs the real error from lua (just in case we decide to replace the error function later)
		error = function() error("exited with error") end,
		warn  = function() error("exited with warn") end,
		succ  = function() error("exited with succ") end,
	}
	-- expose functions for tests
	return {
		parse_extern_path     = parse_extern_path,
		split_prefix          = split_prefix,
		parse_args            = parse_args,
		normalize_mmz         = normalize_mmz,
		write_new_mmz         = write_new_mmz,
		postprocess_pages     = postprocess_pages,
		handle_mmz_prefix     = handle_mmz_prefix,
		handle_mmz_new_extern = handle_mmz_new_extern,
		pathlib               = pathlib,
		-- logging?
	}
end
