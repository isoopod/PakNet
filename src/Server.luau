--!strict
--!optimize 2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local LemonSignal = require(ReplicatedStorage.Packages.lemonsignal)
local types = require(script.Parent.types)

local Server = {}
local ServerClass = { metatable = { __index = Server } }

type _Server<T, V, U..., W...> = types.Server<T, V, U..., W...> & {
	onEvent: LemonSignal.Signal<(Player, T, U...)> | { _head: any? }, -- Public is marked read only

	_events: types.Events,
	_params: types.ManualTuple<T, U...>,
	_returns: types.ManualTuple<V, W...>?,
}

function Server.Fire<T, V, U..., W...>(self: _Server<T, V, U..., W...>, to: Player, v1: T, ...: U...)
	assert(self._events.r, "[PAKNET]: To use 'Fire' you must have 'r' in the remoteType.")

	local s, packet: buffer = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding packet for transmission: {packet}\nArguments: {v1}, {table.concat({ ... }, ", ")}`) end

	self._events.r:FireClient(to, packet)
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

	local s, packet: buffer = pcall(self._params.Write, self._params, v1, ...)
	if not s then error(`[PAKNET]: Error encoding unreliable packet for transmission: {packet}\nArguments: {v1}, {table.concat({ ... }, ", ")}`) end

	self._events.u:FireClient(to, packet)
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

function ServerClass.new<T, V, U..., W...>(events: types.Events, settings: types.RemoteSetting<T, V, U..., W...>): types.Server<T, V, U..., W...>
	local self: _Server<T, V, U..., W...> = setmetatable({}, ServerClass.metatable) :: any

	self.onEvent = LemonSignal.new()

	self._events = events
	self._params = settings.params
	self._returns = settings.returns

	if self._events.f then self._events.f.OnServerInvoke = function(...)
		if self.onInvoke then self.onInvoke(...) end
	end end
	if self._events.r then
		self._events.r.OnClientEvent:Connect(function()
			if self.onEvent._head then -- Check there are any connections
				-- TODO check for ratelimit and deserialize before firing the signal
				return
			end
		end)
	end
	if self._events.u then
		self._events.u.OnClientEvent:Connect(function()
			if self.onEvent._head then -- Check there are any connections
				-- TODO check for ratelimit and deserialize before firing the signal
				return
			end
		end)
	end

	return self
end

return ServerClass
