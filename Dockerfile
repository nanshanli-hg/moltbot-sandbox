FROM docker.io/cloudflare/sandbox:0.7.0

# Install Node.js 22 (required by clawdbot) and rsync (for R2 backup sync)
# The base image has Node 20, we need to replace it with Node 22
# Using direct binary download for reliability
ENV NODE_VERSION=22.13.1
RUN apt-get update && apt-get install -y xz-utils ca-certificates rsync make git wget \
    && curl -fsSLk https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz -o /tmp/node.tar.xz \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && node --version \
    && npm --version \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm globally
RUN npm install -g pnpm

# Install Go 1.24
RUN wget -q https://go.dev/dl/go1.24.1.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go1.24.1.linux-amd64.tar.gz \
    && rm go1.24.1.linux-amd64.tar.gz

# Build and install gogcli
RUN git clone --depth 1 https://github.com/steipete/gogcli.git /tmp/gogcli \
    && cd /tmp/gogcli \
    && sed -i 's/go 1.25/go 1.24/' go.mod \
    && /usr/local/go/bin/go mod tidy \
    && PATH=/usr/local/go/bin:$PATH make build \
    && cp bin/gog /usr/local/bin/ \
    && rm -rf /tmp/gogcli /root/go

# Install openclaw (formerly moltbot/clawdbot)
# Pin to specific version for reproducible builds
RUN npm install -g openclaw@2026.1.29 \
    && openclaw --version

# Create openclaw directories
# Templates are stored in /root/.openclaw-templates for initialization
RUN mkdir -p /root/.openclaw \
    && mkdir -p /root/.openclaw-templates \
    && mkdir -p /root/clawd \
    && mkdir -p /root/clawd/skills

# Copy startup script
# Build cache bust: 2026-01-28-v26-browser-skill
COPY start-moltbot.sh /usr/local/bin/start-moltbot.sh
RUN chmod +x /usr/local/bin/start-moltbot.sh

# Copy default configuration template
COPY moltbot.json.template /root/.openclaw-templates/moltbot.json.template

# Copy custom skills
COPY skills/ /root/clawd/skills/

# Set working directory
WORKDIR /root/clawd

# Expose the gateway port
EXPOSE 18789
