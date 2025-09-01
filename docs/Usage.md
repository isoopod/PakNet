---
sidebar_position: 3
---

# Usage

In PakNet, creating remotes involves setting up network modules within `ReplicatedStorage`. These modules return a mounted namespace of remotes that can be accessed and used in your game.

## Creating Remotes

To create remotes, you'll need to use the `PakNet:Mount` function. This function mounts a remote namespace, where each remote is a key-value pair that represents a remote definition.

```lua
PakNet:Mount(file: Instance, namespace: RemoteTable)
```

- **file**: The `Instance` where remote instances will be created (usually `script`).
- **namespace**: A table that holds the remote definitions.

:::warning
Do not mount multiple namespaces to the same file. This can cause name collisions and break everything — even if the namespaces don't overlap.
:::

### Organizational Tips

- Typically, you'll mount the remote directly to the current script.
- If you want to create multiple namespaces within a single script for better organization, create folders under the module for each namespace and mount to those.

### Defining Remotes

A remote table is essentially a map where each key is the remote name, and the value is the remote's definition. To define a remote, use:

```lua
PakNet:DefineRemote(settings: RemoteSettings)
```

`RemoteSettings` is a dictionary with the following fields:

**params** *(required)*  
A PakNet schema that defines the parameters for the remote.

**returns** *(required for remote functions only)*  
A PakNet schema that defines the return values for the remote function.

**remoteType** *(required)*  
A string specifying the type of remote. Valid values:

- `"f"` – RemoteFunction
- `"r"` – RemoteEvent
- `"u"` – UnreliableRemoteEvent
- Combinations are allowed (e.g. `"fr"`, `"fu"`, `"ru"`, `"fru"`). The letters must always appear in alphabetical order.

**rateLimit** *(optional)*  
A table that specifies rate limiting for the remote.

- `global` (boolean): If true, the limit applies globally. If false or omitted, it applies per player.
- `limit` (number): Maximum number of requests allowed within the window.
- `window` (number): Duration of the window in seconds.

**timeout** *(optional)*  
A number (seconds) specifying the timeout for remote functions. If exceeded, the call is cancelled and returns `nil`.

```lua title="networkExample.luau"
local PakNet = require(path.to.PakNet)

-- We will mount this namespace on the current script
local namespace = PakNet:Mount(script, {
    -- The name of the remote is the key, and the value is a remote configuration, created with PakNet:DefineRemote()
    SomeRemoteEvent = PakNet:DefineRemote({
        -- params is a schema defining how to read and write the packet.
        -- PakNet:Schema is used the same as Pack:Define
        params = PakNet:Schema(PakNet.String16),
        -- remoteType is a string telling PakNet what instances we need for the remote
        -- If it contains "r", a RemoteEvent will be created
        remoteType = "r",
    }),

    SomeUnreliableEvent = PakNet:DefineRemote({
        -- If we are using a tuple schema, we have to assert the type due to luau being unable to capture the generic pack
        -- Hovering over the datatype will show you what the type is defined at if you are unsure
        params = PakNet:Schema(PakNet.Float64, PakNet.Vector3) :: PakNet.Schema<number, vector>,
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
            Name = PakNet.String16,
            Level = PakNet.UInt,
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
namespace.Signal = PakNet:LoadGlobalSignal()

return namespace
```

:::tip
When defining a tuple Schema (one with multiple arguments), you have to assert the type as `PakNet.Schema<...>`

When you have complicated data structures, it can be annoying to convert them into standard types.
You can copy the definition inside the function and surround it in `typeof()` instead of writing it out with types as well.

```lua
 params = PakNet:Schema(PakNet.Dictionary({
    Name = PakNet.String16,
    Level = PakNet.UByte,
}, PakNet.Int)) :: PakNet.Schema<typeof(PakNet.Dictionary({
    Name = PakNet.String16,
    Level = PakNet.UByte,
}), typeof(PakNet.Int)>
```

:::

How you organize namespaces is up to you. You might want to create a centralized network module with all remotes inside it, or you might want to create multiple network modules for different things.

## Using Remotes

Remotes in PakNet have a unified API that combines both server and client functionality. There are some deviations to the RemoteEvent/RemoteFunction API to simplify naming conventions and add new features.

### Key Changes

**Unified API**  
Remote methods for server and client are now combined under consistent names:

- `FireClient` → `Fire`
- `OnServerEvent` → `OnEvent`
  (Client-side names remain unchanged.)

**Server-only additions**  

- `AddSanityCheck`: Attach sanity checks directly to a remote.
- `FireList`: Send to a list of players.
- `FireExcept`: Send to all players except the given ones.
- `OnCheckFail`: Triggered when a packet fails sanity checks.
- `OnParseError`: Triggered when a packet cannot be deserialized.

**Async methods**  
Available on both server and client:

- `InvokeAsync` (server)
- `InvokeServerAsync` (client)
  These are non-blocking versions of `Invoke` and return a Promise.

**Rate limiting**  

- `OnRateLimited`: Triggered when a player exceeds the configured limit.

**Unreliable variants**  
All `Fire` methods have unreliable counterparts that use `UnreliableRemoteEvent` instead of `RemoteEvent`.

### Access Based on Remote Type

The parts of the API you can use depend on whether you’re on the server or client and the Remote's type.

**"f" (Functions)**  

- `OnInvoke` The server-side callback that will run when a client invokes the server.
- `OnClientInvoke` The client-side callback that will run when the server invokes a client.
- `Invoke` Invokes a client from the server.
- `InvokeAsync` Promisified version of `Invoke`.
- `InvokeServer` Invokes the server from a client.
- `InvokeServerAsync` Promisified version of `InvokeServer`.

**"r" (Remote)**  

- `OnEvent` Server-side signal.
- `OnClientEvent` Client-side signal.
- `Fire` Fires from the server to a single player.
- `FireAll` Fires from the server to all players.
- `FireList` Fires from the server to a list of players.
- `FireExcept` Fires from the server to all players except those in the list.
- `FireServer` Fires from the client to the server.
  
**"u" (Unreliable)**  

- `OnEvent` Server-side signal.
- `OnClientEvent` Client-side signal.
- `FireUnreliable` Fires unreliably from the server to a single player.
- `FireAllUnreliable` Fires unreliably from the server to all players.
- `FireListUnreliable` Fires unreliably from the server to a list of players.
- `FireExceptUnreliable` Fires unreliably from the server to all players except those in the list.
- `FireServerUnreliable` Fires unreliably from the client to the server.

### Common Access

- **Server** always has access to the `OnParseError` and `OnCheckFailed` events.
- **Both server and client** always have access to the `OnRateLimited` event and the `ClassName` property (which indicates whether the current context is "Server" or "Client").

---

```lua title="Example.server.luau"
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

network.SomeEverythingEvent.OnInvoke = function(player, data)
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

```lua title="Example.client.luau"
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

print(network.SomeEverythingEvent:InvokeServer({
    Name = "Bob",
    Level = 9001,
    CFrame = CFrame.identity,
    Buildings = {},
}))
-- >>> 9001
```

### Bulk Protection

Setting up `OnRateLimited` and other security events individually for each remote can quickly become tedious. Instead, you can apply protections to an entire namespace at once by iterating over it.  

When iterating a mounted namespace, only remotes are returned — you don't need to worry about filtering out extra entries like `Signal`.

```lua title="BulkProtection.server.luau"
local network = require(game:GetService("ReplicatedStorage"):WaitForChild("networkExample"))

-- This example just kicks the player
-- You may want to hook this up to a proper ban system
for name, remote in network do
    remote.OnRateLimited:Connect(function(player)
        player:Kick("Attempted to bypass rate limit")
    end)

    remote.OnParseError:Connect(function(player)
        player:Kick("Sent invalid packet")
    end)

    remote.OnCheckFail:Connect(function(player, error)
        warn(`{player} Triggered a sanity check for {name}: {error}`)
        player:Kick("Tripped a sanity check")
    end)
end
```

:::warning
Never store sanity checks or other protections inside the module that creates the namespace — or anywhere the client has access to.  
Always keep security logic server-side and isolated.
:::
