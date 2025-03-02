---
sidebar_position: 1
---

# Welcome to PakNet

PakNet is a powerful networking solution designed to improve networking in Roblox. By combining efficiency, security, and ease of use, PakNet makes it easier for developers to implement fast, secure, and scalable networking. Whether you're handling simple remotes or complex data structures, PakNet ensures smooth performance and reliable communication between the server and client.

## Why PakNet?  
<!-- TODO: link to pack gh-pages once created -->
PakNet stands out from other networking libraries by offering greater versatility in Schema construction, enabling support for complex data structures with minimal overhead. Unlike alternatives that prioritize raw speed, PakNet's serialization engine — powered by [Pack](https://github.com/isoopod/Pack) — focuses on reducing bandwidth usage. This is crucial for scaling Roblox games, as the platform enforces a soft transfer limit of 50KiB/s, making bandwidth efficiency more important than sheer serialization speed.  

Many networking libraries fall into the **"one remote event" trap**, where only a single RemoteEvent or RemoteFunction is used, with an identifier included in every packet. This approach wastes bandwidth, as each packet requires additional bytes for the identifier. PakNet avoids this inefficiency by allowing RakNet (Roblox’s underlying network engine) to handle message routing directly, eliminating unnecessary overhead.  

Security is another area where PakNet excels. Each remote instance is hashed using SHA-224, making it significantly harder for exploiters using tools like SimpleSpy to reverse-engineer a game's remotes. Additionally, PakNet provides built-in server-side security signals — such as alerts for packet deserialization failures (often caused by buffer tampering) and triggers for server-side rate limits — giving developers better tools to detect and respond to exploit attempts.  

## Shortcuts

|[Installation](Installation.md)|[Usage](Usage.md)|[API Reference](/api/PakNet)|
|-------------------------------|-----------------|----------------------------|