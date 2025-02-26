--!strict
--!optimize 2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local LemonSignal = require(ReplicatedStorage.Packages.lemonsignal)
local Ratelimit = require(script.Parent.Ratelimit)
local types = require(script.Parent.types)

local Server = {}
local ServerClass = { metatable = { __index = Server } }

type _Server<T, V, U..., W...> = types.Server<T, V, U..., W...> & {
	onEvent: LemonSignal.Signal<(Player, T, U...)> | { _head: any? }, -- Public is marked read only

	_events: types.Events,
	_params: types.ManualTuple<T, U...>,
	_returns: types.ManualTuple<V, W...>?,
	_timeout: number?,
	_ratelimit: Ratelimit.RateLimit?,

	_RateLimited: (self: types.Server<T, V, U..., W...>, player: Player) -> boolean,
}

function Server._RateLimited<T, V, U..., W...>(self: _Server<T, V, U..., W...>, player: Player): boolean
	if self._ratelimit then
		local rateLimited = self._ratelimit:RequestAllowed(player)
		if rateLimited then self.onRateLimited:Fire(player) end
		return rateLimited
	end
	return false
end

--- @method Fire
--- @within Server
--- @param to Player
--- @param args ...any -- The arguments tuple specified by the params schema
function Server.Fire<T, V, U..., W...>(self: _Server<T, V, U..., W...>, to: Player, v1: T, ...: U...)
	assert(self._events.r, "[PAKNET]: To use 'Fire' you must have 'r' in the remoteType.")

	local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding packet for transmission: {packet}\nArguments: {v1}, {table.concat({ ... }, ", ")}`) end

	self._events.r:FireClient(to, packet, --[[>>> Can be simplified next Pack Update]] #refs > 0 and refs or nil)
end

--- @method FireAll
--- @within Server
--- @param args ...any -- The arguments tuple specified by the params schema
--- Fires to all players in the server
function Server.FireAll<T, V, U..., W...>(self: _Server<T, V, U..., W...>, v1: T, ...: U...)
	assert(self._events.r, "[PAKNET]: To use 'FireAll' you must have 'r' in the remoteType.")
	for _, v in Players:GetPlayers() do
		self:Fire(v, v1, ...)
	end
end

--- @method FireList
--- @within Server
--- @param players {Player} -- The list of players to send to
--- @param args ...any -- The arguments tuple specified by the params schema
function Server.FireList<T, V, U..., W...>(self: _Server<T, V, U..., W...>, players: { Player }, v1: T, ...: U...)
	assert(self._events.r, "[PAKNET]: To use 'FireList' you must have 'r' in the remoteType.")
	for _, v in players do
		self:Fire(v, v1, ...)
	end
end

--- @method FireExcept
--- @within Server
--- @param except {Player} -- The list of players not to send to
--- @param args ...any -- The arguments tuple specified by the params schema
--- Fires to all players except those included in the except table
function Server.FireExcept<T, V, U..., W...>(self: _Server<T, V, U..., W...>, except: { Player }, v1: T, ...: U...)
	assert(self._events.r, "[PAKNET]: To use 'FireExcept' you must have 'r' in the remoteType.")
	for _, v in Players:GetPlayers() do
		if not table.find(v, except) then self:Fire(v, v1, ...) end
	end
end

--[=[
	@method FireUnreliable
	@within Server
	@param to Player
	@param args ...any -- The arguments tuple specified by the params schema

	:::warning[Unreliable]
	This is the UnreliableRemoteEvent version of [Server:Fire].  
	Unreliable variants can have reduced network traffic, at the cost of having a payload limit of 900 bytes, being unordered, and not guaranteed to be recieved.  
	This makes them good for non-essential events such as those for VFX, or constantly updating data that needs to be replicated.
	:::
]=]
function Server.FireUnreliable<T, V, U..., W...>(self: _Server<T, V, U..., W...>, to: Player, v1: T, ...: U...)
	assert(self._events.u, "[PAKNET]: To use 'FireUnreliable' you must have 'u' in the remoteType.")

	local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding unreliable packet for transmission: {packet}\nArguments: {v1}, {table.concat({ ... }, ", ")}`) end

	self._events.u:FireClient(to, packet, --[[>>> Can be simplified next Pack Update]] #refs > 0 and refs or nil)
end

--[=[
	@method FireAllUnreliable
	@within Server
	@param args ...any -- The arguments tuple specified by the params schema
	Fires to all players in the server

	:::warning[Unreliable]
	This is the UnreliableRemoteEvent version of [Sever:FireAll].  
	Unreliable variants can have reduced network traffic, at the cost of having a payload limit of 900 bytes, being unordered, and not guaranteed to be recieved.  
	This makes them good for non-essential events such as those for VFX, or constantly updating data that needs to be replicated.
	:::
]=]
function Server.FireAllUnreliable<T, V, U..., W...>(self: _Server<T, V, U..., W...>, v1: T, ...: U...)
	assert(self._events.u, "[PAKNET]: To use 'FireAllUnreliable' you must have 'u' in the remoteType.")
	for _, v in Players:GetPlayers() do
		self:FireUnreliable(v, v1, ...)
	end
end

--[=[
	@method FireListUnreliable
	@within Server
	@param players {Player} -- The list of players to send to
	@param args ...any -- The arguments tuple specified by the params schema

	:::warning[Unreliable]
	This is the UnreliableRemoteEvent version of [Server:FireList].  
	Unreliable variants can have reduced network traffic, at the cost of having a payload limit of 900 bytes, being unordered, and not guaranteed to be recieved.  
	This makes them good for non-essential events such as those for VFX, or constantly updating data that needs to be replicated.
	:::
]=]
function Server.FireListUnreliable<T, V, U..., W...>(self: _Server<T, V, U..., W...>, players: { Player }, v1: T, ...: U...)
	assert(self._events.u, "[PAKNET]: To use 'FireListUnreliable' you must have 'u' in the remoteType.")
	for _, v in players do
		self:FireUnreliable(v, v1, ...)
	end
end

--[=[
	@method FireExceptUnreliable
	@within Server
	@param except {Player} -- The list of players not to send to
	@param args ...any -- The arguments tuple specified by the params schema
	Fires to all players except those included in the except table

	:::warning[Unreliable]
	This is the UnreliableRemoteEvent version of [Server:FireExcept].  
	Unreliable variants can have reduced network traffic, at the cost of having a payload limit of 900 bytes, being unordered, and not guaranteed to be recieved.  
	This makes them good for non-essential events such as those for VFX, or constantly updating data that needs to be replicated.
	:::
]=]
function Server.FireExceptUnreliable<T, V, U..., W...>(self: _Server<T, V, U..., W...>, except: { Player }, v1: T, ...: U...)
	assert(self._events.u, "[PAKNET]: To use 'FireExceptUnreliable' you must have 'u' in the remoteType.")
	for _, v in Players:GetPlayers() do
		if not table.find(v, except) then self:FireUnreliable(v, v1, ...) end
	end
end

--[=[
	@method Invoke
	@within Server
	@yields
	@param to Player
	@param args ..any -- The arguments tuple specified by the params schema
	@return ...any -- The return tuple specified by the returns schema, or nil if it times out

	:::danger
	Invoking the client from the server should always be done with a timeout set in the remote settings.  
	In the event an exploiter modifies the client invoke callback to never return, 
	not having a callback will cause that thread to yield forever on the server, piling up in memory.  

	Many people will tell you never to invoke the client from the server in general, but there are valid use cases and its up to you if you want to use something or not. 
	:::
]=]
function Server.Invoke<T, V, U..., W...>(self: _Server<T, V, U..., W...>, to: Player, v1: T, ...: U...): (V, W...)
	assert(self._events.f, "[PAKNET]: To use 'Invoke' you must have 'f' in the remoteType.")

	local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding packet for transmission: {packet}\nArguments: {v1}, {table.concat({ ... }, ", ")}`) end

	local result
	local finished = false

	local thread = coroutine.running()
	local invokeThread: thread, timeoutThread: thread

	invokeThread = task.spawn(function()
		result = { self._events.f:InvokeClient(to, packet, #refs > 0 and refs or nil) }
		pcall(task.cancel, timeoutThread)
		finished = true
		task.spawn(thread)
	end)

	if self._timeout then
		-- If self._timeout is set, wait up to that duration
		timeoutThread = task.delay(self._timeout, function()
			if not finished then
				warn(`[PAKNET]: Invoke timed out after {self._timeout} seconds.`)
				pcall(task.cancel, invokeThread)
				finished = true
				result = nil
				task.spawn(thread)
			end
		end)
	else
		-- If no timeout is set, warn after 15 seconds about a possible infinite yield
		-- You really shouldn't be using server-side invokes without a timeout set.
		timeoutThread = task.delay(15, function()
			if not finished then warn(debug.traceback("[PAKNET]: Warning: Possible infinite yield in Server.Invoke")) end
		end)
	end

	coroutine.yield()

	return table.unpack(result or {}) :: any
end

--- @class Server
function ServerClass.new<T, V, U..., W...>(events: types.Events, settings: types.RemoteSettings<T, V, U..., W...>): types.Server<T, V, U..., W...>
	local self: _Server<T, V, U..., W...> = setmetatable({}, ServerClass.metatable) :: any

	if self._events.r or self._events.u then self.onEvent = LemonSignal.new() end
	self.onRateLimited = LemonSignal.new()

	self._events = events
	self._params = settings.params
	self._returns = settings.returns
	self._timeout = settings.timeout

	if settings.rateLimit then self._ratelimit = Ratelimit.new(settings.rateLimit) end

	if self._events.f then
		self._events.f.OnServerInvoke = function(player: Player, buff, refs)
			if self.onInvoke and not self:_RateLimited(player) then self.onInvoke(player, self._params:Read(buff, refs)) end
		end
	end
	if self._events.r then
		self._events.r.OnServerEvent:Connect(function(player, buff, refs)
			if self.onEvent._head and not self:_RateLimited(player) then -- Check there are any connections and if we are rate limited
				self.onEvent:Fire(player, self._params:Read(buff, refs))
			end
		end)
	end
	if self._events.u then
		self._events.u.OnServerEvent:Connect(function(player, buff, refs)
			if self.onEvent._head and not self:_RateLimited(player) then -- Check there are any connections and if we are rate limited
				self.onEvent:Fire(player, self._params:Read(buff, refs))
			end
		end)
	end

	return self
end

return ServerClass
