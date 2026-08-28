# Operating-system setup for building and hosting

This runbook prepares a clean **Windows 11**, **Ubuntu 26.04 LTS**, or
**macOS** machine to build the current repository, initialize PostgreSQL, and
host the coordinator. Run commands from the repository root unless a section
says otherwise.

## What the current build requires

| Dependency | Required for | Supported version or constraint |
| --- | --- | --- |
| Git | checkout | Current vendor-supported release |
| Node.js and npm | NestJS server and love.js web build | Node.js **22 or newer** |
| PostgreSQL client and server | MMO schema/system of record | PostgreSQL **16 or newer** |
| Bash, GNU Make, `zip`, and `curl` | repository build/hosting scripts | Current OS package |
| Python 3, `venv`, and pip | ROM extraction and local web host | Current OS package |
| RGBDS | building `pokered` | **1.0.3** (see `pokered/.rgbds-version`) |
| LÖVE and LuaJIT | desktop client and its tests | LÖVE 11.x; current LuaJIT |
| Docker | containerized server hosting | Optional, but recommended for hosting |
| cloudflared | temporary public links | Optional; not needed for LAN or a normal reverse proxy |

The checked-in npm lockfiles supply the JavaScript dependencies. The love.js
package includes its Emscripten/WASM runtime, so a separate Emscripten SDK is
not required.

> **Current database integration:** PostgreSQL and its migrations are part of
> the persistence build-out. The coordinator in `backend/` still keeps the P0
> session in memory and does not yet read `DATABASE_URL`. Initialize and test
> the schema now, but do not expect restarting the current coordinator to
> preserve connected players.

## Windows 11 (WSL 2)

Use WSL 2 rather than Git Bash or native PowerShell for the build. The
repository entry points are Bash scripts and assume Unix utilities, paths, and
symlinks. PowerShell is used only to install WSL; all later commands run in the
Ubuntu shell.

1. In **PowerShell as Administrator**, install WSL and Ubuntu 26.04:

   ```powershell
   wsl --install -d Ubuntu-26.04
   wsl --update
   ```

   Reboot if prompted, launch the distribution, and create its Linux user. If
   `Ubuntu-26.04` is not listed by `wsl --list --online`, install the current
   Ubuntu distribution from Microsoft Store and then follow the Ubuntu section
   below; confirm its release with `cat /etc/os-release`.

2. Keep the checkout in the WSL filesystem (for example `~/src`), not under
   `/mnt/c`, for reliable executable bits, symlinks, and build performance:

   ```bash
   mkdir -p ~/src
   cd ~/src
   git clone <repository-url> poke_gen1_mmo
   cd poke_gen1_mmo
   ```

3. Complete every command in [Ubuntu 26.04 LTS](#ubuntu-2604-lts). Windows can
   normally reach WSL listeners through `localhost`; allow the chosen public
   port through Windows Firewall only when other machines must connect.

Docker Desktop with WSL integration is an alternative to installing Docker
Engine inside Ubuntu. Do not install both unless you deliberately manage the
two Docker daemons.

## Ubuntu 26.04 LTS

### 1. Install base tools

```bash
sudo apt update
sudo apt install -y \
  build-essential ca-certificates curl git make zip \
  python3 python3-pip python3-venv \
  postgresql postgresql-client \
  luajit love docker.io
sudo systemctl enable --now postgresql
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Log out and back in after adding yourself to the `docker` group. Treat Docker
group membership as root-equivalent access. Docker is optional if the server
will run directly under Node.js.

Ubuntu's package versions can change during the LTS lifetime. Verify the
installed PostgreSQL major version is at least 16:

```bash
psql --version
sudo -u postgres psql -tAc 'SHOW server_version;'
```

If either reports an older major version, install PostgreSQL 16 or newer from
the PostgreSQL project's Apt repository before continuing; do not initialize
this schema on PostgreSQL 15 or earlier.

### 2. Install Node.js 22+

Use your organization's supported Node.js installation method (for example a
version manager or the Node.js binary repository), then verify the actual
runtime rather than assuming the distribution package is new enough:

```bash
node --version
npm --version
node -e 'const major=Number(process.versions.node.split(".")[0]); process.exit(major >= 22 ? 0 : 1)'
```

### 3. Install RGBDS 1.0.3

The ROM build is pinned to RGBDS 1.0.3. Install that release from the RGBDS
project or build it from its tagged source when Ubuntu's package does not match.
Confirm all four programs resolve to the same release:

```bash
rgbasm --version
rgblink --version
rgbfix --version
rgbgfx --version
```

RGBDS is unnecessary when hosting only a copyright-safe backend and a
previously built static client. It is required for the private `make play`
workflow that assembles a local ROM.

## macOS

Install the Xcode command-line tools and Homebrew first, then install the
repository dependencies. These commands work on current Apple Silicon and
Intel Homebrew installations without hard-coding the Homebrew prefix:

```bash
xcode-select --install
brew update
brew install node postgresql@16 python rgbds luajit make zip
brew install --cask love docker
brew services start postgresql@16
```

Open Docker Desktop once and wait until `docker info` succeeds. Docker is
optional for a direct Node.js deployment. For a temporary public tunnel, also
run `brew install cloudflared`.

Homebrew may keep versioned PostgreSQL binaries outside the default `PATH`.
Add the path it reports from `brew info postgresql@16`, or for the current
shell run:

```bash
export PATH="$(brew --prefix postgresql@16)/bin:$PATH"
```

Confirm the minimum versions:

```bash
node --version       # v22 or newer
psql --version       # 16 or newer
rgbasm --version     # 1.0.3
python3 --version
```

## Initialize PostgreSQL 16+

The following creates a local development login and database. Replace the
example password, and never commit it or put it directly in a process-list
command in production.

```bash
sudo -u postgres psql <<'SQL'
CREATE ROLE pokemmo_migrator LOGIN CREATEDB CREATEROLE PASSWORD 'replace-me';
CREATE DATABASE pokemmo OWNER pokemmo_migrator;
SQL
```

On macOS, the Homebrew superuser is normally your macOS account rather than a
`postgres` OS user, so use `psql postgres` in place of
`sudo -u postgres psql`. In WSL, use the Ubuntu command unchanged.

Set the connection string only in the current shell or a secret manager:

```bash
export DATABASE_URL='postgresql://pokemmo_migrator:replace-me@127.0.0.1:5432/pokemmo'
```

Apply the migrations in numeric order and stop on the first error:

```bash
for migration in docs/database/migrations/*.sql; do
  psql -X -v ON_ERROR_STOP=1 "$DATABASE_URL" -f "$migration"
done
```

Verify both the server version and recorded schema versions:

```bash
psql -X "$DATABASE_URL" -c 'SHOW server_version;'
psql -X "$DATABASE_URL" -c 'TABLE mmo.schema_migrations;'
```

The migrations create the least-privilege `mmo_app` and ownership roles.
Provision login credentials outside the migration files. A future persistent
server process should connect as an operator-created login that can assume
`mmo_app`; migration automation should use a separate login that can assume
`mmo_owner`.

## Install, build, and test

Use reproducible lockfile installs on a clean checkout:

```bash
npm --prefix backend ci
npm --prefix backend test
npm --prefix backend run build
npm --prefix web ci
npm --prefix web run build
```

The web build creates `web/dist/`; it does not contain a ROM. To prepare the
desktop client with a legally obtained compatible ROM, run:

```bash
make setup
```

To assemble the repository's local `pokered` checkout for a private development
session, run `make -C pokered red`. Never publish the resulting ROM or include
it in a container/static bundle.

## Host the server

### Direct Node.js process

Build once, then run the compiled server:

```bash
npm --prefix backend ci
npm --prefix backend run build
HOST=0.0.0.0 PORT=8080 NODE_ENV=production npm --prefix backend run start:prod
```

The browser WebSocket is available at `/ws` on the HTTP port. Verify liveness:

```bash
curl --fail http://127.0.0.1:8080/health
```

Use a service manager (systemd, launchd, or a Windows/WSL supervisor) to set the
working directory, restart policy, environment, unprivileged user, and secret
source. Put a maintained reverse proxy or load balancer in front of port 8080,
terminate TLS there, and expose `https://`/`wss://` publicly. Do not expose the
development WebSocket port `7779`. Expose TCP `7778` only when desktop clients
need it and the network is trusted or otherwise protected.

### Docker

The current backend image packages Node.js and the compiled coordinator but
does **not** package PostgreSQL. Run PostgreSQL as a separately backed-up
service; do not put the database in the coordinator container.

```bash
docker build -t pokemon-mmo-server:local backend
docker run --rm --name pokemon-mmo-server \
  -p 8080:8080 \
  -e PORT=8080 \
  pokemon-mmo-server:local
```

Verify `curl --fail http://127.0.0.1:8080/health`, then publish the static
`web/dist/` directory separately. Configure the client with
`?server=wss://YOUR_HOST/ws` or build it with
`web/build-web.sh --server wss://YOUR_HOST/ws`.

## Production checklist

- Keep PostgreSQL private to the application network; require encrypted
  connections where traffic crosses hosts.
- Store database and TLS credentials in a secret manager, not `.env` files in
  the repository, shell history, images, or client bundles.
- Configure PostgreSQL backups, retention, monitoring, and a tested restore
  before claiming persistence or production readiness.
- Allow inbound TCP 443 at the edge. Keep PostgreSQL 5432, HTTP 8080, and
  development ports firewalled from the public internet.
- Serve only `web/dist/`; scan it for ROMs, saves, secrets, and generated
  ROM-derived data before publishing.
- Remember that the current coordinator remains an in-memory P0 service even
  when the schema is initialized; a restart disconnects players and resets the
  active world.