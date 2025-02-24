local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pack = require(ReplicatedStorage.Packages.pack)
export type ManualTuple<T, U...> = Pack.ManualTuple<T, U...>

--[=[
    @type RemoteType "f" | "r" | "u" | "fr" | "fu" | "fru"
    @within RemoteSetting
    Indicates what type(s) of remote event this Remote will need as a string literal  
    - f : function - enables returns and invoke methods  
    - r : reliable - a standard remote event, enables the basic methods  
    - u : unreliable - an unreliable remote event, enables unreliable variants of the basic methods  
    
    Combinations of these letters activate each mode. The literal is written in alphabetical order.

    :::warning
    Unreliable Remotes have a payload limit of 900 bytes.
    :::
    
    Unreliables are best used for ephemeral events including effects that are only relevant for a short time, or for replicating 
    continuously changing data. These events are not resent if they are lost and they do not wait for previously fired events to 
    arrive before being processed, potentially resulting in reduced latency and network traffic.
]=]
export type RemoteType = "f" | "r" | "u" | "fr" | "fu" | "fru"

--[=[
    @interface RateLimitSetting
    @within RemoteSetting
    .global boolean? -- When true - the rate limit applies for all players, otherwise is per player. Defaults to true.
    .limit number -- Maximum number of entrances in the window
    .window nubmer -- How many seconds the window lasts
	Applies a sliding-window rate limit to the Remote. What this means is that if **limit** number of entrances have been made within the last **window** seconds,
    The action will be rate limited and dropped. When checking, actions from over **window** seconds ago will be ignored, hence it is a sliding-window, instead of a
    fixed window that resets after a number of seconds.  
    This is applied on both the server and client, and the server has access to a signal triggered if a client bypasses
    their rate limit, which can be used for moderation (a client should not be able to get around the rate limit without exploits)
]=]
export type RateLimitSetting = {
	global: boolean?,
	limit: number,
	window: number,
}

--[=[
    @class RemoteSetting

    @prop params any
    @prop returns any?
    @prop remoteType RemoteType
    @prop rateLimit RateLimitSrtting?
    (type for params and returns TODO until Pack documentation is ready)

    Provides the structure for creating a Remote in PakNet. These will be created in the RemoteTable when creating a namespace with PakNet.mount

    params and returns (only needed if the function RemoteType is active) are Pack Schemas created with PakNet:Schema
    :::tip
    Schemas are tuples, however because of luau limitations meaning higer-level polymorphism is not possible right now, only the first argument will be properly typed.  
    You can manually assert the type of schemas with the PakNet.ManualTuple<...> type for now.  
    Using these tuples can be helpful and allows you to structure your data closer to how you can in regular remote events, without any overhead.
    :::
]=]
export type RemoteSetting<T, U, V..., W...> = {
	params: Pack.ManualTuple<T, V...>, -- Wally users: use wally-package-types to fix missing type here
	returns: Pack.ManualTuple<U, W...>?,
	remoteType: RemoteType,
	rateLimit: RateLimitSetting?,
}

export type RemoteTable = {
	[string]: RemoteSetting,
}

export type Events = { f: RemoteFunction?, r: RemoteEvent?, u: UnreliableRemoteEvent? }

export type Server<T, V, U..., W...> = {
	Fire: <T, V, U..., W...>(self: _Server<T, V, U..., W...>, to: Player, T, U...) -> (),
	FireAll: <T, V, U..., W...>(self: _Server<T, V, U..., W...>, T, U...) -> (),
	FireList: <T, V, U..., W...>(self: _Server<T, V, U..., W...>, players: { Player }, T, U...) -> (),
	FireExcept: <T, V, U..., W...>(self: _Server<T, V, U..., W...>, except: { Player }, T, U...) -> (),

	FireUnreliable: <T, V, U..., W...>(self: _Server<T, V, U..., W...>, to: Player, T, U...) -> (),
	FireAllUnreliable: <T, V, U..., W...>(self: _Server<T, V, U..., W...>, T, U...) -> (),
	FireListUnreliable: <T, V, U..., W...>(self: _Server<T, V, U..., W...>, players: { Player }, T, U...) -> (),
	FireExceptUnreliable: <T, V, U..., W...>(self: _Server<T, V, U..., W...>, except: { Player }, T, U...) -> (),
}

return nil
