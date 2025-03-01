--!strict
--!optimize 2

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Modules
local LemonSignal = require(ReplicatedStorage.Packages.lemonsignal)
local Promise = require(ReplicatedStorage.Packages["typed-promise"])
local Ratelimit = require(script.Parent.Ratelimit)
local types = require(script.Parent.types)

local Client = {}
local ClientClass = { metatable = { __index = Client } }

type _Client<T, V, U..., W...> = types.Client<T, V, U..., W...> & {
	onClientEvent: LemonSignal.Signal<(T, U...)> | { _head: any? }, -- Public is marked read only
	onRateLimited: LemonSignal.Signal<>,

	_events: types.Events,
	_params: types.ManualTuple<T, U...>,
	_returns: types.ManualTuple<V, W...>?,
	_timeout: number?,
	_ratelimit: Ratelimit.RateLimit?,

	_RateLimited: (self: types.Client<T, V, U..., W...>) -> boolean,
}

Client.ClassName = "Client"

function Client._RateLimited<T, V, U..., W...>(self: _Client<T, V, U..., W...>): boolean
	if self._ratelimit then
		local rateLimited = self._ratelimit:RequestAllowed()
		if rateLimited then self.onRateLimited:Fire() end
		return rateLimited
	end
	return false
end

--- @method FireServer
--- @within Client
--- @param args ...any -- The arguments tuple specified by the params schema
function Client.FireServer<T, V, U..., W...>(self: _Client<T, V, U..., W...>, v1: T, ...: U...)
	assert(self._events.r, "[PAKNET]: To use 'Fire' you must have 'r' in the remoteType.")

	local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding packet for transmission: {packet}\nArguments: {v1}, {table.concat({ ... }, ", ")}`) end

	self._events.r:FireServer(packet, --[[>>> Can be simplified next Pack Update]] #refs > 0 and refs or nil)
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

	local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding unreliable packet for transmission: {packet}\nArguments: {v1}, {table.concat({ ... }, ", ")}`) end

	self._events.u:FireServer(packet, --[[>>> Can be simplified next Pack Update]] #refs > 0 and refs or nil)
end

--[=[
	@method InvokeServer
	@within Client
	@yields
	@param args ..any -- The arguments tuple specified by the params schema
	@return ...any -- The return tuple specified by the returns schema, or nil if it times out

	:::warning
	If the server never returns anything, the thread will be left yielding forever unless a timeout is specified.
	:::
]=]
function Client.InvokeServer<T, V, U..., W...>(self: _Client<T, V, U..., W...>, v1: T, ...: U...): (V, W...)
	assert(self._events.f, "[PAKNET]: To use 'InvokeServer' you must have 'f' in the remoteType.")

	local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding packet for transmission: {packet}\nArguments: {v1}, {table.concat({ ... }, ", ")}`) end

	local result
	local finished = false

	local thread = coroutine.running()
	local invokeThread: thread, timeoutThread: thread

	invokeThread = task.spawn(function()
		result = { self._events.f:InvokeServer(packet, #refs > 0 and refs or nil) }
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

	return table.unpack(result or {}) :: any
end

--[=[
	@method InvokeServerAsync
	@within Client
	@param args ..any -- The arguments tuple specified by the params schema
	@external Promise https://eryn.io/roblox-lua-promise/api/Promise
	@return Promise

	Asynchronous variant of InvokeServer that does not block the calling thread, and instead returns a Promise  

	:::warning
	Without an timeout set, the promise can yield forever if the server never returns anything.

	You could use the Promise:timeout(n) method as well, just make sure to do this everywhere if you are removing the timeout.  
	You may want to set timeout very high as opposed to removing it, as without it the promise will raise a warning after 15 seconds.
	:::
]=]
function Client.InvokeServerAsync<T, V, U..., W...>(self: _Client<T, V, U..., W...>, v1: T, ...: U...): Promise.TypedPromise<V, W...>
	assert(self._events.f, "[PAKNET]: To use 'InvokeServerAsync' you must have 'f' in the remoteType.")
	local vararg = { ... }

	return Promise.new(function(resolve, reject, onCancel)
		local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, unpack(vararg))
		if not s then
			reject(`Error encoding packet for transmission: {packet}\nArguments: {v1}, {table.concat(vararg, ", ")}`)
			return
		end

		local invokeThread, timeoutThread

		-- Handle cancellation
		onCancel(function()
			pcall(task.cancel, timeoutThread)
			pcall(task.cancel, invokeThread)
		end)

		-- Invoke the client
		invokeThread = task.spawn(function()
			local result = { self._events.f:InvokeServer(packet, #refs > 0 and refs or nil) }
			pcall(task.cancel, timeoutThread)
			resolve(table.unpack(result))
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

--- @class Client
function ClientClass.new<T, V, U..., W...>(events: types.Events, settings: types.RemoteSettings<T, V, U..., W...>): types.Client<T, V, U..., W...>
	local self: _Client<T, V, U..., W...> = setmetatable({}, ClientClass.metatable) :: any

	self._events = events
	self._params = settings.params
	self._returns = settings.returns
	self._timeout = settings.timeout

	if self._events.r or self._events.u then self.onClientEvent = LemonSignal.new() end
	self.onRateLimited = LemonSignal.new()

	if settings.rateLimit then
		settings.rateLimit.global = true -- Always treat as global on client
		self._ratelimit = Ratelimit.new(settings.rateLimit)
	end

	if self._events.f then
		self._events.f.OnClientInvoke = function(buff, refs)
			if self.onClientInvoke and not self:_RateLimited() then return self.onClientInvoke(self._params:Read(buff, refs)) end
			return nil :: any
		end
	end
	if self._events.r then
		self._events.r.OnClientEvent:Connect(function(buff, refs)
			if self.onClientEvent._head and not self:_RateLimited() then -- Check there are any connections and if we are rate limited
				self.onClientEvent:Fire(self._params:Read(buff, refs))
			end
		end)
	end
	if self._events.u then
		self._events.u.OnClientEvent:Connect(function(buff, refs)
			if self.onClientEvent._head and not self:_RateLimited() then -- Check there are any connections and if we are rate limited
				self.onClientEvent:Fire(self._params:Read(buff, refs))
			end
		end)
	end

	return self
end

return ClientClass
