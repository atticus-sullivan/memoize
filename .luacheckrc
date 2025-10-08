std = {
    globals = { -- these globals can be set and accessed.
	"pdfw", "inspect", 
    }, 
    read_globals = { -- these globals can only be accessed.
	"pairs", "tostring", "type", "getmetatable", "setmetatable",
	"error", "assert", "print", "table", "math", "ipairs", 
	"io", "string", "tonumber", 
	"pdfe",
    }
}
