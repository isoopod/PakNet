--!strict
--!native
--!optimize 2

local Pack = require(script.Parent.Parent.Parent.Pack)

local datatype = table.freeze({
	Eval = "Instance",
	Read = function(reader: Pack.ReaderData): any
		local inst = table.remove(reader.refs, 1)
		if typeof(inst) ~= "Instance" then error(`Instance expected. Got {typeof(inst)}`) end
		return inst
	end,
	Write = function(writer: Pack.WriterData, value: any)
		if typeof(value) ~= "Instance" then error(`Instance expected. Got {typeof(value)}`) end
		Pack.Writer.addRef(writer, value)
	end,
}) :: Pack.DatatypeInterface<any>

return datatype
