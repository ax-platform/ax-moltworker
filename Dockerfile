FROM docker.io/cloudflare/sandbox:0.7.0

# Install Node.js 22 (required by openclaw) and rsync (for R2 backup sync)
# The base image has Node 20, we need to replace it with Node 22
# Using direct binary download for reliability
ENV NODE_VERSION=22.13.1
RUN ARCH="$(dpkg --print-architecture)" \
    && case "${ARCH}" in \
         amd64) NODE_ARCH="x64" ;; \
         arm64) NODE_ARCH="arm64" ;; \
         *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;; \
       esac \
    && apt-get update && apt-get install -y xz-utils ca-certificates rsync \
    && curl -fsSLk https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz -o /tmp/node.tar.xz \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && node --version \
    && npm --version

# Install pnpm globally
RUN npm install -g pnpm

# Install openclaw
# Pin to specific version for reproducible builds
RUN npm install -g openclaw@2026.3.23-2 \
    && openclaw --version

# Create openclaw directories
# Templates are stored in /root/.openclaw-templates for initialization
RUN mkdir -p /root/.openclaw \
    && mkdir -p /root/.openclaw/extensions \
    && mkdir -p /root/.openclaw-templates \
    && mkdir -p /root/clawd \
    && mkdir -p /root/clawd/skills

# Copy startup script
# Build cache bust: 2026-03-25-openclaw-upgrade
COPY start-moltbot.sh /usr/local/bin/start-moltbot.sh
RUN chmod +x /usr/local/bin/start-moltbot.sh

# Install ax-platform plugin for aX Platform integration
# Fetched from source repo to avoid code duplication
RUN apt-get install -y git \
    && git clone --depth 1 https://github.com/ax-platform/ax-openclaw-plugin.git /tmp/ax-plugin \
    && cp -r /tmp/ax-plugin/extension /root/.openclaw/extensions/ax-platform \
    && cd /root/.openclaw/extensions/ax-platform && npm install --omit=dev \
    && rm -rf /tmp/ax-plugin \
    && echo "ax-platform plugin installed from ax-openclaw-plugin repo"

# Copy default configuration template
COPY moltbot.json.template /root/.openclaw-templates/moltbot.json.template

# Copy custom skills
COPY skills/ /root/clawd/skills/

# Set working directory
WORKDIR /root/clawd

# Expose the gateway port
EXPOSE 18789
