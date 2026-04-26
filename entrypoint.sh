#!/usr/bin/env bash
set -euo pipefail

# Persistent state lives on the mounted volume so the serverId and any
# claimed pairing survives container restarts.
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

# First boot writes ${TRUNK_HOME}/.trunk/config.json with a fresh
# environmentId and runs the WorkOS device flow to claim it; subsequent
# boots reuse the existing config and skip the claim.
config_path="${TRUNK_HOME}/.trunk/config.json"
if [[ ! -f "${config_path}" ]]; then
  bun run apps/server/src/bin.ts pair
fi

environment_id=$(grep -o '"environmentId"[[:space:]]*:[[:space:]]*"[^"]*"' "${config_path}" | head -1 | sed -E 's/.*"environmentId"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
echo ""
echo "============================================"
echo "  Trunk environmentId: ${environment_id}"
echo "  Open: https://app.trunk.codes"
echo "============================================"
echo ""

# Loopback host keeps the inbound surface zero. The relay opens
# loopback connections in-process; nothing else should reach /ws.
exec bun run apps/server/src/bin.ts serve \
  --port "${PORT:-3773}" \
  --host 127.0.0.1
