# GeoServer Performans Optimizasyon Rehberi

Bu dokümanda GeoServer'ın maksimum performans için nasıl yapılandırılacağı detaylı olarak açıklanmaktadır.

## 📊 JVM Performans Ayarları

### Heap Memory Konfigürasyonu

16GB RAM için önerilen ayarlar:

```bash
INITIAL_MEMORY=8G
MAXIMUM_MEMORY=12G
```

#### Farklı RAM Yapılandırmaları

| Sistem RAM | Initial Heap (Xms) | Maximum Heap (Xmx) | Notlar |
|-----------|-------------------|-------------------|---------|
| 8GB | 2G | 4G | Minimum kurulum |
| 16GB | 8G | 12G | **Önerilen** |
| 32GB | 16G | 24G | Yüksek yük |
| 64GB | 32G | 48G | Enterprise |

> [!IMPORTANT]
> JVM heap'i sistemdeki toplam RAM'in %75'ini geçmemelidir. İşletim sistemi ve diğer servisler için alan bırakın.

### G1 Garbage Collector

G1GC, düşük gecikme süresi ve yüksek throughput için optimize edilmiştir:

```bash
JAVA_OPTS=-XX:+UseG1GC
         -XX:MaxGCPauseMillis=200
         -XX:ParallelGCThreads=4
         -XX:ConcGCThreads=2
         -XX:InitiatingHeapOccupancyPercent=70
```

#### Parametre Açıklamaları

| Parametre | Değer | Açıklama |
|-----------|-------|----------|
| `MaxGCPauseMillis` | 200 | Hedef GC pause süresi (ms) |
| `ParallelGCThreads` | 4 | Paralel GC thread sayısı (CPU core sayısı) |
| `ConcGCThreads` | 2 | Concurrent GC thread sayısı |
| `InitiatingHeapOccupancyPercent` | 70 | GC'nin başlama heap doluluk oranı |

### JVM Profiling

```powershell
# JVM istatistikleri
docker exec geoserver jstat -gcutil 1 1000

# Thread dump
docker exec geoserver jstack 1 > thread-dump.txt

# Heap dump (sorun analizi için)
docker exec geoserver jmap -dump:format=b,file=/tmp/heap-dump.hprof 1
```

## 🗄️ Veri Depolama Optimizasyonu

### SSD Kullanımı

**Kritik**: `D:\geoserver_data` mutlaka SSD üzerinde olmalıdır.

```powershell
# Disk performansını test edin
winsat disk -drive d

# I/O performansı
Get-Counter "\PhysicalDisk(*)\Avg. Disk sec/Read"
Get-Counter "\PhysicalDisk(*)\Avg. Disk sec/Write"
```

### Veri Dizini Yapısı

```
D:\geoserver_data\
├── coverage/          # Raster verileri
├── data/             # Shapefile ve vektör verileri
├── gwc/              # GeoWebCache tile önbellekleri
├── layers/           # Layer konfigürasyonları
├── styles/           # SLD stil dosyaları
└── workspaces/       # Workspace tanımları
```

## 🎯 GeoServer Konfigürasyon Optimizasyonları

### 1. Connection Pooling

`Admin Panel → Stores → Your DataStore → Connection Parameters`

| Parametre | Önerilen Değer | Açıklama |
|-----------|----------------|----------|
| `max connections` | 20-50 | Maksimum veritabanı bağlantısı |
| `min connections` | 5-10 | Minimum idle bağlantı |
| `connection timeout` | 20 | Bağlantı timeout (saniye) |
| `validate connections` | true | Bağlantı doğrulama |
| `fetch size` | 1000 | SQL fetch boyutu |

#### Örnek PostGIS Konfigürasyonu

```xml
<dataStore>
  <connectionParameters>
    <max_connections>30</max_connections>
    <min_connections>10</min_connections>
    <connection_timeout>20</connection_timeout>
    <validate_connections>true</validate_connections>
    <fetch_size>1000</fetch_size>
    <preparedStatements>true</preparedStatements>
  </connectionParameters>
</dataStore>
```

### 2. Tile Caching (GeoWebCache)

GeoWebCache varsayılan olarak etkindir ve büyük performans artışı sağlar.

#### Cache Konfigürasyonu

`Admin Panel → Tile Caching → Caching Defaults`

```xml
<gwc>
  <diskQuota>
    <enabled>true</enabled>
    <diskBlockSize>4096</diskBlockSize>
  </diskQuota>
  <cacheDirectory>D:\geoserver_data\gwc</cacheDirectory>
</gwc>
```

#### Layer için Cache Etkinleştirme

1. Layer → Tile Caching → Create a cached layer
2. Gridsets seçin (EPSG:4326, EPSG:3857)
3. Zoom levels: 0-18 (ihtiyaca göre)
4. Tile formats: PNG, JPEG
5. Metatiling: 4x4 (genel kullanım için iyi)

#### Disk Quota

```bash
# Maksimum cache boyutu (GB)
<diskQuota>
  <quota>
    <value>50</value>
    <units>GB</units>
  </quota>
  <quotaStore>JDBC</quotaStore>
</diskQuota>
```

### 3. WMS/WFS Optimizasyonları

#### WMS Settings

`Admin Panel → Services → WMS`

| Ayar | Önerilen | Açıklama |
|------|----------|----------|
| Resource Consumption Limits → Max rendering memory | 65536 | KB cinsinden |
| Resource Consumption Limits → Max rendering time | 60 | Saniye |
| Raster Rendering Options → JPEG Compression | 75 | Kalite/boyut dengesi |
| Enable HTTP Response Headers Caching | true | Browser caching |

#### WFS Settings

`Admin Panel → Services → WFS`

| Ayar | Önerilen | Açıklama |
|------|----------|----------|
| Maximum number of features | 10000 | Tek istekte max feature |
| Service Level → Complete | false | Basic yeterli |
| GML encoding → Optimize | true | Daha küçük response |

### 4. Layer Ölçek Aralıkları

Büyük veri setleri için ölçek aralıklarını ayarlayın:

```xml
<Layer>
  <MinScaleDenominator>10000</MinScaleDenominator>
  <MaxScaleDenominator>1000000</MaxScaleDenominator>
</Layer>
```

## 🚀 İleri Seviye Optimizasyonlar

### JAI-EXT Kütüphaneleri

JAI-EXT, raster işleme performansını önemli ölçüde artırır.

```bash
# .env dosyasına ekleyin
STABLE_EXTENSIONS=jai-ext
```

Kurulum sonrası:
1. `Admin Panel → About & Status → JAI-EXT`
2. Tüm operasyonların JAI-EXT kullanıldığını doğrulayın

### Image Mosaic Optimizasyonu

Büyük raster verileri için:

```xml
<coverageStore>
  <type>ImageMosaic</type>
  <workspace>myworkspace</workspace>
  <USE_JAI_IMAGEREAD>false</USE_JAI_IMAGEREAD>
  <SUGGESTED_TILE_SIZE>512,512</SUGGESTED_TILE_SIZE>
</coverageStore>
```

### Shapefile İndeks Oluşturma

```powershell
# .shx ve .prj dosyalarının yanında .qix indeks oluşturun
# QGIS veya ogr2ogr kullanarak
ogrinfo -sql "CREATE SPATIAL INDEX ON yourlayer" yourlayer.shp
```

### Vector Tile Kullanımı

WMS yerine vector tile kullanımı:

```bash
STABLE_EXTENSIONS=vectortiles-plugin,mbstyles-plugin
```

## 📊 Performans İzleme

### GeoServer Built-in Monitoring

`Admin Panel → Monitor` (monitoring extension gerekli)

```bash
STABLE_EXTENSIONS=monitoring-plugin
```

### Metrik Toplama

#### JMX Metrics

```bash
JAVA_OPTS=-Dcom.sun.management.jmxremote
         -Dcom.sun.management.jmxremote.port=1099
         -Dcom.sun.management.jmxremote.authenticate=false
         -Dcom.sun.management.jmxremote.ssl=false
```

VisualVM veya JConsole ile bağlanın:
```powershell
jconsole localhost:1099
```

### Request Logging

`webapps/geoserver/WEB-INF/classes/GEOSERVER_DEVELOPER_LOGGING.properties`

```properties
log4j.category.org.geoserver.ows=DEBUG
log4j.category.org.geoserver.wms=DEBUG
```

## 🎯 Benchmark ve Test

### Apache Bench ile Load Test

```powershell
# WMS GetCapabilities - 1000 requests, 10 concurrent
ab -n 1000 -c 10 http://localhost:8080/geoserver/wms?service=WMS&request=GetCapabilities

# WMS GetMap
ab -n 500 -c 5 "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.1.0&REQUEST=GetMap&LAYERS=mylayer&BBOX=-180,-90,180,90&WIDTH=800&HEIGHT=600&SRS=EPSG:4326&FORMAT=image/png"
```

### PowerShell Performance Test

```powershell
# Proje içinde sağlanan script
.\scripts\performance-test.ps1 -TestType wms -Requests 100 -Concurrent 10
```

### Hedef Performans Metrikleri

| Metrik | Hedef | Mükemmel |
|--------|-------|----------|
| GetCapabilities Response Time | < 200ms | < 100ms |
| GetMap (cached) | < 50ms | < 20ms |
| GetMap (uncached, simple) | < 500ms | < 200ms |
| GetFeature (100 features) | < 300ms | < 150ms |
| Throughput (req/sec) | > 50 | > 100 |

## 🔧 Sorun Giderme

### Yavaş WMS Responses

1. **Tile cache kullanın**: En etkili çözüm
2. **Layer ölçek aralıkları**: Gereksiz veri yüklemeyi engelleyin
3. **SLD optimizasyonu**: Karmaşık stilleri basitleştirin
4. **Spatial index**: Vektör verilerde mutlaka kullanın

### Memory Leaks

```powershell
# Heap kullanımı trend analizi
docker exec geoserver jstat -gcutil 1 5000 100 > heap-trend.txt

# Heap dump al ve analiz et (Eclipse MAT)
docker exec geoserver jmap -dump:live,format=b,file=/tmp/heap.hprof 1
```

### High CPU Usage

```powershell
# Thread dump al
docker exec geoserver jstack 1 > thread-dump.txt

# En çok CPU kullanan threadleri bul
docker exec geoserver top -H -p 1
```

## 📈 Sürekli İyileştirme

### Checklist

- [ ] JVM heap ayarları sistemle uyumlu mu?
- [ ] G1GC parametreleri doğru mu?
- [ ] Veri dizini SSD üzerinde mi?
- [ ] Connection pooling aktif mi?
- [ ] Tile caching etkin mi?
- [ ] Spatial indexler var mı?
- [ ] JAI-EXT kurulu mu?
- [ ] Layer ölçek aralıkları ayarlı mı?
- [ ] WMS/WFS timeout'lar makul mü?
- [ ] Monitoring aktif mi?

### Düzenli Kontroller

```powershell
# Haftalık performans raporu
.\scripts\performance-test.ps1 -TestType wms > weekly-report.txt

# Aylık heap analizi
docker exec geoserver jmap -heap 1 > monthly-heap-report.txt
```

## 🔗 Kaynaklar

- [GeoServer Production Environment](https://docs.geoserver.org/stable/en/user/production/index.html)
- [GeoWebCache Documentation](https://www.geowebcache.org/docs/current/)
- [Java G1GC Tuning](https://www.oracle.com/technical-resources/articles/java/g1gc.html)
- [JAI-EXT Project](https://github.com/geosolutions-it/jai-ext)
