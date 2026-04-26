#!/usr/bin/env bash
set -uo pipefail

echo "[trunk-environment] entrypoint start; TRUNK_HOME=${TRUNK_HOME:-unset} TRUNK_API_URL=${TRUNK_API_URL:-unset}"

# Persistent state lives on the mounted volume so the serverId and any
# claimed pairing survives container restarts.
mkdir -p "${TRUNK_HOME}"
echo "[trunk-environment] ensured ${TRUNK_HOME}"

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
# boots reuse the existing config and skip the claim. Tolerate claim
# failures so the server still comes up — the user can re-pair later.
config_path="${TRUNK_HOME}/.trunk/config.json"
echo "[trunk-environment] config_path=${config_path} exists=$([[ -f $config_path ]] && echo yes || echo no)"
if [[ ! -f "${config_path}" ]]; then
  echo "[trunk-environment] running trunk pair (with --no-claim for unattended bootstrap)"
  bun run apps/server/src/bin.ts pair --no-claim || echo "[trunk-environment] WARN: trunk pair --no-claim exited non-zero"
fi

environment_id=$(grep -o '"environmentId"[[:space:]]*:[[:space:]]*"[^"]*"' "${config_path}" | head -1 | sed -E 's/.*"environmentId"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
trunk_app_url="${TRUNK_APP_URL:-https://app.trunk.codes}"
echo ""
echo "============================================================"
echo " Trunk environment is up — pair it with your account:"
echo ""
echo "   ${trunk_app_url}/pair?environmentId=${environment_id}"
echo ""
echo " Open that URL on any device, sign in, and you're done."
echo "============================================================"
echo ""

# Bind to 0.0.0.0 so the host platform's healthcheck can reach $PORT.
# T3's WS upgrade is still gated by the loopback-trust header (which
# only RemoteLink, running in the same process, knows), and the
# WorkOS bearer for browser /ws — so the open bind is not an exposure
# as long as the container has no public networking configured.
echo "[trunk-environment] launching serve on port ${PORT:-3773}"
exec bun run apps/server/src/bin.ts serve \
  --port "${PORT:-3773}" \
  --host 0.0.0.0
