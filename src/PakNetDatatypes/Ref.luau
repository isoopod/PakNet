--!strict
--!native
--!optimize 2

local Pack = require(script.Parent.Parent.Parent.Pack)

local datatype = table.freeze({
	Eval = "any", -- Put refs last in unions
	Read = function(reader: Pack.ReaderData): any
		return table.remove(reader.refs, 1)
	end,
	Write = function(writer: Pack.WriterData, value: any)
		Pack.Writer.addRef(writer, value)
	end,
}) :: Pack.DatatypeInterface<any>

return datatype
