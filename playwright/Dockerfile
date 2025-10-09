FROM node:20-alpine

LABEL maintainer="playwright-test"
LABEL description="Playwright container for resource comparison"

# Install dependencies for Playwright
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont

# Set working directory
WORKDIR /app

# Install Playwright Test framework (includes playwright core)
RUN npm install -g @playwright/test@latest

# Skip browser download - will connect to external Chrome
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

# Set working directory for test scripts
WORKDIR /test-scripts

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node --version || exit 1

# Default command
CMD ["tail", "-f", "/dev/null"]
