# Account data model

The initial account relationship sketch is now represented by the PostgreSQL
migrations and the [database architecture](architecture.md). In summary:

```text
account
  +-- credential / sessions / recovery tokens / sanctions
  +-- characters
        +-- party and boxed Pokemon + moves
        +-- inventory + immutable ledger
        +-- badges / flags / quests / Pokedex
        +-- verified battle participation / trades
```

Credentials and token digests are deliberately separate from characters. The
full constraints and deletion behavior are defined in
[`002_gameplay.sql`](../../database/migrations/002_gameplay.sql), while audit
and idempotency records are defined in
[`003_operations.sql`](../../database/migrations/003_operations.sql).