FROM python:3.11-slim

WORKDIR /app

# Install Docker SDK for Python and Prometheus client
RUN pip install --no-cache-dir docker prometheus-client

# Copy exporter script
COPY exporter.py /app/exporter.py
RUN chmod +x /app/exporter.py

# Expose Prometheus metrics port
EXPOSE 8091

# Run the exporter
CMD ["python3", "/app/exporter.py"]

