--!strict

--[[ RateLimit
Sliding window rate-limit applied on server and client
--]]

-- Services
local RunService = game:GetService("RunService")
-- Modules

local IS_SERVER = RunService:IsServer()

local RateLimit = {}
local RateLimitClass = { metatable = { __index = RateLimit } }
export type RateLimit = {}
type _RateLimit = RateLimit & {}

function RateLimitClass.new(): RateLimit
	local self: _RateLimit = setmetatable({}, RateLimitClass.metatable) :: any
	return self
end

return RateLimitClass :: typeof(RateLimitClass)
