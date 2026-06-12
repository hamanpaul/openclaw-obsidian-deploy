# Public Docker Packaging Enhancement Plan

## Summary

This plan reframes the repository around a public deployment contract:

1. **generic OpenClaw base image**
2. **public addon example**
3. **synthetic local smoke tests**

The plan explicitly excludes private backups, live personal runtime mounts, and user-specific deployment assumptions.

## Goals

1. Build a reproducible OpenClaw image from source without embedding any personal data.
2. Keep the runtime contract small: `OpenClaw + supervisord + generic extension points`.
3. Provide one addon example that demonstrates how to extend the image without introducing private repos or secrets.
4. Validate everything locally with synthetic fixtures only.

## Phases

### Phase 1: Clean base image

- build OpenClaw from source in `Dockerfile`
- create a generic `appuser`
- ship `supervisord` with only `openclaw-gateway`
- generate default config into a mounted `.openclaw` directory when missing

### Phase 2: Addon example

- add `Dockerfile.addons`
- install one public example process under `/opt/openclaw-addons`
- load the addon through `/etc/supervisor/conf.d/*.conf`

### Phase 3: Synthetic local tests

- add `docker-compose.quickstart.yml`
- add `docker-compose.addons.example.yml`
- keep fixtures under `build-context/local-test/`
- avoid any real token, personal workspace, or private backup

### Phase 4: Public documentation

- rewrite `README.md` for quickstart and addon example
- document the path contract in `docs/path-mapping.md`
- keep historical notes while removing private deployment assumptions

## Exit criteria

- base quickstart builds and serves `/healthz`
- addon example builds and writes its heartbeat file
- no committed artifact depends on personal auth, personal paths, or private backup data
