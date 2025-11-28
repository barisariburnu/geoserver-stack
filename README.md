# GeoServer Docker Kurulum Rehberi

Windows x64 sunucusuna yüksek performanslı GeoServer kurulumu için Docker tabanlı çözüm.

## 📋 İçindekiler

- [Ön Gereksinimler](#ön-gereksinimler)
- [Hızlı Başlangıç](#hızlı-başlangıç)
- [Konfigürasyon](#konfigürasyon)
- [Kullanım](#kullanım)
- [Performans Optimizasyonu](#performans-optimizasyonu)
- [Güvenlik](#güvenlik)
- [Monitoring](#monitoring)
- [Yedekleme ve Kurtarma](#yedekleme-ve-kurtarma)
- [Sorun Giderme](#sorun-giderme)

## 🔧 Ön Gereksinimler

### Donanım Gereksinimleri

- **RAM**: Minimum 16GB (Önerilen: 32GB)
- **Disk**: SSD tabanlı depolama, D:\ sürücüsünde en az 50GB boş alan
- **CPU**: 4+ core işlemci

### Yazılım Gereksinimleri

1. **Docker Desktop for Windows**
   - [Docker Desktop](https://www.docker.com/products/docker-desktop/) en son sürümü
   - WSL2 backend etkin olmalı
   
   ```powershell
   # Docker sürümünü kontrol edin
   docker --version
   docker-compose --version
   ```

2. **Windows PowerShell** (5.1 veya üzeri)

### Ön Kontroller

```powershell
# Sistem bilgilerini kontrol edin
systeminfo | findstr /C:"Total Physical Memory"

# Docker çalışıyor mu?
docker ps

# WSL2 etkin mi?
wsl --list --verbose
```

## 🚀 Hızlı Başlangıç

### 1. Projeyi Klonlayın veya İndirin

```powershell
cd D:\Workspace
git clone <repo-url> geoserver
cd geoserver
```

### 2. Environment Dosyasını Yapılandırın

```powershell
# .env.example dosyasını kopyalayın
Copy-Item .env.example .env

# .env dosyasını düzenleyin (özellikle admin şifresini değiştirin!)
notepad .env
```

> [!CAUTION]
> **MUTLAKA** `GEOSERVER_ADMIN_PASSWORD` değerini güçlü bir şifre ile değiştirin!

### 3. Veri Dizinini Oluşturun

```powershell
# D:\ sürücüsünde veri dizini oluşturun
New-Item -ItemType Directory -Path "D:\geoserver_data" -Force
```

### 4. GeoServer'ı Başlatın

```powershell
# Docker container'ı başlatın
docker-compose up -d

# Logları izleyin
docker-compose logs -f geoserver
```

### 5. Erişimi Doğrulayın

Tarayıcınızda şu adresi açın: [http://localhost:8080/geoserver](http://localhost:8080/geoserver)

- **Kullanıcı Adı**: `.env` dosyasında tanımladığınız `GEOSERVER_ADMIN_USER` (varsayılan: admin)
- **Şifre**: `.env` dosyasında tanımladığınız `GEOSERVER_ADMIN_PASSWORD`

## ⚙️ Konfigürasyon

### Environment Değişkenleri

`.env` dosyasındaki önemli ayarlar:

| Değişken | Açıklama | Varsayılan |
|----------|----------|------------|
| `GEOSERVER_ADMIN_USER` | Admin kullanıcı adı | admin |
| `GEOSERVER_ADMIN_PASSWORD` | Admin şifresi | **MUTLAKA DEĞİŞTİRİN** |
| `INITIAL_MEMORY` | JVM başlangıç heap | 8G |
| `MAXIMUM_MEMORY` | JVM maksimum heap | 12G |
| `SAMPLE_DATA` | Demo veri yükleme | false |
| `STABLE_EXTENSIONS` | Kurulacak eklentiler | (boş) |

### JVM Ayarları

16GB RAM için optimize edilmiş ayarlar `docker-compose.yml` dosyasında:

```yaml
environment:
  - INITIAL_MEMORY=8G
  - MAXIMUM_MEMORY=12G
  - JAVA_OPTS=-XX:+UseG1GC -XX:MaxGCPauseMillis=200 ...
```

Farklı RAM yapılandırmaları için:

| Toplam RAM | INITIAL_MEMORY | MAXIMUM_MEMORY |
|------------|----------------|----------------|
| 8GB | 2G | 4G |
| 16GB | 8G | 12G |
| 32GB | 16G | 24G |
| 64GB | 32G | 48G |

## 📊 Kullanım

### Temel Docker Komutları

```powershell
# Container'ı başlat
docker-compose up -d

# Container'ı durdur
docker-compose stop

# Container'ı yeniden başlat
docker-compose restart

# Logları görüntüle
docker-compose logs -f

# Container'ı kaldır
docker-compose down

# Container durumunu kontrol et
docker-compose ps
```

### Sağlık Kontrolü

**Windows:**
```powershell
# Health check script'ini çalıştır
.\scripts\windows\health-check.ps1

# Admin şifresi ile REST API test et
.\scripts\windows\health-check.ps1 -AdminPassword "YourPassword" -Verbose
```

**Linux:**
```bash
# Health check script'ini çalıştır
./scripts/linux/health-check.sh

# Admin şifresi ile test et
ADMIN_PASSWORD="YourPassword" VERBOSE=true ./scripts/linux/health-check.sh
```

### Performans Testi

**Windows:**
```powershell
# WMS servisini test et (100 istek, 10 concurrent)
.\scripts\windows\performance-test.ps1 -TestType wms -Requests 100 -Concurrent 10

# WFS servisi için
.\scripts\windows\performance-test.ps1 -TestType wfs -Requests 50 -Concurrent 5
```

**Linux:**
```bash
# WMS servisini test et
TEST_TYPE=wms REQUESTS=100 CONCURRENT=10 ./scripts/linux/performance-test.sh

# WFS servisi için
TEST_TYPE=wfs REQUESTS=50 CONCURRENT=5 ./scripts/linux/performance-test.sh
```

## 🚀 Performans Optimizasyonu

Detaylı bilgi için [PERFORMANCE.md](docs/PERFORMANCE.md) dosyasına bakın.

### Önemli Noktalar

1. **JVM Heap**: Sistemdeki toplam RAM'in %50-75'i
2. **G1GC**: Düşük gecikme için G1 Garbage Collector kullanılır
3. **SSD Depolama**: `D:\geoserver_data` mutlaka SSD üzerinde olmalı
4. **Tile Cache**: GeoWebCache varsayılan olarak etkindir

### Eklenti Kurulumu

JAI-EXT gibi performans eklentileri için:

```bash
# .env dosyasına ekleyin
STABLE_EXTENSIONS=jai-ext,imagemosaic-jdbc-plugin,pyramid-plugin
```

## 🔒 Güvenlik

Detaylı bilgi için [SECURITY.md](docs/SECURITY.md) dosyasına bakın.

### Temel Güvenlik Adımları

1. **Admin Şifresini Değiştirin**
   
   İlk kurulumdan sonra GeoServer web arayüzünden:
   - Security → Users, Groups, Roles
   - Users → admin → Change Password

2. **HTTPS Yapılandırması**

   ```powershell
   # SSL sertifikası oluştur veya Let's Encrypt kullan
   # docker-compose.yml'de 8443 portunu aktif edin
   ```

3. **IP Kısıtlamaları**

   GeoServer admin panel → Security → Service Security

4. **Firewall Kuralları**

   ```powershell
   # Sadece belirli IP'lerden erişime izin ver
   New-NetFirewallRule -DisplayName "GeoServer HTTP" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow -RemoteAddress 192.168.1.0/24
   ```

## 📈 Monitoring

Detaylı bilgi için [MONITORING.md](docs/MONITORING.md) dosyasına bakın.

### Monitoring Stack'i Başlatma

```powershell
cd monitoring
docker-compose -f docker-compose.monitoring.yml up -d
```

### Erişim

- **Grafana**: [http://localhost:3000](http://localhost:3000) (admin/admin)
- **Prometheus**: [http://localhost:9090](http://localhost:9090)
- **cAdvisor**: [http://localhost:8081](http://localhost:8081)

### Metriklerin İzlenmesi

```powershell
# Container kaynak kullanımı
docker stats geoserver

# JVM metrikleri (JConsole ile)
jconsole localhost:8080
```

## 💾 Yedekleme ve Kurtarma

### Otomatik Yedekleme

**Windows:**
```powershell
# Sıkıştırılmış yedek oluştur (varsayılan)
.\scripts\windows\backup.ps1

# Container'ı durdurup yedek al
.\scripts\windows\backup.ps1 -StopContainer

# 60 günlük retention
.\scripts\windows\backup.ps1 -RetentionDays 60
```

**Linux:**
```bash
# Sıkıştırılmış yedek oluştur
./scripts/linux/backup.sh

# Container'ı durdurup yedek al
STOP_CONTAINER=true ./scripts/linux/backup.sh

# 60 günlük retention
RETENTION_DAYS=60 ./scripts/linux/backup.sh
```

### Manuel Yedekleme

```powershell
# Veri dizinini kopyala
Copy-Item -Path "D:\geoserver_data" -Destination "D:\backups\geoserver_$(Get-Date -Format 'yyyyMMdd')" -Recurse
```

### Geri Yükleme

```powershell
# Container'ı durdur
docker-compose stop

# Yedekten geri yükle
Remove-Item -Path "D:\geoserver_data\*" -Recurse -Force
Expand-Archive -Path "D:\geoserver_backups\geoserver_backup_TIMESTAMP.zip" -DestinationPath "D:\geoserver_data"

# Container'ı başlat
docker-compose start
```

### Zamanlanmış Yedekleme
### Container Başlamıyor

```powershell
# Logları kontrol edin
docker-compose logs geoserver

# Port kullanımda mı?
netstat -ano | findstr :8080

# Docker servisi çalışıyor mu?
Get-Service com.docker.service
```

### Yavaş Performans

```powershell
# JVM heap kullanımını kontrol edin
docker exec geoserver jstat -gc 1

# Disk I/O
Get-Counter "\PhysicalDisk(*)\Disk Transfers/sec"

# CPU kullanımı
docker stats geoserver --no-stream
```

### Veri Kalıcı Değil

```powershell
# Volume mount'u kontrol edin
docker inspect geoserver | findstr "Mounts" -A 10

# Veri dizini var mı?
Test-Path "D:\geoserver_data"
```

### Bağlantı Hataları

```powershell
# GeoServer'a erişim testi
curl http://localhost:8080/geoserver/web/

# Container içinden test
docker exec geoserver curl http://localhost:8080/geoserver/web/

# Firewall kuralları
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*8080*"}
```

## 📚 İleri Seviye

### Eklenti Yönetimi

```bash
# .env dosyasına ekleyin
STABLE_EXTENSIONS=wps-extension,css-plugin,importer-plugin,querylayer-plugin

# Container'ı yeniden başlatın
docker-compose up -d
```

### Cluster Kurulumu

Multiple GeoServer instances için `docker-compose.yml` dosyasını genişletin ve load balancer ekleyin.

### PostGIS Entegrasyonu

```yaml
# docker-compose.yml'ye ekleyin
services:
  postgis:
    image: postgis/postgis:latest
    environment:
      POSTGRES_PASSWORD: postgres
    volumes:
      - postgis-data:/var/lib/postgresql/data
```

## 🤝 Katkıda Bulunma

İyileştirme önerileri ve hata raporları için issue açabilirsiniz.

## 📄 Lisans

Bu proje MIT lisansı altında sunulmaktadır.

## 🔗 Kaynaklar

- [GeoServer Resmi Dokümantasyon](https://docs.geoserver.org/)
- [Kartoza Docker GeoServer](https://github.com/kartoza/docker-geoserver)
- [Docker Dokümantasyon](https://docs.docker.com/)
- [GeoServer Performance Tuning](https://docs.geoserver.org/stable/en/user/production/index.html)
