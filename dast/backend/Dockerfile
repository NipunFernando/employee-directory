# Dockerfile
FROM ghcr.io/zaproxy/zaproxy:stable

# Install additional tools
USER root
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    python3

# Copy scanning script
COPY dast-scan-backend.sh /usr/local/bin/dast-scan.sh
RUN chmod +x /usr/local/bin/dast-scan.sh

# Switch back to zap user
USER zap

WORKDIR /zap

# Entry point
ENTRYPOINT ["/usr/local/bin/dast-scan.sh"]