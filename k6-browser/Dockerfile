FROM node:20-alpine

LABEL maintainer="k6-browser-test"
LABEL description="k6 browser container for resource comparison"

# Install k6 v1.3.0
RUN apk add --no-cache ca-certificates curl && \
    curl -sL "https://github.com/grafana/k6/releases/download/v1.3.0/k6-v1.3.0-linux-amd64.tar.gz" -o /tmp/k6.tar.gz && \
    tar -xzf /tmp/k6.tar.gz -C /tmp && \
    cp /tmp/k6-v1.3.0-linux-amd64/k6 /usr/local/bin/k6 && \
    chmod +x /usr/local/bin/k6 && \
    rm -rf /tmp/k6* && \
    apk del curl

# Verify k6 installation
RUN k6 version

# Set working directory
WORKDIR /test-scripts

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD k6 version || exit 1

# Default command
CMD ["tail", "-f", "/dev/null"]

