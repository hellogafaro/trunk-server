FROM oven/bun:1

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       git \
       openssh-client \
       ca-certificates \
       curl \
       python3 \
       make \
       g++ \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/trunk

# The CLI lives in the public trunk repo. Pull a known revision so
# rebuilds are reproducible. Override TRUNK_REF at build time to pin
# to a tag or commit.
ARG TRUNK_REPO=https://github.com/hellogafaro/trunk.git
ARG TRUNK_REF=main
RUN git clone --depth 1 --branch "${TRUNK_REF}" "${TRUNK_REPO}" . \
  && bun install --frozen-lockfile

ENV TRUNK_HOME=/data
ENV TRUNK_API_URL=wss://api.trunk.codes

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3773
CMD ["/usr/local/bin/entrypoint.sh"]
