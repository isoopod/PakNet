--!strict

-- Return a dummy version of PakNet in edit mode so tooling can depend on modules using PakNet

local Pack = require(script.Parent.Parent.Pack)
local Promise = require(script.Parent.Parent.Promise)
local Signal = require(script.Parent.Parent.Signal)
local types = require(script.Parent.types)

local dummy = {}

local meta = {}
function meta.AddSanityCheck() end
function meta.InvokeAsync(self: any)
	return Promise.new(function(_, reject, onCancel)
		-- Timeout handling
		if self._timeout then
			local timeoutThread

			-- Handle cancellation
			onCancel(function()
				pcall(task.cancel, timeoutThread)
			end)

			timeoutThread = task.delay(self._timeout :: any, function()
				reject(`Invoke timed out after {self._timeout} seconds.`)
			end)
		end
	end)
end
function meta.Invoke(self: any)
	local thread = coroutine.running()

	if self._timeout then task.delay(self._timeout :: any, function()
		task.spawn(thread)
	end) end

	coroutine.yield()
	return nil, nil
end
function meta.FireExceptUnreliable() end
function meta.FireAllUnreliable() end
function meta.FireListUnreliable() end
function meta.FireUnreliable() end
function meta.FireExcept() end
function meta.FireAll() end
function meta.FireList() end
function meta.Fire() end

meta.ClassName = "Server"

local function newDummyRemote<T, V, U..., W...>(settings: types.RemoteSettings<T, V, U..., W...>)
	local self = setmetatable({}, { __index = meta })

	self.OnEvent = Signal.new()

	self.OnRateLimited = Signal.new()
	self.OnParseError = Signal.new()
	self.OnCheckFail = Signal.new()

	self._timeout = settings.timeout

	return self
end

function dummy.Mount(_, _, remoteTable: types.RemoteTable)
	local remotes: { [string]: any } = setmetatable({}, {
		-- Only iterate over remotes in GI (This is to ignore Signal if added)
		__iter = function(self)
			local nextKey: any, nextVal: any = next(self, nil)
			return function()
				while nextKey do
					local k, v = nextKey, nextVal
					nextKey, nextVal = next(self, nextKey)
					if type(v) == "table" and (v.ClassName == "Server" or v.ClassName == "Client") then return k, v end
				end
				return nil
			end
		end,
	})

	for name, settings in remoteTable do
		remotes[name] = newDummyRemote(settings)
	end

	return remotes
end

function dummy.DefineRemote(_, settings)
	return settings
end

function dummy.Schema()
	return nil
end

local signals = {}
function dummy.LoadGlobalSignal()
	return function(identifier: string)
		signals[identifier] = signals[identifier] or Signal.new()
		return signals[identifier]
	end
end

-- Retain standard Pack integration so schemas dont error
function dummy.__index(self, key: any)
	if dummy[key] then return dummy[key] end

	local redirects = rawget(self, "_redirects") :: { [string]: any }
	if redirects[key] then return redirects[key] end

	return Pack[key]
end

local object = setmetatable({
	-- Redirects some datatype lookups that would go to Pack to PakNet specific datatypes
	-- These don't need to be lazy-loaded, as PakNet is probably only going to be used on the main thread
	_redirects = {
		Instance = require(script.Parent.PakNetDatatypes.Instance),
		Ref = require(script.Parent.PakNetDatatypes.Ref),
		-- We will keep the default behaviour of 'any' once implemented in Pack, and explain the difference between any and ref in the PakNet documentation
	},
}, dummy) :: any

return object
