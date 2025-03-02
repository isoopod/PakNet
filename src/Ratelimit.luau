--!strict
--!optimize 2
--!native

--[[ RateLimit
	Sliding window ratelimit applied on server and client.

	The limit is made slightly less strict on the server to account for slight fluctuations in latency that could cause false positives.
--]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
-- Modules
local types = require(script.Parent.types)

-- In future I will probably expose these in a configuration file (probably just gonna expand the pack config shared table)
-- Alternative is making them per remote in the RateLimitSettings (maybe use config table for defaults but use ones in remote settings if provided)
-- These defaults seem to work reasonably well, but may be tweaked later down the line.
local SHORT_WINDOW_TOLERANCE = 2 -- Any window shorter than this number is defined as short
local WINDOW_ADJUSTMENT = 0.9 -- Modifier to window length on server, if the window is short
local LIMIT_ADJUSTMENMT = 1.1 -- Modifier to limit size on the server, if the window is not short

-- I might also implement an alternative leaky bucket rate limit so people can choose between the two

local RateLimit = {}
local RateLimitClass = { metatable = { __index = RateLimit } }
export type RateLimit = {
	read global: boolean?,
	read limit: number,
	read window: number,

	RequestAllowed: (self: RateLimit, player: Player?) -> boolean,
}
type _RateLimit = RateLimit & {
	global: boolean?,
	limit: number,
	window: number,

	_requests: { [Player]: { number } },
	_globalRequests: { number },
}

-- In an ordered array, find the highest index which is lesser than target
local function findHighestLessThan(arr: { number }, target: number): number?
	local low: any = 1
	local high: any = #arr
	local index: number?

	while low <= high do
		local mid = (low + high) // 2
		if arr[mid] < target then
			-- Current entry is a candidate; check right for a better one
			index = mid
			low = mid + 1
		else
			-- Entry is >= target; search left
			high = mid - 1
		end
	end

	return index
end

-- Truncate an array from the start up to index.
local function truncateArray(tbl: { any }, index: number)
	local len = #tbl
	table.move(tbl, index + 1, len, 1) -- Move elements after `index` to the start
	for i = len - index + 1, len do
		tbl[i] = nil -- Clear leftover elements
	end
end

function RateLimit.RequestAllowed(self: _RateLimit, player: Player?): boolean
	if not self.global then
		assert(player, "Player expected in non-global rate limits")
		self._requests[player] = self._requests[player] or {}

		-- Find the index we should remove all before as these requests are older than the window
		local removeUpTo = findHighestLessThan(self._requests[player], time() - self.window)
		if removeUpTo then truncateArray(self._requests[player], removeUpTo) end

		if #self._requests[player] < self.limit then
			table.insert(self._requests[player], time())
			return true
		end
	else
		-- Find the index we should remove all before as these requests are older than the window
		local removeUpTo = findHighestLessThan(self._globalRequests, time() - self.window)
		if removeUpTo then truncateArray(self._globalRequests, removeUpTo) end

		if #self._globalRequests < self.limit then
			table.insert(self._globalRequests, time())
			return true
		end
	end
	return false
end

function RateLimitClass.new(settings: types.RateLimitSettings): RateLimit
	local self: _RateLimit = setmetatable({}, RateLimitClass.metatable) :: any

	self.global = settings.global
	self.limit = settings.limit
	self.window = settings.window

	if not self.global then
		self._requests = {}
		if RunService:IsServer() then Players.PlayerRemoving:Connect(function(player: Player)
			self._requests[player] = nil
		end) end
	else
		self._globalRequests = {}
	end

	if RunService:IsServer() then
		-- The ratelimit needs to be slightly less strict on the server to account for slight fluctuations in network latency
		if self.window < SHORT_WINDOW_TOLERANCE then
			self.window *= WINDOW_ADJUSTMENT
		else
			self.limit = math.ceil(self.limit * LIMIT_ADJUSTMENMT)
		end
	end

	return self
end

return RateLimitClass :: typeof(RateLimitClass)
