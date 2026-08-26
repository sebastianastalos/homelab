# No plain container image is published for CloudCLI UI - the only upstream
# image (cloudcliai/sandbox) is built FROM docker/sandbox-templates and expects
# Docker's microVM sandbox runtime, which needs the apt-installed sbx CLI and
# does not nest inside TrueNAS' Docker. So we build our own.
#
# npm package versions are pinned so the image is reproducible, but note
# Renovate does not track npm installs inside a Dockerfile - bump these by hand
# and rebuild (same maintenance shape as github-runner).
FROM node:22.23.2-slim

ARG CLOUDCLI_VERSION=1.37.2
ARG CLAUDE_CODE_VERSION=2.1.246

# git is needed by Claude Code; ca-certificates for npm/registry TLS
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN npm install -g --no-audit --no-fund \
      "@cloudcli-ai/cloudcli@${CLOUDCLI_VERSION}" \
      "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
 && cloudcli --version && claude --version

WORKDIR /projects
