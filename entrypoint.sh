#!/usr/bin/env bash
set -uo pipefail

if [[ -n "${RAILWAY_PUBLIC_DOMAIN:-}" && -z "${TRUNK_PUBLIC_URL:-}" ]]; then
  export TRUNK_PUBLIC_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi

echo "[trunk-environment] entrypoint start; TRUNK_HOME=${TRUNK_HOME:-unset} TRUNK_PUBLIC_URL=${TRUNK_PUBLIC_URL:-unset}"

# Persistent state lives on the mounted volume so the environmentId and
# claimed pairing survive container restarts.
mkdir -p "${TRUNK_HOME}"

# Optional SSH key from a Railway/Render/Fly secret. The container needs
# this to clone or push to private git remotes.
if [[ -n "${SSH_PRIVATE_KEY:-}" ]]; then
  mkdir -p /root/.ssh
  printf '%s\n' "${SSH_PRIVATE_KEY}" > /root/.ssh/id_ed25519
  chmod 600 /root/.ssh/id_ed25519
  ssh-keyscan github.com >> /root/.ssh/known_hosts 2>/dev/null || true
fi

# Optional git user identity for commits the agent makes.
if [[ -n "${GIT_USER_NAME:-}" ]]; then
  git config --global user.name "${GIT_USER_NAME}"
fi
if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
  git config --global user.email "${GIT_USER_EMAIL}"
fi

# `trunk start` (the default subcommand) bootstraps the local config on
# first boot, prints the SaaS pair URL, then runs the server. That logic
# lives in the CLI itself — no shell-side banner needed.
echo "[trunk-environment] launching trunk on port ${PORT:-3773}"
exec bun run apps/server/src/bin.ts serve \
  --port "${PORT:-3773}" \
  --host 0.0.0.0
