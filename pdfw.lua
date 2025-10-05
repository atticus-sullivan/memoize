#!/usr/bin/env texlua

local tracing = true
local trace, tinspect, tracein, traceout
do
   local tracing_indent = ''
   trace = function(s, ...)
      if tracing then print(tracing_indent .. s, ...) end
   end
   tinspect = function(x, levels)
      if tracing then inspect(x, levels, tracing_indent) end
   end
   tracein = function() tracing_indent = tracing_indent .. '  ' end
   traceout = function() tracing_indent = tracing_indent:sub(1, -3) .. "" end
end

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

--Assigning nil to a table removes the entry, so we need this to put a null
--value into a dict or array, don't we?
do --null
   local metatable_null = { pdfw = 'null', __tostring = function() return 'null' end }
   function pdfw.null(value) return setmetatable({}, metatable_null) end
end

do --name
   local metatable_name = {
      pdfw = 'name',
      __tostring = function(obj)
	 return '/' .. obj.value:gsub('/', '#2F')
      end,
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
   local function is_legal_array_key(key)
      return math.type(key) == "integer" and key > 0
   end
   local function is_legal_dictionary_key(key)
      return type(key) == "string"
   end
      
   local mt_index = function(tbl, key, pdfe_doc, legal_index_f)
      assert(legal_index_f(key))
      value = tbl[key]
      if is_pdfe_triplet(value) then
	 value = pdfw.from_pdfe_triplet(pdfe_doc, table.unpack(value))
	 tbl[key] = value
      end
      return value
   end
   
   local mt_newindex = function(tbl, key, value, legal_index_f)
      assert(legal_index_f(key))
      tbl[key] = value
   end
   
   local mt_pairs = function(tbl, pdfe_doc, pairs_f)
      for key, value in pairs_f(tbl) do
	 if is_pdfe_triplet(value) and not tbl[key] then
	    tbl[key] = pdfw.from_pdfe_triplet(pdfe_doc, table.unpack(value))
	 end
      end
      return pairs_f(tbl)
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
	       return mt_newindex(tbl,k,v,is_legal_array_key) end,
	    __pairs = function(t)
	       return mt_pairs(tbl,pdfe_doc,ipairs) end,
	    __len = function(t) return #tbl end,
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
		 mt_newindex(tbl,k,v,is_legal_dictionary_key) end,
	   __pairs = function(t)
	      return mt_pairs(tbl,pdfe_doc,pairs) end,
	 }
      )
   end

end --array & dictionary

do --stream
   metatable_stream = { pdfw = 'stream' }
   function pdfw.from_pdfe_stream(pdfe_doc, stream, dictionary)
      return setmetatable(
	 { stream = stream, dictionary = dictionary, pdfe_doc = pdfe_doc },
	 metatable_stream
      )
   end
end

do --reference

   local function ref_index_error()
      error("Cannot index a reference! Did you forget to call the reference to resolve it?", 2)
   end

   local reference_resolutions = {}
   setmetatable(reference_resolutions, { __mode = 'k' } )

   local metatable_pdfw_reference = {
      pdfw = "pdfw_reference", __index = ref_index_error, __newindex = ref_index_error,
      __call = function(obj)
	 return rawget(obj, 'referenced_pdfw_obj')
      end,
   }

   function pdfw.reference(pdfw_obj)
      return setmetatable(
	 { referenced_pdfw_obj = pdfw_obj },
	 metatable_pdfw_reference
      )
   end

   local metatable_pdfe_reference = {
      pdfw = "pdfe_reference", __index = ref_index_error, __newindex = ref_index_error,
      __call = function(obj, id)
	 if id then
	    return rawget(obj, 'referenced_pdfe_obj_id')
	 else
	    local pdfe_doc = rawget(obj,'pdfe_doc')
	    local reference_resolutions_for_doc = reference_resolutions[pdfe_doc]
	    if not reference_resolutions_for_doc then
	       reference_resolutions_for_doc = {}
	       reference_resolutions[pdfe_doc] = reference_resolutions_for_doc
	    end
	    local referenced_pdfe_obj_id = rawget(obj, 'referenced_pdfe_obj_id')
	    local reference_resolution = reference_resolutions_for_doc[referenced_pdfe_obj_id]
	    if not reference_resolution then
	       local pdfe_reference = rawget(obj, 'pdfe_reference')
	       reference_resolution = pdfw.from_pdfe_triplet(
		  pdfe_doc, pdfe.getfromreference(pdfe_reference))
	       reference_resolutions_for_doc[referenced_pdfe_obj_id] = reference_resolution
	    end
	    return reference_resolution
	 end
      end,
   }

   function pdfw.from_pdfe_reference(pdfe_doc, pdfe_reference, referenced_pdfe_obj_id)
      return setmetatable({ pdfe_doc = pdfe_doc,
			    pdfe_reference = pdfe_reference,
			    referenced_pdfe_obj_id = referenced_pdfe_obj_id },
	 metatable_pdfe_reference)
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

do --linearize

   local linearize, distribute, distributor
   
   linearize = function(pdf, obj, indirect)
      if indirect then
	 if not pdf.objects[obj] then
	    pdf.max_id = pdf.max_id + 1
	    pdf.objects[obj] = pdf.max_id
	    local pdf_repr = distribute(obj, distributor)(obj, pdf)
	    local id = pdf.objects[obj]
	    pdf.xref[id] = pdf.fh:seek()
	    pdf.fh:write(id .. ' 0 obj\n', pdf_repr, '\nendobj\n')
	    return pdf_repr
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
      ["nil"] = function() return 'null' end,                        --null
      boolean = tostring,
      number = tostring,
      name = tostring,
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
	    child_obj = obj[key]
	    child_reprs[i] = '/' .. key .. ' ' .. pdfw.linearize(pdf, child_obj)
	    i = i + 1
	 end
	 child_reprs[i] = '>>'
	 return table.concat(child_reprs, ' ', 0)
      end,
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
      pdfe_reference = function(obj, pdf)
	 if pdf.updating then
	    return obj(true) .. ' 0 R' --obj(true) --> object id
	 else
	    local referenced_pdfw_object = obj()
	    pdfw.linearize(pdf, referenced_pdfw_object, true)
	    return pdf.objects[referenced_pdfw_object] .. ' 0 R'
	 end
      end,
      pdfw_reference = function(obj, pdf)
	 local referenced_pdfw_object = obj()
	 pdfw.linearize(pdf, referenced_pdfw_object, true)
	 return pdf.objects[referenced_pdfw_object] .. ' 0 R'
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
   
   pdf.objects = {}
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
   
   pdf.objects, pdf.max_id, pdf.xref, pdf.fh, pdf.trailer.Size = nil, nil, nil, nil, nil
end

function pdfw.update(pdf, filename)
   local fh = io.open(filename, 'rb')
   fh:seek("end", -40)
   local prev = fh:read("a")
   fh:close()
   _,_,prev = prev:find('startxref%s+(%d+)%s+%%%%EOF')
   
   pdf.updating = true
   pdf.objects = {}
   pdf.max_id = pdf.trailer.Size
   pdf.xref = {}
   pdf.fh = io.open(filename, 'a+b')
   pdf.fh:seek("end")
   
   pdfw.linearize(pdf, pdf.trailer, false, true)

   local startxref = pdf.fh:seek()
   pdf.fh:write(
      'xref\n0 1\n0000000000 65535 f \n',
      trailer.Size + 1, ' ', pdf.max_id - pdf.trailer.Size, "\n"
   )
   for id = pdf.trailer.Size + 1, pdf.max_id  do
      pos = pdf.xref[id]
      pdf.fh:write(string.format("%010d", pos), ' 00000 n \n')
   end
   
   pdf.trailer.Size = pdf.max_id + 1
   pdf.trailer.Prev = prev
   pdf.fh:write("trailer\n", pdfw.linearize(pdf, pdf.trailer, false, true), "\n")
   
   pdf.fh:write("startxref\n", startxref, "\n")
   
   pdf.fh:write("%%EOF\n")
   pdf.fh:close()   
   pdf.updating = nil
end

return pdfw
