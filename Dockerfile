# syntax=docker/dockerfile:1

########################################
# Base (build environment)
########################################
FROM node:20-bookworm AS base

WORKDIR /app

RUN apt-get update && \
    apt-get install -y curl git python3 openssh-client ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# install bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

########################################
# Install dependencies
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
# Runtime (small image)
########################################
FROM node:20-bookworm-slim AS runtime

ENV NODE_ENV=production

RUN apt-get update && \
    apt-get install -y git openssh-client python3 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

########################################
# Create user 1000:1000
########################################
RUN groupadd -g 1000 openchamber && \
    useradd -u 1000 -g 1000 -m -s /bin/bash openchamber

########################################
# Prepare directories
########################################
RUN mkdir -p \
    /home/openchamber/.npm-global \
    /home/openchamber/.config \
    /home/openchamber/.ssh && \
    chown -R 1000:1000 /home/openchamber

########################################
# Switch user
########################################
USER 1000:1000

WORKDIR /home/openchamber

########################################
# npm global config
########################################
ENV NPM_CONFIG_PREFIX=/home/openchamber/.npm-global
ENV PATH=$NPM_CONFIG_PREFIX/bin:$PATH

RUN npm config set prefix /home/openchamber/.npm-global && \
    npm install -g opencode-ai

########################################
# Copy app
########################################
COPY --chown=1000:1000 --from=builder /app/package.json ./package.json
COPY --chown=1000:1000 --from=builder /app/packages/web/package.json ./packages/web/package.json
COPY --chown=1000:1000 --from=builder /app/packages/web/dist ./packages/web/dist
COPY --chown=1000:1000 --from=builder /app/packages/web/server ./packages/web/server
COPY --chown=1000:1000 --from=builder /app/packages/web/bin ./packages/web/bin

COPY --chown=1000:1000 --from=deps /app/node_modules ./node_modules
COPY --chown=1000:1000 --from=deps /app/packages/web/node_modules ./packages/web/node_modules

COPY --chown=1000:1000 --chmod=755 scripts/docker-entrypoint.sh /app/openchamber-entrypoint.sh

########################################
# Expose
########################################
EXPOSE 3000

ENTRYPOINT ["/app/openchamber-entrypoint.sh"]# syntax=docker/dockerfile:1

########################################
# Base (build environment)
########################################
FROM node:20-bookworm AS base

WORKDIR /app

RUN apt-get update && \
    apt-get install -y curl git python3 openssh-client ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# install bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

########################################
# Install dependencies
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
# Runtime (small image)
########################################
FROM node:20-bookworm-slim AS runtime

ENV NODE_ENV=production

RUN apt-get update && \
    apt-get install -y git openssh-client python3 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

########################################
# Create user 1000:1000
########################################
RUN groupadd -g 1000 openchamber && \
    useradd -u 1000 -g 1000 -m -s /bin/bash openchamber

########################################
# Prepare directories
########################################
RUN mkdir -p \
    /home/openchamber/.npm-global \
    /home/openchamber/.config \
    /home/openchamber/.ssh && \
    chown -R 1000:1000 /home/openchamber

########################################
# Switch user
########################################
USER 1000:1000

WORKDIR /home/openchamber

########################################
# npm global config
########################################
ENV NPM_CONFIG_PREFIX=/home/openchamber/.npm-global
ENV PATH=$NPM_CONFIG_PREFIX/bin:$PATH

RUN npm config set prefix /home/openchamber/.npm-global && \
    npm install -g opencode-ai

########################################
# Copy app
########################################
COPY --chown=1000:1000 --from=builder /app/package.json ./package.json
COPY --chown=1000:1000 --from=builder /app/packages/web/package.json ./packages/web/package.json
COPY --chown=1000:1000 --from=builder /app/packages/web/dist ./packages/web/dist
COPY --chown=1000:1000 --from=builder /app/packages/web/server ./packages/web/server
COPY --chown=1000:1000 --from=builder /app/packages/web/bin ./packages/web/bin

COPY --chown=1000:1000 --from=deps /app/node_modules ./node_modules
COPY --chown=1000:1000 --from=deps /app/packages/web/node_modules ./packages/web/node_modules

COPY --chown=1000:1000 --chmod=755 scripts/docker-entrypoint.sh /app/openchamber-entrypoint.sh

########################################
# Expose
########################################
EXPOSE 3000

ENTRYPOINT ["/app/openchamber-entrypoint.sh"]
