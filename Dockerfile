# syntax=docker/dockerfile:1

FROM node:20-bookworm-slim

ENV NODE_ENV=production \
    UV_SYSTEM_PYTHON=1 \
    BUN_INSTALL=/home/openchamber/.bun \
    NPM_CONFIG_PREFIX=/home/openchamber/.npm-global \
    PATH=/home/openchamber/.bun/bin:/home/openchamber/.npm-global/bin:/usr/local/bin:$PATH

WORKDIR /home/openchamber

########################################
# uv (python package manager)
########################################
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

########################################
# bun runtime
########################################
COPY --from=oven/bun:1 /usr/local/bin/bun /usr/local/bin/bun

########################################
# system packages
########################################
RUN apt-get update && apt-get install -y \
    curl \
    git \
    openssh-client \
    python3 \
    python-is-python3 \
    build-essential \
    ca-certificates \
    unzip \
 && rm -rf /var/lib/apt/lists/*

########################################
# create user 1001
########################################
RUN groupadd -g 1001 openchamber && \
    useradd -u 1001 -g 1001 -m -s /bin/bash openchamber

########################################
# create directories used by volumes
########################################
RUN mkdir -p \
 /home/openchamber/.bun \
 /home/openchamber/.npm \
 /home/openchamber/.npm-global \
 /home/openchamber/.config/openchamber \
 /home/openchamber/.config/opencode \
 /home/openchamber/.local/share/opencode \
 /home/openchamber/.local/state/opencode \
 /home/openchamber/.ssh \
 /home/openchamber/workspaces \
 /home/openchamber/app-db

RUN chown -R 1001:1001 /home/openchamber

USER 1001:1001

########################################
# install openchamber
########################################
RUN curl -fsSL https://raw.githubusercontent.com/btriapitsyn/openchamber/main/scripts/install.sh | bash

########################################
# install opencode CLI
########################################
RUN --mount=type=cache,target=/home/openchamber/.npm,uid=1001,gid=1001 \
    npm install -g opencode-ai

EXPOSE 3000

CMD ["openchamber"]
