# GeoServer Docker-based Management Scripts

Bu dizindeki scriptler Docker container içinde çalışmak üzere tasarlanmıştır.

## 📋 Kullanım

### Health Check

```bash
docker exec -it geoserver bash /scripts/health-check.sh
```

Veya host'tan:

```bash
docker-compose exec geoserver bash -c "curl -f http://localhost:8080/geoserver/web/ || exit 1"
```

### Backup

```bash
docker exec -it geoserver bash /scripts/backup.sh
```

Parametreler:
- `SOURCE_DIR`: Kaynak dizin (default: /opt/geoserver/data_dir)
- `BACKUP_DIR`: Yedek dizin (default: ./backups)
- `RETENTION_DAYS`: Retention günü (default: 30)

### Performance Test

```bash
docker exec -it geoserver bash /scripts/performance-test.sh
```

Parametreler:
- `GEOSERVER_URL`: GeoServer URL (default: http://localhost:8080/geoserver)
- `TEST_TYPE`: Test tipi (wms, wfs, rest)
- `REQUESTS`: İstek sayısı (default: 100)
- `CONCURRENT`: Concurrent istek (default: 10)

## 🎯 Alternatif: Docker Compose Exec

Docker compose ile direkt kullanım:

### Health Check
```bash
# Basit check
docker-compose exec geoserver curl -f http://localhost:8080/geoserver/web/

# Detaylı check
docker-compose exec geoserver bash -c '
  echo "Container Status: OK"
  echo "Memory: $(free -h | grep Mem | awk "{print \$3\"/\"\$2}")"
  curl -s http://localhost:8080/geoserver/rest/about/version.json
'
```

### Backup  
```bash
# Veri dizinini yedekle
docker-compose exec geoserver tar -czf /tmp/backup-$(date +%Y%m%d).tar.gz -C /opt/geoserver data_dir
docker cp geoserver:/tmp/backup-$(date +%Y%m%d).tar.gz ./backups/
```

### Performance Metrics
```bash
# JVM stats
docker-compose exec geoserver jstat -gcutil 1 1000 5

# Memory info
docker-compose exec geoserver jmap -heap 1

# Thread info
docker-compose exec geoserver jstack 1 | grep "State"
```