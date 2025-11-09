# Dockerfile
FROM ghcr.io/zaproxy/zaproxy:stable

# Install additional tools
USER root
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    python3 \
    py3-pip \
    firefox-esr \
    xvfb

# Install Selenium for authenticated scanning (optional)
RUN pip3 install --no-cache-dir selenium

# Copy scanning script
COPY dast-scan-frontend.sh /usr/local/bin/dast-scan.sh
RUN chmod +x /usr/local/bin/dast-scan.sh

# Switch back to zap user
USER zap

WORKDIR /zap

# Entry point
ENTRYPOINT ["/usr/local/bin/dast-scan.sh"]