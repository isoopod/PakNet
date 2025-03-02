---
sidebar_position: 3
---

# Usage

In PakNet, creating remotes involves setting up network modules within `ReplicatedStorage`. These modules return a mounted namespace of remotes that can be accessed and used in your game.

### Creating Remotes
To create remotes, you'll need to use the `PakNet:Mount` function. This function mounts a remote namespace, where each remote is a key-value pair that represents a remote definition.

```lua
PakNet:Mount(file: Instance, namespace: RemoteTable)
```

- **file**: The `Instance` where remote instances will be created (usually `script`).
- **namespace**: A table that holds the remote definitions.

:::warning
Do not mount multiple namespaces to the same file. This can cause name collisions and break everything—even if the namespaces don't overlap.
:::

### Organizational Tips:
- Typically, you'll mount the remote directly to the current script.
- If you want to create multiple namespaces within a single script for better organization, create folders under the module for each namespace and mount to those.

### Defining Remotes
A remote table is essentially a map where each key is the remote name, and the value is the remote's definition. To define a remote, use:

```lua
PakNet:DefineRemote(settings: RemoteSettings)
```

The `RemoteSettings` is a dictionary with the following fields:

- **params** *(required)*: A PakNet schema that defines the parameters for the remote.
- **returns** *(required for remote functions only)*: A PakNet schema that defines the return values for the remote function.
- **remoteType** *(required)*: Specifies the type of remote. It can be any combination of the following:
  - **"f"**: RemoteFunction
  - **"r"**: RemoteEvent
  - **"u"**: UnreliableRemoteEvent
  - Combinations like **"fr"**, **"fu"**, **"ru"**, and **"fru"** can also be used for remotes that have multiple types (e.g., a remote that is both a RemoteFunction and a RemoteEvent, also note that it is always written in alphabetical order).

- **rateLimit** *(optional)*: A table that specifies rate limiting for the remote.
  - **global**: Boolean indicating whether the rate limit applies globally or per player.
  - **limit**: The maximum number of requests allowed within a specified window.
  - **window**: The duration in seconds that defines the rate limit window.

- **timeout** *(optional)*: A number specifying the timeout duration (in seconds) for remote functions.

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

Remotes in PakNet have a unified API that combines both server and client functionality. Some changes have been made to the API to simplify naming conventions and add new features.

### Key Changes:
- **Unified API**: Server and client remote methods are combined. For example:
  - `FireClient` is now just `Fire`.
  - `OnServerEvent` is now `OnEvent`.
  
  The names on the client side remain the same.

- **New Features**:
  - **Server-only methods**: 
    - `FireList` and `FireExcept`: Variants of the `Fire` method.
    - `OnParseError`: Fires when an incoming packet fails to deserialize.
  - **Async Methods**: Both server and client have:
    - `InvokeAsync` (on the client, it's called `InvokeServerAsync`): A non-blocking version of `Invoke` that returns a Promise.
  - **Rate Limiting**:
    - `OnRateLimited` event: Triggers when a player is rate-limited, and the server will receive the player object.
  
- **Unreliable Variants**: All `Fire` methods have unreliable variants that use a `UnreliableRemoteEvent` instead of a `RemoteEvent`.

### Access Based on Remote Type:
The parts of the API you can use depend on whether you’re on the server or client and the remote's type. Here’s a breakdown:

- **"f" (Functions)**: 
  - Unlocks `OnInvoke`, `OnClientInvoke`, `Invoke`, `InvokeAsync`, `InvokeServer`, and `InvokeServerAsync`.
  
- **"r" (Remote)**: 
  - Unlocks `OnEvent`, `OnClientEvent`, `Fire`, `FireAll`, `FireList`, `FireExcept`, and `FireServer`.
  
- **"u" (Unreliable)**: 
  - Unlocks `OnEvent`, `OnClientEvent`, `FireUnreliable`, `FireAllUnreliable`, `FireListUnreliable`, `FireExceptUnreliable`, and `FireServerUnreliable`.

### Common Access:
- **Server** always has access to the `OnParseError` event.
- **Both server and client** always have access to the `OnRateLimited` event and the `ClassName` property (which indicates whether the current context is "Server" or "Client").

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