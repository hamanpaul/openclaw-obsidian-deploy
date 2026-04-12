ARG OPENCLAW_BASE_OS_IMAGE="ubuntu:24.04"
ARG OPENCLAW_DOCKER_USER="1000:1000"
ARG OPENCLAW_GIT_URL="https://github.com/openclaw/openclaw.git"
ARG OPENCLAW_REF="main"
ARG CUSTOM_CLAW_TOOLS_GIT_URL="https://github.com/hamanpaul/custom-claw-tools.git"
ARG CUSTOM_CLAW_TOOLS_REF="main"
ARG CUSTOM_SKILLS_GIT_URL="https://github.com/hamanpaul/custom-skills.git"
ARG CUSTOM_SKILLS_REF="main"
ARG OPENCLAW_NODE_MAJOR="22"
ARG OPENCLAW_TZ="Asia/Taipei"
ARG OPENCLAW_SUPERCRONIC_VERSION="v0.2.29"

FROM ${OPENCLAW_BASE_OS_IMAGE} AS build

ARG DEBIAN_FRONTEND=noninteractive
ARG OPENCLAW_GIT_URL
ARG OPENCLAW_REF
ARG CUSTOM_CLAW_TOOLS_GIT_URL
ARG CUSTOM_CLAW_TOOLS_REF
ARG CUSTOM_SKILLS_GIT_URL
ARG CUSTOM_SKILLS_REF
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
      fd-find \
      git \
      gnupg \
      jq \
      openssh-client \
      python3 \
      python3-pip \
      python3-venv \
      python3-yaml \
      ripgrep \
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

RUN git clone --depth 1 --branch "${OPENCLAW_REF}" "${OPENCLAW_GIT_URL}" openclaw && \
    git clone --depth 1 --branch "${CUSTOM_CLAW_TOOLS_REF}" "${CUSTOM_CLAW_TOOLS_GIT_URL}" custom-claw-tools && \
    git clone --depth 1 --branch "${CUSTOM_SKILLS_REF}" "${CUSTOM_SKILLS_GIT_URL}" custom-skills

WORKDIR /src/openclaw
RUN pnpm install --frozen-lockfile && \
    pnpm canvas:a2ui:bundle && \
    pnpm build:docker

ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

WORKDIR /src/custom-claw-tools/picoclaw-ops-companion
RUN npm ci && \
    npm run build

RUN rm -rf \
      /src/openclaw/.git \
      /src/custom-claw-tools/.git \
      /src/custom-skills/.git

FROM ${OPENCLAW_BASE_OS_IMAGE} AS runtime

ARG DEBIAN_FRONTEND=noninteractive
ARG OPENCLAW_DOCKER_USER
ARG OPENCLAW_NODE_MAJOR
ARG OPENCLAW_TZ
ARG OPENCLAW_SUPERCRONIC_VERSION

SHELL ["/bin/bash", "-lc"]

RUN ln -snf "/usr/share/zoneinfo/${OPENCLAW_TZ}" /etc/localtime && \
    echo "${OPENCLAW_TZ}" >/etc/timezone && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      fd-find \
      git \
      gnupg \
      hostname \
      jq \
      lsof \
      openssh-client \
      openssl \
      procps \
      python3 \
      python3-pip \
      python3-venv \
      python3-yaml \
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

RUN npm install -g \
      obsidian-headless \
      @googleworkspace/cli \
      @google/gemini-cli \
      @github/copilot \
      @openai/codex && \
    python3 -m pip install --no-cache-dir --break-system-packages garmindb

RUN arch="$(dpkg --print-architecture)" && \
    case "$arch" in \
      amd64) supercronic_arch="amd64" ;; \
      arm64) supercronic_arch="arm64" ;; \
      *) echo "unsupported architecture for supercronic: $arch" >&2; exit 1 ;; \
    esac && \
    curl -fsSL -o /usr/local/bin/supercronic \
      "https://github.com/aptible/supercronic/releases/download/${OPENCLAW_SUPERCRONIC_VERSION}/supercronic-linux-${supercronic_arch}" && \
    chmod 0755 /usr/local/bin/supercronic

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
    if [ ! -d /home/appuser ]; then \
      install -d -o appuser -g appuser /home/appuser; \
    fi && \
    rm -f /home/haman && \
    ln -s /home/appuser /home/haman && \
    mkdir -p \
      /app \
      /workspace/vault \
      /ops/scripts \
      /opt/openclaw-defaults/agents/main/agent \
      /home/appuser/.agents/skills \
      /home/appuser/.cache/supervisor \
      /home/appuser/.local/bin \
      /home/appuser/.local/state/openclaw && \
    chown -R appuser:appuser /app /workspace/vault /home/appuser

ENV HOME=/home/appuser
ENV OPENCLAW_REPO_DIR=/app
ENV CUSTOM_CLAW_TOOLS_ROOT=/home/appuser/custom-claw-tools
ENV CUSTOM_SKILLS_ROOT=/home/appuser/custom-skills
ENV OPENCLAW_DEFAULTS_DIR=/opt/openclaw-defaults
ENV PATH=/home/appuser/.local/bin:/usr/local/bin:/usr/bin:/bin
ENV NODE_ENV=production
ENV OPENCLAW_GATEWAY_TOKEN=local-dev-token
ENV OPENCLAW_CONTROL_UI_ALLOW_INSECURE_AUTH=1

WORKDIR /app

COPY --from=build --chown=appuser:appuser /src/openclaw/dist ./dist
COPY --from=build --chown=appuser:appuser /src/openclaw/node_modules ./node_modules
COPY --from=build --chown=appuser:appuser /src/openclaw/package.json ./package.json
COPY --from=build --chown=appuser:appuser /src/openclaw/openclaw.mjs ./openclaw.mjs
COPY --from=build --chown=appuser:appuser /src/openclaw/extensions ./extensions
COPY --from=build --chown=appuser:appuser /src/openclaw/skills ./skills
COPY --from=build --chown=appuser:appuser /src/openclaw/docs ./docs
COPY --from=build --chown=appuser:appuser /src/custom-claw-tools /home/appuser/custom-claw-tools
COPY --from=build --chown=appuser:appuser /src/custom-skills /home/appuser/custom-skills
COPY scripts /ops/scripts
COPY config-template/openclaw.json /opt/openclaw-defaults/openclaw.json
COPY config-template/agents/main/agent/models.json /opt/openclaw-defaults/agents/main/agent/models.json
COPY config-template/supervisord.conf /etc/supervisor/supervisord.conf

RUN chmod +x /ops/scripts/*.sh && \
    /ops/scripts/install-runtime-bin-links.sh && \
    /ops/scripts/install-openclaw-skills.sh && \
    ln -sf /ops/scripts/container-systemctl.sh /usr/local/bin/systemctl && \
    ln -sf /app/openclaw.mjs /usr/local/bin/openclaw

EXPOSE 18789 45450 45460 8080

USER root

ENTRYPOINT ["/usr/bin/tini", "--", "/ops/scripts/container-entrypoint.sh"]
