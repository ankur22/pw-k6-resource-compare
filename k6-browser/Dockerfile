# Build stage - compile k6 from source
FROM golang:1.25-alpine AS builder

LABEL maintainer="k6-browser-test"

# Copy k6 source code from local repository (relative to build context)
COPY k6 /build/k6

# Build k6
WORKDIR /build/k6

# Build k6 (main.go is in root, not cmd/k6)
RUN go build

# Final stage - runtime environment
FROM node:20-alpine

LABEL maintainer="k6-browser-test"
LABEL description="k6 browser container for resource comparison"

# Install runtime dependencies
RUN apk add --no-cache ca-certificates

# Copy k6 binary from builder stage
COPY --from=builder /build/k6/k6 /usr/local/bin/k6
RUN chmod +x /usr/local/bin/k6

# Verify k6 installation
RUN k6 version

# Set working directory
WORKDIR /test-scripts

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD k6 version || exit 1

# Default command
CMD ["tail", "-f", "/dev/null"]
