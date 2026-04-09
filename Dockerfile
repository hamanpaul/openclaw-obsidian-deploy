ARG OPENCLAW_BASE_IMAGE="openclaw:v2026.2.15"
FROM ${OPENCLAW_BASE_IMAGE}

ARG OPENCLAW_DOCKER_APT_PACKAGES="ca-certificates curl jq git ripgrep fd-find yq rsync tzdata python3 python-is-python3 python3-yaml minicom"
ARG OPENCLAW_INSTALL_OBSIDIAN_HEADLESS=1

USER root
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${OPENCLAW_DOCKER_APT_PACKAGES} && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
RUN if [ "${OPENCLAW_INSTALL_OBSIDIAN_HEADLESS}" = "1" ]; then \
      npm install -g obsidian-headless; \
    fi

WORKDIR /app

ARG OPENCLAW_DOCKER_USER=1000:1000
COPY --chown=${OPENCLAW_DOCKER_USER} build-context/external-sources /opt/external-sources
COPY --chown=${OPENCLAW_DOCKER_USER} scripts /ops/scripts
COPY --chown=${OPENCLAW_DOCKER_USER} config-template/openclaw.json /home/node/.openclaw/openclaw.json
COPY --chown=${OPENCLAW_DOCKER_USER} config-template/agents/main/agent/models.json /home/node/.openclaw/agents/main/agent/models.json
RUN test -f /opt/external-sources/manifest.json || \
      (echo "missing /opt/external-sources/manifest.json; run ./scripts/prepare-external-sources.sh before building" >&2 && exit 1)
RUN /bin/chmod +x /ops/scripts/*.sh && \
    /bin/mkdir -p /app/skills /app/.agents/skills && \
    if [ -d /opt/external-sources/custom-claw-tools/famiclean-skill/skills ]; then \
      /usr/bin/rsync -a /opt/external-sources/custom-claw-tools/famiclean-skill/skills/ /app/skills/; \
    fi && \
    if [ -d /opt/external-sources/custom-claw-tools/picoclaw-ops-companion/skills ]; then \
      /usr/bin/rsync -a /opt/external-sources/custom-claw-tools/picoclaw-ops-companion/skills/ /app/skills/; \
    fi && \
    if [ -d /opt/external-sources/custom-skills/test-playbook ]; then \
      /bin/mkdir -p /app/.agents/skills/test-playbook && \
      /usr/bin/rsync -a /opt/external-sources/custom-skills/test-playbook/ /app/.agents/skills/test-playbook/; \
    fi && \
    if [ -d /opt/external-sources/custom-skills/serialwrap-mcp ]; then \
      /bin/mkdir -p /app/.agents/skills/serialwrap-mcp && \
      /usr/bin/rsync -a /opt/external-sources/custom-skills/serialwrap-mcp/ /app/.agents/skills/serialwrap-mcp/; \
    fi && \
    if [ -f /opt/external-sources/serialwrap/install.sh ]; then \
      cd /opt/external-sources/serialwrap && \
      SERIALWRAP_INSTALL_AUTOBIND=0 /bin/bash ./install.sh /home/node/.paul_tools; \
    fi && \
    if [ -f /opt/external-sources/custom-claw-tools/picoclaw-ops-companion/package.json ]; then \
      cd /opt/external-sources/custom-claw-tools/picoclaw-ops-companion && \
      npm ci --include=dev && \
      npm run build; \
    fi && \
    /bin/chown -R node:node /opt/external-sources /home/node/.openclaw /home/node/.paul_tools /app/skills /app/.agents/skills

ENV NODE_ENV=production
ENV OPENCLAW_GATEWAY_TOKEN=local-dev-token
ENV OPENCLAW_CONTROL_UI_ALLOW_INSECURE_AUTH=1
ENV PATH="/home/node/.paul_tools:${PATH}"

USER root

EXPOSE 18789 45450

ENTRYPOINT ["/ops/scripts/runtime-bootstrap.sh"]
