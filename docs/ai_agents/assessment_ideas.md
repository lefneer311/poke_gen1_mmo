#START
ChatGPT Proposed:

I would strongly consider keeping Lua server-side

At least initially.

Rather than rewriting battle logic into whatever language the backend uses, I'd investigate:

MMO server
    │
    ├── networking / persistence
    │
    └── simulation service
            │
            └── Lua
                 ├── Damage
                 ├── Status
                 ├── TurnOrder
                 ├── MoveEffects
                 └── rulesets

There are three realistic ways to do it.

1. Separate Lua simulation process

Something like:

Node/Nest backend
       │
       │ IPC / local RPC
       ▼
Lua simulation worker

This is probably the easiest prototype.

2. Embed Lua into the backend

Depending on the eventual server language, run Lua directly inside the server process.

Potentially cleaner eventually, but more integration complexity.

3. Eventually port pure simulation

Only after the server-authoritative design has stabilized.

I would not start here.

Maintaining two independently implemented Pokémon battle engines is inviting subtle bugs.

World simulation is harder than battles

Ironically, battle authority might be easier.

A battle is bounded:

start state
+
action A
+
action B
+
RNG
=
new state

The overworld is continuous.

You'll need to define exactly what the server owns.

A pragmatic first server-authoritative world does not need MMO-grade physics.

For Pokémon's tile movement:

client -> move_request(NORTH)

server:
    Is player allowed to move?
    Is destination traversable?
    Is destination map-valid?
    Is there an authoritative warp?
    Is movement rate plausible?

server -> movement_accepted(new_position)

That's actually quite manageable because Pokémon movement is discrete.

You don't have FPS-style latency/physics synchronization problems.

The tile-based design works substantially in your favor.

Don't server-authorize absolutely everything

There is a useful boundary.

Keep cosmetic behavior client-side.

For example:

CLIENT

walking animation
sprite interpolation
screen transitions
music
sound
battle animations
dialogue rendering
menus
HUD
particle effects
camera

Server owns consequences:

SERVER

position
map
party
Pokémon
HP
PP
inventory
money
quests
flags
encounter outcomes
battle state
experience
evolution
trades
items
progression

Map scripts need classification.

Something like:

show_text("Hello!")

is harmless client behavior.

But:

give_item("MASTER_BALL")

cannot remain client authoritative.

The investigation already proposes essentially this split between cosmetic/local script effects and state-mutating server events.

#END
#START
The content system is unusually helpful

This may be one of the biggest reasons I think the project is worth pursuing.

Upstream says essentially every major content noun lives in one of 37 registries, and mods can register, override, patch or remove entries.

And your source analysis confirmed that the identifiers are strings rather than fundamentally eight-bit ROM indexes.

That gives you a path toward:

RED:PIKACHU
RED:MEWTWO

MMO:SHOPKEEPER_POKEMON
MMO:CUSTOM_MOVE_001

GEN2:CHIKORITA
GEN3:TREECKO

EVENT:HALLOWEEN_GENGAR

without trying to wedge everything back into Pokémon Red's ROM tables.

The browser still locally imports the legally supplied original asset data.

Custom content can come from your project's original asset packs/mods.

That separation is quite elegant.
#END
#START
Later-generation mechanics are possible, but that's where scope explodes

The attachment correctly identifies the remaining Gen I assumptions:

four-move assumptions exist in code;
Pokémon currently use DVs/stat experience;
there is one special stat;
no native ability/nature/held-item/IV/EV representation exists;
some UI assumes the Game Boy presentation model.

None of those look like fundamental blockers.

They are schema migrations and engine work.

For example, this:

pokemon = {
    species = "PIKACHU",
    level = 42,
    dvs = {...},
    statExp = {...},
}

can eventually become:

pokemon = {
    id = "...",
    species = "PIKACHU",
    level = 42,

    ivs = {...},
    evs = {...},

    nature = "TIMID",
    ability = "STATIC",
    heldItem = "LIGHT_BALL",

    moves = {...},
}

The difficulty comes from all the code that consumes the structure.

So I would deliberately not make “modernize Pokémon mechanics” part of the first MMO milestone.

First prove:

Gen I mechanics
+
persistent server character
+
server authoritative battles
+
server authoritative inventory
+
validated world movement
+
browser client

Then modernize mechanics.
#END
#START
The browser isn't a major concern

This also looks favorable.

The source investigation found the browser version is fundamentally the same Lua game compiled through love.js/WASM; its network transport is WebSocket-backed and ROM import/storage is handled through the browser shell.

And the current project already advertises itself explicitly as Gen I running in-browser with multiplayer.

So you aren't trying to invent a browser port simultaneously with the MMO architecture.

That is a huge reduction in project risk.
#END
#START
I would change the protocol early

Newline-delimited JSON over WebSockets is completely acceptable for early development.

Keep it initially.

But stop sending opaque multiplayer payloads and define semantic messages.

For example:

{
  "type": "battle_action",
  "battleId": "abc",
  "action": {
    "type": "move",
    "slot": 2
  }
}

instead of:

battle_message:
    opaque LinkBattle bytes

The current opaque relay exists specifically because the server isn't interpreting battle semantics.

Once the server becomes authoritative, the protocol should express intent.

Same thing for movement:

{
  "type": "move",
  "direction": "north",
  "sequence": 384
}

rather than:

{
  "map": "CELADON",
  "x": 991,
  "y": 42
}

That's a fundamental security boundary.
#END
#START
SQL transactions fit Pokémon extremely well

Trading is a good example.

You want:

BEGIN

lock player A pokemon
lock player B pokemon

validate A owns Pokémon A
validate B owns Pokémon B
validate both players are eligible

transfer Pokémon A -> B
transfer Pokémon B -> A

record trade

COMMIT

Likewise buying something:

BEGIN

check money
check inventory rule
subtract money
add item

COMMIT

Battle rewards:

BEGIN

verify completed battle
award XP
award money
apply evolution
persist HP/PP/status
record encounter

COMMIT

This is where MariaDB/PostgreSQL becomes extremely valuable.

The database is not the simulation engine.

It's the durable authority boundary.
#END
#START
What I would not persist every frame

Don't do:

UPDATE characters SET x=?, y=? ...

every tile step.

Keep active world state in memory:

World server memory
    player x/y
    current battle
    nearby entities
    short-lived NPC state

and periodically/checkpoint meaningfully durable information into SQL.

For example:

on map change
on logout
every N seconds
after major transaction
after battle
after item acquisition
after quest progression

MariaDB is your persistent backing store, not your realtime state bus.

If this eventually scales substantially, Redis or another ephemeral shared-state layer may become useful, but I would not introduce it initially.
#END
#START
A sensible server decomposition

I would probably start with one deployable application:

mmo-server
├── gateway
├── sessions
├── world
├── battle
├── characters
├── pokemon
├── inventory
├── content
└── persistence

Not microservices.

Even if internally:

battle

uses a separate Lua worker process, keep the system operationally monolithic at first.

A premature:

account-service
world-service
battle-service
inventory-service
trade-service
pokemon-service

would massively increase the work without making the game better.
#END
#START
Authentication is similarly mundane

You don't need anything exotic.

Eventually:

POST /register
POST /login
        ↓
session/JWT/token
        ↓
WebSocket connect
        ↓
authenticate connection
        ↓
select character

Passwords should use a modern password hash such as Argon2id.

But I agree strongly with the investigation's ordering: don't make authentication the first project. The attached report explicitly recommends establishing deterministic simulation and state boundaries first.

For initial development:

dev-token -> character ID

is plenty.
#END
#START
Where I see the actual risks

I would rate them approximately like this:

Area	Risk
Browser client viability	Low
ROM/content import model	Low
Mod/content extensibility	Low–Medium
MariaDB persistence	Low
Accounts/auth	Low
Server inventory/progression	Low–Medium
Server-authoritative battle	Medium
Server-authoritative movement	Medium
Shared NPC/script world	Medium–High
Existing Lua simulation extraction	Medium
Later-gen Pokémon mechanics	Medium–High
Fully generic MMO scripting	High
Large-scale MMO infrastructure	High, but irrelevant initially

The key distinction is that the difficult pieces look like normal game-server engineering problems, not "we picked the wrong engine and need to throw it away" problems.
#END
#START
One particularly encouraging new upstream detail

The current gen1recomp architecture documentation says its test suite already runs headless behavior tests under LuaJIT using LÖVE stubs, including collision, warps, stats, damage, encounters, a scripted battle, and save round-trips.

That's important.

It means the proposal in the attached document to extract a deterministic headless simulation layer is not fighting completely against the project.

There is already headless execution infrastructure.

That moves my assessment noticeably toward “yes, pursue this.”
#END
#START
My assessment

I'd put it around 8/10 for suitability as a starting framework for the project you're describing.

Not because it already is an MMO framework—it isn't. The current server is explicitly just a proof-of-concept relay, and its own README describes it that way.

Rather, the hard-to-replace pieces are unusually favorable:

browser runtime already works → native engine instead of emulation → ROM separated from runtime → extensible registries → mod system → string identifiers → save structures that aren't SRAM-bound → headless testing already exists → deterministic battle components exist → multiplayer transport already exists.

Those are exactly the kinds of properties you'd want if the goal were to evolve a single-player Pokémon engine into an authoritative online one.

I would fork it rather than start from scratch, preserve gen1recomp as much as possible, and treat the current Link Battle MMO backend as disposable scaffolding. The principal new product would effectively be the authoritative server and the clean simulation boundary, not a rewrite of the client.

The attached investigation's conclusion—preserve the native engine/registries and move trust server-side incrementally—is, in my view, the right architectural direction.
#END