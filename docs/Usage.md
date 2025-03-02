---
sidebar_position: 3
---

# Usage
## Creating Remotes
To create remotes using PakNet, you will create network modules somewhere in ReplicatedStorage. These modules return a mounted namespace of remotes.

You can mount a namespace using `PakNet:Mount(file: Instance, namespace: RemoteTable)` where file is the Instance the needed instances will be created inside  
:::warning
You should not mount multiple namespaces to the same file, as this can result in name collisions and break everything (even if both namespaces have no overlapping keys).
:::  

Typically, you will mount directly to the current script, but if you want to create multiple namespaces in one script for organizational purposes, you can use create folders under the module for each namespace and mount to them.

The remote table format is a map of strings as names to a remote definition using `PakNet:DefineRemote(settings: RemoteSettings)`  
RemoteSettings is a dictionary where:
    - **params** *(always required)* is a PakNet Schema
    - **returns** *(only required for remote functions)* is also a PakNet Schema
    - **remoteType** *(always required)* is any of **"f" "r" "u" "fr" "fu" "ru" "fru"** so that:
        - Containing **f** means it has a RemoteFunction
        - Containing **r** means it has a RemoteEvent
        - Containing **u** means it has an UnreliableRemoteEvent
    - **rateLimit** *(optional)* is a table where:
        - **global** is a boolean indicating if it should be per-player (false) or global (true)
        - **limit** is the maximum amount of requests within the window
        - **window** is the duration of the window (so that only requests from the past `window` seconds are counted towards the limit)
    - **timeout** *(optional)* is a number for when invocations should timeout for remote functions.

```lua title="networkExample.luau"
local PakNet = require(path.to.PakNet)

-- We will mount this namespace on the current script
local namespace = PakNet:Mount(script, {
    -- The name of the remote is the key, and the value is a remote configuration, created with PakNet:DefineRemote()
    SomeRemoteEvent = PakNet:DefineRemote({
        -- params is a schema defining how to read and write the packet.
        -- PakNet:Schema is used the same as Pack:Define
        params = PakNet:Schema(PakNet.string16),
        -- remoteType is a string telling PakNet what instances we need for the remote
        -- If it contains "r", a RemoteEvent will be created
        remoteType = "r",
    }),

    SomeUnreliableEvent = PakNet:DefineRemote({
        -- If we are using a tuple schema, we have to assert the type due to luau being unable to capture the generic pack
        -- Hovering over the datatype will show you what the type is defined at if you are unsure
        params = PakNet:Schema(PakNet.float64, PakNet.Vector3) :: PakNet.Schema<number, vector>,
        -- If remoteType contains "u", an UnreliableRemoteEvent will be created
        remoteType = "u",
        -- We can attach a ratelimit to our remote, to prevent it being spammed
        rateLimit = {
            limit = 60, -- Allows 60 requests
            window = 3, -- per 3 seconds 
        },
    }),

    SomeRemoteFunction = PakNet:DefineRemote({
        params = PakNet:Schema(PakNet.Array(PakNet.Double)),
        -- When we have a remote function, we have to specify the return schema as well
        returns = PakNet:Schema(PakNet.UInt),
        -- If remoteType contains "f", a RemoteFunction will be created
        remoteType = "f",
        -- We can set a timeout for remote functions, after which requests will be cancelled and nil will be returned
        timeout = 5,
    }),

    SomeEverythingEvent = PakNet:DefineRemote({
        -- Heres an example of a more complex schema
        params = PakNet:Schema(PakNet.Dictionary({
            Name = PakNet.string16,
            Level = PakNet.UByte,
            CFrame = PakNet.CFrame,
            Buildings = PakNet.Map(PakNet.Vector3, PakNet.Instance),
        })),
        returns = PakNet:Schema(PakNet.Array(PakNet.nullable(PakNet.Double))),
        -- We can combine remote types, but they must be in alphabetical order
        -- For example you could also use "fr" "fu" or "ru"
        remoteType = "fru",
        rateLimit = {
            limit = 10, -- Allows 10 requests
            window = 1, -- per second
        },
        timeout = 15,
    }),
})

-- You can pass through the global signal function, if you find that useful
-- Nice if you have a centralized network module, rarther than many separate namespaces
namespace.Signal = PakNet.Signal

return namespace
```

How you organize namespaces is up to you. You might want to create a centralized network module with all remotes inside it, or you might want to create multiple network modules for different things.

## Using Remotes
Remotes share a similar API to the standard Roblox remotes, however, their API's have been combined into one. The names of server methods and events have also been changed to remove Server/Client, so for example `FireClient` is just `Fire` and `OnServerEvent` is now `OnEvent`. The names on the client remain the same.  
PakNet also introduces some new functionality, Server remotes get built in `FireList` and `FireExcept` variants, as well as an event that fires if an incoming packet failed to deserialize called `OnParseError`. Both Client and Server get `InvokeAsync` (`InvokeServerAsync` on client), a non-blocking version of `Invoke` that returns a Promise. Both also get the `OnRateLimited` event, which will also return the player that was rate limited on the server.  
There are Unreliable variants of all the Fire methods, which will use a UnreliableRemoteEvent instead of a RemoteEvent.

With this combined API, the parts of it you can use depend on the current RunContext (Server or Client) and the current remote's remoteType.  
"f" unlocks the `OnInvoke` / `OnClientInvoke` callback, `Invoke`, `InvokeAsync`, `InvokeServer`, and `InvokeServerAsync`  
"r" unlocks the `OnEvent` / `OnClientEvent` signal, `Fire`, `FireAll`, `FireList`, `FireExcept`, and `FireServer`  
"u" unlocks the `OnEvent` / `OnClientEvent` signal, `FireUnreliable`, `FireAllUnreliable`, `FireListUnreliable`, `FireExceptUnreliable`, and `FireServerUnreliable`  
The server always has access to the `OnParseError` signal. Both server and client always have access to `OnRateLimited` and `ClassName` (with ClassName being "Server" or "Client").

```lua title="ClientExample.luau"
local network = require(game:GetService("ReplicatedStorage"):WaitForChild("networkExample"))

network.SomeRemoteEvent:FireServer("Hello World!")

-- Send SomeUnreliableEvent faster than the rate limit
network.SomeUnreliableEvent.OnRateLimited:Connect(function()
    print("Rate Limited")
    -- >>> Rate Limited (x40)
end)

for i = 1, 100 do
    network.SomeUnreliableEvent:FireServerUnreliable(i, Vector3.new(i, i, i))
end

print(network.SomeRemoteFunction:InvokeServer({
    Name = "Bob",
    Level = 9001,
    CFrame = CFrame.identity,
    Buildings = {},
}))
-- >>> 9001
```

```lua title="ServerExample.luau"
local network = require(game:GetService("ReplicatedStorage"):WaitForChild("networkExample"))

-- A big benefit of schemas is that you get proper typings, so message will default to string in this example
network.SomeRemoteEvent.OnEvent:Connect(function(message)
    print(message)
    -- >>> Hello World!
end)

network.SomeUnreliableEvent.OnEvent:Connect(function(num, vector)
    print(num)
    -- The client ratelimit will stop it at 60
    -- >>> 1 ... 60
end)

network.SomeRemoteFunction.OnInvoke = function(player, data)
    print(data)
    --[[ >>>{
                ["Buildings"] = {},
                ["CFrame"] = 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1,
                ["Level"] = 9001,
                ["Name"] = "Bob"
            }
    ]]
    
    return data.Level
end
```