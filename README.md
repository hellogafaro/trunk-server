# trunk-server

Container image that runs a Trunk server in the cloud and connects it to
[`api.trunk.codes`](https://api.trunk.codes) via the outbound relay. Use
this when you want a Trunk environment that isn't your laptop — Railway,
Render, Fly, Hetzner, anywhere that runs Docker.

## How it works

The Trunk CLI (in [hellogafaro/trunk](https://github.com/hellogafaro/trunk))
opens a single outbound WebSocket to `api.trunk.codes`. Each browser that
signs in at [app.trunk.codes](https://app.trunk.codes) is bridged through
that link to the loopback `/ws` endpoint inside the container. The
container exposes no inbound port to the public internet.

## Deploy on Railway

1. Click **New Project → Deploy from GitHub repo** and pick your fork (or
   the canonical `hellogafaro/trunk-server`).
2. **Volume**: add a persistent volume mounted at `/data`. This is where
   `~/.trunk/config.json` lives — without it every redeploy generates a
   fresh `serverId` and you'd have to re-pair.
3. **Variables**:
   | Name | Value |
   |---|---|
   | `TRUNK_API_URL` | `wss://api.trunk.codes` |
   | `TRUNK_HOME` | `/data` |
   | `ANTHROPIC_API_KEY` | (optional, for the Claude provider) |
   | `OPENAI_API_KEY` | (optional, for the Codex provider) |
   | `SSH_PRIVATE_KEY` | (optional, for cloning private repos) |
   | `GIT_USER_NAME` / `GIT_USER_EMAIL` | (optional, for agent commits) |
4. **Public networking**: leave it disabled. Trunk only dials outbound.
5. Deploy. Look at the logs — the first boot prints something like:
   ```
   Trunk server pairing complete.

     config:    /data/.trunk/config.json
     serverId:  calm-meadow-u9rx
   ```
6. Sign in at [app.trunk.codes](https://app.trunk.codes), open
   `/connect-server`, paste the `serverId`. The browser then opens a
   real-time session against your Railway container.

## Deploy elsewhere

Any Docker host works. The only requirements:

- Outbound HTTPS to `api.trunk.codes`.
- Persistent volume at `${TRUNK_HOME}` (default `/data`) so the
  `serverId` survives restarts.
- No inbound port needs to be exposed.

## Pinning a CLI version

The image clones `hellogafaro/trunk@main` by default. Pin to a specific
tag or commit at build time:

```
docker build --build-arg TRUNK_REF=v0.1.0 -t trunk-server .
```

## Local sanity check

```bash
docker build -t trunk-server .
docker run --rm \
  -e TRUNK_API_URL=ws://host.docker.internal:8787 \
  -v "$(pwd)/.trunk-data:/data" \
  trunk-server
```

This points the container at a local `wrangler dev` instance and stores
the serverId in `./.trunk-data/`.
