--!strict
--!native
--!optimize 2

local types = require(script.Parent.Parent.Parent._Index["isoopod_pack@0.2.0"].pack.Types) -- TODO: Export needed Pack types for external datatypes

-- I want to avoid using pack.custom here as it adds a wrapper layer that may very slightly impact speed

local datatype = table.freeze({
	Eval = "any", -- Put refs last in unions
	Read = function(Reader: types.Reader): any
		local inst = Reader.refs[Reader:u16()]
		if typeof(inst) ~= "Instance" then error(`Instance expected. Got {typeof(inst)}`) end
		return inst
	end,
	Write = function(Writer: types.Writer, value: any)
		if typeof(value) ~= "Instance" then error(`Instance expected. Got {typeof(value)}`) end

		table.insert(Writer.refs, value :: any)
		Writer:alloc(2)
		Writer:u16(#Writer.refs)
	end,
}) :: types.DatatypeInterface<any>

return datatype
