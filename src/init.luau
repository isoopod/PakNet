--!strict
--!optimize 2

-- Services
local RunService = game:GetService("RunService")
local SharedTableRegistry = game:GetService("SharedTableRegistry")
-- Modules
local Client = require(script.Client)
local LemonSignal = require(script.Parent.lemonsignal)
local MountNamespace = require(script.MountNamespace)
local Pack = require(script.Parent.pack)
local Server = require(script.Server)
local types = require(script.types)

local SALT = string.gsub(game.JobId, "-", ""):upper()
if SALT == "" then SALT = "00000000000000000000000000000000" end -- For local testing, JobId on server is '' while on client it is a UUID of all 0's

local IS_SERVER = RunService:IsServer()
local SHOULD_SEARCH = not IS_SERVER or script:GetActor() ~= nil -- Search for remotes if not on the main server environment

local PACK_CONFIG = (SharedTableRegistry:GetSharedTable("PACK_CONFIG")) :: SharedTable
local DEBUG = PACK_CONFIG.__DEBUG__ == true

local MountedFileSet = (DEBUG and {}) :: { [Instance]: boolean }

--- @class PakNet
--- Main class for PakNet, used to create Remotes and houses some utilities
local PakNet = {}

--[=[
    Mounts a file (any instance but probably the module script remotes are being created in) and a table of Remote definitions to create a namespace

    @param file Instance
    @param RemoteTable {[string]: RemoteSetting}
    @return {[string]: Server | Client}

    :::tip[Advanced]
    The reason file must be specified is because that is where the remote event instances will be stored under for each Remote. The reason we create events for each Remote
    unlike other libraries is that sending a packet identifier is wasted bandwidth and it's better to let RakNet handle it. The permanent memory overhead from the extra
    events in negligable and network bandwidth is far limited with the 50kbps cap.

    This in theory means we cant have multiple remotes with the same name in one module, but what if you want to further categorize said file by organising remotes into
    multiple namespaces. One way we can do this is to create some folders under our file and create new namespaces from those.
    :::
]=]
function PakNet.Mount(_: types.PakNet, file: Instance, RemoteTable: types.RemoteTable)
	if DEBUG and IS_SERVER and not SHOULD_SEARCH then
		if MountedFileSet[file] then warn(`[PAKNET]: Attempted to mount multiple namespaces to file {file:GetFullName()}. This may result in undefined behaviour.`) end
		MountedFileSet[file] = true
	end

	local eventTable = MountNamespace(file, SALT, RemoteTable)

	local remotes: { [string]: any } = {}

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

function PakNet.DefineRemote<T, V, U..., W...>(_: types.PakNet, settings: types.RemoteSettings<T, V, U..., W...>): types.Remote<T, V, U..., W...>
	-- Simply remaps the settings class to a Remote type for later type inference
	return settings :: any
end

export type Schema<T, U...> = types.ManualTuple<T, U...>
function PakNet.Schema<T, U...>(_, v1: T, ...: U...)
	return Pack:Define(v1, ...)
end

-- Global signal by identifier
export type Signal = LemonSignal.Signal<...any>
local signals = {}

function PakNet.Signal(identifier: string): Signal
	signals[identifier] = signals[identifier] or LemonSignal.new()
	return signals[identifier]
end

function PakNet.__index(self, key)
	if PakNet[key] then return PakNet[key] end

	local redirects = rawget(self, "_redirects") :: { [string]: any }
	if redirects[key] then return redirects[key] end

	return Pack[key]
end

local object = setmetatable({
	-- Redirects some datatype lookups that would go to Pack to PakNet specific datatypes
	-- These don't need to be lazy-loaded, as PakNet is probably only going to be used on the main thread
	_redirects = {
		Instance = require(script.PakNetDatatypes.ref),
		ref = require(script.PakNetDatatypes.ref),
		-- We will keep the default behaviour of 'any' once implemented in Pack, and explain the difference between any and ref in the PakNet documentation
	},
}, PakNet) :: any

return object :: types.PakNet
