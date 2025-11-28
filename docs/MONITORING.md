# GeoServer Monitoring Rehberi

Bu dokümanda GeoServer kurulumunuzun izlenmesi ve performans metriklerinin toplanması açıklanmaktadır.

## 📊 Monitoring Stack

### Bileşenler

- **Prometheus**: Metrik toplama ve depolama
- **Grafana**: Görselleştirme ve dashboard
- **cAdvisor**: Container metrikleri
- **Node Exporter** (opsiyonel): Sistem metrikleri

## 🚀 Monitoring Stack Kurulumu

### 1. Stack'i Başlatma

```powershell
docker-compose -f .\monitoring\docker-compose.monitoring.yml up -d
```

### 2. Erişim Kontrolleri

```powershell
# Container durumunu kontrol et
docker ps | findstr "geoserver\|prometheus\|grafana\|cadvisor"

# Logları görüntüle
docker-compose -f .\monitoring\docker-compose.monitoring.yml logs -f
```

### 3. Web Arayüzleri

| Servis | URL | Varsayılan Credentials |
|--------|-----|------------------------|
| **Grafana** | http://localhost:3000 | admin / admin |
| **Prometheus** | http://localhost:9090 | - |
| **cAdvisor** | http://localhost:8081 | - |

## 📈 Grafana Konfigürasyonu

### İlk Giriş

1. http://localhost:3000 adresine gidin
2. İlk girişte şifre değiştirin
3. Prometheus datasource otomatik eklenmiş olmalı

### Dashboard Import Etme

#### Önerilen Dashboardlar

1. **Docker Container Monitoring**
   - Dashboard ID: `193` (cAdvisor)
   - https://grafana.com/grafana/dashboards/193

2. **Prometheus Stats**
   - Dashboard ID: `2`
   - https://grafana.com/grafana/dashboards/2

#### Import Adımları

1. Grafana → `+` → `Import`
2. Dashboard ID'yi girin veya JSON yükleyin
3. Prometheus datasource'u seçin
4. `Import` tıklayın

### Custom GeoServer Dashboard

`monitoring/grafana/dashboards/geoserver-dashboard.json` oluşturun:

```json
{
  "dashboard": {
    "title": "GeoServer Performance",
    "panels": [
      {
        "title": "CPU Usage",
        "targets": [
          {
            "expr": "rate(container_cpu_usage_seconds_total{name=\"geoserver\"}[5m]) * 100"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "targets": [
          {
            "expr": "container_memory_usage_bytes{name=\"geoserver\"} / 1024 / 1024 / 1024"
          }
        ]
      }
    ]
  }
}
```

## 🔍 Prometheus Queries

### Container Metrikleri

#### CPU Kullanımı

```promql
# CPU yüzdesi
rate(container_cpu_usage_seconds_total{name="geoserver"}[5m]) * 100

# CPU throttling
rate(container_cpu_throttled_seconds_total{name="geoserver"}[5m])
```

#### Memory Kullanımı

```promql
# Memory kullanımı (GB)
container_memory_usage_bytes{name="geoserver"} / 1024 / 1024 / 1024

# Memory limit
container_spec_memory_limit_bytes{name="geoserver"} / 1024 / 1024 / 1024

# Memory pressure
(container_memory_usage_bytes{name="geoserver"} / container_spec_memory_limit_bytes{name="geoserver"}) * 100
```

#### Network I/O

```promql
# Network receive rate (MB/s)
rate(container_network_receive_bytes_total{name="geoserver"}[5m]) / 1024 / 1024

# Network transmit rate (MB/s)
rate(container_network_transmit_bytes_total{name="geoserver"}[5m]) / 1024 / 1024
```

#### Disk I/O

```promql
# Disk read rate (MB/s)
rate(container_fs_reads_bytes_total{name="geoserver"}[5m]) / 1024 / 1024

# Disk write rate (MB/s)
rate(container_fs_writes_bytes_total{name="geoserver"}[5m]) / 1024 / 1024
```

### GeoServer Specific Metrikleri

> [!NOTE]
> GeoServer'dan direktprometheus metrics almak için JMX Exporter veya monitoring extension gerekir.

## 📊 Alert Konfigürasyonu

### Prometheus Alerts

`monitoring/alerts/geoserver-alerts.yml`:

```yaml
groups:
  - name: geoserver
    interval: 30s
    rules:
      # High CPU usage
      - alert: HighCPUUsage
        expr: rate(container_cpu_usage_seconds_total{name="geoserver"}[5m]) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "GeoServer high CPU usage"
          description: "CPU usage is above 80% for 5 minutes"

      # High Memory usage
      - alert: HighMemoryUsage
        expr: (container_memory_usage_bytes{name="geoserver"} / container_spec_memory_limit_bytes{name="geoserver"}) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "GeoServer high memory usage"
          description: "Memory usage is above 90%"

      # Container down
      - alert: ContainerDown
        expr: absent(container_memory_usage_bytes{name="geoserver"})
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "GeoServer container is down"
          description: "GeoServer container has been down for 1 minute"

      # High response time
      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="geoserver"}[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "GeoServer high response time"
          description: "95th percentile response time is above 2 seconds"
```

### Alert Güncellemesi

```powershell
# prometheus.yml'de alert dosyasını ekleyin
# Prometheus'u reload edin
docker exec geoserver-prometheus kill -HUP 1
```

## 📧 Alertmanager (Opsiyonel)

### Kurulum

`monitoring/alertmanager/config.yml`:

```yaml
global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@example.com'
  smtp_auth_username: 'alerts@example.com'
  smtp_auth_password: 'password'

route:
  receiver: 'email-notifications'
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

receivers:
  - name: 'email-notifications'
    email_configs:
      - to: 'admin@example.com'
        headers:
          Subject: 'GeoServer Alert: {{ .GroupLabels.alertname }}'
```

### docker-compose.monitoring.yml'ye ekleyin

```yaml
services:
  alertmanager:
    image: prom/alertmanager:latest
    container_name: geoserver-alertmanager
    restart: unless-stopped
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager:/etc/alertmanager
    command:
docker exec geoserver grep -c "ERROR" /opt/geoserver/data_dir/logs/geoserver.log

# Warning counter
docker exec geoserver grep -c "WARN" /opt/geoserver/data_dir/logs/geoserver.log

# Recent errors
docker exec geoserver tail -n 50 /opt/geoserver/data_dir/logs/geoserver.log | grep "ERROR"
```

### Log Aggregation (Loki + Grafana)

`monitoring/docker-compose.monitoring.yml`:

```yaml
services:
  loki:
    image: grafana/loki:latest
    container_name: geoserver-loki
    ports:
      - "3100:3100"
    volumes:
      - ./loki/config.yml:/etc/loki/local-config.yaml
    networks:
      - monitoring-network

  promtail:
    image: grafana/promtail:latest
    container_name: geoserver-promtail
    volumes:
      - /var/log:/var/log:ro
      - D:\geoserver_data\logs:/geoserver-logs:ro
      - ./promtail/config.yml:/etc/promtail/config.yml
    networks:
      - monitoring-network
```

## 📈 Performance Metrics Dashboard

### Key Metrics to Monitor

| Metrik | Healthy | Warning | Critical |
|--------|---------|---------|----------|
| CPU Usage | < 60% | 60-80% | > 80% |
| Memory Usage | < 70% | 70-85% | > 85% |
| Response Time (p95) | < 500ms | 500ms-2s | > 2s |
| Error Rate | < 1% | 1-5% | > 5% |
| Disk I/O Wait | < 10% | 10-30% | > 30% |
| Request Rate | Baseline ±20% | ±50% | > 2x baseline |

### Grafana Panel Examples

```json
{
  "panels": [
    {
      "title": "Request Rate",
      "targets": [{
        "expr": "rate(geoserver_requests_total[5m])"
      }],
      "type": "graph"
    },
    {
      "title": "Error Rate",
      "targets": [{
        "expr": "rate(geoserver_errors_total[5m]) / rate(geoserver_requests_total[5m]) * 100"
      }],
      "type": "stat",
      "fieldConfig": {
        "thresholds": [
          { "value": 1, "color": "green" },
          { "value": 5, "color": "yellow" },
          { "value": 10, "color": "red" }
        ]
      }
    }
  ]
}
```

## 🔧 Troubleshooting

### Prometheus Not Scraping

```powershell
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Prometheus config
docker exec geoserver-prometheus promtool check config /etc/prometheus/prometheus.yml
```

### Grafana Datasource Issues

```powershell
# Test Prometheus connection
curl http://prometheus:9090/api/v1/query?query=up

# Check Grafana logs
docker logs geoserver-grafana
```

## 📚 Best Practices

### Monitoring Checklist

- [ ] Prometheus collecting metrics
- [ ] Grafana dashboards configured
- [ ] Alerts defined and tested
- [ ] Alert notifications working
- [ ] Log aggregation active
- [ ] Baseline metrics established
- [ ] Regular metric review scheduled
- [ ] Incident response plan ready

### Retention Policies

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

storage:
  tsdb:
    retention.time: 30d
    retention.size: 10GB
```

## 🔗 Kaynaklar

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [cAdvisor](https://github.com/google/cadvisor)
- [Windows Exporter](https://github.com/prometheus-community/windows_exporter)

