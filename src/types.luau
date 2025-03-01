local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LemonSignal = require(ReplicatedStorage.Packages.lemonsignal)
local Pack = require(ReplicatedStorage.Packages.pack)
local Promise = require(ReplicatedStorage.Packages["typed-promise"])

export type ManualTuple<T, U...> = Pack.ManualTuple<T, U...>

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
	(type for params and returns TODO until Pack documentation is ready)

	Provides the structure for creating a Remote in PakNet. These will be created with `PakNet.defineRemote` in the RemoteTable when creating a namespace with `PakNet.mount`

	params and returns (returns are only needed if the function RemoteType is active) are Pack Schemas created with `PakNet.schema`  
	If making use of the tuple support, you will need to assert the type of this to `PakNet.ManualTuple<arg1, (...vararg)>`, as only the first arg can be infered.
	timeout is how long the server will wait when invoking the client. If a value is not return before timeout, the request will be dropped and return nil. 

	:::tip
	Schemas are tuples, however because of luau limitations meaning higer-level polymorphism is not possible right now, only the first argument will be properly typed.  
	You can manually assert the type of schemas with the PakNet.ManualTuple<...> type for now.  
	Using these tuples can be helpful and allows you to structure your data closer to how you can in regular remote events, without any overhead.
	:::
]=]
--- @prop params any
--- @within RemoteSettings
--- Pack schema defining the structure of the packet

--- @prop returns any?
--- @within RemoteSettings
--- Pack schema defining the strucutre of the return when invoking the packet, if applicable

--- @prop remoteType RemoteType
--- @within RemoteSettings

--- @prop rateLimit RateLimitSetting?
--- @within RemoteSettings

--- @prop timeout number?
--- @within RemoteSettings
export type RemoteSettings<T, V, U..., W...> = {
	params: Pack.ManualTuple<T, U...>,
	returns: Pack.ManualTuple<V, W...>?,
	remoteType: RemoteType,
	rateLimit: RateLimitSettings?,
	timeout: number?,
}

export type RemoteTable = {
	[string]: RemoteSettings,
}

export type Events = { f: RemoteFunction?, r: RemoteEvent?, u: UnreliableRemoteEvent? }

export type Server<T, V, U..., W...> = {
	read onEvent: LemonSignal.Signal<(Player, T, U...)>,
	read onRateLimited: LemonSignal.Signal<Player>,
	onInvoke: ((player: Player, T, U...) -> (V, W...))?,

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

--- @class Client
export type Client<T, V, U..., W...> = {
	read onClientEvent: LemonSignal.Signal<(T, U...)>,
	read onRateLimited: LemonSignal.Signal<>,
	onClientInvoke: ((T, U...) -> (V, W...))?,

	FireServer: (self: Server<T, V, U..., W...>, T, U...) -> (),

	FireServerUnreliable: (self: Server<T, V, U..., W...>, T, U...) -> (),

	InvokeServer: (self: Server<T, V, U..., W...>, T, U...) -> (V, W...),
	InvokeServerAsync: (self: Server<T, V, U..., W...>, T, U...) -> Promise.TypedPromise<V, W...>,
}

export type Remote<T, V, U..., W...> = Server<T, V, U..., W...> | Client<T, V, U..., W...>

export type PakNet = {
	Mount: <T>(self: PakNet, file: Instance, RemoteTable: T) -> T,
	DefineRemote: <T, V, U..., W...>(self: PakNet, settings: RemoteSettings<T, V, U..., W...>) -> Remote<T, V, U..., W...>,

	-- TODO: Export the Pack datatypes type and union that
	-- For now we will just duplicate the definition here
	--====================================================--
	read uint8: number,
	read UByte: number,
	read uint16: number,
	read UShort: number,
	read uint32: number,
	read UInt: number,

	read int8: number,
	read Byte: number,
	read int16: number,
	read Short: number,
	read int32: number,
	read Int: number,

	read float32: number,
	read Float: number,
	read float64: number,
	read double: number,

	read boolean: boolean,
	read BitField: (length: number) -> { boolean },

	read string8: string,
	read string16: string,
	read string32: string,
	read string_fixed: (len: number) -> string,

	read buffer8: buffer,
	read buffer16: buffer,
	read buffer32: buffer,
	read buffer_fixed: (len: number) -> buffer,

	read Color3: Color3,
	read Color3float32: Color3,
	read BrickColor: BrickColor,

	read CFrame: CFrame,
	read Vector3: vector & Vector3,
	read Vector3int16: vector & Vector3,
	read Vector2: Vector2,
	read Vector2int16: Vector2,
	read Region3: Region3,
	read Region3int16: Region3int16,
	read UDim: Udim,
	read UDim2: UDim2,

	read DateTime: DateTime,
	read EnumItem: EnumItem,
	read Instance: Instance,

	read custom: <T>(read: (Reader) -> T, write: (Writer, T) -> ()) -> T,
	read object: <T, U>(metatable: T, classData: U) -> typeof(setmetatable({} :: U, {} :: T)),

	read Array: <T>(type: T) -> { T },
	read Dictionary: <T>(format: T) -> T,
	read Map: <K, V>(keyType: K, valueType: V) -> { [K]: V },

	read null: nil,
	read nullable: <T>(type: T) -> T?,
	--====================================================--

	read ref: any,
}

return nil
