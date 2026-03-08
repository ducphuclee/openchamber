FROM node:20-bookworm-slim

ENV NODE_ENV=production \
    NPM_CONFIG_PREFIX=/home/openchamber/.npm-global \
    PATH=/home/openchamber/.npm-global/bin:/usr/local/bin:$PATH \
    UV_SYSTEM_PYTHON=1

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
# runtime packages
########################################
RUN apt-get update && apt-get install -y \
    curl \
    git \
    openssh-client \
    python3 \
    python-is-python3 \
    ca-certificates \
    unzip \
 && rm -rf /var/lib/apt/lists/*

########################################
# user 1001:1001 (match docker compose)
########################################
RUN groupadd -g 1001 openchamber && \
    useradd -u 1001 -g 1001 -m -s /bin/bash openchamber

########################################
# directories used by volumes
########################################
RUN mkdir -p \
 /home/openchamber/.config/openchamber \
 /home/openchamber/.config/opencode \
 /home/openchamber/.local/share/opencode \
 /home/openchamber/.local/state/opencode \
 /home/openchamber/.ssh \
 /home/openchamber/workspaces \
 /home/openchamber/app-db

########################################
# switch user
########################################
USER 1001:1001

########################################
# install openchamber
########################################
RUN curl -fsSL https://raw.githubusercontent.com/btriapitsyn/openchamber/main/scripts/install.sh | bash

EXPOSE 3000

CMD ["openchamber"]
