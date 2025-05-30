--!strict

local LemonSignal = require(script.Parent.Parent.Signal)
local Pack = require(script.Parent.Parent.Pack)
local Promise = require(script.Parent.Parent.Promise)

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
export type RemoteType = "f" | "r" | "u" | "ru" | "fr" | "fu" | "fru"

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
	Defines the structure for creating a Remote in PakNet. Remotes are created using `PakNet.defineRemote` within a `RemoteTable`, which is then mounted to a namespace using `PakNet.mount`.  

	- **`params` and `returns`**: Both are **Pack Schemas** created with `PakNet.schema`. The `returns` field is only required if the remote includes a function (`"f"` in `remoteType`).  
	- **Tuple Support**: If using tuples, you may need to manually assert the type as `PakNet.Schema<arg1, (...vararg)>`, since only the first argument can be inferred.  
	- **`timeout`**: Determines how long the server waits for a client response when invoking a function. If no value is returned before the timeout expires, the request is dropped and `nil` is returned.  

	:::tip  
	Schemas are tuples, but due to Luau’s limitations, only the first argument is properly typed. For now, you can manually assert schema types using `PakNet.Schema<...>`.  

	Using tuples allows you to structure data similarly to standard RemoteEvents without adding overhead.  
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
	ClassName: "Server",

	OnEvent: Signal<(Player, T, U...)>,
	OnRateLimited: Signal<Player>,
	OnParseError: Signal<Player, string>,
	OnCheckFail: LemonSignal.Signal<Player>,
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
	InvokeAsync: (self: Server<T, V, U..., W...>, to: Player, T, U...) -> Promise.TypedPromise<(V, W...)>,

	AddSanityCheck: (self: Server<T, V, U..., W...>, check: (player: Player, T, U...) -> boolean) -> (),
}

export type Client<T, V, U..., W...> = {
	ClassName: "Client",

	OnClientEvent: Signal<(T, U...)>,
	OnRateLimited: Signal<>,
	OnClientInvoke: ((T, U...) -> (V, W...))?,

	FireServer: (self: Client<T, V, U..., W...>, T, U...) -> (),

	FireServerUnreliable: (self: Client<T, V, U..., W...>, T, U...) -> (),

	InvokeServer: (self: Client<T, V, U..., W...>, T, U...) -> (V, W...),
	InvokeServerAsync: (self: Client<T, V, U..., W...>, T, U...) -> Promise.TypedPromise<(V, W...)>,
}

export type Remote<T, V, U..., W...> = Server<T, V, U..., W...> & Client<T, V, U..., W...>

export type PakNet = {
	Mount: <T>(self: PakNet, file: Instance, RemoteTable: T) -> T,

	Schema: <T, U...>(self: any, T, U...) -> Schema<T, U...>,
	DefineRemote: <T, V, U..., W...>(self: any, settings: RemoteSettings<T, V, U..., W...>) -> Remote<T, V, U..., W...>,

	LoadGlobalSignal: (self: PakNet) -> (identifier: string) -> Signal<...any>,

	-- Extended datatypes --
	Ref: any,
} & Pack.Datatypes

return nil
