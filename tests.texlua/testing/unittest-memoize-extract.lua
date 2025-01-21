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

	describe("split_prefix", function()
		it("should split a valid prefix with directory and name", function()
			local dir_prefix, name_prefix = extract.split_prefix("path/to/file")
			expect.equal(dir_prefix, "path/to/")
			expect.equal(name_prefix, "file")
		end)

		it("should handle a prefix with no directory", function()
			local dir_prefix, name_prefix = extract.split_prefix("file")
			expect.equal(dir_prefix, "")
			expect.equal(name_prefix, "file")
		end)

		it("should return nil for an empty string", function()
			local dir_prefix, name_prefix = extract.split_prefix("")
			expect.exist(dir_prefix)
			expect.equal(dir_prefix, "")
			expect.equal(name_prefix, "")
		end)

		it("should return a slash as dir_prefix and empty name_prefix for '/'", function()
			local dir_prefix, name_prefix = extract.split_prefix("/")
			expect.equal(dir_prefix, "/")
			expect.equal(name_prefix, "")
		end)

		it("should correctly handle input with trailing slash", function()
			local dir_prefix, name_prefix = extract.split_prefix("path/to/")
			expect.equal(dir_prefix, "path/to/")
			expect.equal(name_prefix, "")
		end)

		it("should handle input with multiple slashes but no name", function()
			local dir_prefix, name_prefix = extract.split_prefix("path///")
			expect.equal(dir_prefix, "path///")
			expect.equal(name_prefix, "")
		end)

		it("should handle input with special characters", function()
			local dir_prefix, name_prefix = extract.split_prefix("path/to/@#$%^&*()")
			expect.equal(dir_prefix, "path/to/")
			expect.equal(name_prefix, "@#$%^&*()")
		end)

		it("should handle input with whitespace", function()
			local dir_prefix, name_prefix = extract.split_prefix("path/to/ file ")
			expect.equal(dir_prefix, "path/to/")
			expect.equal(name_prefix, " file ")
		end)
	end)

	describe("parse_args", function()
		it("should parse valid arguments with defaults", function()
			local defaults = {pdf = nil, format = "plain", quiet = false}
			local args = extract.parse_args({"-P", "output.pdf", "-f", "latex", "mmz"}, defaults)
			expect.equal(args, {
				pdf    = "output.pdf",
				format = "latex",
				quiet  = false,
				mmz    = "mmz",
			})
		end)

		it("should raise an error for missing value after '-P'", function()
			local defaults = {}
			expect.fail(function()
				extract.parse_args({"-P", "mmz"}, defaults)
			end)
		end)

		it("should raise an error for invalid format", function()
			local defaults = {}
			expect.fail(function()
				extract.parse_args({"-f", "invalidformat", "mmz"}, defaults)
			end)
		end)

		it("should handle multiple flags correctly", function()
			local defaults = {}
			local args = extract.parse_args({"-p", "-k", "-q", "mmz"}, defaults)
			expect.equal(args, {
				quiet = true,
				prune = true,
				keep  = true,
				mmz   = "mmz",
			})
		end)

		it("should handle long argument names correctly", function()
			local defaults = {}
			local args = extract.parse_args({"--prune", "--quiet", "mmz"}, defaults)
			expect.equal(args, {
				quiet = true,
				prune = true,
				mmz   = "mmz",
			})
		end)

		it("should assign the last argument to mmz", function()
			local defaults = {}
			local args = extract.parse_args({"-P", "output.pdf", "final.mmz"}, defaults)
			expect.equal(args, {
				pdf = "output.pdf",
				mmz = "final.mmz",
			})
		end)

		-- TODO should the argument parsing detect something like this? Or just take '-p' as mmz file
		-- it("should fail if no mmz is given", function()
		-- 	local defaults = {pdf = nil, format = "plain", quiet = false}
		-- 	-- expect.fail(function()
		-- 		extract.parse_args({"-P", "output.pdf", "-f", "latex", "-p"}, defaults)
		-- 	-- end)
		-- end)

		-- TODO -h would end up as mmz file -> argument parsing needs to be adjusted
		-- it("should exit successfully and print help for '-h'", function()
		-- 	local defaults = {}
		-- 	expect.fail(function()
		-- 		extract.parse_args({"-h"}, defaults)
		-- 	end)
		-- end)

		-- TODO -V would end up as mmz file -> argument parsing needs to be adjusted
		-- it("should exit successfully and print version for '-V'", function()
		-- 	local defaults = {}
		-- 	expect.fail(function()
		-- 		extract.parse_args({"-V"}, defaults)
		-- 	end)
		-- end)

		it("should handle no flags and return defaults", function()
			local defaults = {pdf = nil, prune = false}
			local args = extract.parse_args({"mmz"}, defaults)
			expect.equal(args, {
				prune = false,
				mmz   = "mmz",
			})
		end)

		it("should fail with no arguments", function()
			local defaults = {pdf = nil, prune = false}
			expect.fail(function()
				extract.parse_args({}, defaults)
			end)
		end)

		it("should raise an error for an unrecognized argument", function()
			local defaults = {}
			expect.fail(function()
				extract.parse_args({"-z", "mmz"}, defaults)
			end)
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
