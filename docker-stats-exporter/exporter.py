#!/usr/bin/env python3
"""
Simple Docker Stats Exporter for Prometheus
Reads docker stats API and exposes as Prometheus metrics
Works on macOS Docker Desktop where cAdvisor has socket issues

References:
- Docker Engine API stats endpoint: https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerStats
- Docker stats command source: https://github.com/docker/cli/blob/master/cli/command/container/stats_helpers.go
- CPU calculation formula: https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerStats (see "Calculating CPU percentage")
"""

import docker
import time
from prometheus_client import start_http_server, Gauge
import sys

# Create Prometheus metrics
cpu_usage = Gauge('container_cpu_usage_percent', 'Container CPU usage percentage', ['name'])
memory_usage = Gauge('container_memory_usage_bytes', 'Container memory usage in bytes', ['name'])
memory_limit = Gauge('container_memory_limit_bytes', 'Container memory limit in bytes', ['name'])
network_rx = Gauge('container_network_rx_bytes', 'Container network bytes received', ['name'])
network_tx = Gauge('container_network_tx_bytes', 'Container network bytes transmitted', ['name'])

# Containers to monitor
MONITORED_CONTAINERS = ['k6-browser', 'playwright', 'chrome-debug']

def collect_metrics():
    """Collect metrics from Docker stats API"""
    try:
        client = docker.from_env()
        
        for container_name in MONITORED_CONTAINERS:
            try:
                container = client.containers.get(container_name)
                stats = container.stats(stream=False)
                
                # CPU percentage calculation
                # Formula from Docker CLI: https://github.com/docker/cli/blob/master/cli/command/container/stats_helpers.go#L166-L174
                # 
                # cpu_percent = (cpu_delta / system_delta) * 100.0
                # 
                # Where:
                #   cpu_delta = difference in total CPU time used by container between samples
                #   system_delta = difference in total system CPU time between samples
                # 
                # This gives percentage of TOTAL system CPU (across all cores)
                # For a 4-core system:
                #   - 25% = container using 100% of 1 core
                #   - 100% = container using all 4 cores
                #   - With 1 CPU limit, max will be ~25%
                #
                # See: https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerStats
                try:
                    cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - \
                               stats['precpu_stats']['cpu_usage']['total_usage']
                    system_delta = stats['cpu_stats']['system_cpu_usage'] - \
                                  stats['precpu_stats']['system_cpu_usage']
                    
                    if system_delta > 0 and cpu_delta >= 0:
                        # Percentage of total system CPU
                        cpu_percent = (cpu_delta / system_delta) * 100.0
                    else:
                        cpu_percent = 0.0
                except (KeyError, ZeroDivisionError, TypeError) as e:
                    cpu_percent = 0.0
                    print(f"CPU calc error for {container_name}: {e}")
                
                # Memory usage and limit
                # From Docker stats API: https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerStats
                # 
                # memory_stats.usage = current memory usage (includes cache)
                # memory_stats.limit = memory limit set by Docker (e.g., 512MB)
                # 
                # Note: 'usage' includes page cache. For working set (excluding cache),
                # use: memory_stats.usage - memory_stats.stats.cache
                mem_usage = stats['memory_stats'].get('usage', 0)
                mem_limit = stats['memory_stats'].get('limit', 0)
                
                # Network I/O statistics
                # From Docker stats API: https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerStats
                # 
                # networks[interface].rx_bytes = total bytes received
                # networks[interface].tx_bytes = total bytes transmitted
                # 
                # These are cumulative counters. Use rate() in Prometheus for bytes/sec.
                try:
                    if 'networks' in stats:
                        # Try eth0 first, then fallback to first network interface
                        if 'eth0' in stats['networks']:
                            net_rx = stats['networks']['eth0']['rx_bytes']
                            net_tx = stats['networks']['eth0']['tx_bytes']
                        else:
                            first_net = list(stats['networks'].values())[0]
                            net_rx = first_net['rx_bytes']
                            net_tx = first_net['tx_bytes']
                    else:
                        net_rx = 0
                        net_tx = 0
                except (KeyError, IndexError, TypeError):
                    net_rx = 0
                    net_tx = 0
                
                # Update metrics
                cpu_usage.labels(name=container_name).set(cpu_percent)
                memory_usage.labels(name=container_name).set(mem_usage)
                memory_limit.labels(name=container_name).set(mem_limit)
                network_rx.labels(name=container_name).set(net_rx)
                network_tx.labels(name=container_name).set(net_tx)
                
                print(f"{container_name}: CPU={cpu_percent:.2f}%, Mem={mem_usage/1024/1024:.0f}MB/{mem_limit/1024/1024:.0f}MB, Net RX/TX={net_rx}/{net_tx}")
                
            except docker.errors.NotFound:
                print(f"Container {container_name} not found")
            except Exception as e:
                print(f"Error collecting stats for {container_name}: {e}")
                import traceback
                traceback.print_exc()
                
    except Exception as e:
        print(f"Error connecting to Docker: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    # Start Prometheus metrics server
    port = 8091
    start_http_server(port)
    print(f"Docker Stats Exporter started on port {port}")
    print(f"Monitoring containers: {', '.join(MONITORED_CONTAINERS)}")
    print(f"Metrics available at http://localhost:{port}/metrics")
    
    # Collect metrics every 5 seconds
    while True:
        collect_metrics()
        print("---")
        time.sleep(5)

