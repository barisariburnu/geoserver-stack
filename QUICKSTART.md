# GeoServer Stack - Quick Start

Get GeoServer running in under 5 minutes with production-grade performance optimizations.

## ⚡ Quick Setup (5 Minutes)

### 1. Clone & Configure (1 min)

```bash
# Clone repository
git clone https://github.com/barisariburnu/geoserver-stack
cd geoserver-stack

# Setup environment
cp .env.example .env

# Set admin password
echo "GEOSERVER_ADMIN_PASSWORD=YourStrongPassword123!" >> .env
```

### 2. Start GeoServer (1 min)

```bash
docker-compose up -d
```

### 3. Wait for Startup (2-3 min)

```bash
# Watch logs
docker-compose logs -f geoserver

# Wait for "Server startup in [XXXX] milliseconds"
```

### 4. Access GeoServer

Open: http://localhost:8080/geoserver

- **Username**: `admin`
- **Password**: From `.env` file

## ✅ Verify Installation

```bash
# Health check
docker-compose exec geoserver curl -f http://localhost:8080/geoserver/web/

# Check JAI-EXT (should show "true" for all operations)
# Browser: http://localhost:8080/geoserver → About & Status → JAI-EXT
```

## 🚀 Enable High Performance (GeoWebCache)

For 10-50ms response times:

1. **Login** to GeoServer
2. **Layers** → Select your layer
3. **Tile Caching** tab
4. **Create a cached layer**
5. Select gridsets: `EPSG:4326`, `EPSG:3857`
6. **Save**

## 📊 Test Performance

```bash
# Container stats
docker stats geoserver --no-stream

# JVM memory
docker-compose exec geoserver jstat -gcutil 1 1000 5

# Response time test
time curl http://localhost:8080/geoserver/wms?service=WMS&request=GetCapabilities
```

## 🔧 Essential Commands

```bash
# Stop
docker-compose stop

# Restart  
docker-compose restart

# View logs
docker-compose logs -f

# Backup data
docker-compose exec geoserver tar -czf /tmp/backup.tar.gz -C /opt/geoserver data_dir
docker cp geoserver:/tmp/backup.tar.gz ./backups/
```

## ⚙️ Memory Tuning

Edit `.env` based on your RAM:

| RAM | INITIAL_MEMORY | MAXIMUM_MEMORY |
|-----|----------------|----------------|
| 8GB | 2G | 4G |
| 16GB | 8G | 12G |
| 32GB | 16G | 24G |

Then restart:
```bash
docker-compose restart
```

## 🎯 Performance Checklist

After starting GeoServer:

- [ ] Change admin password
- [ ] Verify JAI-EXT is active (About & Status)
- [ ] Enable GeoWebCache for layers
- [ ] Configure spatial indexes on data sources
- [ ] Set up automated backups
- [ ] Enable monitoring (optional)

## 🚨 Troubleshooting

### Port Already in Use

```bash
# Linux/Mac
lsof -i :8080

# Windows
netstat -ano | findstr :8080

# Change port in docker-compose.yml
ports:
  - "8081:8080"  # Use 8081 instead
```

### Slow Performance

1. Enable GeoWebCache (see above)
2. Check memory: `docker stats geoserver`
3. Review logs: `docker-compose logs geoserver | grep ERROR`

### Container Won't Start

```bash
# Check logs
docker-compose logs geoserver

# Verify .env file
cat .env | grep PASSWORD

# Remove and recreate
docker-compose down
docker-compose up -d
```

## 📚 Next Steps

- **Full Documentation**: [README.md](README.md)
- **Performance Guide**: [docs/PERFORMANCE.md](docs/PERFORMANCE.md)
- **Security**: [docs/SECURITY.md](docs/SECURITY.md)
- **Monitoring**: [docs/MONITORING.md](docs/MONITORING.md)

---

**You're all set!** GeoServer is running with production-grade performance optimizations 🚀

For advanced configuration, see the [full README](README.md).
