# Link Battle MMO — Architecture Investigation and Multiplayer Evolution

> **Status:** Investigation / design notes
> **Purpose:** Explore the architecture of Link Battle MMO and the feasibility of evolving it into a more extensible, server-authoritative multiplayer Pokémon platform.
>
> This document is intentionally exploratory. It describes hypotheses, architectural directions, and areas requiring source-level verification rather than prescribing an implementation.

## 1. Background

Link Battle MMO is interesting because it combines several components that, at first glance, appear to have very different constraints:

* a user-supplied Generation I Pokémon ROM;
* `gen1recomp`, a native recreation of the Generation I game engine;
* a browser/WASM client;
* multiplayer additions;
* and a network server coordinating players and battles.

An initial concern is that depending on a Pokémon Red/Blue ROM might inherently constrain the project to functionality supported by the original Game Boy software.

That does **not** appear to be the case.

The important architectural distinction is that the ROM appears to function primarily as a **source of game data and copyrighted assets**, rather than as the executable game engine.

The resulting architecture is therefore potentially much more extensible than an emulator-based multiplayer system.

---

## 2. Working Architectural Model

The architecture appears conceptually similar to:

```text
User-supplied Gen I ROM
          |
          | extraction/import
          v
+---------------------------+
| Extracted game content    |
|                           |
| maps / tiles              |
| sprites                   |
| Pokemon data              |
| moves                     |
| trainers                  |
| encounters                |
| text                      |
| animations                |
| music / SFX data          |
| other vanilla content     |
+-------------+-------------+
              |
              v
+---------------------------+
| gen1recomp                |
|                           |
| native game engine        |
| Lua / LÖVE-based systems  |
|                           |
| overworld                 |
| battle engine             |
| menus                     |
| scripting                 |
| rendering                 |
| save handling             |
| mod registries            |
+-------------+-------------+
              |
              v
+---------------------------+
| Link Battle MMO additions |
|                           |
| multiplayer presence      |
| remote players            |
| challenges                |
| battle synchronization    |
| networking                |
+-------------+-------------+
              |
              v
        Network server
```

The first major investigation should verify this model against the current source tree.

---

# 3. ROM Dependency

## 3.1 Key Question

How much of the game actually executes from the original ROM?

The working hypothesis is:

> The ROM supplies vanilla game content, while `gen1recomp` implements the runtime behavior independently.

If true, this means the ROM is not fundamentally limiting the project to Generation I mechanics.

For example, a system implemented by the native engine could potentially support:

* additional Pokémon;
* additional moves;
* additional types;
* abilities;
* held items;
* new status effects;
* new evolution methods;
* new maps;
* new regions;
* new NPC behavior;
* new battle mechanics;
* new UI screens;
* new encounter systems;
* multiplayer-specific mechanics;
* raids;
* cooperative battles;
* persistent world events;
* server-controlled quests.

These systems do not necessarily need corresponding representations inside the original ROM.

## 3.2 Investigate Exactly What Is Extracted

Identify every category of ROM-derived content.

Potential examples include:

```text
maps
map blocks
tilesets
collision data
sprites
Pokemon graphics
trainer graphics
Pokemon base stats
learnsets
evolution data
moves
move animations
trainer parties
wild encounters
items
dialogue
fonts
UI graphics
music
sound effects
Pokemon cries
palettes
```

Determine whether extraction produces:

1. raw binary blobs;
2. decoded runtime structures;
3. generated Lua definitions;
4. cached graphics/audio;
5. some combination of the above.

## 3.3 Determine Runtime ROM Dependency

Verify whether the ROM is needed:

* only during first-run extraction;
* during every startup;
* while entering particular maps;
* during battles;
* for audio playback;
* or continuously throughout execution.

This distinction has important consequences for both architecture and distribution.

---

# 4. gen1recomp as a Game Engine

The most important architectural question may not involve Link Battle MMO itself.

It may be:

> How general-purpose has `gen1recomp` already become?

If the original engine behavior has been substantially reimplemented in Lua, then `gen1recomp` may effectively be a standalone Pokémon-style engine with a Generation I compatibility/content layer.

## 4.1 Systems to Inspect

Map the implementation of:

```text
overworld simulation
movement
collision
map transitions
NPCs
event scripting
dialogue
inventory
party management
Pokemon storage
wild encounters
trainer encounters
battle simulation
experience
leveling
evolution
status effects
items
shops
menus
save/load
audio
rendering
```

For each system determine whether its source of truth is:

```text
ROM-derived data
native engine code
Lua mod code
hardcoded Gen I assumptions
```

## 4.2 Identify Hardcoded Generation I Assumptions

Search for assumptions such as:

```text
species <= 151
moves <= 165
party size == 6
four moves per Pokemon
fixed type count
fixed stat set
fixed status representation
fixed inventory categories
fixed map dimensions
8-bit identifiers
Gen I damage formula
Gen I critical-hit rules
Gen I special stat
Gen I type effectiveness
Gen I experience curves
```

These assumptions are much more important than the ROM dependency itself.

They represent the actual cost of supporting later-generation or custom mechanics.

---

# 5. Mod Architecture

`gen1recomp` appears to provide a significant registry/mod system.

This should be investigated carefully because it may already solve much of the extensibility problem.

## 5.1 Registry Inventory

Identify registries for concepts such as:

```text
species
moves
types
items
maps
tilesets
encounters
trainers
statuses
evolution methods
growth curves
Poké Balls
screens
script commands
text tokens
songs
cries
palettes
transitions
```

Determine whether records can be:

```text
registered
overridden
patched
extended
removed
namespaced
```

## 5.2 Identifier Model

Determine whether content is identified by:

```text
numeric ROM IDs
numeric engine IDs
strings
namespaced strings
registry objects
```

This is critical.

A system centered on arbitrary registry identifiers such as:

```text
pokemon:bulbasaur
pokemon:pikachu
custom:frostfang
```

will be considerably easier to extend than one where every system assumes an 8-bit ROM species index.

## 5.3 Custom Assets

Determine whether mods can supply assets independently of the ROM.

Examples:

```text
PNG sprites
tilesets
maps
music
sound effects
battle animations
fonts
UI graphics
```

Ideally the asset resolution model could become:

```text
requested asset
      |
      v
mod override?
   |       |
  yes      no
   |       |
   v       v
mod asset  ROM-derived asset
```

This would allow arbitrary original content while retaining ROM-derived vanilla content.

---

# 6. Current Link Battle MMO Networking

The current server appears intentionally lightweight.

The working model is approximately:

```text
             Multiplayer server
                    |
        +-----------+-----------+
        |           |           |
        v           v           v
     Client A    Client B    Client C

Clients own substantial game state.

Server coordinates multiplayer interactions.
```

Likely server responsibilities include:

```text
player presence
player positions
challenge negotiation
battle coordination
battle-turn relay
```

This architecture is reasonable for a multiplayer proof of concept.

It is substantially less suitable for a persistent MMO.

---

# 7. Client Authority

The largest architectural constraint appears to be **client authority**, rather than the Generation I ROM.

Investigate which state is currently authoritative on the client:

```text
player position
party
Pokemon stats
moves
PP
inventory
money
badges
progression
quests
NPC state
world state
encounters
battle state
damage calculation
experience
evolution
save data
```

For each field classify it as:

```text
CLIENT AUTHORITATIVE
SERVER AUTHORITATIVE
REPLICATED
DERIVED
UNKNOWN
```

A useful deliverable would be an authority matrix.

Example:

| System            | Current Authority | Desired Authority |
| ----------------- | ----------------- | ----------------- |
| Rendering         | Client            | Client            |
| Input             | Client            | Client            |
| Player position   | TBD               | Server validated  |
| Party             | TBD               | Server            |
| Inventory         | TBD               | Server            |
| Battle simulation | TBD               | Server            |
| NPC state         | Client/local      | Server            |
| World events      | Client/local      | Server            |
| UI                | Client            | Client            |
| Audio             | Client            | Client            |

---

# 8. Battle Architecture

Battles are likely one of the most important systems to move server-side.

A relay architecture might resemble:

```text
Client A                     Client B
   |                            |
   | select move                |
   +----------> server <--------+
                relay
   |                            |
   | locally simulate battle    |
   |                            |
```

That approach works if clients are trusted and simulation remains deterministic.

It creates problems for a persistent MMO.

A malicious or modified client may potentially claim impossible state.

Examples:

```text
Pokemon with impossible stats
invalid moves
unlimited PP
impossible items
invalid level
modified damage calculations
impossible status state
```

## 8.1 Desired Battle Model

A stronger architecture would be:

```text
Client
  |
  | intent: use THUNDERBOLT
  v
Server
  |
  | validate actor
  | validate move
  | validate PP
  | determine turn order
  | calculate accuracy
  | calculate damage
  | apply status
  | mutate battle state
  |
  v
Authoritative turn result
  |
  +-----------> Client A
  |
  +-----------> Client B
```

Clients render the result but do not determine it.

## 8.2 Shared Battle Engine

Investigate whether the existing Lua battle engine can execute headlessly.

Possible approaches:

### Option A — Run Lua on the server

Reuse the existing battle implementation directly.

Advantages:

* minimizes duplicated battle logic;
* reduces divergence between client and server;
* preserves existing mechanics;
* potentially supports existing mods.

Questions:

* Can the battle engine run without LÖVE/rendering dependencies?
* Is game state cleanly separable from UI state?
* Can Lua execution be embedded in the chosen server runtime?
* Is deterministic RNG available?
* Can mods safely execute server-side?

### Option B — Port battle logic to server language

Reimplement battle mechanics in TypeScript or another backend language.

Advantages:

* native integration with server state;
* easier operational tooling;
* easier server-side validation.

Disadvantages:

* duplicated mechanics;
* synchronization burden;
* higher risk of client/server behavioral divergence.

### Option C — Shared portable simulation layer

Extract simulation logic into a runtime-independent module usable by both client and server.

Potentially the best long-term design, but probably the highest initial refactoring cost.

---

# 9. Persistent World Architecture

A true MMO architecture should move persistent state to the server.

Conceptually:

```text
                    SERVER
         +-------------------------+
         | accounts                |
         | characters              |
         | parties                 |
         | Pokemon                 |
         | inventory               |
         | progression             |
         | maps                    |
         | NPC state               |
         | encounters              |
         | battles                 |
         | quests                  |
         | world events            |
         | economy                 |
         | persistence             |
         +------------+------------+
                      |
              protocol/messages
                      |
         +------------+------------+
         |            |            |
         v            v            v
      Client A     Client B     Client C
```

Clients should primarily own:

```text
rendering
audio
input
menus
UI
local interpolation
optional movement prediction
asset management
```

---

# 10. Server-Owned Player Data

Long-term player data could include:

```text
Account
Character
Party
Pokemon
Inventory
Money
Badges
Flags
QuestState
MapLocation
PCStorage
Pokedex
Statistics
Settings
```

A Pokémon record might conceptually become:

```text
PokemonInstance
    id
    species_id
    level
    experience
    nature
    ability
    moves[]
    pp[]
    ivs
    evs
    status
    held_item
    metadata
```

This model need not be constrained to Generation I fields.

For example, later-generation concepts could simply be added to the server model even if the ROM knows nothing about them.

---

# 11. Server-Defined Content

An especially interesting architecture would separate **vanilla asset ownership** from **server-defined game content**.

The user supplies a compatible ROM locally.

The client extracts vanilla assets.

The server supplies content definitions and references those locally available assets.

Example:

```text
Server content manifest

species:
  pikachu:
    sprite: rom:pokemon/pikachu
    cry: rom:cry/pikachu

  frostfang:
    sprite: mod:frostfang/front.png
    cry: mod:frostfang/cry.ogg
```

Maps could similarly reference ROM-derived tilesets:

```text
map:
  id: custom:new_pallet
  tileset: rom:tileset/overworld
  layout: server-defined
  npcs:
    - server-defined
```

This would allow the original ROM to act as a local vanilla content source without determining game functionality.

---

# 12. Content Manifest

Investigate a server-provided content manifest.

On connection:

```text
Client
  |
  | protocol version
  | engine version
  | ROM fingerprint
  | installed mod fingerprints
  v
Server
  |
  | required content manifest
  | ruleset
  | mod requirements
  | compatibility information
  v
Client
```

The server might define:

```text
required engine version
supported ROM revisions
required mods
optional mods
ruleset version
species registry hash
move registry hash
map registry hash
asset pack hashes
protocol version
```

This could prevent incompatible clients from joining.

---

# 13. ROM Fingerprinting

Investigate how `gen1recomp` currently verifies ROM compatibility.

Potential mechanisms:

```text
SHA-1
SHA-256
CRC
ROM title/header
known revision database
```

A multiplayer client should communicate only a fingerprint or compatibility identifier.

The ROM itself should never be uploaded to the server.

Example:

```text
client -> server

{
    rom_family: "pokemon_red",
    rom_revision: "US_1.0",
    fingerprint: "...",
    engine_version: "...",
    content_hash: "..."
}
```

---

# 14. Protocol Investigation

Document the current network protocol.

Determine:

* transport;
* serialization format;
* message framing;
* connection lifecycle;
* authentication;
* player identity;
* room/world organization;
* position update frequency;
* challenge flow;
* battle flow;
* reconnect behavior;
* timeout behavior;
* error handling.

Create a message catalog.

Example:

```text
CONNECT
WELCOME
PLAYER_JOIN
PLAYER_LEAVE
PLAYER_MOVE
CHALLENGE
CHALLENGE_ACCEPT
CHALLENGE_DECLINE
BATTLE_START
BATTLE_ACTION
BATTLE_RESULT
BATTLE_END
```

These names are illustrative and should be replaced with the actual protocol.

---

# 15. Movement and World Simulation

Determine how player movement currently works.

Questions:

* Does the client send coordinates or movement intents?
* Can a client teleport by sending arbitrary coordinates?
* Does the server know map collision?
* Does the server validate map transitions?
* Are remote players interpolated?
* How frequently are updates sent?
* Are NPCs synchronized?
* Can multiple players interact with the same object?

A server-authoritative evolution might use:

```text
Client:
MOVE NORTH

Server:
validate movement
update position

Server:
POSITION x=10 y=14

Clients:
render/interpolate
```

Rather than:

```text
Client:
I am now at x=10 y=14
```

---

# 16. NPC and Shared World State

A multiplayer world introduces state that does not exist in a purely local Pokémon game.

Examples:

```text
shared NPC positions
shared doors
shared switches
shared pickups
shared trainers
shared encounters
world bosses
raids
timed events
weather
day/night state
resource nodes
quest objectives
```

Investigate whether existing map scripting can be adapted so that selected scripts execute authoritatively on the server.

A useful distinction may be:

```text
CLIENT-LOCAL EVENTS
    cosmetic animation
    dialogue presentation
    UI
    sound

SERVER EVENTS
    give item
    remove item
    start battle
    change quest
    mutate world
    change money
    alter Pokemon
```

---

# 17. Script Security

If existing Lua scripts or mods can modify gameplay state, moving them server-side raises security concerns.

Investigate:

* whether scripts execute arbitrary Lua;
* filesystem access;
* network access;
* dynamic code loading;
* sandboxing;
* trusted vs untrusted mods.

A production server should not execute arbitrary client-provided Lua.

The server should control the authoritative mod set.

---

# 18. Persistence

Investigate the existing save format.

Determine:

```text
what state is serialized
where saves are stored
whether saves mirror Gen I SRAM
whether saves use native structures
whether arbitrary mod data can be persisted
```

For an MMO, local saves should probably cease being authoritative.

Potential server persistence:

```text
PostgreSQL
   |
   +-- accounts
   +-- characters
   +-- pokemon
   +-- moves
   +-- inventory
   +-- progression
   +-- quests
   +-- world_state
   +-- battle_history
```

The exact database is less important initially than clearly defining the ownership boundary.

---

# 19. Authentication

The proof-of-concept may not need substantial identity management.

A persistent server probably does.

Investigate possible progression:

```text
anonymous session
      |
      v
named temporary character
      |
      v
account authentication
      |
      v
persistent character
```

Do not make authentication unnecessarily complicated during early development.

A development server may benefit from intentionally simple local identities.

---

# 20. Compatibility With Later-Generation Mechanics

One goal worth investigating is whether the engine can support selected later-generation mechanics without attempting to reproduce an entire later-generation game.

Examples:

```text
abilities
held items
physical/special move split
natures
IVs
EVs
weather
double battles
new types
new status mechanics
new evolution conditions
expanded movesets
expanded species registry
```

For each mechanic identify:

1. data-model changes;
2. battle-engine changes;
3. UI changes;
4. persistence changes;
5. network-protocol changes;
6. asset requirements.

This will reveal whether the architecture scales cleanly.

---

# 21. Custom Species Proof of Concept

A useful early extensibility test would be adding one entirely custom species that has no ROM representation.

For example:

```text
Species:
    custom:testmon

Sprite:
    external PNG

Types:
    custom or vanilla

Moves:
    mixture of vanilla and custom

Encounter:
    custom map

Battle:
    native engine

Persistence:
    save and reload correctly

Multiplayer:
    another player can observe and battle it
```

If this works cleanly, it would strongly validate the assumption that the ROM is merely a vanilla content provider.

---

# 22. Custom Move Proof of Concept

Similarly, create a move whose behavior cannot be represented by the Generation I engine.

For example:

```text
Custom move:
    damage opponent
    apply custom status
    alter weather
    trigger custom animation
```

Verify:

```text
registry
battle execution
animation
serialization
network synchronization
save/load
AI
UI
```

This provides a focused test of engine extensibility.

---

# 23. Headless Engine Experiment

One of the most valuable experiments may be running part of `gen1recomp` without graphics.

Goal:

```text
$ headless-battle test.json

Pikachu used Thunderbolt
Blastoise took 42 damage
Blastoise became paralyzed
...
```

If the battle engine can execute headlessly, substantial portions of the existing implementation may be reusable server-side.

Investigate dependencies on:

```text
love.graphics
love.audio
love.filesystem
love.timer
global UI state
rendering callbacks
input state
```

Separate simulation dependencies from presentation dependencies.

---

# 24. Determinism

If simulation code is shared between server and client, determine whether it is deterministic.

Investigate:

```text
RNG source
RNG seed handling
floating point usage
iteration order
timing dependencies
frame-dependent logic
platform-dependent behavior
```

Ideally:

```text
InitialState + Inputs + RNGSeed
             |
             v
       deterministic result
```

This could enable:

* replay;
* debugging;
* battle verification;
* spectator mode;
* deterministic tests.

---

# 25. Testing Strategy

The architecture would benefit significantly from simulation tests.

Examples:

```text
battle tests
movement tests
inventory transaction tests
evolution tests
experience tests
status tests
trade tests
persistence tests
protocol tests
compatibility tests
```

Battle fixtures could resemble:

```text
Given:
    Pikachu level 20
    Squirtle level 20
    RNG seed X

When:
    Pikachu uses Thunderbolt

Then:
    expected damage
    expected status
    expected resulting state
```

These tests become particularly important while extracting simulation logic from UI code.

---

# 26. Migration Strategy

Avoid rewriting the entire architecture at once.

A safer evolution might be:

## Phase 1 — Document Current Architecture

Produce:

```text
module map
protocol map
authority matrix
state model
ROM dependency map
mod registry map
```

No major behavioral changes.

## Phase 2 — Harden Multiplayer Protocol

Introduce:

```text
explicit protocol version
structured message definitions
validation
connection state machine
error messages
compatibility handshake
```

## Phase 3 — Server-Owned Identity

Move:

```text
player identity
character identity
session state
```

to the server.

## Phase 4 — Server-Owned Pokémon State

Move:

```text
party
Pokemon instances
moves
PP
inventory
progression
```

to server persistence.

## Phase 5 — Authoritative Battles

Move battle simulation to the server.

Clients send actions.

Server sends results.

## Phase 6 — Authoritative Movement

Server validates:

```text
movement
collision
map transitions
```

## Phase 7 — Shared World

Introduce:

```text
NPC state
shared events
quests
cooperative encounters
world persistence
```

## Phase 8 — Expanded Content

Add:

```text
custom species
custom moves
custom maps
later-generation mechanics
server-defined content
```

---

# 27. Questions to Answer From Source Inspection

The following should be answered before committing to a major redesign:

* [ ] Is the ROM used after extraction?
* [ ] Exactly what data is extracted?
* [ ] Which systems are implemented natively?
* [ ] Which systems retain hardcoded Gen I assumptions?
* [ ] How do registry identifiers work?
* [ ] Can species exist without ROM IDs?
* [ ] Can moves exist without ROM IDs?
* [ ] Can mods supply arbitrary graphics?
* [ ] Can mods supply arbitrary audio?
* [ ] How is mod compatibility calculated?
* [ ] What multiplayer messages currently exist?
* [ ] What state does the server retain?
* [ ] What state does the client retain?
* [ ] How are player positions synchronized?
* [ ] How are battles synchronized?
* [ ] Where is battle RNG generated?
* [ ] Can battle simulation run without rendering?
* [ ] Can overworld simulation run headlessly?
* [ ] What does the save system serialize?
* [ ] Can arbitrary mod state be serialized?
* [ ] How difficult would server-side Lua execution be?
* [ ] Are game systems sufficiently separated from LÖVE APIs?
* [ ] What security assumptions exist around mods?
* [ ] How does the WASM build differ from native execution?

---

# 28. Repository Areas to Inspect

Start by mapping these areas rather than modifying them:

```text
backend/
src/mmo/
web/
gen1recomp/
pokered/
```

Within `gen1recomp`, locate implementations for:

```text
battle
maps
player
Pokemon
moves
items
registries
mods
scripts
save/load
ROM extraction
network/link play
```

Search for references to:

```text
151
165
species_id
move_id
rom
extract
registry
register
LinkBattle
serialize
deserialize
save
socket
websocket
battle
rng
random
love.graphics
love.audio
```

---

# 29. Desired Architectural Direction

The long-term architecture worth evaluating is:

```text
             USER-SUPPLIED ROM
                    |
                    v
          +-------------------+
          | Local extractor   |
          +---------+---------+
                    |
                    v
          +-------------------+
          | Vanilla asset     |
          | cache             |
          +---------+---------+
                    |
          +---------+---------+
          |                   |
          v                   v
   ROM-derived assets     Mod assets
          |                   |
          +---------+---------+
                    |
                    v
             GAME CLIENT
          +-------------------+
          | rendering         |
          | audio             |
          | UI                |
          | input             |
          | interpolation     |
          | local asset cache |
          +---------+---------+
                    |
               WebSocket
                    |
                    v
         AUTHORITATIVE SERVER
       +-------------------------+
       | authentication          |
       | characters              |
       | Pokemon                 |
       | inventory               |
       | battle simulation       |
       | movement validation     |
       | maps/world state        |
       | NPCs                    |
       | quests                  |
       | economy                 |
       | persistence             |
       | content manifest        |
       +-------------------------+
```

The defining principle is:

> **The ROM supplies compatible vanilla content; it does not define the limits of the game.**

---

# 30. Evaluation Criteria

Before adopting this direction, evaluate it against:

### Technical feasibility

Can enough of the existing engine be reused?

### Complexity

Does server authority require rewriting most of the game?

### Maintainability

Can client and server mechanics remain synchronized?

### Mod compatibility

Can the existing mod ecosystem survive the authority transition?

### Performance

Can a server simulate many simultaneous players and battles?

### Security

Can clients be treated as untrusted?

### Content architecture

Can ROM-derived and original assets coexist cleanly?

### Developer experience

Can new content and mechanics be added without touching ROM structures?

### Upstream compatibility

Can changes remain sufficiently modular to continue consuming upstream `gen1recomp` and/or Link Battle MMO improvements?

---

# 31. Initial Hypothesis

The current working hypothesis is:

1. The Generation I ROM is **not** the primary architectural limitation.
2. `gen1recomp` appears to separate game behavior from ROM-derived content sufficiently to permit substantial extension.
3. Its registry/mod architecture may already provide many of the necessary content-extension mechanisms.
4. Link Battle MMO demonstrates that multiplayer can be layered onto this engine.
5. The major limitation for a larger MMO is **client authority**.
6. The most important technical investigation is therefore whether simulation logic can be separated from presentation and reused headlessly.
7. If battle and world simulation can execute server-side, an incremental transition to an authoritative architecture appears plausible.
8. ROM-derived vanilla content and arbitrary original/mod content could potentially coexist.
9. A server-provided content manifest could define the multiplayer world's rules without redistributing the user's ROM.
10. The resulting system could become substantially more capable than Generation I while retaining compatibility with locally extracted Generation I content.

---

# 32. Immediate Next Steps

Before implementation:

1. Map the source tree.
2. Trace ROM extraction from startup through runtime.
3. Build a complete registry inventory.
4. Identify hardcoded Gen I limits.
5. Document the existing multiplayer protocol.
6. Produce the client/server authority matrix.
7. Trace one complete battle from challenge through completion.
8. Trace one player movement update end-to-end.
9. Trace save/load of a Pokémon.
10. Determine whether battle simulation can execute headlessly.
11. Determine whether arbitrary non-ROM species and moves are already possible.
12. Prototype one custom species if necessary to verify the content model.
13. Prototype one headless battle.
14. Only then design the authoritative-server migration.

The first implementation work should be **instrumentation and characterization**, not architectural replacement.

---

# 33. Non-Goals During Investigation

Avoid prematurely:

* rewriting the backend;
* replacing the network protocol;
* introducing a production database;
* implementing authentication;
* porting the battle engine;
* adding later-generation mechanics;
* replacing Lua;
* changing the ROM extraction model;
* building large amounts of new content.

First establish exactly what the existing architecture already provides.

---

# 34. Guiding Principle

The project should be approached as a potentially general-purpose multiplayer Pokémon engine that happens to bootstrap vanilla content from a legally user-supplied Generation I ROM—not as a Game Boy ROM whose original limitations must necessarily be preserved.

The source investigation should attempt to **disprove** that premise.

If the engine contains deep ROM-index assumptions, presentation/simulation coupling, or pervasive Generation I constraints, document them explicitly.

If it does not, preserve the existing architecture wherever possible and concentrate future work on moving trust and persistent state from clients to the server.
