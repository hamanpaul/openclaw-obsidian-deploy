ARG OPENCLAW_BASE_OS_IMAGE="ubuntu:24.04"
ARG OPENCLAW_DOCKER_USER="1000:1000"
ARG OPENCLAW_GIT_URL="https://github.com/openclaw/openclaw.git"
ARG OPENCLAW_REF="main"
ARG OPENCLAW_NODE_MAJOR="22"
ARG OPENCLAW_TZ="UTC"

FROM ${OPENCLAW_BASE_OS_IMAGE} AS build

ARG DEBIAN_FRONTEND=noninteractive
ARG OPENCLAW_GIT_URL
ARG OPENCLAW_REF
ARG OPENCLAW_NODE_MAJOR
ARG OPENCLAW_TZ

SHELL ["/bin/bash", "-lc"]

RUN ln -snf "/usr/share/zoneinfo/${OPENCLAW_TZ}" /etc/localtime && \
    echo "${OPENCLAW_TZ}" >/etc/timezone && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      build-essential \
      ca-certificates \
      curl \
      git \
      gnupg \
      python3 \
      rsync \
      tzdata \
      unzip \
      xz-utils && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://deb.nodesource.com/setup_${OPENCLAW_NODE_MAJOR}.x" | bash - && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://bun.sh/install | bash && \
    ln -sf /root/.bun/bin/bun /usr/local/bin/bun

RUN corepack enable && corepack prepare pnpm@10.32.1 --activate

WORKDIR /src

RUN git clone --depth 1 --branch "${OPENCLAW_REF}" "${OPENCLAW_GIT_URL}" openclaw

WORKDIR /src/openclaw

RUN pnpm install --frozen-lockfile && \
    pnpm canvas:a2ui:bundle && \
    pnpm build:docker && \
    pnpm ui:build

RUN rm -rf /src/openclaw/.git

FROM ${OPENCLAW_BASE_OS_IMAGE} AS runtime

ARG DEBIAN_FRONTEND=noninteractive
ARG OPENCLAW_DOCKER_USER
ARG OPENCLAW_NODE_MAJOR
ARG OPENCLAW_TZ

SHELL ["/bin/bash", "-lc"]

RUN ln -snf "/usr/share/zoneinfo/${OPENCLAW_TZ}" /etc/localtime && \
    echo "${OPENCLAW_TZ}" >/etc/timezone && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      jq \
      openssh-client \
      python3 \
      ripgrep \
      rsync \
      supervisor \
      tini \
      tzdata && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://deb.nodesource.com/setup_${OPENCLAW_NODE_MAJOR}.x" | bash - && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@10.32.1 --activate

RUN uid="${OPENCLAW_DOCKER_USER%%:*}" && \
    gid="${OPENCLAW_DOCKER_USER##*:}" && \
    group_name="$(getent group "$gid" | cut -d: -f1 || true)" && \
    if [ -z "$group_name" ]; then \
      groupadd --gid "$gid" appuser; \
    elif [ "$group_name" != "appuser" ]; then \
      groupmod --new-name appuser "$group_name"; \
    fi && \
    existing_user="$(getent passwd "$uid" | cut -d: -f1 || true)" && \
    if [ -n "$existing_user" ] && [ "$existing_user" != "appuser" ]; then \
      usermod --login appuser "$existing_user"; \
      usermod --home /home/appuser --move-home appuser; \
      usermod --gid "$gid" appuser; \
    elif ! id -u appuser >/dev/null 2>&1; then \
      useradd --uid "$uid" --gid "$gid" --create-home --shell /bin/bash appuser; \
    fi && \
    install -d -o appuser -g appuser \
      /app \
      /workspace \
      /ops/scripts \
      /opt/openclaw-defaults/agents/main/agent \
      /opt/openclaw-addons/bin \
      /opt/openclaw-addons/skills \
      /etc/supervisor/conf.d \
      /home/appuser/.agents/skills \
      /home/appuser/.cache/supervisor \
      /home/appuser/.local/bin \
      /home/appuser/.local/state/openclaw

ENV HOME=/home/appuser
ENV OPENCLAW_REPO_DIR=/app
ENV OPENCLAW_DEFAULTS_DIR=/opt/openclaw-defaults
ENV OPENCLAW_WORKSPACE_DIR=/workspace
ENV OPENCLAW_CONFIG_DIR=/home/appuser/.openclaw
ENV OPENCLAW_ADDONS_ROOT=/opt/openclaw-addons
ENV PATH=/home/appuser/.local/bin:/usr/local/bin:/usr/bin:/bin
ENV NODE_ENV=production
ENV OPENCLAW_GATEWAY_TOKEN=local-dev-token
ENV OPENCLAW_CONTROL_UI_ALLOW_INSECURE_AUTH=1
ENV OPENCLAW_DEFAULT_MODEL=github-copilot/claude-haiku-4.5
ENV OPENCLAW_DEFAULT_PROFILE_ID=github-copilot:github

WORKDIR /app

COPY --from=build --chown=appuser:appuser /src/openclaw/dist ./dist
COPY --from=build --chown=appuser:appuser /src/openclaw/node_modules ./node_modules
COPY --from=build --chown=appuser:appuser /src/openclaw/package.json ./package.json
COPY --from=build --chown=appuser:appuser /src/openclaw/openclaw.mjs ./openclaw.mjs
COPY --from=build --chown=appuser:appuser /src/openclaw/extensions ./extensions
COPY --from=build --chown=appuser:appuser /src/openclaw/skills ./skills
COPY --from=build --chown=appuser:appuser /src/openclaw/docs ./docs

COPY scripts/container-entrypoint.sh /ops/scripts/container-entrypoint.sh
COPY scripts/container-systemctl.sh /ops/scripts/container-systemctl.sh
COPY scripts/ensure-openclaw-config.sh /ops/scripts/ensure-openclaw-config.sh
COPY scripts/ensure-zh-tw-default.sh /ops/scripts/ensure-zh-tw-default.sh
COPY scripts/install-openclaw-skills.sh /ops/scripts/install-openclaw-skills.sh
COPY scripts/install-runtime-bin-links.sh /ops/scripts/install-runtime-bin-links.sh
COPY scripts/render-supercronic-crontab.sh /ops/scripts/render-supercronic-crontab.sh
COPY scripts/run-openclaw-gateway.sh /ops/scripts/run-openclaw-gateway.sh
COPY scripts/run-supercronic.sh /ops/scripts/run-supercronic.sh
COPY scripts/runtime-common.sh /ops/scripts/runtime-common.sh

COPY config-template/openclaw.json /opt/openclaw-defaults/openclaw.json
COPY config-template/agents/main/agent/models.json /opt/openclaw-defaults/agents/main/agent/models.json
COPY config-template/supervisord.conf /etc/supervisor/supervisord.conf

RUN chmod +x /ops/scripts/*.sh && \
    ln -sf /ops/scripts/container-systemctl.sh /usr/local/bin/systemctl && \
    ln -sf /app/openclaw.mjs /usr/local/bin/openclaw

EXPOSE 18789

USER root

ENTRYPOINT ["/usr/bin/tini", "--", "/ops/scripts/container-entrypoint.sh"]
