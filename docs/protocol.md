# MMO protocol

**Status:** Draft catalogue of the unversioned current protocol
**Owner:** Backend and MMO-client maintainers
**Canonical schema:** `backend/src/modules/mmo/domain/protocol.ts`

## Transport and compatibility

Native TCP and browser WebSocket connections carry the same newline-delimited
JSON messages. Each JSON value is one object with a string `type`. WebSocket
frames have a 64 KiB ceiling. Protocol negotiation, resume tokens, formal size
limits for TCP messages, and compatibility guarantees are **not implemented**;
changing a message therefore requires coordinated client/server deployment and
updated fixtures.

UUID fields use the standard textual UUID form. Directions are `up`, `down`,
`left`, or `right`. Unknown fields in client messages are rejected. Numbers
described as finite reject `NaN` and infinities.

## Client messages

| Type | Required fields | Optional/default fields | Valid state |
| --- | --- | --- | --- |
| `join_world` | `name` (trimmed, 1–24), `mapId` (1–80), finite `x`, `y` | finite `px`, `py`; `facing`=`down`; `moving`=`false`; `appearance` max 80 | First message, once per connection |
| `move` | `mapId` (1–80), finite `x`, `y`, `facing` | finite `px`, `py`; `moving`; nonnegative integer `seq` | Joined and not in battle |
| `challenge` | UUID `targetId` | — | Joined; same map; both available |
| `challenge_reply` | UUID `challengeId`, boolean `accept` | — | Joined challenge recipient |
| `battle_message` | UUID `battleId`, any JSON `payload` | — | Member of that active battle |
| `battle_end` | UUID `battleId` | — | Member of that active battle |
| `ping` | — | string/number `nonce` | Joined |

## Server messages and direction

| Type | Key fields | Emitted when |
| --- | --- | --- |
| `welcome` | `playerId`, `player` | Join accepted |
| `snapshot` | `mapId`, `players` | Join or map change |
| `world_snapshot` | `selfId`, `mapId`, `players` | Join or map change; compatibility alias currently sent with `snapshot` |
| `player_joined` | `player` | A peer enters the receiver's map |
| `player_moved` | player/map/position/facing fields, optional `seq` | A peer reports movement on the same map |
| `player_left` | `playerId` | A peer leaves a map or disconnects |
| `challenge_sent` | `challengeId`, `target` | Challenge created |
| `challenge_received` | `challengeId`, `from` | Challenge created |
| `challenge_declined` | `challengeId`, `playerId` | Recipient declines |
| `challenge_cancelled` | `challengeId` | Either participant disconnects |
| `battle_start` | `battleId`, `opponent`, `role`, `seed` | Challenge accepted; roles are `host`/`guest`, seed is unsigned 32-bit |
| `battle_message` | `battleId`, `fromPlayerId`, `payload` | Opponent sends an opaque link payload |
| `battle_ended` | `battleId`, `reason` | A participant ends or disconnects |
| `pong` | optional `nonce` | Response to `ping` |
| `error` | `code`, `message` | Schema, framing, or coordinator rejection |

`player` objects contain `id`, `name`, `mapId`, finite `x`/`y`, optional
`px`/`py`, `facing`, `moving`, and optional `appearance`.

## State transitions

```text
connected -> joined -> pending challenge -> in battle -> joined
    |           |              |               |
    +-----------+--------------+---------------+-> disconnected
```

A map change emits a leave on the old map, snapshots the new map, then emits a
join on the new map. Only one pending challenge may involve either participant.
Either battle participant may end the battle. Restarting the coordinator loses
all state.

## Stable coordinator error codes

`not_initialized`, `already_initialized`, `in_battle`, `target_unavailable`,
`cannot_challenge`, `challenge_pending`, `challenge_not_found`,
`challenger_unavailable`, and `battle_not_found` are emitted by the coordinator.
Transport adapters can reject malformed JSON, invalid schemas, or oversized
frames; their close/error behavior remains implementation-defined and needs
canonical fixtures before it can be promised as stable.

## Change policy

Until version negotiation exists, prefer additive server output that old clients
ignore, do not add required client fields, and test both transports. Every
protocol change must update the schema, coordinator tests, Lua client handling,
this catalogue, and representative valid/invalid fixtures.