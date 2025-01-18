-- this is incomplete for now

---@meta

---@class
pdfe = {}

---@class pdfe.Document
---@class pdfe.Dictionary

---@param filename string
---@return pdfe.Document
function pdfe.open(filename) end

---@param doc pdfe.Document
function pdfe.close(doc) end

---@param doc pdfe.Document
---@return integer
function getnofpages(doc) end

---@param doc pdfe.Document
---@param pagenumber integer
---@return pdfe.Dictionary
function pdfe.getpage(doc, pagenumber) end

---@param dict pdfe.Dictionary
---@param boxname string e.g. "MediaBox"
---@return [number, number, number, number] x y width height
function pdfe.getbox(dict ,boxname) end
