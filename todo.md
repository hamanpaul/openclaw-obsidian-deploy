# TODO - Public OpenClaw Docker Packaging

## Goal

Ship a public-ready OpenClaw Docker layout with:

1. a generic all-in-one base image
2. a public addon example
3. synthetic local smoke tests

## Definition of done

- [ ] `Dockerfile` builds a generic base runtime with no private assumptions
- [ ] `Dockerfile.addons` demonstrates a public extension path
- [ ] `docker-compose.quickstart.yml` and `docker-compose.addons.example.yml` both work with synthetic fixtures
- [ ] README and docs describe only the public contract
- [ ] no committed file depends on private backup material, personal paths, or real credentials
