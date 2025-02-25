--!strict
--!optimize 2

-- Services
local RunService = game:GetService("RunService")
local SharedTableRegistry = game:GetService("SharedTableRegistry")
-- Modules
local MountNamespace = require(script.MountNamespace)
local Server = require(script.Server)
local types = require(script.types)

local SALT = string.gsub(game.JobId, "-", ""):upper()
local IS_SERVER = RunService:IsServer()
local SHOULD_SEARCH = not IS_SERVER or script:GetActor() ~= nil -- Search for remotes if not on the main server environment

local PACK_CONFIG = (SharedTableRegistry:GetSharedTable("PACK_CONFIG")) :: SharedTable
local DEBUG = PACK_CONFIG.__DEBUG__ == true

local MountedFileSet = (DEBUG and {}) :: { [Instance]: boolean }

--- @Class PakNet
--- Main class for PakNet, used to create Remotes and houses some utilities
local PakNet = {}

--[=[
    Mounts a file (any instance but probably the module script remotes are being created in) and a table of Remote definitions to create a namespace

    @param file Instance
    @param RemoteTable {[string]: RemoteSetting}
    @return Namespace any

    :::tip[Advanced]
    The reason file must be specified is because that is where the remote event instances will be stored under for each Remote. The reason we create events for each Remote
    unlike other libraries is that sending a packet identifier is wasted bandwidth and it's better to let RakNet handle it. The permanent memory overhead from the extra
    events in negligable and network bandwidth is far limited with the 50kbps cap.

    This in theory means we cant have multiple remotes with the same name in one module, but what if you want to further categorize said file by organising remotes into
    multiple namespaces. One way we can do this is to create some folders under our file and create new namespaces from those.
    :::
]=]
function PakNet.mount(file: Instance, RemoteTable: types.RemoteTable)
	if DEBUG and IS_SERVER and not SHOULD_SEARCH then
		if MountedFileSet[file] then warn(`[PAKNET]: Attempted to mount multiple namespaces to file {file:GetFullName()}. This may result in undefined behaviour.`) end
		MountedFileSet[file] = true
	end

	local eventTable = MountNamespace(file, SALT, RemoteTable)

	local remotes = {}

	for name, settings in RemoteTable do
		local events = eventTable[name]

		if IS_SERVER then remotes[name] = Server.new(events, settings :: any) end
	end

	return remotes
end

function PakNet.defineRemote<T, V, U..., W...>(settings: types.RemoteSetting<T, V, U..., W...>): types.Remote<T, V, U..., W...>
	-- Simply remaps the settings class to a Remote type for later type inference
	return settings :: any
end

-- TODO: Create a constructor for remote settings so that we can have the types pass through and actually work

return PakNet
