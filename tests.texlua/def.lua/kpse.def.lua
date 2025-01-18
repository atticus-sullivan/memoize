---@meta

---@class kpse
kpse = {}

---@class kpathsea
local kpathsea = {}

---@overload fun(name:string)
---@param name string
---@param progname string
function kpse.set_program_name(name, progname) end

---@overload fun(name:string):kpathsea
---@param name string
---@param progname string
---@return kpathsea
function kpse.new(name, progname) end

-- starting from here every function is for kpathsea as well as for kpse

---@param name string
function kpse.record_input_file(name) end
---@param name string
function kpathsea:record_input_file(name) end

---@param name string
function kpse.record_output_file(name) end
---@param name string
function kpathsea:record_output_file(name) end

---@overload fun(filename:string, ftype:string)
---@overload fun(filename:string, mustexist:boolean)
---@overload fun(filename:string, ftype:string, mustexist:boolean)
---@overload fun(filename:string, ftype:string, dpi:number)
---@param filename string
---@return string
function kpse.find_file(filename) end

---@overload fun(filename:string, ftype:string)
---@overload fun(filename:string, mustexist:boolean)
---@overload fun(filename:string, ftype:string, mustexist:boolean)
---@overload fun(filename:string, ftype:string, dpi:number)
---@param filename string
---@return string
function kpathsea:find_file(filename) end

---@param filename string
---@param options table
---@return string[]
function kpse.lookup(filename, options) end
---@param filename string
---@param options table
---@return string[]
function kpathsea:lookup(filename, options) end

---@overload fun(prefix:string, base_dpi:number, mfmode:string, fallback:string)
---@param prefix string
---@param base_dpi number
---@param mfmode string
function kpse.init_prog(prefix, base_dpi, mfmode) end
---@overload fun(prefix:string, base_dpi:number, mfmode:string, fallback:string)
---@param prefix string
---@param base_dpi number
---@param mfmode string
function kpathsea:init_prog(prefix, base_dpi, mfmode) end

---@param name string
---@return string
function kpse.readable_file(name) end
---@param name string
---@return string
function kpathsea:readable_file(name) end

---@param s string
---@return string
function kpse.expand_path(s) end
---@param s string
---@return string
function kpathsea:expand_path(s) end

---@param s string
---@return string
function kpse.expand_var(s) end
---@param s string
---@return string
function kpathsea:expand_var(s) end

---@param s string
---@return string
function kpse.expand_braces(s) end
---@param s string
---@return string
function kpathsea:expand_braces(s) end

---@param fname string
---@return boolean
function kpse.in_name_ok(fname) end
---@param fname string
---@return boolean
function kpathsea:in_name_ok(fname) end

---@param fname string
---@return boolean
function kpse.in_name_ok_silent_extended(fname) end
---@param fname string
---@return boolean
function kpathsea:in_name_ok_silent_extended(fname) end

---@param fname string
---@return boolean
function kpse.out_name_ok(fname) end
---@param fname string
---@return boolean
function kpathsea:out_name_ok(fname) end

---@param fname string
---@return boolean
function kpse.out_name_ok_silent_extended(fname) end
---@param fname string
---@return boolean
function kpathsea:out_name_ok_silent_extended(fname) end

---@param ftype string
---@return string
function kpse.show_path(ftype) end
---@param ftype string
---@return string
function kpathsea:show_path(ftype) end

---@param s string
---@return string
function kpse.var_value(s) end
---@param s string
---@return string
function kpathsea:var_value(s) end

---@return string
function kpse.version() end
---@return string
function kpathsea:version() end

---@param filename string
---@return string, string
function kpse.check_permission(filename) end
---@param filename string
---@return string, string
function kpathsea:check_permission(filename) end
