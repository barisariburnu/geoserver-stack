# GeoServer Stack

Production-ready, performance-optimized GeoServer deployment using Docker. Pre-configured with JAI-EXT, GDAL (ECW support), GeoWebCache, and enterprise-grade JVM tuning.

## 🎯 Features

- **High Performance**: JVM G1GC tuning, JAI-EXT for raster processing, optimized tile caching
- **ECW Support**: Pre-installed GDAL plugin for ECW raster format support
- **Secure Access**: Automatic SSL configuration with Nginx and PFX support
- **Production Ready**: Health checks, persistent storage, automated backups
- **Scalable**: Connection pooling, control flow, resource limits
- **Monitoring**: Prometheus/Grafana integration ready
- **Docker-based**: Platform-agnostic, easy deployment

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Minimum 8GB RAM (16GB recommended)
- SSD storage recommended
- **SSL Certificate** (Optional, for HTTPS): A `.pfx` file

### Installation

```bash
# Clone or download this repository
git clone https://github.com/barisariburnu/geoserver-stack.git
cd geoserver-stack

# Create environment file
cp .env.example .env

# Edit .env and set admin password and SSL details
nano .env  # or vim, code, etc.
```

### SSL Configuration (HTTPS)

To enable HTTPS with your own PFX certificate:

1.  Place your `.pfx` file into `certificates/` directory.
2.  Update `.env` file:
    ```env
    # SSL Password for the PFX file
    PFX_PASS=your_pfx_password
    
    # Domain Name (and optionally IP) for Nginx
    DOMAIN_NAME=geoserver.yourdomain.com
    ```
3.  The system will automatically detect the PFX file, extract key/cert, and configure Nginx.

### Start the Stack

```bash
# Start GeoServer and Nginx
docker-compose up -d

# Check logs
docker-compose logs -f
```

### Access

- **Public HTTPS**: `https://<YOUR_IP_OR_DOMAIN>/geoserver`
- **Internal HTTP**: `http://localhost:8080/geoserver` (not exposed by default)

**Credentials:**
- **Username**: `admin`
- **Password**: Defined in `GEOSERVER_ADMIN_PASSWORD` in `.env`

> **⚠️ IMPORTANT**: Change the default admin password immediately!

## ⚙️ Configuration

### Environment Variables

Key settings in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `GEOSERVER_ADMIN_PASSWORD` | - | **REQUIRED** Admin password |
| `PFX_PASS` | changeit | Password for the SSL PFX file |
| `DOMAIN_NAME` | - | Domain name for Nginx config |
| `PROXY_BASE_URL` | https://... | Public URL of the server |
| `INITIAL_MEMORY` | 8G | JVM initial heap |
| `MAXIMUM_MEMORY` | 12G | JVM maximum heap |
| `STABLE_EXTENSIONS` | jai-ext,gdal-plugin... | Extensions (GDAL included) |
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

## � Project Structure

```
geoserver-stack/
├── docker-compose.yml           # Main configuration
├── .env.example                 # Environment template
├── .gitignore                   # Git ignore rules
├── README.md                    # This file
├── certificates/                # SSL Certificates (PFX file goes here)
├── nginx/                       # Nginx Configuration
│   └── templates/
│       └── default.conf.template # Nginx Config Template
├── scripts/                     # Management scripts
│   └── convert_certs.sh         # Auto-convert PFX to CRT/KEY
├── config/                      # Custom configurations
├── geoserver_data/              # Persistent data (auto-created)
├── backups/                     # Backup storage
├── docs/                        # Documentation
│   ├── PERFORMANCE.md
│   ├── SECURITY.md
│   ├── MONITORING.md
│   └── OPTIMIZATION_SUMMARY.md
└── monitoring/                  # Monitoring stack
    ├── docker-compose.monitoring.yml
    ├── prometheus.yml
    └── grafana/
```

## 🔧 Management

### Docker Commands

```bash
# Start
docker-compose up -d

# Stop
docker-compose stop

# Restart Nginx (e.g. after changing certs)
docker-compose up -d --force-recreate nginx

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
```

### Backup

```bash
# Create backup
docker-compose exec geoserver tar -czf /tmp/backup-$(date +%Y%m%d).tar.gz -C /opt/geoserver data_dir

# Copy to host
docker cp geoserver:/tmp/backup-$(date +%Y%m%d).tar.gz ./backups/
```

### Performance Monitoring

```bash
# JVM memory usage
docker-compose exec geoserver jstat -gcutil 1 1000 5

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
   - Add your `.pfx` file to `certificates/` and set password in `.env`.

3. **Data Access Control**
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

### Data Not Persisting

```bash
# Verify volume mount
docker inspect geoserver | grep Mounts

# Check data directory
docker-compose exec geoserver ls -la /opt/geoserver/data_dir/
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

---

**GeoServer Stack** - Production-ready GeoServer in minutes 🚀
