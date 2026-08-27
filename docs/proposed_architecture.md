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