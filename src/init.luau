--!strict
--!optimize 2

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
-- Modules
local MountNamespace = require(script.MountNamespace)
local types = require(script.types)

local SALT = game.JobId
local IS_SERVER = RunService:IsServer()
local SHOULD_SEARCH = not IS_SERVER or script:GetActor() ~= nil -- Search for remotes if not on the main server environment

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
	local eventTable = MountNamespace(file, SALT, RemoteTable)
end

-- Search for any remote definitions (in ReplicatedStorage/Remotes) and preload them
if IS_SERVER and not SHOULD_SEARCH then
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or (ReplicatedStorage :: ReplicatedStorage):FindFirstChild("remotes") -- type gymnastics :(
	if remotes then
		if remotes.ClassName == "ModuleScript" then
			pcall(require, remotes)
		else
			for _, v in remotes:GetDescendants() do
				if v.ClassName == "ModuleScript" then pcall(require, v) end
			end
		end
	end
end

return PakNet
