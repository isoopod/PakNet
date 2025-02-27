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

function Server.Fire<T, V, U..., W...>(self: _Server<T, V, U..., W...>, to: Player, v1: T, ...: U...)
	assert(self._events.r, "[PAKNET]: To use 'Fire' you must have 'r' in the remoteType.")

	local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding packet for transmission: {packet}\nArguments: {v1}, {table.concat({ ... }, ", ")}`) end

	self._events.r:FireClient(to, packet, --[[>>> Can be simplified next Pack Update]] #refs > 0 and refs or nil)
end

function Server.FireAll<T, V, U..., W...>(self: _Server<T, V, U..., W...>, v1: T, ...: U...)
	for _, v in Players:GetPlayers() do
		self:Fire(v, v1, ...)
	end
end

function Server.FireList<T, V, U..., W...>(self: _Server<T, V, U..., W...>, players: { Player }, v1: T, ...: U...)
	for _, v in players do
		self:Fire(v, v1, ...)
	end
end

function Server.FireExcept<T, V, U..., W...>(self: _Server<T, V, U..., W...>, except: { Player }, v1: T, ...: U...)
	for _, v in Players:GetPlayers() do
		if not table.find(v, except) then self:Fire(v, v1, ...) end
	end
end

function Server.FireUnreliable<T, V, U..., W...>(self: _Server<T, V, U..., W...>, to: Player, v1: T, ...: U...)
	assert(self._events.u, "[PAKNET]: To use 'FireUnreliable' you must have 'u' in the remoteType.")

	local s, packet: buffer, refs: { any } = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding unreliable packet for transmission: {packet}\nArguments: {v1}, {table.concat({ ... }, ", ")}`) end

	self._events.u:FireClient(to, packet, --[[>>> Can be simplified next Pack Update]] #refs > 0 and refs or nil)
end

function Server.FireAllUnreliable<T, V, U..., W...>(self: _Server<T, V, U..., W...>, v1: T, ...: U...)
	for _, v in Players:GetPlayers() do
		self:FireUnreliable(v, v1, ...)
	end
end

function Server.FireListUnreliable<T, V, U..., W...>(self: _Server<T, V, U..., W...>, players: { Player }, v1: T, ...: U...)
	for _, v in players do
		self:FireUnreliable(v, v1, ...)
	end
end

function Server.FireExceptUnreliable<T, V, U..., W...>(self: _Server<T, V, U..., W...>, except: { Player }, v1: T, ...: U...)
	for _, v in Players:GetPlayers() do
		if not table.find(v, except) then self:FireUnreliable(v, v1, ...) end
	end
end

function ServerClass.new<T, V, U..., W...>(events: types.Events, settings: types.RemoteSettings<T, V, U..., W...>): types.Server<T, V, U..., W...>
	local self: _Server<T, V, U..., W...> = setmetatable({}, ServerClass.metatable) :: any

	if self._events.r or self._events.u then self.onEvent = LemonSignal.new() end
	self.onRateLimited = LemonSignal.new()

	self._events = events
	self._params = settings.params
	self._returns = settings.returns

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
