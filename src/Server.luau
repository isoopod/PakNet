--!strict
--!optimize 2

-- Services
local Players = game:GetService("Players")
-- Modules
local Promise = require(script.Parent.Parent.Promise)
local Ratelimit = require(script.Parent.Ratelimit)
local Signal = require(script.Parent.Parent.Signal)
local types = require(script.Parent.types)

local Server = {}
local ServerClass = { metatable = { __index = Server } }

type _Server<T, V, U..., W...> = types.Server<T, V, U..., W...> & {
	OnEvent: any,

	_events: types.Events,
	_params: types.Schema<T, U...>,
	_returns: types.Schema<V, W...>?,
	_timeout: number?,
	_ratelimit: Ratelimit.RateLimit?,
	_sanityChecks: { (player: Player, T, U...) -> boolean? },
	_nChecks: number,

	_RateLimited: (self: any, player: Player) -> boolean,
	_DoChecks: (self: any, player: Player, ...any) -> boolean,
}

Server.ClassName = "Server"

local function concatArgs(...)
	local res: { string } = {}
	for _, v in { ... } do
		table.insert(res, tostring(v))
	end
	return table.concat(res, ", ")
end

function Server._RateLimited<T, V, U..., W...>(self: _Server<T, V, U..., W...>, player: Player): boolean
	if self._ratelimit then
		local ratelimited = not self._ratelimit:RequestAllowed(player)
		if ratelimited then self.OnRateLimited:Fire(player) end
		return ratelimited
	end
	return false
end

function Server._DoChecks<T, V, U..., W...>(self: _Server<T, V, U..., W...>, player: Player, ...: any)
	local passed = true

	for i = 1, self._nChecks do
		local success, status: boolean | string = pcall(self._sanityChecks[i], player, ...)
		if not success or status == false then
			passed = false
			self.OnCheckFail:Fire(player, not success and status :: string or "Check returned false")
			break
		end
	end

	return passed
end

--- @method Fire
--- @within Server
--- @param to Player
--- @param args ...any -- The arguments tuple specified by the params schema
function Server.Fire<T, V, U..., W...>(self: _Server<T, V, U..., W...>, to: Player, v1: T, ...: U...)
	assert(self._events.r, "[PAKNET]: To use 'Fire' you must have 'r' in the remoteType.")

	local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding packet for transmission: {packet}\nArguments: {v1}, {concatArgs(...)}`) end

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
		if not table.find(except, v) then self:Fire(v, v1, ...) end
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
	if not s then error(`[PAKNET]: Error encoding unreliable packet for transmission: {packet}\nArguments: {v1}, {concatArgs(...)}`) end

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
		if not table.find(except, v) then self:FireUnreliable(v, v1, ...) end
	end
end

--[=[
	@method Invoke
	@within Server
	@yields
	@param to Player
	@param args ..any -- The arguments tuple specified by the params schema
	@return ...any -- The return tuple specified by the returns schema, or nil if it times out
	Invokes `OnClientInvoke` on the client side, halting the thread until `OnClientInvoke` returns or the invocation times out, determined by the remote settings.  
	Will return nil if the invocation times out or the return value does not pass all the sanity tests.

	:::warning
	Invoking the client from the server should always be done with a timeout set in the remote settings.  
	In the event an exploiter modifies the client invoke callback to never return, 
	not having a callback will cause that thread to yield forever on the server, piling up in memory.  

	Many people will tell you never to invoke the client from the server in general, but there are valid use cases and its up to you if you want to use something or not. 
	:::
]=]
function Server.Invoke<T, V, U..., W...>(self: _Server<T, V, U..., W...>, to: Player, v1: T, ...: U...): (V, W...)
	assert(self._events.f, "[PAKNET]: To use 'Invoke' you must have 'f' in the remoteType.")

	local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding packet for transmission: {packet}\nArguments: {v1}, {concatArgs(...)}`) end

	local result, returnRefs
	local finished = false

	local thread = coroutine.running()
	local invokeThread: thread, timeoutThread: thread

	invokeThread = task.spawn(function()
		result, returnRefs = self._events.f:InvokeClient(to, packet, refs)
		pcall(task.cancel, timeoutThread)
		finished = true

		if not self:_DoChecks(to, unpack(result)) then
			warn("Value returned by InvokeClient did not pass all sanity tests")
			result = nil
		end

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

	if result == nil then return nil, nil :: any end

	assert(self._returns, "[PAKNET]: Remote function missing `returns` field.")
	local s2, result2 = pcall(function()
		return { self._returns:Read(result, returnRefs) }
	end)

	if not s2 then
		self.OnParseError:Fire(to, unpack(result2) :: any)
		error(`Parse error for {to}: {result}`)
	end

	return unpack(result2), nil :: any
end

--[=[
	@method InvokeAsync
	@within Server
	@param to Player
	@param args ..any -- The arguments tuple specified by the params schema
	@return Promise

	Asynchronous variant of [Server.Invoke] that does not block the calling thread, and instead returns a Promise  

	:::warning
	Without an timeout set, the promise can yield forever.

	You could use the Promise:timeout(n) method as well, just make sure to do this everywhere if you are removing the timeout.  
	You may want to set timeout very high as opposed to removing it, as without it the promise will raise a warning after 15 seconds.
	:::
]=]
function Server.InvokeAsync<T, V, U..., W...>(self: _Server<T, V, U..., W...>, to: Player, v1: T, ...: U...): Promise.TypedPromise<V, W...>
	assert(self._events.f, "[PAKNET]: To use 'InvokeAsync' you must have 'f' in the remoteType.")
	assert(self._returns, "[PAKNET]: Remote function missing `returns` field.")

	local vararg = { ... }

	return Promise.new(function(resolve, reject, onCancel)
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
			local packet2, returnRefs = self._events.f:InvokeClient(to, packet, refs)

			local s2, result = pcall(function()
				return { self._returns:Read(packet2, returnRefs) }
			end)

			if not s2 then
				self.OnParseError:Fire(to, unpack(result) :: any)
				reject(`Parse error for {to}: {result}`)
			end

			if not self:_DoChecks(to, unpack(result)) then reject("Value returned by InvokeClient did not pass all sanity tests") end

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

--[=[
	@method AddSanityCheck
	@within Server
	@param check (player: Player, ...any) -> boolean
	Directly attaches a sanity check to the remote, that will be checked before firing the OnEvent signal. 
	You can use this to avoid repeating input validation when you want to connect to the event in multiple places.
	Multiple sanity checks can be added to the same remote.

	The check is considered to be failed if it returns false or throws an error. If throwing an error, the error will be passed to the `OnCheckFail` signal.
	This lets you use assertions in your sanity checks, as they will be caught and handled by PakNet. True does not need to be explicitly returned.
	
	Sanity checks are also called for the return value of invokes.
]=]
function Server.AddSanityCheck<T, V, U..., W...>(self: _Server<T, V, U..., W...>, check: (player: Player, T, U...) -> boolean?)
	table.insert(self._sanityChecks, check)
	self._nChecks += 1
end

--[=[
	@class Server
	@external Signal https://data-oriented-house.github.io/LemonSignal/classes/signal.html
	@external Promise https://eryn.io/roblox-lua-promise/api/Promise
	While a created remote has the type of both Server and Client, You will only have access to the properties and methods here in scripts on the Server Side.
	Server remotes in PakNet allow the server to listen for client events, send data to specific clients, and enforce security measures such as rate limiting and sanity checks.

	Server remotes include additional security and utility features:  
	- **Sanity Checks**: Built-in support for validating incoming data before processing.  
	- **Rate Limiting**: Prevents spam by enforcing request limits per player or globally.  
	- **Tamper Detection**: Events fire when a packet is malformed or fails to deserialize.  
]=]
function ServerClass.new<T, V, U..., W...>(events: types.Events, settings: types.RemoteSettings<T, V, U..., W...>): types.Server<T, V, U..., W...>
	local self: _Server<T, V, U..., W...> = setmetatable({}, ServerClass.metatable) :: any

	self._events = events
	self._params = settings.params
	self._returns = settings.returns
	self._timeout = settings.timeout
	self._sanityChecks = {}
	self._nChecks = 0

	--[=[
		@prop OnEvent Signal
		@within Server
		A signal that fires when a Remote is fired from the client with FireServer or FireServerUnreliable (and their variants)
	]=]
	if self._events.r or self._events.u then self.OnEvent = Signal.new() :: any end

	--[=[
		@prop OnRateLimited Signal
		@within Server
		A signal that fires when the server-side ratelimit rejects a packet. Sends the player that tripped the ratelimit (even if global).
		This can be a sign of tampering, but there may still be cases where flucuations in network latency cause false positives.
		The server rate limit is adjusted to be slightly less strict than the client rate limit to compensate for this.
	]=]
	self.OnRateLimited = Signal.new() :: any

	--[=[
		@prop OnParseError Signal
		@within Server
		A signal that fires when parsing an incoming packet errors. Sends the player that caused the parse error, followed by the error.
		If this happens, it means either a client is tampering with something or you have an issue with your remotes on the client side.
	]=]
	self.OnParseError = Signal.new() :: any

	--[=[
		@prop OnCheckFail Signal
		@within Server
		A signal that fires when a sanity check attached to the remote fails. Sends the player which sent the packet that failed the check, as well as the error message.
	]=]
	self.OnCheckFail = Signal.new()

	--[=[
		@prop OnInvoke ((player: Player, any...) -> (any...))?
		@within Server
		When using a remote function from client to server, the OnInvoke handler must be assigned on the server. This is used in the same way as regular remote functions.  
		The function must take in a player and the `params` tuple, and return the `returns` tuple.

		```lua
		-- example.server.luau
		
		-- SomeRemoteFunction is a remote with remoteType `f`, param of `Boolean` and return of `String8`
		network.SomeRemoteFunction.OnInvoke = function(player, val: boolean)
			if val then
				return "True"
			else
				return "False"
			end
		end
		```
	]=]

	if settings.rateLimit then self._ratelimit = Ratelimit.new(settings.rateLimit) end

	local function parsePacket(player, buff, refs): ...any
		local s, result = pcall(function()
			return { self._params:Read(buff, refs) }
		end)

		if not s then
			self.OnParseError:Fire(player, unpack(result) :: any)
			error(`Parse error for {player}: {result}`)
		end

		return unpack(result)
	end

	if self._events.f then
		self._events.f.OnServerInvoke = function(player: Player, buff, refs)
			if self.OnInvoke and not self:_RateLimited(player) then
				local returns = { self.OnInvoke(player, parsePacket(player, buff, refs)) }

				assert(self._returns, "[PAKNET]: Remote function missing `returns` field.")
				local s, packet: buffer, returnRefs: { any } = pcall(self._returns.Write, self._returns, unpack(returns))
				if not s then error(`[PAKNET]: Error encoding return packet for transmission: {packet}\nArguments: {concatArgs(unpack(returns))}`) end

				return packet, returnRefs
			end
			return nil :: any, nil :: any
		end
	end
	if self._events.r then
		self._events.r.OnServerEvent:Connect(function(player, buff, refs)
			if self.OnEvent._head and not self:_RateLimited(player) then
				local packet = { parsePacket(player, buff, refs) }
				if self:_DoChecks(player, table.unpack(packet)) then self.OnEvent:Fire(player, table.unpack(packet)) end
			end
		end)
	end
	if self._events.u then
		self._events.u.OnServerEvent:Connect(function(player, buff, refs)
			if self.OnEvent._head and not self:_RateLimited(player) then
				local packet = { parsePacket(player, buff, refs) }
				if self:_DoChecks(player, table.unpack(packet)) then self.OnEvent:Fire(player, table.unpack(packet)) end
			end
		end)
	end

	return self
end

return ServerClass
