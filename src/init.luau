--!strict
--!optimize 2

local types = require(script.types)
if game:GetService("RunService"):IsEdit() then
	local fallback = require(script.EditModeFallback) :: any
	return fallback :: types.PakNet
end

-- Services
local RunService = game:GetService("RunService")
local SharedTableRegistry = game:GetService("SharedTableRegistry")
-- Modules
local Client = require(script.Client)
local MountNamespace = require(script.MountNamespace)
local Pack = require(script.Parent.Pack)
local Server = require(script.Server)
local Signal = require(script.Parent.Signal)

local SALT = string.gsub(game.JobId, "-", ""):upper()
if SALT == "" then SALT = "00000000000000000000000000000000" end -- For local testing, JobId on server is '' while on client it is a UUID of all 0's

local IS_SERVER = RunService:IsServer()
local SHOULD_SEARCH = not IS_SERVER or script:GetActor() ~= nil -- Search for remotes if not on the main server environment

local PACK_CONFIG = SharedTableRegistry:GetSharedTable("PACK_CONFIG")
local DEBUG = PACK_CONFIG.__DEBUG__ == true

local MountedFileSet = (DEBUG and {}) :: { [Instance]: boolean }

--- @class PakNet
--- Main class for PakNet, used to create Remotes and houses some utilities
local PakNet = {}

--[=[
	@method Mount
	@within PakNet
	@param file Instance
	@param RemoteTable {[string]: RemoteSetting}
	@return {[string]: Server | Client}
	
	Mounts a namespace (RemoteTable) to a file, with the file usually being the ModuleScript calling this method.

	:::warning
	Do not mount multiple namespaces to the same file. This can cause name collisions and break everything — even if the namespaces don't overlap.
	:::

	:::tip[Organizational Tips]
	- Typically, you'll mount the remote directly to the current script.
	- If you want to create multiple namespaces within a single script for better organization, create folders under the module for each namespace and mount to those.
	:::
]=]
function PakNet.Mount(_: types.PakNet, file: Instance, RemoteTable: types.RemoteTable)
	if DEBUG and IS_SERVER and not SHOULD_SEARCH then
		if MountedFileSet[file] then warn(`[PAKNET]: Attempted to mount multiple namespaces to file {file:GetFullName()}. This may result in undefined behaviour.`) end
		MountedFileSet[file] = true
	end

	local eventTable = MountNamespace(file, SALT, RemoteTable)

	local remotes: { [string]: any } = setmetatable({}, {
		-- Only iterate over remotes in GI (This is to ignore Signal if added)
		__iter = function(self)
			local nextKey: any, nextVal: any = next(self, nil)
			return function()
				while nextKey do
					local k, v = nextKey, nextVal
					nextKey, nextVal = next(self, nextKey)
					if type(v) == "table" and (v.ClassName == "Server" or v.ClassName == "Client") then return k, v end
				end
				return nil
			end
		end,
	}) :: any

	for name, settings in RemoteTable do
		local events = eventTable[name]

		if IS_SERVER then
			remotes[name] = Server.new(events, settings :: any)
		else
			remotes[name] = Client.new(events, settings :: any)
		end
	end

	return remotes
end

--[=[
	@method DefineRemote
	@within PakNet
	@param settings: RemoteSettings
	@return Server | Client

	Defines a remote from a RemoteSettings table.
]=]
function PakNet.DefineRemote<T, V, U..., W...>(_: types.PakNet, settings: types.RemoteSettings<T, V, U..., W...>): types.Remote<T, V, U..., W...>
	-- Simply remaps the settings class to a Remote type for later type inference
	return settings :: any
end

--[=[
	@method Schema
	@within PakNet
	@external Datatype https://isoopod.github.io/Pack/docs/Datatypes/Primitives
	@param ... Datatype
	@return Schema

	Defines a Schema from the provided datatypes.  
	This supports tuples, however due to luau limitations you will need to manually annotate the type.

	```lua
	-- The type of this schema will implicitly be infered as CFrame
	PakNet:Schema(PakNet.CFrame)

	-- For tuples, you must explicitly annotate the type of the schema using PakNet.Schema<...>. 
	-- The luau type solver can only infer the first argument.
	PakNet:Schema(PakNet.CFrame, PakNet.Vector3) :: PakNet.Schema<CFrame, Vector3>
	```
]=]
export type Schema<T, U...> = types.Schema<T, U...>
function PakNet.Schema<T, U...>(_, v1: T, ...: U...)
	return Pack:Define(v1, ...)
end

-- Global signal by identifier
export type Signal = Signal.Signal<...any>
local signals = {}

--[=[
	@method LoadGlobalSignal
	@within PakNet
	@return (identifier: string) -> Signal
	The global signal library provides a way to create and manage signals that can be accessed across multiple scripts within the same execution environment (server or client). This allows scripts to communicate without direct references.  

	Global signals are retrieved using a **string identifier**, making it easy to share events across scripts. However, **they do not persist between actors**, meaning signals created in one actor are not accessible in another.  

	Using the global signal library is **optional**. If you don’t need it, you don’t have to use it. It’s useful for loosely coupling scripts, centralizing event handling, and managing shared state without relying on direct references.

	```lua
	-- network.luau
	local namespace = PakNet:Mount(...)

	namespace.Signal = PakNet:LoadGlobalSignal()

	return namespace
	```

	```lua
	-- example1.server.luau
	local network = require(path.to.network)

	local signal = network.Signal("Example")
	signal:Fire("Hello World!")
	```

	```lua
	-- example2.server.luau
	local network = require(path.to.network)

	local signal = network.Signal("Example")
	signal:Connect(function(...)
		print(...) -- >>> Hello World!
	end)
	```
]=]
function PakNet.LoadGlobalSignal(_: types.PakNet): (identifier: string) -> Signal
	return function(identifier: string)
		signals[identifier] = signals[identifier] or Signal.new()
		return signals[identifier]
	end
end

function PakNet.__index(self, key)
	if PakNet[key] then return PakNet[key] end

	local redirects = rawget(self, "_redirects") :: { [string]: any }
	if redirects[key] then return redirects[key] end

	return Pack[key]
end

local object: types.PakNet = setmetatable({
	-- Redirects some datatype lookups that would go to Pack to PakNet specific datatypes
	-- These don't need to be lazy-loaded, as PakNet is probably only going to be used on the main thread
	_redirects = {
		Instance = require(script.PakNetDatatypes.Instance),
		Ref = require(script.PakNetDatatypes.Ref),
		-- We will keep the default behaviour of 'any' once implemented in Pack, and explain the difference between any and ref in the PakNet documentation
	},
}, PakNet) :: any

return object
