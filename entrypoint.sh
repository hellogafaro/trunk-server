#!/usr/bin/env bash
set -uo pipefail

export TRUNK_HOME="${TRUNK_HOME:-/data}"
export HOME="${TRUNK_HOME}"
export TRUNK_RUN_USER="${TRUNK_RUN_USER:-trunk}"

if [[ -n "${RAILWAY_PUBLIC_DOMAIN:-}" && -z "${TRUNK_PUBLIC_URL:-}" ]]; then
  export TRUNK_PUBLIC_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi

echo "[trunk-environment] entrypoint start; TRUNK_HOME=${TRUNK_HOME} HOME=${HOME} TRUNK_PUBLIC_URL=${TRUNK_PUBLIC_URL:-unset}"

run_as_app() {
  if [[ "$(id -u)" -eq 0 ]]; then
    gosu "${TRUNK_RUN_USER}" "$@"
  else
    "$@"
  fi
}

# Persistent state lives on the mounted volume so the environmentId and
# claimed pairing survive container restarts.
mkdir -p "${TRUNK_HOME}" "${TRUNK_HOME}/projects"
if [[ "$(id -u)" -eq 0 ]]; then
  chown -R "${TRUNK_RUN_USER}:${TRUNK_RUN_USER}" "${TRUNK_HOME}"
fi

# Optional SSH key from a Railway/Render/Fly secret. The container needs
# this to clone or push to private git remotes.
if [[ -n "${SSH_PRIVATE_KEY:-}" ]]; then
  run_as_app mkdir -p "${HOME}/.ssh"
  printf '%s\n' "${SSH_PRIVATE_KEY}" > "${HOME}/.ssh/id_ed25519"
  chmod 600 "${HOME}/.ssh/id_ed25519"
  ssh-keyscan github.com >> "${HOME}/.ssh/known_hosts" 2>/dev/null || true
  if [[ "$(id -u)" -eq 0 ]]; then
    chown -R "${TRUNK_RUN_USER}:${TRUNK_RUN_USER}" "${HOME}/.ssh"
  fi
fi

# Optional git user identity for commits the agent makes.
if [[ -n "${GIT_USER_NAME:-}" ]]; then
  run_as_app git config --global user.name "${GIT_USER_NAME}"
fi
if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
  run_as_app git config --global user.email "${GIT_USER_EMAIL}"
fi

# `trunk start` (the default subcommand) bootstraps the local config on
# first boot, prints the SaaS pair URL, then runs the server. That logic
# lives in the CLI itself — no shell-side banner needed.
echo "[trunk-environment] launching trunk on port ${PORT:-3773}"
if [[ "$(id -u)" -eq 0 ]]; then
  exec gosu "${TRUNK_RUN_USER}" bun run apps/server/src/bin.ts serve \
    --port "${PORT:-3773}" \
    --host 0.0.0.0 \
    --base-dir "${TRUNK_HOME}"
fi

exec bun run apps/server/src/bin.ts serve \
  --port "${PORT:-3773}" \
  --host 0.0.0.0 \
  --base-dir "${TRUNK_HOME}"
