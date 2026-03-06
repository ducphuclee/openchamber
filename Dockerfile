# syntax=docker/dockerfile:1

########################################
# Base image
########################################
FROM node:20-bookworm AS base

WORKDIR /app

RUN apt-get update && \
    apt-get install -y \
        curl \
        git \
        python3 \
        openssh-client \
        ca-certificates \
        unzip && \
    rm -rf /var/lib/apt/lists/*

# install bun
RUN curl -fsSL https://bun.sh/install | bash && \
    mv /root/.bun/bin/bun /usr/local/bin/bun

########################################
# Dependencies
########################################
FROM base AS deps

WORKDIR /app

COPY package.json bun.lock ./
COPY packages/ui/package.json ./packages/ui/
COPY packages/web/package.json ./packages/web/
COPY packages/desktop/package.json ./packages/desktop/
COPY packages/vscode/package.json ./packages/vscode/

RUN bun install --frozen-lockfile

########################################
# Build
########################################
FROM deps AS builder

WORKDIR /app
COPY . .

RUN bun run build:web

########################################
# Runtime
########################################
FROM node:20-bookworm-slim AS runtime

ENV NODE_ENV=production

WORKDIR /home/openchamber

RUN apt-get update && \
    apt-get install -y \
        git \
        openssh-client \
        python3 \
        ca-certificates \
        curl \
        unzip && \
    rm -rf /var/lib/apt/lists/*

########################################
# install bun in runtime
########################################
RUN curl -fsSL https://bun.sh/install | bash && \
    mv /root/.bun/bin/bun /usr/local/bin/bun

########################################
# ensure UID 1000 user exists
########################################
RUN if ! id -u 1000 >/dev/null 2>&1; then \
      useradd -u 1000 -m -s /bin/bash openchamber; \
    fi

########################################
# directories
########################################
RUN mkdir -p \
    /home/openchamber/.ssh \
    /home/openchamber/.config \
    /home/openchamber/.npm-global && \
    chown -R 1000:1000 /home/openchamber

########################################
# switch user
########################################
USER 1000:1000

########################################
# npm global
########################################
ENV NPM_CONFIG_PREFIX=/home/openchamber/.npm-global
ENV PATH=/home/openchamber/.npm-global/bin:/usr/local/bin:$PATH

RUN npm config set prefix /home/openchamber/.npm-global && \
    npm install -g opencode-ai

########################################
# copy built app
########################################
COPY --chown=1000:1000 --from=builder /app/package.json ./package.json
COPY --chown=1000:1000 --from=builder /app/packages/web/package.json ./packages/web/package.json
COPY --chown=1000:1000 --from=builder /app/packages/web/bin ./packages/web/bin
COPY --chown=1000:1000 --from=builder /app/packages/web/server ./packages/web/server
COPY --chown=1000:1000 --from=builder /app/packages/web/dist ./packages/web/dist

COPY --chown=1000:1000 --from=deps /app/node_modules ./node_modules
COPY --chown=1000:1000 --from=deps /app/packages/web/node_modules ./packages/web/node_modules

COPY --chmod=755 scripts/docker-entrypoint.sh /app/openchamber-entrypoint.sh

########################################
# port
########################################
EXPOSE 3000

ENTRYPOINT ["/app/openchamber-entrypoint.sh"]
