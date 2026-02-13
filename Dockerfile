FROM node:22-bookworm AS builder

ARG OPENCLAW_REPO_GIT_URL="https://github.com/openclaw/openclaw.git"
ARG OPENCLAW_REPO_REF="main"

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"
RUN corepack enable

WORKDIR /src

RUN git clone --depth 1 --branch "${OPENCLAW_REPO_REF}" "${OPENCLAW_REPO_GIT_URL}" openclaw

WORKDIR /src/openclaw
RUN pnpm install --frozen-lockfile
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build
RUN CI=true pnpm prune --prod

FROM node:22-bookworm-slim

ARG OPENCLAW_DOCKER_APT_PACKAGES="ca-certificates curl jq git ripgrep fd-find yq rsync tzdata python3 python-is-python3"
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${OPENCLAW_DOCKER_APT_PACKAGES} && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /app

ARG OPENCLAW_DOCKER_USER=1000:1000
COPY --from=builder --chown=${OPENCLAW_DOCKER_USER} /src/openclaw /app
COPY --chown=${OPENCLAW_DOCKER_USER} scripts /ops/scripts
COPY --chown=${OPENCLAW_DOCKER_USER} config-template/openclaw.json /home/node/.openclaw/openclaw.json
COPY --chown=${OPENCLAW_DOCKER_USER} config-template/agents/main/agent/models.json /home/node/.openclaw/agents/main/agent/models.json
RUN /bin/chmod +x /ops/scripts/*.sh

ENV NODE_ENV=production

USER node

ENTRYPOINT ["node", "openclaw.mjs"]
CMD ["gateway", "--allow-unconfigured"]
