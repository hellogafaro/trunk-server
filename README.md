# trunk-environment

Container image that runs a [Trunk](https://github.com/hellogafaro/trunk)
server in the cloud. Pairs with [app.trunk.codes](https://app.trunk.codes)
over a direct HTTPS/WSS connection — no relay, no Trunk-side data path.

## How it works

The container starts T3 in `serve` mode on the port Railway assigns. T3
prints a pair URL + token. You paste the URL + token into
`app.trunk.codes/onboarding`. The browser holds a bearer; Trunk's tiny
Worker (`api.trunk.codes`) keeps the saved-env list in WorkOS Vault so
the same envs show up on every device you sign into.

## Deploy on Railway (one-click)

The recommended path is the published Railway template — it preconfigures
the domain (port 8080), the persistent volume (`/data`), and the env-var
schema. Replace the URL below with the published template once you create
it from your service in the Railway dashboard:

> Deploy on Railway: _replace with the published template URL_

## Deploy on Railway (manual)

1. **New Project → Deploy from GitHub repo** → pick this repo.
2. **Networking**: generate a domain with **target port 8080**. Railway
   will inject `RAILWAY_PUBLIC_DOMAIN`; the entrypoint forwards it as
   `TRUNK_PUBLIC_URL` so the printed pair URL is publicly reachable.
3. **Volume**: mount `/data`. Without it the env identity rotates on
   every redeploy.
4. **Variables** (all optional):

   | Name | Purpose |
   |---|---|
   | `ANTHROPIC_API_KEY` | Claude provider |
   | `OPENAI_API_KEY` | Codex provider |
   | `SSH_PRIVATE_KEY` | clone/push to private git remotes |
   | `GIT_USER_NAME` / `GIT_USER_EMAIL` | agent-authored commits |
   | `TRUNK_PUBLIC_URL` | overrides the auto-detected public URL |

5. Deploy. The boot log prints:

   ```
   Trunk server is ready.
   Connection string: https://<your-railway-domain>
   Token: <pair-token>
   Pairing URL: https://<your-railway-domain>/pair#token=<token>
   ```

6. Open `app.trunk.codes/onboarding`. Paste the **Connection string** as
   _Environment URL_, the **Token** as _Pair token_, give it a label.

## Deploy elsewhere

Any Docker host works. Requirements:

- A reachable HTTPS hostname (Tailscale, Cloudflare Tunnel, or your own
  TLS proxy). `app.trunk.codes` only connects over `https://` or
  `ws://localhost`.
- Persistent volume at `${TRUNK_HOME}` (default `/data`).
- Set `TRUNK_PUBLIC_URL` to the public hostname so the printed pair URL
  is correct.

## Pinning a CLI version

The image clones `hellogafaro/trunk@main` by default. Pin to a specific
commit or tag at build time:

```
docker build --build-arg TRUNK_REF=<sha> -t trunk-environment .
```

## Publishing the Railway template

Once the service is configured (domain, volume, env vars):

1. Railway dashboard → service → **Create Template**.
2. Railway snapshots the repo URL, branch, and current dashboard config.
3. Share the resulting template URL — clicking it deploys a new service
   with the same config preconfigured.
