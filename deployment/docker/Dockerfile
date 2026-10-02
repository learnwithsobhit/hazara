# Multi-stage build for hazara-server.
# Build from repo root: docker build -f deployment/docker/Dockerfile .

FROM rust:1.88-bookworm AS builder
WORKDIR /app
COPY backend/ ./backend/
WORKDIR /app/backend
RUN cargo build --release -p hazara-server

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /data \
    && chown nobody:nogroup /data
WORKDIR /srv
COPY --from=builder /app/backend/target/release/hazara-server /usr/local/bin/hazara-server
COPY deployment/docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENV RUST_LOG=info
ENV PORT=8080
ENV HAZARA_STATE=/data
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8080/healthz || exit 1
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["hazara-server"]
