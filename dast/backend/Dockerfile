# Dockerfile
FROM ghcr.io/zaproxy/zaproxy:stable

# Switch to root to install packages
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    jq \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Copy scanning script
# Note: Build context should be set to dast/backend directory in Choreo
COPY dast-scan-backend.sh /usr/local/bin/dast-scan.sh
RUN chmod +x /usr/local/bin/dast-scan.sh

# Ensure script has proper line endings
RUN sed -i 's/\r$//' /usr/local/bin/dast-scan.sh || true

# Switch back to non-root user
USER 10001

WORKDIR /zap

# Entry point
ENTRYPOINT ["/usr/local/bin/dast-scan.sh"]