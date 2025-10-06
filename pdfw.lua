#!/usr/bin/env texlua

do
   local function _inspect_table(x, levels, indent, received_done)
      -- done prevents infinite regress
      local done = {} for k,v in pairs(received_done) do done[k]=v end
      if levels ~= 0 and (not done or not done[x]) then
	 done[x] = true
	 for k,v in pairs(x) do
	    local mt = getmetatable(v) and " meta" .. tostring(getmetatable(v)) or ''
	    print(indent .. tostring(k), tostring(v) .. mt)
	    if type(v) == 'table' then
	       _inspect_table(v, levels-1, indent .. '  ', done)
	    end
	 end
      end
   end
   function inspect(x, levels, indent)
      indent = indent or ''
      levels = levels or -1
      local mt = getmetatable(x) and " meta" .. tostring(getmetatable(x)) or ''
      print(indent .. tostring(x) .. mt)
      if type(x) == 'table' then
	 _inspect_table(x, levels, indent .. '| ', {})
      elseif pdfe.type(x) == 'pdfe.dictionary' then
	 _inspect_table(pdfe.dictionarytotable(x), levels, indent .. '| ', {})
      elseif pdfe.type(x) == 'pdfe.array' then
	 _inspect_table(pdfe.arraytotable(x), levels, indent .. '| ', {})
	 --elseif pdfe.type(x) == 'pdfe.stream' then
	 --   _inspect_table(pdfe.arraytotable(x), levels, indent .. '| ')
      end
   end
end

local pdfw = {}

local function index_error() error("Invalid index", 2) end
local function identity(obj) return obj end
local function obj_value_tostring(obj) return tostring(obj.value) end

local referenced_objects =  setmetatable({}, { __mode = 'k' } )
local original_object_ids = setmetatable({}, { __mode = 'k' } )
local updated_objects =     setmetatable({}, { __mode = 'k' } )

--Assigning nil to a table removes the entry, so we need this to put a null
--value into a dict or array, don't we?

do --null
   local metatable_null = {
      pdfw = 'null',
      __index = index_error, __newindex = index_error,
      __tostring = function() return 'null' end,
      __call = identity,
   }
   function pdfw.null(value) return setmetatable({}, metatable_null) end
end

--We only define pdfw.boolean/integer/float for the unlikely situation of an
--indirect object.

do --boolean
   local metatable_boolean = {
      pdfw = 'boolean',
      __index = index_error, __newindex = index_error,
      __call = identity,
      __tostring = obj_value_tostring,
   }
   function pdfw.boolean(value)
      return setmetatable({value = value and true or false}, metatable_boolean)
   end
end

do --integer
   local metatable_integer = {
      pdfw = 'integer',
      __index = index_error, __newindex = index_error,
      __call = identity,
      __tostring = obj_value_tostring,
   }
   function pdfw.integer(value)
      return setmetatable({value = tonumber(value)}, metatable_integer)
   end
end

do --float
   local metatable_float = {
      pdfw = 'float',
      __index = index_error, __newindex = index_error,
      __call = identity,
      __tostring = obj_value_tostring,
   }
   function pdfw.float(value)
      return setmetatable({value = tonumber(value)}, metatable_float)
   end
end

do --name
   local metatable_name = {
      pdfw = 'name',
      __tostring = function(obj)
	 return '/' .. obj.value:gsub('/', '#2F')
      end,
      __call = identity,
      __index = index_error, __newindex = index_error,
   }
   function pdfw.name(value)
      return setmetatable({value = value}, metatable_name)
   end
end

do --string
   local metatable_string = {
      pdfw = 'string',
      __tostring = function(obj)
	 return table.concat{ hex and '<' or '(', obj.value, hex and '>' or ')' }
      end,
      __concat = function(a,b)
	 local hex_a = type(a) ~= 'string' and a.hex 
	 local hex_b = type(b) ~= 'string' and b.hex
	 if not ((hex_a and hex_b) or (not hex_a and not hex_b)) then
	    error("Cannot concatenate a hex and a non-hex string", 2)
	 end
	 return pdfw.string(
	    (type(a) == 'string' and a or a.value)
	    ..
	    (type(b) == 'string' and b or b.value),
	    hex_a
	 )
      end,
      __index = index_error, __newindex = index_error,
      __call = identity,
   }
   function pdfw.string(value, hex)
      return setmetatable({value = value, hex = hex}, metatable_string)
   end
end   


do --array & dictionary

   local metatable_pdfe_triplet = {}
   local function is_pdfe_triplet(obj)
      return getmetatable(obj) == metatable_pdfe_triplet
   end
   
   --The situations for array and dictionary are very similar, so we define
   --parametrized metamethods.
   
   local mt_index = function(tbl, key, pdfe_doc, legal_index_f)
      assert(legal_index_f(key))
      value = tbl[key]
      if is_pdfe_triplet(value) then
	 value = pdfw.from_pdfe_triplet(pdfe_doc, table.unpack(value))
	 tbl[key] = value
      end
      return value
   end
   
   local mt_newindex = function(obj, tbl, key, value, pdfe_doc, legal_index_f)
      assert(legal_index_f(key))
      tbl[key] = value
      updated_objects[pdfe_doc] = updated_objects[pdfe_doc] or {}
      updated_objects[pdfe_doc][obj] = true
   end
   
   local mt_pairs = function(tbl, pdfe_doc, pairs_f)
      for key, value in pairs_f(tbl) do
	 if is_pdfe_triplet(value) and not tbl[key] then
	    tbl[key] = pdfw.from_pdfe_triplet(pdfe_doc, table.unpack(value))
	 end
      end
      return pairs_f(tbl)
   end

   local function is_legal_array_key(key)
      return math.type(key) == "integer" and key > 0
   end
   local function is_legal_dictionary_key(key)
      return type(key) == "string"
   end
   
   function pdfw.from_pdfe_array(pdfe_doc, pdfe_obj)
      assert(pdfe.type(pdfe_doc) == 'pdfe' and pdfe.type(pdfe_obj) == 'pdfe.array')
      local tbl = pdfe.arraytotable(pdfe_obj)
      for k, pdfe_triplet in ipairs(tbl) do
	 setmetatable(pdfe_triplet, metatable_pdfe_triplet)
      end
      return setmetatable({},
	 {
	    pdfw = "array",
	    __index = function(t,k)
	       return mt_index(tbl,k,pdfe_doc,is_legal_array_key) end,
	    __newindex = function(t,k,v) 
	       return mt_newindex(t,tbl,k,v,pdfe_doc,is_legal_array_key) end,
	    __pairs = function(t)
	       return mt_pairs(tbl,pdfe_doc,ipairs) end,
	    __len = function(t) return #tbl end,
	    __call = identity,
	 }
      )
   end

   function pdfw.from_pdfe_dictionary(pdfe_doc, pdfe_obj)
      assert(pdfe.type(pdfe_doc) == 'pdfe' and pdfe.type(pdfe_obj) == 'pdfe.dictionary')
      local tbl = pdfe.dictionarytotable(pdfe_obj)
      for k, pdfe_triplet in pairs(tbl) do
	 setmetatable(pdfe_triplet, metatable_pdfe_triplet)
      end
      return setmetatable({},
	 { pdfw = "dictionary",
	   __index = function(t,k) return
		 mt_index(tbl,k,pdfe_doc,is_legal_dictionary_key) end,
	   __newindex = function(t,k,v) return
		 mt_newindex(t,tbl,k,v,pdfe_doc,is_legal_dictionary_key) end,
	   __pairs = function(t)
	      return mt_pairs(tbl,pdfe_doc,pairs) end,
	    __call = identity,
	 }
      )
   end

end --array & dictionary

do --stream
   
   metatable_stream = {
      pdfw = 'stream',
      __index = index_error, __newindex = index_error,
   }
   
   function pdfw.from_pdfe_stream(pdfe_doc, stream, dictionary)
      return setmetatable(
	 { pdfe_doc = pdfe_doc, stream = stream, dictionary = dictionary },
	 metatable_stream
      )
   end
   
end

do --reference

   local function ref_index_error()
      error("Cannot index a reference! \z
             Did you forget to call the reference to resolve it?", 2)
   end
   
   do
      
      local function mt_call(obj, pdfe_doc, pdfe_reference, referenced_pdfe_obj_id)
	 --todo: simplify once we open the pdfe doc within pdfw
	 referenced_objects[pdfe_doc] = referenced_objects[pdfe_doc] or {}
	 local referenced_objects_for_doc = referenced_objects[pdfe_doc]
	 local referenced_object = referenced_objects_for_doc[referenced_pdfe_obj_id]
	 if not referenced_object then
	    referenced_object = pdfw.from_pdfe_triplet(
	       pdfe_doc, pdfe.getfromreference(pdfe_reference))
	    referenced_objects_for_doc[referenced_pdfe_obj_id] = referenced_object
	    original_object_ids[referenced_object] = {
	       pdfe_doc = pdfe_doc, id = referenced_pdfe_obj_id }
	 end
	 return referenced_object
      end

      function pdfw.from_pdfe_reference(pdfe_doc, pdfe_reference, referenced_pdfe_obj_id)
	 return setmetatable({}, {
	       pdfw = "reference",
	       __index = ref_index_error, __newindex = ref_index_error,
	       __call = function(obj) return mt_call(
		     obj, pdfe_doc, pdfe_reference, referenced_pdfe_obj_id) end,
	 })
      end
      
   end

   function pdfw.reference(referenced_pdfw_obj)
      return setmetatable({}, {
	    pdfw = "reference",
	    __index = ref_index_error, __newindex = ref_index_error,
	    __call = function(obj) return referenced_pdfw_obj end,
      })
   end

end --reference

do --pdfw.from_pdfe_triplet
   local val = function(pdfe_doc, value) return value end
   local distributor = {
      function() return pdfw.null() end, --null
      val, --boolean
      val, --integer
      val, --float
      function(pdfe_doc, value) return pdfw.name(value) end,
      function(pdfe_doc, value, hex) return pdfw.string(value, hex) end,
      pdfw.from_pdfe_array, ['pdfe.array'] = pdfw.from_pdfe_array,
      pdfw.from_pdfe_dictionary, ['pdfe.dictionary'] = pdfw.from_pdfe_dictionary,
      pdfw.from_pdfe_stream, ['pdfe.stream'] = pdfw.from_pdfe_stream,
      pdfw.from_pdfe_reference, ['pdfe.reference'] = pdfw.from_pdfe_reference,
   }
   function pdfw.from_pdfe_triplet(pdfe_doc, type, value, detail)
      if pdfe.type(pdfe_doc) ~= 'pdfe' then
	 error("The first argument should be a pdf document object", 2)
      end
      f = distributor[type]-- or distributor[pdfe.type(value)]
      if not f then
	 error("object type not found in distributor", 2)
      end
      return f(pdfe_doc, value, detail)
   end
end

function pdfw.type(obj, strict)
   mt = getmetatable(obj)
   if strict then
      return mt and mt.pdfw
   else
      return (mt and mt.pdfw) or type(obj)
   end
end

do --linearize

   local linearize, distribute, distributor
   
   linearize = function(pdf, obj, indirect)
      if indirect then
	 if not pdf.object_ids[obj] then
	    if pdf.updating then
	       local original = original_object_ids[obj]
	       if original and original.pdfe_doc == pdf.pdfe_doc then
		  pdf.object_ids[obj] = original.id
	       else
		  pdf.max_id = pdf.max_id + 1
		  pdf.object_ids[obj] = pdf.max_id
	       end
	    else
	       pdf.max_id = pdf.max_id + 1
	       pdf.object_ids[obj] = pdf.max_id
	    end
	    if not pdf.updating or updated_objects[pdf.pdfe_doc][obj] then
	       local pdf_repr = distribute(obj, distributor)(obj, pdf)
	       local id = pdf.object_ids[obj]
	       pdf.xref[id] = pdf.fh:seek()
	       pdf.fh:write(id .. ' 0 obj\n', pdf_repr, '\nendobj\n')
	       return pdf_repr
	    end
	 end
      else
	 return distribute(obj, distributor)(obj, pdf)
      end
   end

   pdfw.linearize = linearize

   distribute = function(obj, distributor)
      mt = getmetatable(obj)
      local f = (mt and distributor[mt.pdfw]) or distributor[type(obj)]
      assert (f, ("Unsupported type %s of object %s"):format(type(obj), obj))
      return f
   end
   
   distributor = {
      --Note the reversed order of pdf and obj in the functions below. This is so
      --that the first couple of functions below can easily receive merely obj.
      ["nil"] = function() return 'null' end, --primitive nil --> pdf null
      null = tostring, --pdfw.null
      --The following four are both for primitive and pdfw objects.
      boolean = tostring,
      number = tostring,
      name = tostring,
      --Note that '/foo' will end up as a name.  This is intentional, so that
      --names can be given simply as strings.  If you need a string that starts
      --with a slash, use either octal \057 or wrap the string in pdfw.string.
      string = tostring,
      array = function(obj, pdf)
	 local child_reprs = { [0] = '[' }
	 for i, child_obj in ipairs(obj) do
	    child_reprs[i] = pdfw.linearize(pdf, child_obj)
	 end
	 table.insert(child_reprs, ']')
	 return table.concat(child_reprs, ' ', 0)
      end,
      dictionary = function(obj, pdf)
	 local child_reprs = { [0] = '<<' }
	 local i = 1
	 for key, child_obj in pairs(obj) do
	    child_obj = obj[key] --necessary! but why?
	    child_reprs[i] = '/' .. key .. ' ' .. pdfw.linearize(pdf, child_obj)
	    i = i + 1
	 end
	 child_reprs[i] = '>>'
	 return table.concat(child_reprs, ' ', 0)
      end,
      --A table is cast into either an array or a dictionary.  Basically, it is
      --an array if numeric index 1 is present.  However, an empty table could
      --be either an array or a dictionary.  We get around this by the
      --convention that setting numeric index 0 implies that it is an array.
      table = function(obj, pdf)
	 local r
	 if obj[1] or obj[0] then
	    r = distributor["array"](obj, pdf)
	 else
	    r = distributor["dictionary"](obj, pdf)
	 end
	 return r
      end,
      stream = function(obj, pdf)
	 local chunks = {
	    distributor["dictionary"](
	       pdfw.from_pdfe_dictionary(obj.pdfe_doc, obj.dictionary), pdf),
	    'stream',
	    obj.stream(),
	    'endstream'
	 }
	 return table.concat(chunks, "\n")
      end,
      reference = function(obj, pdf)
	 local referenced_pdfw_object = obj()
	 pdfw.linearize(pdf, referenced_pdfw_object, true)
	 return pdf.object_ids[referenced_pdfw_object] .. ' 0 R'
      end,
   }
   
end --linearize


function pdfw.new(from)
   local trailer
   if pdfe.type(from) == 'pdfe' then
      trailer = pdfw.from_pdfe_dictionary(from, from.trailer) -- from --> pdfe document
   elseif type(from) == 'table' then
      trailer = from
   elseif not from then
      trailer = {
	 Root = pdfw.reference{
	    Type = '/Catalog',
	    Pages = pdfw.reference{
	       Type = '/Pages',
	       Count = 0,
	       Kids = {},
	    },
	 },
	 Info = {
	    Producer = 'pdfw',
	 },
      }
   else
      error("You can only create a PDF from a pdfe document or a trailer dictionary", 2)
   end
   local pdf = {
      trailer = trailer,
      major = 1,
      minor = 4,
   }
   return pdf
end

function pdfw.from_pdfe_page(source_pdfe_doc, page_n)
   return pdfw.from_pdfe_dictionary(
      source_pdfe_doc, pdfe.getpage(source_pdfe_doc, page_n))
end

function pdfw.append_page(pdf, source_pdfe_doc, page_n)
   local Pages = pdf.trailer.Root().Pages()
   new_page = pdfw.from_pdfe_page(source_pdfe_doc, page_n)
   table.insert(Pages.Kids, pdfw.reference(new_page))
   Pages.Count = Pages.Count + 1
   new_page.Parent = pdfw.reference(Pages)
   local major, minor = pdfe.getversion(source_pdfe_doc)
   if major > pdf.major then
      pdf.major = major
      pdf.minor = minor
   elseif major == pdf.major then
      pdf.minor = math.max(pdf.minor, minor)
   end
end

function pdfw.save(pdf, filename)
   
   pdf.object_ids = {}
   pdf.max_id = 0
   pdf.xref = {}
   pdf.fh = io.open(filename, 'wb')
   
   pdf.fh:write(string.format("%%PDF-%d.%d\n", pdf.major, pdf.minor))
   
   local magic_bin = 'PDFW'
   magic_bin = {magic_bin:byte(1,-1)}
   pdf.fh:write("%")
   for i,v in ipairs(magic_bin) do
      pdf.fh:write(string.char(v+128))
   end
   pdf.fh:write("\n")

   --Note that this does not write out the trailer itself, because argument
   --|indirect| is not given.  Writing out the |Catalog| here would not work,
   --because |Info| is only referred to by the trailer, so it would get written
   --out (alongside the trailer) behind |xref|.
   pdfw.linearize(pdf, pdf.trailer)
   
   local startxref = pdf.fh:seek()
   pdf.fh:write(
      'xref\n',
      '0 ', #pdf.xref + 1, "\n",
      '0000000000 65535 f \n'
   )
   for id,pos in ipairs(pdf.xref) do
      pdf.fh:write(string.format("%010d", pos), ' 00000 n \n')
   end
   
   pdf.trailer.Size = #pdf.xref + 1
   pdf.fh:write("trailer\n", pdfw.linearize(pdf, pdf.trailer), "\n")
   
   pdf.fh:write("startxref\n", startxref, "\n")
   pdf.fh:write("%%EOF\n")
   pdf.fh:close()
   
   pdf.object_ids, pdf.max_id, pdf.xref, pdf.fh, pdf.trailer.Size = nil, nil, nil, nil, nil
end

function pdfw.update(pdf, filename, pdfe_doc, prune)
   
   pdf.pdfe_doc = pdfe_doc -- temporary
   
   local fh = io.open(filename, 'rb')
   fh:seek("end", -40)
   local prev = fh:read("a")
   fh:close()
   _,_,prev = prev:find('startxref%s+(%d+)%s+%%%%EOF')
   
   pdf.updating = true
   pdf.object_ids = {}
   pdf.max_id = pdf.trailer.Size
   pdf.xref = {}
   pdf.fh = io.open(filename, 'a+b')
   pdf.fh:seek("end")
   
   pdfw.linearize(pdf, pdf.trailer)
   for obj,_ in pairs(updated_objects[pdf.pdfe_doc]) do
      if original_object_ids[obj] then
	 pdfw.linearize(pdf, obj, true)
      end
   end

   local startxref = pdf.fh:seek()
   pdf.fh:write('xref\n',
		'0 1\n0000000000 65535 f \n')
   
   local function write_xref_section(start_id)
      while not pdf.xref[start_id] and start_id <= pdf.max_id do
	 start_id = start_id + 1
      end
      if start_id > pdf.max_id then return start_id end

      local next_id = start_id + 1
      while pdf.xref[next_id] do next_id = next_id + 1 end
      
      pdf.fh:write(start_id, ' ', next_id - start_id, "\n")
      for id = start_id, next_id - 1  do
	 pdf.fh:write(string.format("%010d", pdf.xref[id]), ' 00000 n \n')
      end

      return next_id
   end
      
   local id = 1
   while id <= pdf.max_id do id = write_xref_section(id) end
   assert(id == pdf.max_id + 1)
   
   pdf.trailer.Size = id
   pdf.trailer.Prev = prev
   pdf.fh:write("trailer\n", pdfw.linearize(pdf, pdf.trailer, false, true), "\n")
   
   pdf.fh:write("startxref\n", startxref, "\n")

   pdf.fh:write("%%EOF\n")
   pdf.fh:close()   
   pdf.updating = nil
end

return pdfw
