# Public Docker Packaging Specification

## 1. Base image

### Required characteristics

- Base OS: Ubuntu 24.04
- Runtime user: generic non-root `appuser`
- Toolchain:
  - Node.js 22
  - `pnpm` via `corepack`
  - `supervisord`
  - `tini`
  - `jq`, `rsync`, `ripgrep`, `python3`

### Runtime behavior

- `ENTRYPOINT` starts `/ops/scripts/container-entrypoint.sh`
- `container-entrypoint.sh` prepares writable runtime directories
- `supervisord` starts only `openclaw-gateway` in the base image
- default OpenClaw config is created in `/home/appuser/.openclaw` if missing

## 2. Addon extension points

The base image exposes the following public extension points:

| Type | Path |
| --- | --- |
| executable addons | `/opt/openclaw-addons/bin` |
| addon skills | `/opt/openclaw-addons/skills` |
| addon supervisor config | `/etc/supervisor/conf.d/*.conf` |

## 3. Public addon example

The example addon must:

1. build from `Dockerfile.addons`
2. add exactly one extra supervised process
3. write output only into the synthetic workspace
4. require no real credential or personal data

## 4. Local test fixtures

Synthetic fixtures live under:

- `build-context/local-test/quickstart/`
- `build-context/local-test/addons-example/`

They may contain:

- empty `.openclaw` directories
- placeholder markdown files
- generated runtime state

They must not contain:

- real auth tokens
- private backup material
- user-specific path references
- copied personal notes

## 5. Compose contracts

### `docker-compose.quickstart.yml`

- builds the base image
- mounts the quickstart synthetic config and workspace
- exposes the gateway on `18789`

### `docker-compose.addons.example.yml`

- builds the addon image from the local base image
- mounts the addon synthetic config and workspace
- exposes the gateway on `18790`

## 6. Validation

Minimum validation sequence:

```bash
bash -n scripts/*.sh
docker compose --env-file ./.env.example -f ./docker-compose.quickstart.yml config
docker compose --env-file ./.env.example -f ./docker-compose.addons.example.yml config
./scripts/deploy-smoke.sh --down-after
COMPOSE_FILE=./docker-compose.addons.example.yml \
SERVICE_NAME=openclaw-addons-example \
HEALTH_URL=http://127.0.0.1:18790/healthz \
./scripts/deploy-smoke.sh --down-after
```
