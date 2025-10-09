# k6 Browser vs Playwright Resource Comparison

This project provides a complete Docker-based environment to compare compute resource usage between k6 browser and Playwright when running identical browser automation tests.

## Architecture

```
┌──────────────────────┐
│   k6-browser         │
│   (PURE - only k6)   │──┐
│   (1 CPU, 512MB)     │  │
└──────────────────────┘  │
                          │
┌──────────────────────┐  │    ┌──────────────────┐
│   playwright         │  ├───▶│  Chrome          │
│   (PURE - only PW)   │  │    │  (browserless)   │
│   (1 CPU, 512MB)     │──┘    └──────────────────┘
└──────────────────────┘
         ↑
         │ Monitored by (Docker Stats API)
         │
┌──────────────────────┐
│  Stats Exporter      │
│  (reads cgroups)     │
└──────────────────────┘
         │
         │ Prometheus scrapes
         ↓
┌──────────────────────┐
│   Prometheus         │
│   (metrics storage)  │
└──────────────────────┘
         │
         │ Grafana queries
         ↓
┌──────────────────────┐
│     Grafana          │
│   (Dashboards)       │
└──────────────────────┘
```

## Components

- **k6-browser**: k6 v1.3.0 (Node.js 20 Alpine) - PURE, no monitoring overhead
- **Playwright**: Latest Playwright (Node.js 20 Alpine) - PURE, no monitoring overhead
- **Chrome**: Standalone Chrome instance via browserless/chrome (external browser)
- **Stats Exporter**: Custom Docker Stats exporter (reads Docker API, works on macOS)
- **Prometheus**: Time-series metrics storage (scrapes stats exporter)
- **Grafana**: Visualization and dashboards

## ✅ Zero Monitoring Overhead

**Important:** Test containers are PURE - they contain only the test tool with **zero monitoring overhead**.

Metrics are collected **externally** via Docker Stats Exporter which:
- Reads Docker API (`docker stats`)
- Respects resource limits (1 CPU, 512MB)
- Provides **isolated metrics** per container
- Works reliably on macOS Docker Desktop

This ensures a **truly fair comparison** between k6 and Playwright.

## Resource Limits

Both k6-browser and Playwright containers are constrained to:
- **CPU**: 1.0 cores (max), 0.5 cores (reserved)
- **Memory**: 512MB (max), 256MB (reserved)

## Prerequisites

- Docker (with Docker Compose)
- Your test scripts (see `test-scripts/README.md`)

## Quick Start

### 1. Start the Stack

```bash
docker compose up -d
```

This will start all services:
- Chrome: http://localhost:3000 (Debug viewer)
- Grafana: http://localhost:3001 (Dashboards)
- Prometheus: http://localhost:9090
- Stats Exporter: http://localhost:8091/metrics

### 2. Wait for Services to Initialize

```bash
# Check all containers are healthy
docker compose ps

# Watch logs
docker compose logs -f
```

### 3. Add Your Test Scripts

Place your test scripts in the `test-scripts/` directory:

```
test-scripts/
├── k6/
│   └── test.js
└── playwright/
    └── test.js
```

See `test-scripts/README.md` for script examples.

### 4. Run Tests

**Using the test runner script (recommended):**

```bash
# Run k6 test
./run-tests.sh k6

# Run Playwright test (default: 1 worker)
./run-tests.sh playwright

# Run Playwright with parallel workers
PLAYWRIGHT_WORKERS=5 PLAYWRIGHT_REPEAT=10 ./run-tests.sh playwright

# Run both tests sequentially
./run-tests.sh both

# Run both in parallel for side-by-side comparison
./run-tests.sh both-parallel
```

**Environment Variables for Test Configuration:**

```bash
# Playwright configuration
PLAYWRIGHT_WORKERS=10    # Number of parallel workers (default: 1)
PLAYWRIGHT_REPEAT=50     # Repeat each test N times (default: 1)

# k6 configuration (future support)
K6_VUS=10               # Number of virtual users (default: 1)
K6_ITERATIONS=50        # Number of iterations (default: 1)

# Examples:
PLAYWRIGHT_WORKERS=10 PLAYWRIGHT_REPEAT=50 ./run-tests.sh playwright
```

**Or run directly:**

```bash
# k6 browser test
docker compose exec k6-browser k6 run /test-scripts/k6/test.js

# Playwright test with workers
docker compose exec playwright sh -c "cd /test-scripts/playwright && npx playwright test --workers=5 --repeat-each=10"
```

### 5. View Metrics in Grafana

Open http://localhost:3001 in your browser. The "k6 vs Playwright Resource Comparison" dashboard will show:

- **CPU Usage Comparison**: Real-time CPU usage for both containers
- **Memory Usage Comparison**: Working set memory usage
- **Gauges**: Current CPU % and memory usage
- **Network I/O**: Network traffic comparison
- **Memory RSS**: Resident set size comparison

## Running Tests Simultaneously

To compare side-by-side, run tests at the same time in separate terminals:

**Terminal 1:**
```bash
docker compose exec k6-browser k6 run /test-scripts/k6/test.js
```

**Terminal 2:**
```bash
docker compose exec playwright node /test-scripts/playwright/test-simple.js
```

Watch the Grafana dashboard to see real-time resource usage.

## Running Tests with Timing

To measure execution time:

```bash
# k6 browser
time docker compose exec k6-browser k6 run /test-scripts/k6/test.js

# Playwright
time docker compose exec playwright node /test-scripts/playwright/test-simple.js
```

## Monitoring Endpoints

- **Grafana**: http://localhost:3001
  - Username: admin (auto-login enabled)
  - Dashboard: "k6 vs Playwright Resource Comparison"
  
- **Prometheus**: http://localhost:9090
  - Query metrics directly
  - Example: `container_memory_usage_bytes{name="k6-browser"}`

- **Stats Exporter**: http://localhost:8091/metrics
  - View raw Prometheus metrics
  - Check container CPU, memory, network stats

- **Chrome Debug**: http://localhost:3000
  - View browser sessions
  - Inspect DevTools Protocol

## Prometheus Queries

Useful queries for manual analysis (from Docker Stats Exporter):

```promql
# CPU usage percentage (0-100% of total system, max ~25% for 1 CPU on 4-core system)
container_cpu_usage_percent{name="k6-browser"}
container_cpu_usage_percent{name="playwright"}
container_cpu_usage_percent{name="chrome-debug"}

# Memory usage in bytes (respects 512MB limit for k6/playwright)
container_memory_usage_bytes{name="k6-browser"}
container_memory_usage_bytes{name="playwright"}
container_memory_usage_bytes{name="chrome-debug"}

# Memory limits (shows Docker-configured limits)
container_memory_limit_bytes{name="k6-browser"}      # 512MB
container_memory_limit_bytes{name="playwright"}      # 512MB
container_memory_limit_bytes{name="chrome-debug"}    # host limit

# Network bytes (cumulative counters - use rate() for throughput)
container_network_rx_bytes{name="k6-browser"}
container_network_tx_bytes{name="k6-browser"}

# Network throughput (bytes per second)
rate(container_network_rx_bytes{name="k6-browser"}[30s])
rate(container_network_tx_bytes{name="playwright"}[30s])
```

## Troubleshooting

### Containers Won't Start

```bash
# Check logs
docker compose logs

# Restart services
docker compose restart
```

### Chrome Connection Issues

Verify Chrome is accessible:
```bash
curl http://localhost:3000
```

Check the WebSocket endpoint from within containers:
```bash
docker compose exec k6-browser sh -c 'echo $K6_BROWSER_WS_URL'
docker compose exec playwright sh -c 'echo $CHROME_WS_URL'
```

### No Metrics in Grafana

1. Check Prometheus is scraping stats exporter: http://localhost:9090/targets
   - Should show `docker-stats` job with status "UP"
2. Verify stats exporter is running:
   ```bash
   curl http://localhost:8091/metrics | grep container_
   ```
3. Check exporter logs for errors:
   ```bash
   docker compose logs stats-exporter
   ```
4. Manually query Prometheus:
   ```bash
   curl 'http://localhost:9090/api/v1/query?query=container_memory_usage_bytes'
   ```

### Memory Limit Exceeded

If containers are OOM killed, check logs:
```bash
docker compose logs k6-browser
docker compose logs playwright
```

Consider adjusting limits in `docker-compose.yml`.

## Cleaning Up

```bash
# Stop all services
docker compose down

# Remove volumes (metrics data)
docker compose down -v

# Remove images
docker compose down --rmi all
```

## Customization

### Adjusting Resource Limits

Edit `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'      # Change CPU limit
      memory: 1024M    # Change memory limit
```

### Adding Custom Metrics

Modify `prometheus/prometheus.yml` to add additional scrape targets or metric exporters.

### Dashboard Customization

Edit `grafana/dashboards/resource-comparison.json` or create new dashboards via the Grafana UI. Auto-provisioned dashboards can be updated in the UI.

## Architecture Decisions

1. **Same Base OS**: Both containers use `node:20-alpine` for consistency
2. **External Chrome**: Isolates browser overhead from tool overhead
3. **Resource Limits**: Docker resource constraints ensure fair comparison (1 CPU, 512MB each)
4. **External Monitoring**: Stats exporter monitors containers from outside (zero overhead in test containers)
5. **Isolated Metrics**: Each container's metrics are independent - running k6 test doesn't affect Playwright graphs
6. **macOS Compatible**: Uses Docker Stats API instead of cAdvisor (which has Docker socket issues on macOS)

## Test Script Notes

### k6 Browser
- Uses `k6/experimental/browser` module
- Connects to external Chrome via `K6_BROWSER_WS_URL` environment variable
- Scripts mounted read-only
- Configure via environment: `K6_VUS`, `K6_ITERATIONS`

### Playwright
- Uses custom CDP fixtures in `fixtures.js` for external Chrome connection
- Supports Playwright Test framework features: workers, retries, reporters
- Configure via environment: `PLAYWRIGHT_WORKERS`, `PLAYWRIGHT_REPEAT`
- Example: `PLAYWRIGHT_WORKERS=10 PLAYWRIGHT_REPEAT=50 ./run-tests.sh playwright`

### External Chrome
- browserless/chrome provides CDP endpoint for both tools
- Available at `ws://chrome:3000` from containers
- Debug UI at http://localhost:3000

## Metrics Collected

All metrics collected via **Docker Stats Exporter** (external monitoring):

- **CPU**: Usage percentage (0-100% of total system CPU)
  - For 4-core system: 25% = 100% of 1 allocated core
  - Metric: `container_cpu_usage_percent`
  
- **Memory**: Current usage and limits
  - `container_memory_usage_bytes` - actual memory used
  - `container_memory_limit_bytes` - Docker limit (512MB for k6/playwright)
  
- **Network**: Cumulative RX/TX bytes
  - `container_network_rx_bytes` - total bytes received
  - `container_network_tx_bytes` - total bytes transmitted
  - Use `rate()` in Prometheus for throughput

**Note:** Metrics are **isolated per container**. Running k6 test only affects k6-browser metrics, not playwright.

## License

MIT

## Contributing

Feel free to open issues or submit pull requests for improvements!

