# Docker Stats Exporter for Prometheus

Simple Prometheus exporter that reads Docker container stats via the Docker API and exposes them as Prometheus metrics.

## Why This Exists

This exporter was created to solve a specific issue: **cAdvisor doesn't work properly with Docker Desktop on macOS** due to Docker socket permission issues. This lightweight exporter uses the Docker Python SDK to read container stats directly.

## How It Works

1. Connects to Docker daemon via `/var/run/docker.sock`
2. Polls `docker stats` API every 5 seconds for monitored containers
3. Calculates metrics using official Docker formulas
4. Exposes metrics in Prometheus format on port 8091

## Metrics Exposed

| Metric | Description | Reference |
|--------|-------------|-----------|
| `container_cpu_usage_percent{name="..."}` | CPU usage as % of total system CPU | [Docker CLI source](https://github.com/docker/cli/blob/master/cli/command/container/stats_helpers.go#L166-L174) |
| `container_memory_usage_bytes{name="..."}` | Current memory usage including cache | [Docker Engine API](https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerStats) |
| `container_memory_limit_bytes{name="..."}` | Memory limit set by Docker | [Docker Engine API](https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerStats) |
| `container_network_rx_bytes{name="..."}` | Cumulative bytes received | [Docker Engine API](https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerStats) |
| `container_network_tx_bytes{name="..."}` | Cumulative bytes transmitted | [Docker Engine API](https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerStats) |

## CPU Calculation Explained

The CPU percentage formula matches Docker CLI's implementation:

```python
cpu_percent = (cpu_delta / system_delta) * 100.0
```

**What this means:**
- `cpu_delta`: Container's CPU time used between two samples
- `system_delta`: Total system CPU time between two samples
- Result: **Percentage of total system CPU** (across all cores)

**Example on 4-core system:**
- `25%` = Container using 100% of 1 core
- `100%` = Container using all 4 cores  
- With 1 CPU limit = Max ~25%

**References:**
- Docker stats calculation: https://github.com/docker/cli/blob/master/cli/command/container/stats_helpers.go#L166-L174
- API documentation: https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerStats

## Memory Calculation

Memory usage comes directly from Docker's cgroup stats:

- `memory_stats.usage`: Total memory used (includes page cache)
- `memory_stats.limit`: Memory limit from Docker (e.g., 512MB from `--memory` flag)

**Note:** The `usage` value includes page cache. For active/working set memory, you can calculate:
```
working_set = usage - cache
```

## Monitored Containers

Configured in `exporter.py`:
```python
MONITORED_CONTAINERS = ['k6-browser', 'playwright', 'chrome-debug']
```

## Usage

```bash
# Build and run
docker compose build stats-exporter
docker compose up -d stats-exporter

# View metrics
curl http://localhost:8091/metrics

# Check specific container
curl http://localhost:8091/metrics | grep 'container_memory_usage_bytes{name="k6-browser"}'
```

## Prometheus Configuration

```yaml
scrape_configs:
  - job_name: 'docker-stats'
    static_configs:
      - targets: ['stats-exporter:8091']
    scrape_interval: 5s
```

## Limitations

1. **No filesystem I/O metrics** - Docker stats API doesn't provide these
2. **Cumulative network stats** - Use `rate()` in Prometheus for throughput
3. **Polling-based** - 5-second collection interval (vs cAdvisor's event-based)

## Advantages vs cAdvisor

✅ Works on macOS Docker Desktop  
✅ Simple and lightweight  
✅ Easy to customize  
✅ Respects Docker resource limits  
✅ Isolated per-container metrics  

## References

- **Docker Engine API v1.41:** https://docs.docker.com/engine/api/v1.41/
- **Docker Stats Endpoint:** https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerStats
- **Docker CLI Stats Implementation:** https://github.com/docker/cli/blob/master/cli/command/container/stats_helpers.go
- **Docker SDK for Python:** https://docker-py.readthedocs.io/en/stable/
- **Prometheus Python Client:** https://github.com/prometheus/client_python

