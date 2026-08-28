                 Browser
       ┌─────────────────────────┐
       │ love.js / WASM client   │
       │                         │
       │ ROM-imported assets     │
       │ rendering               │
       │ audio                   │
       │ UI                      │
       │ input                   │
       │ interpolation           │
       │ prediction              │
       │ local cache             │
       └────────────┬────────────┘
                    │
             WebSocket / JSON
              initially
                    │
                    ▼
       ┌─────────────────────────┐
       │ MMO Application Server  │
       │                         │
       │ sessions                │
       │ authentication          │
       │ world instances         │
       │ movement validation     │
       │ battles                 │
       │ encounters              │
       │ NPC state               │
       │ quests                  │
       │ trading                 │
       │ inventory               │
       │ progression             │
       └────────────┬────────────┘
                    │
                   SQL
                    │
                    ▼
       ┌─────────────────────────┐
       │ MariaDB / PostgreSQL    │
       │                         │
       │ accounts                │
       │ characters              │
       │ Pokémon                 │
       │ inventories             │
       │ progression             │
       │ quests                  │
       │ persistent world state  │
       └─────────────────────────┘

The application-server diagram is a target rather than the current runtime.
The proposed incremental boundary, protocol, failure semantics, and migration
gates for its `battles` responsibility are detailed in the
[server-authoritative battle design](battle_server_authority.md).