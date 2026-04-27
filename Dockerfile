# Stage 1 — install + native build. Has the full toolchain so the
# node-pty postinstall (and any other native deps) succeeds.
FROM oven/bun:1 AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       git \
       ca-certificates \
       python3 \
       make \
       g++ \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/trunk

ARG TRUNK_REPO=https://github.com/hellogafaro/trunk.git
# Pin to a SHA so each bump invalidates the Docker layer cache and we
# always get the intended trunk revision. To upgrade: edit this line.
ARG TRUNK_REF=d548a386
RUN git clone "${TRUNK_REPO}" . \
  && git checkout "${TRUNK_REF}" \
  && bun install --frozen-lockfile

# Drop everything the headless server doesn't need at runtime: sibling
# apps, the API worker, source maps, .git, dev caches. node_modules
# stays intact so the workspace symlinks for @t3tools/* keep resolving.
RUN rm -rf \
      .git \
      apps/api \
      apps/desktop \
      apps/marketing \
      apps/web \
      docs \
      .turbo \
  && find . -name "*.map" -delete

# Stage 2 — slim runtime. No toolchain, just bun + git + ssh for git
# auth.
FROM oven/bun:1-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       git \
       openssh-client \
       ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/trunk
COPY --from=builder /opt/trunk /opt/trunk

ENV TRUNK_HOME=/data
ENV TRUNK_API_URL=wss://api.trunk.codes
ENV NODE_ENV=production

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3773
CMD ["/usr/local/bin/entrypoint.sh"]
