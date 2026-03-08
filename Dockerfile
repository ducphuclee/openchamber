# syntax=docker/dockerfile:1

########################################
# STAGE 1: Base - Cài đặt công cụ lõi
########################################
FROM node:20-bookworm AS base

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Bỏ --no-install-recommends và thêm build-essential để hỗ trợ node-gyp
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
        curl git python3 openssh-client ca-certificates unzip build-essential

RUN curl -fsSL https://bun.sh/install | bash && \
    mv /root/.bun/bin/bun /usr/local/bin/bun

########################################
# STAGE 2: Deps - Cài đặt dependencies với Cache
########################################
FROM base AS deps

WORKDIR /app

COPY package.json bun.lock ./
COPY packages/ui/package.json ./packages/ui/
COPY packages/web/package.json ./packages/web/
COPY packages/desktop/package.json ./packages/desktop/
COPY packages/vscode/package.json ./packages/vscode/

RUN --mount=type=cache,target=/root/.bun/install/cache \
    bun install --frozen-lockfile

########################################
# STAGE 3: Builder - Build mã nguồn
########################################
FROM deps AS builder

WORKDIR /app
COPY . .
RUN bun run build:web

########################################
# STAGE 4: Runtime - Image cuối cùng
########################################
FROM node:20-bookworm-slim AS runtime

ENV NODE_ENV=production \
    UV_SYSTEM_PYTHON=1 \
    UV_LINK_MODE=copy \
    NPM_CONFIG_PREFIX=/home/openchamber/.npm-global \
    PATH=/home/openchamber/.npm-global/bin:/usr/local/bin:$PATH

WORKDIR /home/openchamber

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
COPY --from=base /usr/local/bin/bun /usr/local/bin/bun

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Ở runtime thì không cần build-essential nữa cho nhẹ
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
        git openssh-client python3 ca-certificates curl unzip

########################################
# User 1001:1001
########################################
RUN groupadd -g 1001 openchamber && \
    useradd -u 1001 -g 1001 -m -s /bin/bash openchamber && \
    mkdir -p /home/openchamber/.ssh /home/openchamber/.config /home/openchamber/.npm-global && \
    chown -R 1001:1001 /home/openchamber

USER 1001:1001

RUN --mount=type=cache,target=/home/openchamber/.npm,uid=1001,gid=1001 \
    npm config set prefix /home/openchamber/.npm-global && \
    npm install -g opencode-ai

########################################
# Copy mã nguồn
########################################
COPY --chown=1001:1001 --from=builder /app/package.json ./package.json
COPY --chown=1001:1001 --from=builder /app/packages/web/package.json ./packages/web/package.json
COPY --chown=1001:1001 --from=builder /app/packages/web/bin ./packages/web/bin
COPY --chown=1001:1001 --from=builder /app/packages/web/server ./packages/web/server
COPY --chown=1001:1001 --from=builder /app/packages/web/dist ./packages/web/dist

COPY --chown=1001:1001 --from=deps /app/node_modules ./node_modules
COPY --chown=1001:1001 --from=deps /app/packages/web/node_modules ./packages/web/node_modules

COPY --chmod=755 scripts/docker-entrypoint.sh /app/openchamber-entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/app/openchamber-entrypoint.sh"]
