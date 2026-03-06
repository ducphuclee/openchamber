# syntax=docker/dockerfile:1

########################################
# Base image
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
# Build stage
########################################
FROM deps AS builder

WORKDIR /app

COPY . .

RUN bun run build:web

########################################
# Runtime (minimal)
########################################
FROM node:20-bookworm-slim AS runtime

WORKDIR /home/openchamber

RUN apt-get update && \
    apt-get install -y git openssh-client python3 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production

# create non-root user
RUN useradd -m -s /bin/bash openchamber

USER openchamber

########################################
# npm global path
########################################
ENV NPM_CONFIG_PREFIX=/home/openchamber/.npm-global
ENV PATH=$NPM_CONFIG_PREFIX/bin:$PATH

RUN mkdir -p /home/openchamber/.npm-global && \
    mkdir -p /home/openchamber/.config && \
    mkdir -p /home/openchamber/.ssh && \
    npm config set prefix /home/openchamber/.npm-global && \
    npm install -g opencode-ai

########################################
# Copy build artifacts
########################################

COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/packages/web/package.json ./packages/web/package.json
COPY --from=builder /app/packages/web/dist ./packages/web/dist
COPY --from=builder /app/packages/web/server ./packages/web/server
COPY --from=builder /app/packages/web/bin ./packages/web/bin

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/packages/web/node_modules ./packages/web/node_modules

COPY --chmod=755 scripts/docker-entrypoint.sh /app/openchamber-entrypoint.sh

########################################
# Expose
########################################

EXPOSE 3000

ENTRYPOINT ["/app/openchamber-entrypoint.sh"]
