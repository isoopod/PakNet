--!strict
--!optimize 2

-- Modules
local Promise = require(script.Parent.Parent.Promise)
local Ratelimit = require(script.Parent.Ratelimit)
local Signal = require(script.Parent.Parent.Signal)
local types = require(script.Parent.types)

local Client = {}
local ClientClass = { metatable = { __index = Client } }

type _Client<T, V, U..., W...> = types.Client<T, V, U..., W...> & {
	OnClientEvent: any,

	_events: types.Events,
	_params: types.Schema<T, U...>,
	_returns: types.Schema<V, W...>?,
	_timeout: number?,
	_ratelimit: Ratelimit.RateLimit?,

	_RateLimited: (self: types.Client<T, V, U..., W...>) -> boolean,
}

Client.ClassName = "Client"

local function concatArgs(...)
	local res: { string } = {}
	for _, v in { ... } do
		table.insert(res, tostring(v))
	end
	return table.concat(res, ", ")
end

function Client._RateLimited<T, V, U..., W...>(self: _Client<T, V, U..., W...>): boolean
	if self._ratelimit then
		local ratelimited = not self._ratelimit:RequestAllowed()
		if ratelimited then self.OnRateLimited:Fire() end
		return ratelimited
	end
	return false
end

--- @method FireServer
--- @within Client
--- @param args ...any -- The arguments tuple specified by the params schema
function Client.FireServer<T, V, U..., W...>(self: _Client<T, V, U..., W...>, v1: T, ...: U...)
	assert(self._events.r, "[PAKNET]: To use 'Fire' you must have 'r' in the remoteType.")

	if self:_RateLimited() then return end

	local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding packet for transmission: {packet}\nArguments: {v1}, {concatArgs(...)}`) end

	self._events.r:FireServer(packet, refs)
end

--[=[
	@method FireServerUnreliable
	@within Client
	@param args ...any -- The arguments tuple specified by the params schema

	:::warning[Unreliable]
	This is the UnreliableRemoteEvent version of [Client:FireServer].  
	Unreliable variants can have reduced network traffic, at the cost of having a payload limit of 900 bytes, being unordered, and not guaranteed to be recieved.  
	This makes them good for non-essential events such as those for VFX, or constantly updating data that needs to be replicated.
	:::
]=]
function Client.FireServerUnreliable<T, V, U..., W...>(self: _Client<T, V, U..., W...>, v1: T, ...: U...)
	assert(self._events.u, "[PAKNET]: To use 'FireUnreliable' you must have 'u' in the remoteType.")

	if self:_RateLimited() then return end

	local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding unreliable packet for transmission: {packet}\nArguments: {v1}, {concatArgs(...)}`) end

	self._events.u:FireServer(packet, refs)
end

--[=[
	@method InvokeServer
	@within Client
	@yields
	@param args ..any -- The arguments tuple specified by the params schema
	@return ...any -- The return tuple specified by the returns schema, or nil if it times out
	Invokes `OnClientInvoke` on the client side, halting the thread until `OnClientInvoke` returns or the invocation times out, determined by the remote settings.  
	Will return nil if the invocation times out or the return value does not pass all the sanity tests.

	:::warning
	If the server never returns anything, the thread will be left yielding forever unless a timeout is specified.
	:::
]=]
function Client.InvokeServer<T, V, U..., W...>(self: _Client<T, V, U..., W...>, v1: T, ...: U...): (V, W...)
	assert(self._events.f, "[PAKNET]: To use 'InvokeServer' you must have 'f' in the remoteType.")

	if self:_RateLimited() then return nil :: any, nil :: any end

	local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding packet for transmission: {packet}\nArguments: {v1}, {concatArgs(...)}`) end

	local result, returnRefs
	local finished = false

	local thread = coroutine.running()
	local invokeThread: thread, timeoutThread: thread

	invokeThread = task.spawn(function()
		result, returnRefs = self._events.f:InvokeServer(packet, refs)
		pcall(task.cancel, timeoutThread)
		finished = true
		task.spawn(thread)
	end)

	if self._timeout then
		-- If self._timeout is set, wait up to that duration
		timeoutThread = task.delay(self._timeout, function()
			if not finished then
				warn(`[PAKNET]: InvokeServer timed out after {self._timeout} seconds.`)
				pcall(task.cancel, invokeThread)
				finished = true
				result = nil
				task.spawn(thread)
			end
		end)
	else
		-- If no timeout is set, warn after 15 seconds about a possible infinite yield
		timeoutThread = task.delay(15, function()
			if not finished then warn(debug.traceback("[PAKNET]: Warning: Possible infinite yield in Client.InvokeServer")) end
		end)
	end

	coroutine.yield()

	if result == nil then return nil, nil :: any end

	assert(self._returns, "[PAKNET]: Remote function missing `returns` field.")
	return self._returns:Read(result, returnRefs)
end

--[=[
	@method InvokeServerAsync
	@within Client
	@param args ..any -- The arguments tuple specified by the params schema
	@return Promise

	Asynchronous variant of [Client.InvokeServer] that does not block the calling thread, and instead returns a Promise  

	:::warning
	Without an timeout set, the promise can yield forever if the server never returns anything.

	You could use the Promise:timeout(n) method as well, just make sure to do this everywhere if you are removing the timeout.  
	You may want to set timeout very high as opposed to removing it, as without it the promise will raise a warning after 15 seconds.
	:::
]=]
function Client.InvokeServerAsync<T, V, U..., W...>(self: _Client<T, V, U..., W...>, v1: T, ...: U...): Promise.TypedPromise<V, W...>
	assert(self._events.f, "[PAKNET]: To use 'InvokeServerAsync' you must have 'f' in the remoteType.")
	assert(self._returns, "[PAKNET]: Remote function missing `returns` field.")

	local vararg = { ... }

	return Promise.new(function(resolve, reject, onCancel)
		if self:_RateLimited() then reject("Request dropped due to rate limit") end

		local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, unpack(vararg))
		if not s then
			reject(`Error encoding packet for transmission: {packet}\nArguments: {v1}, {concatArgs(unpack(vararg))}`)
			return
		end

		local invokeThread: thread, timeoutThread: thread

		-- Handle cancellation
		onCancel(function()
			pcall(task.cancel, timeoutThread)
			pcall(task.cancel, invokeThread)
		end)

		-- Invoke the client
		invokeThread = task.spawn(function()
			local packet2, returnRefs = self._events.f:InvokeServer(packet, refs)

			local s2, result = pcall(function()
				return { self._returns:Read(packet2, returnRefs) }
			end)

			if not s2 then reject(`Error parsing return packet: {result}`) end

			pcall(task.cancel, timeoutThread)
			resolve(unpack(result))
		end)

		-- Timeout handling
		if self._timeout then
			timeoutThread = task.delay(self._timeout, function()
				pcall(task.cancel, invokeThread)
				reject(`Invoke timed out after {self._timeout} seconds.`)
			end)
		else
			-- Warn after 15 seconds if no timeout is set
			timeoutThread = task.delay(15, function()
				warn(debug.traceback("[PAKNET]: Warning: Possible infinite yield in Client.InvokeServer"))
			end)
		end
	end) :: any
end

--[=[
	@class Client
	While a created remote has the type of both Server and Client, You will only have access to the properties and methods here in scripts on the Client Side.
	Client remotes in PakNet allow clients to send data to the server, request information via remote functions, and listen for server events.
]=]
function ClientClass.new<T, V, U..., W...>(events: types.Events, settings: types.RemoteSettings<T, V, U..., W...>): types.Client<T, V, U..., W...>
	local self: _Client<T, V, U..., W...> = setmetatable({}, ClientClass.metatable) :: any

	self._events = events
	self._params = settings.params
	self._returns = settings.returns
	self._timeout = settings.timeout

	--[=[
		@prop OnClientEvent Signal
		@within Client
		A signal that fires when a Remote is fired from the server with Fire or FireUnreliable (and their variants)
	]=]
	if self._events.r or self._events.u then self.OnClientEvent = Signal.new() :: any end

	--[=[
		@prop OnRateLimited Signal
		@within Client
		A signal that fires when the client-side ratelimit rejects sending packet.
		This can be used to figure out when you have exhausted your budget for the remote.
	]=]
	self.OnRateLimited = Signal.new()

	--[=[
		@prop OnClientInvoke ((any...) -> (any...))?
		@within Client
		When using a remote function from server to client, the OnClientInvoke handler must be assigned on the client. This is the same as regular remote functions.  
		The function must take in the `params` tuple, and return the `returns` tuple.

		```lua
		-- example.client.luau
		
		-- SomeRemoteFunction is a remote with remoteType `f`, param of `Boolean` and return of `String8`
		network.SomeRemoteFunction.OnClientInvoke = function(player, val: boolean)
			if val then
				return "True"
			else
				return "False"
			end
		end
		```

		:::tip
		You should set a timeout value in your remote settings if you are using `OnClientInvoke`
		:::
	]=]

	if settings.rateLimit then
		settings.rateLimit.global = true -- Always treat as global on client
		self._ratelimit = Ratelimit.new(settings.rateLimit)
	end

	if self._events.f then
		self._events.f.OnClientInvoke = function(buff, refs)
			if self.OnClientInvoke then
				local returns = { self.OnClientInvoke(self._params:Read(buff, refs)) }

				assert(self._returns, "[PAKNET]: Remote function missing `returns` field.")
				local s, packet: buffer, returnRefs: { any } = pcall(self._returns.Write, self._returns, unpack(returns))
				if not s then error(`[PAKNET]: Error encoding return packet for transmission: {packet}\nArguments: {concatArgs(unpack(returns))}`) end

				return packet, returnRefs
			end
			return nil :: any, nil :: any
		end
	end
	if self._events.r then
		self._events.r.OnClientEvent:Connect(function(buff, refs)
			if self.OnClientEvent._head then -- Check there are any connections and if we are rate limited
				self.OnClientEvent:Fire(self._params:Read(buff, refs))
			end
		end)
	end
	if self._events.u then
		self._events.u.OnClientEvent:Connect(function(buff, refs)
			if self.OnClientEvent._head then -- Check there are any connections and if we are rate limited
				self.OnClientEvent:Fire(self._params:Read(buff, refs))
			end
		end)
	end

	return self
end

return ClientClass
