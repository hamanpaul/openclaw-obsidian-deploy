ARG OPENCLAW_BASE_IMAGE="openclaw:v2026.2.15"
FROM ${OPENCLAW_BASE_IMAGE}

ARG OPENCLAW_DOCKER_APT_PACKAGES="ca-certificates curl jq git ripgrep fd-find yq rsync tzdata python3 python-is-python3"

USER root
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${OPENCLAW_DOCKER_APT_PACKAGES} && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /app

ARG OPENCLAW_DOCKER_USER=1000:1000
COPY --chown=${OPENCLAW_DOCKER_USER} scripts /ops/scripts
COPY --chown=${OPENCLAW_DOCKER_USER} config-template/openclaw.json /home/node/.openclaw/openclaw.json
COPY --chown=${OPENCLAW_DOCKER_USER} config-template/agents/main/agent/models.json /home/node/.openclaw/agents/main/agent/models.json
RUN /bin/chmod +x /ops/scripts/*.sh

ENV NODE_ENV=production
ENV OPENCLAW_GATEWAY_TOKEN=local-dev-token
ENV OPENCLAW_CONTROL_UI_ALLOW_INSECURE_AUTH=1

USER node

EXPOSE 18789

ENTRYPOINT ["node", "openclaw.mjs"]
CMD ["gateway", "run"]
