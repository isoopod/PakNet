--!strict

local LemonSignal = require(script.Parent.Parent.lemonsignal)
local Pack = require(script.Parent.Parent.pack)
local Promise = require(script.Parent.Parent["typed-promise"])

export type Schema<T, U...> = Pack.Schema<T, U...>

--[=[
	@type RemoteType "f" | "r" | "u" | "fr" | "fu" | "fru"
	@within RemoteSettings
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
	@interface RateLimitSettings
	@within RemoteSettings
	.global boolean? -- When true - the rate limit applies for all players, otherwise is per player. Defaults to true.
	.limit number -- Maximum number of entrances in the window
	.window nubmer -- How many seconds the window lasts
	Applies a sliding-window rate limit to the Remote. What this means is that if ***limit*** number of entrances have been made within the last ***window*** seconds,
	The action will be rate limited and dropped. When checking, actions from over ***window*** seconds ago will be ignored, hence it is a sliding-window, instead of a
	fixed window that resets after a number of seconds.  

	This is applied on both the server (incoming traffic) and client (outgoing traffic).  
	The signal onRateLimited for Server or Client remotes will be fired when the ratelimit is reached.  
	If the server rate limit is triggered, that usually means the client is exploiting, as they should not be able to get past their local rate limit otherwise.
]=]
export type RateLimitSettings = {
	global: boolean?,
	limit: number,
	window: number,
}

--[=[
	@class RemoteSettings
	@external Schema https://isoopod.github.io/Pack/api/Schema
	(type for params and returns TODO until Pack documentation is ready)

	Provides the structure for creating a Remote in PakNet. These will be created with `PakNet.defineRemote` in the RemoteTable when creating a namespace with `PakNet.mount`

	params and returns (returns are only needed if the function RemoteType is active) are Pack Schemas created with `PakNet.schema`  
	If making use of the tuple support, you will need to assert the type of this to `PakNet.Schema<arg1, (...vararg)>`, as only the first arg can be infered.
	timeout is how long the server will wait when invoking the client. If a value is not return before timeout, the request will be dropped and return nil. 

	:::tip
	Schemas are tuples, however because of luau limitations meaning higer-level polymorphism is not possible right now, only the first argument will be properly typed.  
	You can manually assert the type of schemas with the PakNet.Schema<...> type for now.  
	Using these tuples can be helpful and allows you to structure your data closer to how you can in regular remote events, without any overhead.
	:::
]=]
--- @prop params Schema
--- @within RemoteSettings
--- Pack schema defining the structure of the packet

--- @prop returns Schema
--- @within RemoteSettings
--- Pack schema defining the strucutre of the return when invoking the packet, if applicable

--- @prop remoteType RemoteType
--- @within RemoteSettings

--- @prop rateLimit RateLimitSetting?
--- @within RemoteSettings

--- @prop timeout number?
--- @within RemoteSettings
export type RemoteSettings<T, V, U..., W...> = {
	params: Pack.Schema<T, U...>,
	returns: Pack.Schema<V, W...>?,
	remoteType: RemoteType,
	rateLimit: RateLimitSettings?,
	timeout: number?,
}

export type RemoteTable = {
	[string]: RemoteSettings<any, any, ...any, ...any>,
}

export type Events = { f: RemoteFunction?, r: RemoteEvent?, u: UnreliableRemoteEvent? }

-- Fork the Signal type to force Connect and Once to use T... for the fn args instead of any...
export type Signal<T...> = {
	RBXScriptConnection: RBXScriptConnection?,

	Connect: <U...>(self: Signal<T...>, fn: (T...) -> (), U...) -> LemonSignal.Connection<U...>,
	Once: <U...>(self: Signal<T...>, fn: (T...) -> (), U...) -> LemonSignal.Connection<U...>,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

export type Server<T, V, U..., W...> = {
	read ClassName: "Server",

	read OnEvent: Signal<(Player, T, U...)>,
	read OnRateLimited: Signal<Player>,
	read OnParseError: Signal<Player, string>,
	OnInvoke: ((player: Player, T, U...) -> (V, W...))?,

	Fire: (self: Server<T, V, U..., W...>, to: Player, T, U...) -> (),
	FireAll: (self: Server<T, V, U..., W...>, T, U...) -> (),
	FireList: (self: Server<T, V, U..., W...>, players: { Player }, T, U...) -> (),
	FireExcept: (self: Server<T, V, U..., W...>, except: { Player }, T, U...) -> (),

	FireUnreliable: (self: Server<T, V, U..., W...>, to: Player, T, U...) -> (),
	FireAllUnreliable: (self: Server<T, V, U..., W...>, T, U...) -> (),
	FireListUnreliable: (self: Server<T, V, U..., W...>, players: { Player }, T, U...) -> (),
	FireExceptUnreliable: (self: Server<T, V, U..., W...>, except: { Player }, T, U...) -> (),

	Invoke: (self: Server<T, V, U..., W...>, to: Player, T, U...) -> (V, W...),
	InvokeAsync: (self: Server<T, V, U..., W...>, to: Player, T, U...) -> Promise.TypedPromise<V, W...>,
}

export type Client<T, V, U..., W...> = {
	read ClassName: "Client",

	read OnClientEvent: Signal<(T, U...)>,
	read OnRateLimited: Signal<>,
	OnClientInvoke: ((T, U...) -> (V, W...))?,

	FireServer: (self: Client<T, V, U..., W...>, T, U...) -> (),

	FireServerUnreliable: (self: Client<T, V, U..., W...>, T, U...) -> (),

	InvokeServer: (self: Client<T, V, U..., W...>, T, U...) -> (V, W...),
	InvokeServerAsync: (self: Client<T, V, U..., W...>, T, U...) -> Promise.TypedPromise<V, W...>,
}

export type Remote<T, V, U..., W...> = Server<T, V, U..., W...> & Client<T, V, U..., W...>

export type PakNet = {
	Mount: <T>(self: PakNet, file: Instance, RemoteTable: T) -> T,

	Schema: <T, U...>(self: PakNet, T, U...) -> Schema<T, U...>,
	DefineRemote: <T, V, U..., W...>(self: PakNet, settings: RemoteSettings<T, V, U..., W...>) -> Remote<T, V, U..., W...>,

	LoadGlobalSignal: (self: PakNet) -> (identifier: string) -> Signal<...any>,

	-- Extended datatypes --
	read Ref: any,
} & Pack.Datatypes

return nil
