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

describe("memoize-extract.lua", function()
	before(function() end)
	after(function() end)

	describe("parse_extern_path", function()
		-- Test valid paths that should match the pattern
		it("should parse a valid path with all parts", function()
			local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef-42.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.equal(dir_prefix, "/dir/prefix/")
			expect.equal(name_prefix, "file")
			expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
			expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
		end)

		it("should parse a valid path with no dir_prefix", function()
			local path = "file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.equal(dir_prefix, "")
			expect.equal(name_prefix, "file")
			expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
			expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
		end)

		it("should parse a valid path with a numeric suffix", function()
			local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef-99.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.equal(dir_prefix, "/dir/prefix/")
			expect.equal(name_prefix, "file")
			expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
			expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
		end)

		-- Test invalid paths
		it("should return nil for invalid paths", function()
			local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef-invalid.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.not_exist(dir_prefix)
			expect.not_exist(name_prefix)
			expect.not_exist(code_md5sum)
			expect.not_exist(context_md5sum)
		end)

		it("should return nil for paths with missing code_md5sum", function()
			local path = "/dir/prefix/file-no-md5sum-1234567890abcdef1234567890abcdef.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.not_exist(dir_prefix)
			expect.not_exist(name_prefix)
			expect.not_exist(code_md5sum)
			expect.not_exist(context_md5sum)
		end)

		-- Test paths without suffix and multiple hyphens
		it("should parse a valid path without a suffix", function()
			local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.equal(dir_prefix, "/dir/prefix/")
			expect.equal(name_prefix, "file")
			expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
			expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
		end)

		-- Test paths with no context_md5sum
		it("should return nil for paths missing context_md5sum", function()
			local path = "/dir/prefix/file1234567890abcdef1234567890abcdef-.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.not_exist(dir_prefix)
			expect.not_exist(name_prefix)
			expect.not_exist(code_md5sum)
			expect.not_exist(context_md5sum)
		end)

		-- Test edge cases
		it("should handle an empty path", function()
			local path = ""
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.not_exist(dir_prefix)
			expect.not_exist(name_prefix)
			expect.not_exist(code_md5sum)
			expect.not_exist(context_md5sum)
		end)

		it("should return nil for path with only one part", function()
			local path = "1234567890abcdef1234567890abcdef-1234567890abcdef1234567890abcdef.pdf"
			local dir_prefix, name_prefix, code_md5sum, context_md5sum = extract.parse_extern_path(path)

			expect.equal(dir_prefix, "")
			expect.equal(name_prefix, "")
			expect.equal(code_md5sum, "1234567890abcdef1234567890abcdef")
			expect.equal(context_md5sum, "1234567890abcdef1234567890abcdef")
		end)

	end)


	-- describe("xyz", function()
	-- 	local tmp_dir = ""
	-- 	local original_dir = ""
	--
	-- 	before(function()
	-- 		-- Save the current working directory
	-- 		original_dir = assert(lfs.currentdir())
	--
	-- 		-- Create a unique temporary directory
	-- 		tmp_dir = os.tmpname()
	-- 		os.remove(tmp_dir) -- Remove the temp file placeholder
	-- 		lfs.mkdir(tmp_dir)
	--
	-- 		-- Change to the temporary directory
	-- 		lfs.chdir(tmp_dir)
	-- 	end)
	--
	-- 	after(function()
	-- 		-- Change back to the original working directory
	-- 		lfs.chdir(original_dir)
	--
	-- 		-- Cleanup: Remove the temporary directory and its contents
	-- 		local function rmdir(path)
	-- 			for file in lfs.dir(path) do
	-- 				if file ~= "." and file ~= ".." then
	-- 					-- TODO only works on unix due to the pathsep
	-- 					local fullpath = path .. "/" .. file
	-- 					local attr = lfs.attributes(fullpath)
	-- 					if attr and attr.mode == "directory" then
	-- 						rmdir(fullpath)
	-- 					else
	-- 						os.remove(fullpath)
	-- 					end
	-- 				end
	-- 			end
	-- 			lfs.rmdir(path)
	-- 		end
	-- 		rmdir(tmp_dir)
	-- 	end)
	--
	-- 	it("xyz", function()
	-- 	end)
	-- end)
end)
