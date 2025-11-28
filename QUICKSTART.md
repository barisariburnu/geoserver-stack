# GeoServer Hızlı Başlangıç Kılavuzu

Windows x64 için Docker tabanlı yüksek performanslı GeoServer kurulumu.

## ⚡ 5 Dakikada Kurulum

### Adım 1: Environment Dosyasını Hazırlayın

```powershell
# Workspace dizinine gidin
cd D:\Workspace\geoserver

# .env dosyası oluşturun
Copy-Item .env.example .env

# .env dosyasını düzenleyin
notepad .env
```

> ⚠️ **ÖNEMLİ**: `GEOSERVER_ADMIN_PASSWORD` satırını bulun ve güçlü bir şifre girin!

```bash
# Bu satırı değiştirin:
GEOSERVER_ADMIN_PASSWORD=ChangeThisStrongPassword123!

# Örnek güçlü şifre:
GEOSERVER_ADMIN_PASSWORD=MySecur3Pa$$w0rd2024!
```

### Adım 2: Veri Dizinlerini Oluşturun

```powershell
# Veri ve yedek dizinleri
New-Item -ItemType Directory -Path "D:\geoserver_data" -Force
New-Item -ItemType Directory -Path "D:\geoserver_backups" -Force
```

### Adım 3: GeoServer'ı Başlatın

```powershell
# Docker container'ı başlat
docker-compose up -d

# Container'ın başladığını kontrol edin (30-60 saniye bekleyin)
docker-compose ps

# Logları izleyin
docker-compose logs -f geoserver
```

**Başlatma tamamlandığında göreceğiniz log:**
```
geoserver    | INFO: Server startup in [XXXX] milliseconds
```

### Adım 4: Erişimi Test Edin

```powershell
# Health check çalıştırın
.\scripts\health-check.ps1
```

**Tarayıcıda**: http://localhost:8080/geoserver

- **Kullanıcı Adı**: `admin` (veya .env'de değiştirdiyseniz o)
- **Şifre**: `.env` dosyasına girdiğiniz şifre

---

## ✅ Kurulum Başarılı Mı?

Aşağıdakileri görüyorsanız başarılı:

- ✓ Docker container çalışıyor (`docker ps | findstr geoserver`)
- ✓ Health check tüm testleri geçti
- ✓ Web arayüzüne erişebildiniz
- ✓ Admin panel girişi yapabildiniz
- ✓ WMS GetCapabilities yanıt veriyor

---

## 🎯 İlk Yapılacaklar

### 1. Admin Şifresini GeoServer'dan Değiştirin

1. Web arayüzüne giriş yapın
2. Sağ üst → `Security` → `Users, Groups, Roles`
3. `Users` sekmesi → `admin` kullanıcısına tıklayın
4. `Change password` → Yeni şifreyi girin

### 2. İlk Layer'ınızı Oluşturun

**Test için örnek shapefile:**

1. `Data` → `Stores` → `Add new Store`
2. Vector Data Sources → `Shapefile`
3. Workspace: `test` (yoksa oluşturun)
4. Shapefile location: Dosyanızın yolunu girin
5. `Save` → Sonra `Publish` layer'ı

### 3. GeoWebCache'i Test Edin

1. Layer'ınızı seçin
2. `Tile Caching` sekmesi
3. `Create a cached layer` → Varsayılan ayarlarla kaydedin
4. Preview'da tile generation'ı test edin

### 4. İlk Yedeğinizi Alın

```powershell
# Manuel yedek
.\scripts\backup.ps1

# Başarılıysa D:\geoserver_backups\ dizininde .zip dosyası görmelisiniz
```

---

## 🚀 Yararlı Komutlar

### Docker Yönetimi

```powershell
# Container'ı durdur
docker-compose stop

# Container'ı başlat
docker-compose start

# Container'ı yeniden başlat
docker-compose restart

# Logları görüntüle (son 100 satır)
docker-compose logs --tail=100 geoserver

# Logları canlı izle
docker-compose logs -f geoserver

# Container içine gir (debug için)
docker exec -it geoserver bash

# Container'ı tamamen kaldır
docker-compose down

# Container'ı images ile birlikte kaldır
docker-compose down --rmi all
```

### Sağlık Kontrolleri

```powershell
# Basit health check
.\scripts\health-check.ps1

# Admin credentials ile detaylı check
.\scripts\health-check.ps1 -AdminPassword "YourPassword" -Verbose

# Container stats
docker stats geoserver --no-stream

# Container inspect
docker inspect geoserver
```

### Performans Testleri

```powershell
# WMS servisi test (100 istek)
.\scripts\performance-test.ps1 -TestType wms -Requests 100 -Concurrent 10

# WFS servisi test
.\scripts\performance-test.ps1 -TestType wfs -Requests 50 -Concurrent 5

# REST API test
.\scripts\performance-test.ps1 -TestType rest -Requests 200 -Concurrent 20
```

### Yedekleme

```powershell
# Standart yedekleme (compressed)
.\scripts\backup.ps1

# Sıkıştırmasız yedekleme
.\scripts\backup.ps1 -Compress:$false

# Container'ı durdurup yedekle (data consistency için)
.\scripts\backup.ps1 -StopContainer

# Custom retention (örn. 90 gün)
.\scripts\backup.ps1 -RetentionDays 90
```

---

## 🔧 Yaygın Sorunlar ve Çözümleri

### Sorun: Container başlamıyor

```powershell
# Hata loglarını kontrol edin
docker-compose logs geoserver

# Port 8080 kullanımda mı?
netstat -ano | findstr :8080

# Docker servisi çalışıyor mu?
Get-Service com.docker.service
Restart-Service com.docker.service
```

### Sorun: "Permission denied" D:\geoserver_data

```powershell
# Dizin izinlerini kontrol edin
icacls "D:\geoserver_data"

# Everyone'a full control verin (geçici çözüm)
icacls "D:\geoserver_data" /grant Everyone:F /T
```

### Sorun: Yavaş performans

```powershell
# Memory kullanımını kontrol edin
docker stats geoserver

# JVM heap ayarlarını .env'den kontrol edin
# INITIAL_MEMORY ve MAXIMUM_MEMORY değerlerini sisteminize göre ayarlayın

# Container'ı yeniden başlatın
docker-compose restart
```

### Sorun: Web arayüzüne erişilemiyor

```powershell
# Container çalışıyor mu?
docker ps | findstr geoserver

# Health check sonucu nedir?
.\scripts\health-check.ps1

# Container içinden localhost test
docker exec geoserver curl http://localhost:8080/geoserver/web/

# Windows Firewall kontrol
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*8080*"}
```

---

## 📊 Monitoring Kurulumu (Opsiyonel)

### Prometheus + Grafana Stack

```powershell
# Monitoring dizinine gidin
cd monitoring

# Stack'i başlatın
docker-compose -f docker-compose.monitoring.yml up -d

# Kontrol edin
docker ps | findstr "prometheus\|grafana\|cadvisor"
```

**Erişim URL'leri:**
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090
- cAdvisor: http://localhost:8081

**İlk Giriş (Grafana):**
1. http://localhost:3000 → admin/admin ile giriş
2. Yeni şifre belirleyin
3. Sol menü → Dashboards → Import
4. Dashboard ID: `193` (Docker Container & Host Metrics)
5. Prometheus datasource seçin → Import

---

## 📚 Daha Fazla Bilgi

| Konu | Dosya | Açıklama |
|------|-------|----------|
| Genel Kullanım | [README.md](README.md) | Ana dokümantasyon |
| Performans | [docs/PERFORMANCE.md](docs/PERFORMANCE.md) | JVM tuning, caching, optimization |
| Güvenlik | [docs/SECURITY.md](docs/SECURITY.md) | HTTPS, RBAC, IP filtering |
| İzleme | [docs/MONITORING.md](docs/MONITORING.md) | Metrics, alerts, dashboards |

---

## 🆘 Yardım Almak

### Logları Kontrol Edin

```powershell
# Docker logs
docker-compose logs geoserver > geoserver-logs.txt

# GeoServer application logs
docker exec geoserver cat /opt/geoserver/data_dir/logs/geoserver.log
```

### Sistem Bilgileri Toplayın

```powershell
# System info
systeminfo > system-info.txt

# Docker info
docker info > docker-info.txt
docker version >> docker-info.txt

# Container stats
docker stats geoserver --no-stream > container-stats.txt
```

---

## ✨ Kurulum Tamamlandı!

GeoServer artık çalışıyor ve kullanıma hazır.

**Sonraki adımlar için**:
1. ✅ [README.md](README.md) - Detaylı kullanım rehberi
2. ✅ [docs/SECURITY.md](docs/SECURITY.md) - Güvenlik yapılandırması (ZORUNLU!)
3. ✅ [docs/PERFORMANCE.md](docs/PERFORMANCE.md) - Performans iyileştirmeleri
4. ✅ [docs/MONITORING.md](docs/MONITORING.md) - İzleme kurulumu

**Başarılar!** 🎉
