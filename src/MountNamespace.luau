--!strict
--!optimize 2

-- Services
local RunService = game:GetService("RunService")
-- Modules
local SHA2 = require(script.Parent.SHA2)
local types = require(script.Parent.types)

local IS_SERVER = RunService:IsServer()
local SHOULD_SEARCH = not IS_SERVER or script:GetActor() ~= nil -- Search for remotes if not on the main server environment

local function splitUUID(uuid: string): (string, string)
	local hex = uuid:gsub("-", ""):upper()
	return hex:sub(1, 16), hex:sub(17, 32)
end

local function incrementHex(hex: string): string
	local digits = {}
	for i = 1, #hex do
		digits[i] = hex:sub(i, i)
	end
	local carry = 1
	local i = #digits
	while carry > 0 and i >= 1 do
		local c = digits[i]
		local n = tonumber(c, 16) :: number + carry
		if n < 16 then
			digits[i] = string.format("%X", n)
			carry = 0
		else
			digits[i] = "0"
			carry = 1
		end
		i -= 1
	end
	if carry > 0 then
		return string.rep("0", #digits) -- Overflow occurred
	end
	return table.concat(digits)
end

local function incrementUUID(high: string, low: string): (string, string)
	local new_low = incrementHex(low)
	if not new_low then
		new_low = "0000000000000000"
		high = incrementHex(high) or "0000000000000000" -- Reset on overflow
	end
	return high, new_low
end

local function formatUUID(high: string, low: string): string
	local full = high .. low
	return string.format("%s-%s-%s-%s-%s", full:sub(1, 8), full:sub(9, 12), full:sub(13, 16), full:sub(17, 20), full:sub(21, 32))
end

local function SafeMountNamespace(file: Instance, salt: string, remoteTable: types.RemoteTable): { [string]: { f: RemoteFunction?, r: RemoteEvent?, u: UnreliableRemoteEvent? } }
	-- In the event of a hash collision (very unlikely), increment the salt by one and try again until there are no collisions
	local UsedHashSet = {}
	local mounted = {}

	local s = true
	for name, settings in remoteTable do
		local f: RemoteFunction?, r: RemoteEvent?, u: UnreliableRemoteEvent?

		-- Create the needed instnaces for this Remote
		-- See the SHA2 module for why we use SHA224 for the identifier
		if string.find(settings.remoteType, "f") then
			local hash = SHA2.hash224(`{name}{salt}u`)
			if UsedHashSet[hash] then
				s = false
				break
			end
			UsedHashSet[hash] = true

			if SHOULD_SEARCH then
				f = file:WaitForChild(hash) :: any
			else
				f = Instance.new("RemoteFunction")
				f.Name = hash
				f.Archivable = false -- For saving places
				f.Parent = file
			end
		end
		if string.find(settings.remoteType, "r") then
			local hash = SHA2.hash224(`{name}{salt}r`)
			if UsedHashSet[hash] then
				s = false
				break
			end
			UsedHashSet[hash] = true

			if SHOULD_SEARCH then
				r = file:WaitForChild(hash) :: any
			else
				r = Instance.new("RemoteEvent")
				r.Name = hash
				r.Archivable = false -- For saving places
				r.Parent = file
			end
		end
		if string.find(settings.remoteType, "u") then
			local hash = SHA2.hash224(`{name}{salt}u`)
			if UsedHashSet[hash] then
				s = false
				break
			end
			UsedHashSet[hash] = true

			if SHOULD_SEARCH then
				u = file:WaitForChild(hash) :: any
			else
				u = Instance.new("UnreliableRemoteEvent")
				u.Name = hash
				u.Archivable = false -- For saving places
				u.Parent = file
			end
		end

		mounted[name] = { f = f, r = r, u = u } :: any
	end

	-- In the unlikely event of a hash collision in the namespace, increment the salt by 1 and try again.
	if not s then return SafeMountNamespace(file, formatUUID(incrementUUID(splitUUID(salt))), remoteTable) end

	return mounted
end

return SafeMountNamespace
