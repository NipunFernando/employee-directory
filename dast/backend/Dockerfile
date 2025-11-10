# Dockerfile
FROM ghcr.io/zaproxy/zaproxy:stable


RUN apk add --no-cache \
    bash \
    curl \
    jq \
    python3

# Copy scanning script
# Note: Build context should be set to dast/backend directory in Choreo
COPY dast-scan-backend.sh /usr/local/bin/dast-scan.sh
RUN chmod +x /usr/local/bin/dast-scan.sh

# Ensure script has proper line endings
RUN sed -i 's/\r$//' /usr/local/bin/dast-scan.sh || true


# Install additional tools
USER 10001

WORKDIR /zap

# Entry point
ENTRYPOINT ["/usr/local/bin/dast-scan.sh"]