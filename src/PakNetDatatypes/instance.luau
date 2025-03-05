--!strict
--!native
--!optimize 2

local Pack = require(script.Parent.Parent.Parent.pack)

-- I want to avoid using pack.custom here as it adds a wrapper layer that may very slightly impact speed

local datatype = table.freeze({
	Eval = "any", -- Put refs last in unions
	Read = function(reader: Pack.ReaderData): any
		local inst = reader.refs[Pack.Reader.u16(reader)]
		if typeof(inst) ~= "Instance" then error(`Instance expected. Got {typeof(inst)}`) end
		return inst
	end,
	Write = function(writer: Pack.WriterData, value: any)
		if typeof(value) ~= "Instance" then error(`Instance expected. Got {typeof(value)}`) end

		local len = #writer.refs + 1
		writer.refs[len] = value
		Pack.Writer.alloc(writer, 2)
		Pack.Writer.u16(writer, len)
	end,
}) :: Pack.DatatypeInterface<any>

return datatype
