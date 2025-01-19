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

local lfs = require 'lfs'

local lester = require"lester.lester"
local describe = lester.describe
local before   = lester.before
local after    = lester.after
local it       = lester.it
local expect   = lester.expect

STAGE = "testing"
local extract = require"memoize-extract"

describe("parse_extern_path", function()
	local tmp_dir = ""
	local original_dir = ""

	before(function()
		-- Save the current working directory
		original_dir = assert(lfs.currentdir())

		-- Create a unique temporary directory
		tmp_dir = os.tmpname()
		os.remove(tmp_dir) -- Remove the temp file placeholder
		lfs.mkdir(tmp_dir)

		-- Change to the temporary directory
		lfs.chdir(tmp_dir)
	end)

	after(function()
		-- Change back to the original working directory
		lfs.chdir(original_dir)

		-- Cleanup: Remove the temporary directory and its contents
		local function rmdir(path)
			for file in lfs.dir(path) do
				if file ~= "." and file ~= ".." then
					local fullpath = path .. "/" .. file
					local attr = lfs.attributes(fullpath)
					if attr and attr.mode == "directory" then
						rmdir(fullpath)
					else
						os.remove(fullpath)
					end
				end
			end
			lfs.rmdir(path)
		end
		rmdir(tmp_dir)
	end)

	it("xyz", function()
		local dir_prefix, name_prefix, code_md5sum, context_md5sum, suffix = extract.parse_extern_path("dir_prefix/name_prefix.cb9e76832c526b9633671c609b1757ca-cb9e76832c526b9633671c609b1757ca-42.pdf")
		expect.equal(dir_prefix, "dir_prefix")
		expect.equal(name_prefix, "name_prefix")
		expect.equal(code_md5sum, "cb9e76832c526b9633671c609b1757ca")
		expect.equal(context_md5sum, "cb9e76832c526b9633671c609b1757ca")
		expect.equal(suffix, "42")
	end)
end)
