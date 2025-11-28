# GeoServer Stack

Production-ready, performance-optimized GeoServer deployment using Docker. Pre-configured with JAI-EXT, GeoWebCache, and enterprise-grade JVM tuning.

## 🎯 Features

- **High Performance**: JVM G1GC tuning, JAI-EXT for raster processing, optimized tile caching
- **Production Ready**: Health checks, persistent storage, automated backups
- **Scalable**: Connection pooling, control flow, resource limits
- **Monitoring**: Prometheus/Grafana integration ready
- **Docker-based**: Platform-agnostic, easy deployment

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Minimum 8GB RAM (16GB recommended)
- SSD storage recommended

### Installation

```bash
# Clone or download this repository
git clone https://github.com/barisariburnu/geoserver-stack.git
cd geoserver-stack

# Create environment file
cp .env.example .env

# Edit .env and set a strong admin password
nano .env  # or vim, code, etc.

# Start GeoServer
docker-compose up -d

# Check logs
docker-compose logs -f geoserver
```

### First Access

Open http://localhost:8080/geoserver

- **Username**: `admin` (or from `.env`)
- **Password**: Set in `.env` file

> **⚠️ IMPORTANT**: Change the default admin password immediately!

## ⚙️ Configuration

### Environment Variables

Key settings in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `GEOSERVER_ADMIN_PASSWORD` | - | **REQUIRED** Admin password |
| `INITIAL_MEMORY` | 8G | JVM initial heap |
| `MAXIMUM_MEMORY` | 12G | JVM maximum heap |
| `STABLE_EXTENSIONS` | jai-ext,pyramid-plugin,... | Performance extensions |
| `SAMPLE_DATA` | false | Disable demo data |

### Memory Configuration

Adjust based on your system RAM:

| System RAM | INITIAL_MEMORY | MAXIMUM_MEMORY |
|------------|----------------|----------------|
| 8GB | 2G | 4G |
| 16GB | 8G | 12G |
| 32GB | 16G | 24G |
| 64GB | 32G | 48G |

> **Rule of thumb**: Use 50-75% of total RAM for JVM heap

## 📊 Performance Optimizations

### Pre-configured Optimizations

✅ **JVM Tuning**
- G1 Garbage Collector
- Optimized heap size
- Low-latency GC pauses

✅ **Extensions**
- JAI-EXT (raster processing)
- Pyramid plugin (large rasters)
- Image Mosaic JDBC

✅ **Caching**
- GeoWebCache enabled
- Tile caching ready
- HTTP compression

✅ **Control Flow**
- Request throttling
- Resource limits
- Connection pooling ready

### Enable Tile Caching (Recommended)

For optimal performance, enable GeoWebCache for your layers:

1. Login to GeoServer
2. Go to **Layers** → Select your layer
3. **Tile Caching** tab → "Create a cached layer"
4. Select gridsets (EPSG:4326, EPSG:3857)
5. **Save**

**Expected improvement**: 10-50ms response time (vs 200-500ms uncached)

## 🔧 Management

### Docker Commands

```bash
# Start
docker-compose up -d

# Stop
docker-compose stop

# Restart
docker-compose restart

# View logs
docker-compose logs -f

# Remove (keeps data)
docker-compose down

# Remove with volumes (WARNING: deletes data!)
docker-compose down -v
```

### Health Check

```bash
# Quick check
docker-compose exec geoserver curl -f http://localhost:8080/geoserver/web/

# Detailed health
docker-compose exec geoserver bash -c '
  echo "=== GeoServer Health ==="
  echo "Status: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/geoserver/web/)"
  echo "Memory: $(free -h | grep Mem | awk "{print \$3\"/\"\$2}")"
  echo "Uptime: $(uptime -p)"
'
```

### Backup

```bash
# Create backup
docker-compose exec geoserver tar -czf /tmp/backup-$(date +%Y%m%d).tar.gz -C /opt/geoserver data_dir

# Copy to host
docker cp geoserver:/tmp/backup-$(date +%Y%m%d).tar.gz ./backups/

# Automated backups
# See scripts/backup.sh
```

### Performance Monitoring

```bash
# JVM memory usage
docker-compose exec geoserver jstat -gcutil 1 1000 5

# Heap details
docker-compose exec geoserver jmap -heap 1

# Thread dump
docker-compose exec geoserver jstack 1 > thread-dump.txt

# Container stats
docker stats geoserver --no-stream
```

## 📈 Monitoring Stack (Optional)

Deploy Prometheus + Grafana for advanced monitoring:

```bash
cd monitoring
docker-compose -f docker-compose.monitoring.yml up -d
```

Access:
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **cAdvisor**: http://localhost:8081

## 🔒 Security

### Essential Security Steps

1. **Change Admin Password**
   - GeoServer UI → Security → Users → admin → Change Password

2. **Configure HTTPS** (Production)
   - Use reverse proxy (Nginx/Apache)
   - Or configure Tomcat SSL in docker-compose.yml

3. **IP Restrictions**
   - GeoServer → Security → Service Security
   - Or use firewall rules

4. **Data Access Control**
   - Configure layer-level security
   - Use role-based access control (RBAC)

See [docs/SECURITY.md](docs/SECURITY.md) for detailed security hardening.

## 📚 Documentation

- [PERFORMANCE.md](docs/PERFORMANCE.md) - Performance tuning guide
- [SECURITY.md](docs/SECURITY.md) - Security configuration
- [MONITORING.md](docs/MONITORING.md) - Monitoring setup
- [OPTIMIZATION_SUMMARY.md](docs/OPTIMIZATION_SUMMARY.md) - Quick optimization guide

## 🔍 Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs geoserver

# Check port conflicts
netstat -tulpn | grep 8080  # Linux
netstat -ano | findstr :8080  # Windows

# Verify Docker service
docker ps
```

### Slow Performance

1. **Enable GeoWebCache** for layers (most effective!)
2. Check JVM heap usage: `docker exec geoserver jstat -gc 1`
3. Verify spatial indexes exist on data sources
4. Review layer styling complexity
5. Check disk I/O performance

### Data Not Persisting

```bash
# Verify volume mount
docker inspect geoserver | grep Mounts

# Check data directory
docker-compose exec geoserver ls -la /opt/geoserver/data_dir/
```

## 🎯 Performance Benchmarks

Expected performance with optimizations:

| Operation | Target | Excellent |
|-----------|--------|-----------|
| GetCapabilities | <200ms | <100ms |
| GetMap (cached) | <50ms | <20ms |
| GetMap (uncached) | <500ms | <200ms |
| GetFeature (100) | <300ms | <150ms |
| Throughput | >50 req/s | >100 req/s |

## 🛠️ Advanced Configuration

### Add PostGIS Backend

```yaml
# Add to docker-compose.yml
services:
  postgis:
    image: postgis/postgis:latest
    environment:
      POSTGRES_PASSWORD: postgres
    volumes:
      - postgis-data:/var/lib/postgresql/data
    networks:
      - geoserver-network

volumes:
  postgis-data:
```

### Cluster Setup

For high-availability:
1. Multiple GeoServer instances
2. Load balancer (Nginx/HAProxy)
3. Shared data directory (NFS/S3)
4. Database-backed catalog

### Custom Extensions

Add extensions in `.env`:

```bash
STABLE_EXTENSIONS=jai-ext,pyramid-plugin,wps-extension,css-plugin,importer-plugin
```

## 📦 Project Structure

```
geoserver-stack/
├── docker-compose.yml           # Main configuration
├── .env.example                 # Environment template
├── .gitignore                   # Git ignore rules
├── README.md                    # This file
├── config/                      # Custom configurations
├── geoserver_data/              # Persistent data (auto-created)
├── backups/                     # Backup storage
├── docs/                        # Documentation
│   ├── PERFORMANCE.md
│   ├── SECURITY.md
│   ├── MONITORING.md
│   └── OPTIMIZATION_SUMMARY.md
├── monitoring/                  # Monitoring stack
│   ├── docker-compose.monitoring.yml
│   ├── prometheus.yml
│   └── grafana/
└── scripts/                     # Management scripts
    ├── README.md
    ├── backup.sh
    ├── health-check.sh
    └── performance-test.sh
```

## 🤝 Contributing

Improvements and bug reports are welcome!

## 📄 License

MIT License

## 🔗 Resources

- [GeoServer Documentation](https://docs.geoserver.org/)
- [Kartoza Docker GeoServer](https://github.com/kartoza/docker-geoserver)
- [GeoWebCache](https://www.geowebcache.org/)
- [Performance Tuning Guide](https://docs.geoserver.org/stable/en/user/production/)

## ⚡ Quick Performance Tips

1. ✅ **Enable GeoWebCache** for all published layers
2. ✅ **Use spatial indexes** on all geometry columns
3. ✅ **Set scale dependencies** for complex layers
4. ✅ **Optimize SLD styling** (avoid complex symbology)
5. ✅ **Use connection pooling** for data sources
6. ✅ **Enable HTTP compression** (already configured)
7. ✅ **Monitor JVM memory** regularly
8. ✅ **Set up regular backups** (use provided scripts)

---

**GeoServer Stack** - Production-ready GeoServer in minutes 🚀
