--!strict
--!optimize 2

-- Services
local Players = game:GetService("Players")
-- Modules
local LemonSignal = require(script.Parent.Parent.lemonsignal)
local Promise = require(script.Parent.Parent["typed-promise"])
local Ratelimit = require(script.Parent.Ratelimit)
local types = require(script.Parent.types)

local Server = {}
local ServerClass = { metatable = { __index = Server } }

type _Server<T, V, U..., W...> = types.Server<T, V, U..., W...> & {
	OnEvent: LemonSignal.Signal<(Player, T, U...)> | { _head: any? }, -- Public is marked read only
	OnRateLimited: LemonSignal.Signal<Player>,
	OnParseError: LemonSignal.Signal<Player, string>,

	_events: types.Events,
	_params: types.Schema<T, U...>,
	_returns: types.Schema<V, W...>?,
	_timeout: number?,
	_ratelimit: Ratelimit.RateLimit?,

	_RateLimited: (self: types.Server<T, V, U..., W...>, player: Player) -> boolean,
}

Server.ClassName = "Server"

function Server._RateLimited<T, V, U..., W...>(self: _Server<T, V, U..., W...>, player: Player): boolean
	if self._ratelimit then
		local ratelimited = not self._ratelimit:RequestAllowed(player)
		if ratelimited then self.OnRateLimited:Fire(player) end
		return ratelimited
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

	self._events.r:FireClient(to, packet, refs)
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

	self._events.u:FireClient(to, packet, refs)
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
		result = { self._events.f:InvokeClient(to, packet, refs) }
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

--[=[
	@method InvokeAsync
	@within Server
	@param to Player
	@param args ..any -- The arguments tuple specified by the params schema
	@return Promise

	Asynchronous variant of Invoke that does not block the calling thread, and instead returns a Promise  

	:::danger
	Without an timeout set, the promise can yield forever.

	You could use the Promise:timeout(n) method as well, just make sure to do this everywhere if you are removing the timeout.  
	You may want to set timeout very high as opposed to removing it, as without it the promise will raise a warning after 15 seconds.
	:::
]=]
function Server.InvokeAsync<T, V, U..., W...>(self: _Server<T, V, U..., W...>, to: Player, v1: T, ...: U...): Promise.TypedPromise<V, W...>
	assert(self._events.f, "[PAKNET]: To use 'InvokeAsync' you must have 'f' in the remoteType.")
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
			local result = { self._events.f:InvokeClient(to, packet, refs) }
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
				warn(debug.traceback("[PAKNET]: Warning: Possible infinite yield in Server.Invoke"))
			end)
		end
	end) :: any
end

--- @class Server
--- @external Signal https://data-oriented-house.github.io/LemonSignal/classes/signal.html
--- @external Promise https://eryn.io/roblox-lua-promise/api/Promise
function ServerClass.new<T, V, U..., W...>(events: types.Events, settings: types.RemoteSettings<T, V, U..., W...>): types.Server<T, V, U..., W...>
	local self: _Server<T, V, U..., W...> = setmetatable({}, ServerClass.metatable) :: any

	self._events = events
	self._params = settings.params
	self._returns = settings.returns
	self._timeout = settings.timeout

	--[=[
		@prop onEvent Signal
		@within Server
		A signal that fires when a Remote is fired with FireServer or FireServerUnreliable from the client
		if self._events.r or self._events.u then self.onEvent = LemonSignal.new() end
	]=]

	--[=[
		@prop onRateLimited Signal
		@within Server
		A signal that fires when the server-side ratelimit rejects a packet. Sends the player that tripped the ratelimit (even if global).
		This can be a sign of tampering, but there may still be cases where flucuations in network latency cause false positives.
		The server rate limit is adjusted to be slightly less strict than the client rate limit to compensate for this.
	]=]
	self.OnRateLimited = LemonSignal.new()

	--[=[
		@prop onParseError Signal
		@within Server
		A signal that fires when parsing an incoming packet errors. Sends the player that caused the parse error, followed by the error.
		If this happens, it means either a client is tampering with something or you have an issue with your remotes on the client side.
		I would recommend
	]=]
	self.OnParseError = LemonSignal.new()

	if settings.rateLimit then self._ratelimit = Ratelimit.new(settings.rateLimit) end

	local function parsePacket(player, buff, refs): ...any
		local s, result = pcall(function()
			return self._params:Read(buff, refs)
		end)

		if not s then
			self.OnParseError:Fire(player, result)
			error(`Parse error for {player}: {result}`)
		end

		return unpack(result)
	end

	if self._events.f then
		self._events.f.OnServerInvoke = function(player: Player, buff, refs)
			if self.OnInvoke and not self:_RateLimited(player) then return self.OnInvoke(player, parsePacket(player, buff, refs)) end
			return nil :: any
		end
	end
	if self._events.r then
		self._events.r.OnServerEvent:Connect(function(player, buff, refs)
			if self.OnEvent._head and not self:_RateLimited(player) then -- Check there are any connections and if we are rate limited
				self.OnEvent:Fire(player, parsePacket(player, buff, refs))
			end
		end)
	end
	if self._events.u then
		self._events.u.OnServerEvent:Connect(function(player, buff, refs)
			if self.OnEvent._head and not self:_RateLimited(player) then -- Check there are any connections and if we are rate limited
				self.OnEvent:Fire(player, parsePacket(player, buff, refs))
			end
		end)
	end

	return self
end

return ServerClass
